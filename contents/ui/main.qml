import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kitemmodels as KItemModels
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: bar

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Layout.fillWidth: Plasmoid.configuration.fillPanel
    Layout.fillHeight: true
    Layout.minimumWidth: menuButton.width + 4 * (iconSlot + itemGap) + divider.width
        + iconSlot + 3 * barRow.spacing
    Layout.preferredWidth: compactWidth
    Layout.maximumWidth: Plasmoid.configuration.fillPanel ? Infinity : compactWidth
    Layout.preferredHeight: 48

    readonly property int iconSlot: Math.max(24,
        Plasmoid.configuration.iconSize + Plasmoid.configuration.iconPadding)
    readonly property int itemGap: 1
    readonly property color indicatorColor: Plasmoid.configuration.overrideIndicatorColor
        ? Plasmoid.configuration.indicatorColor : Kirigami.Theme.highlightColor
    readonly property int pinnedVisibleSlots: Math.max(4, Plasmoid.configuration.pinnedSlots)
    readonly property int runningVisibleSlots: Math.max(1, Math.min(6, visibleRunningCount()))
    readonly property int compactWidth: menuButton.width + pinnedVisibleSlots * (iconSlot + itemGap)
        + divider.width + runningVisibleSlots * (iconSlot + itemGap) + 3 * barRow.spacing
    readonly property int menuColumns: pinnedVisibleSlots
    property int activeStack: 0
    property var stackMap: ({})
    property var previewEntries: []
    property Item previewAnchor: null
    property int previewRow: -1
    property bool previewReady: false
    property alias previewCloseControl: previewCloseTimer

    Component.onCompleted: {
        loadStackAssignments()
    }

    Connections {
        target: Plasmoid.configuration
        function onStackAssignmentsChanged() { bar.loadStackAssignments() }
        function onStackCountChanged() {
            if (bar.activeStack >= Plasmoid.configuration.stackCount)
                bar.activeStack = Math.max(0, Plasmoid.configuration.stackCount - 1)
        }
    }

    function loadStackAssignments() {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.stackAssignments || "{}")
            stackMap = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({})
        } catch (e) {
            stackMap = ({})
        }
    }

    function launcherKey(url) {
        if (!url) return ""
        const position = tasksModel.launcherPosition(url)
        return position >= 0 ? String(tasksModel.launcherList[position]) : String(url)
    }

    function stackFor(url) {
        const key = launcherKey(url)
        const stored = Number(stackMap[key] || 0)
        return Math.max(0, Math.min(Plasmoid.configuration.stackCount - 1, stored))
    }

    function showStack(index) {
        const count = Math.max(1, Plasmoid.configuration.stackCount)
        activeStack = (index + count) % count
        pinnedFlick.contentX = 0
    }

    function visibleRunningCount() {
        const launcherList = tasksModel.launcherList
        let count = 0
        for (let i = 0; i < tasksModel.count; ++i) {
            const idx = tasksModel.makeModelIndex(i)
            if ((tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                || tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent))
                && !isPinned(tasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon))) ++count
        }
        return count
    }

    function isPinned(url) {
        // Reading the list keeps QML bindings up to date after a pin/unpin.
        if (tasksModel.launcherList.length === 0) return false
        return url && tasksModel.launcherPosition(url) >= 0
    }

    function runningIndexFor(url) {
        if (!url) return -1
        const launcherPosition = tasksModel.launcherPosition(url)
        if (launcherPosition < 0) return -1
        for (let i = 0; i < tasksModel.count; ++i) {
            const idx = tasksModel.makeModelIndex(i)
            if ((tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                || tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent))
                && tasksModel.launcherPosition(tasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)) === launcherPosition) {
                return i
            }
        }
        return -1
    }

    function isTaskActive(row) {
        const currentActiveTask = tasksModel.activeTask
        return tasksModel.data(tasksModel.makeModelIndex(row), TaskManager.AbstractTasksModel.IsActive)
    }

    function activateTask(row) {
        const idx = tasksModel.makeModelIndex(row)
        if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent)) {
            openPreview(previewAnchor, row)
            return
        }
        if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive)) {
            tasksModel.requestToggleMinimized(idx)
        } else {
            tasksModel.requestActivate(idx)
        }
    }

    function activatePinned(url, launcherRow) {
        const row = runningIndexFor(url)
        if (row >= 0) {
            activateTask(row)
        } else {
            tasksModel.requestActivate(tasksModel.makeModelIndex(launcherRow))
        }
    }

    function pinLauncher(url) {
        if (!url) return
        if (!isPinned(url)) tasksModel.requestAddLauncher(url)
        const key = launcherKey(url)
        if (key) {
            const next = Object.assign({}, stackMap)
            next[key] = activeStack
            stackMap = next
            Plasmoid.configuration.stackAssignments = JSON.stringify(next)
            Qt.callLater(() => pinnedFlick.contentX = Math.max(0, pinnedFlick.contentWidth - pinnedFlick.width))
        }
    }

    function unpinLauncher(url) {
        if (!url || !isPinned(url)) return
        const key = launcherKey(url)
        tasksModel.requestRemoveLauncher(url)
        const next = Object.assign({}, stackMap)
        delete next[key]
        stackMap = next
        Plasmoid.configuration.stackAssignments = JSON.stringify(next)
    }

    function dismissPreview() {
        previewLoadTimer.stop()
        previewCloseTimer.stop()
        previewDialog.visible = false
        previewReady = false
        taskBackend.cancelHighlightWindows()
    }

    function allowTaskHover() {
        if (!appDialog.visible) return true
        if (!Plasmoid.configuration.closeMenuOnTaskHover) return false
        appDialog.visible = false
        return true
    }

    function windowCount(row) {
        if (row < 0) return 0
        const idx = tasksModel.makeModelIndex(row)
        return tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent)
            ? tasksModel.rowCount(idx) : 1
    }

    function closeTask(row) {
        if (row < 0) return
        tasksModel.requestClose(tasksModel.makeModelIndex(row))
    }

    function openPreview(anchor, row) {
        if (!anchor || row < 0) return
        taskBackend.cancelHighlightWindows()
        previewAnchor = anchor
        previewRow = row
        const parentIndex = tasksModel.makeModelIndex(row)
        const grouped = tasksModel.data(parentIndex, TaskManager.AbstractTasksModel.IsGroupParent)
        const count = grouped ? tasksModel.rowCount(parentIndex) : 1
        let entries = []
        for (let i = 0; i < count; ++i) {
            const idx = grouped ? tasksModel.makeModelIndex(row, i) : parentIndex
            const ids = tasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList) || []
            const minimized = Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized))
            entries.push({
                row: row, child: grouped ? i : -1,
                title: String(tasksModel.data(idx, Qt.DisplayRole) || "Finestra"),
                icon: tasksModel.data(idx, Qt.DecorationRole),
                winId: ids.length ? ids[0] : undefined,
                minimized: minimized
            })
        }
        previewEntries = entries
        previewDialog.visible = entries.length > 0
        previewGrid.currentIndex = 0
        previewLoadTimer.restart()
        previewCloseTimer.stop()
    }

    function activatePreviewEntry(entry) {
        const idx = entry.child >= 0 ? tasksModel.makeModelIndex(entry.row, entry.child)
            : tasksModel.makeModelIndex(entry.row)
        tasksModel.requestActivate(idx)
        taskBackend.cancelHighlightWindows()
        previewDialog.visible = false
    }

    TaskManager.TasksModel {
        id: tasksModel
        property bool launchersReady: false
        sortMode: TaskManager.TasksModel.SortManual
        groupMode: Plasmoid.configuration.groupApplications
            ? TaskManager.TasksModel.GroupApplications : TaskManager.TasksModel.GroupDisabled
        separateLaunchers: true
        hideActivatedLaunchers: false
        launchInPlace: false
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByScreen: Plasmoid.configuration.scopeScreens === 1
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByVirtualDesktop: Plasmoid.configuration.scopeDesktops === 1
        activity: activityInfo.currentActivity
        filterByActivity: Plasmoid.configuration.scopeActivities === 1

        onLauncherListChanged: {
            if (launchersReady) Plasmoid.configuration.launchers = launcherList
        }
        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers
            launchersReady = true
        }
    }

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManagerApplet.Backend {
        id: taskBackend
        highlightWindows: true
    }
    Mpris.Mpris2Model { id: mprisModel }
    property alias backend: taskBackend
    property alias mediaModel: mprisModel

    Kicker.RootModel {
        id: applications
        property var allApplicationsModel: null
        autoPopulate: false
        appletInterface: bar
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false

        onRefreshed: allApplicationsModel = modelForRow(0)
        Component.onCompleted: refresh()
    }

    KItemModels.KSortFilterProxyModel {
        id: searchedApplications
        sourceModel: applications.allApplicationsModel
        filterRoleName: "display"
        filterCaseSensitivity: Qt.CaseInsensitive
        filterString: appSearch.text
    }

    Row {
        id: barRow
        anchors.fill: parent
        spacing: 1

        Item {
            id: menuButton
            width: Math.max(17, Math.min(22, Math.round(bar.iconSlot * 0.52)))
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 3
                height: parent.width - 3
                radius: 4
                color: menuMouse.containsMouse ? Kirigami.Theme.highlightColor : "transparent"
                opacity: 0.18
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 13
                height: 13
                source: "go-up"
                rotation: appDialog.visible ? 180 : 0
            }
            PlasmaComponents3.Label {
                visible: Plasmoid.configuration.stackCount > 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                text: (bar.activeStack + 1) + "/" + Plasmoid.configuration.stackCount
                font.pixelSize: 9
            }
            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                mainText: Plasmoid.configuration.stackCount > 1
                    ? "Tutte le applicazioni · stack " + (bar.activeStack + 1)
                    : "Tutte le applicazioni"
                location: Plasmoid.location
            }
            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    bar.dismissPreview()
                    appDialog.visible = !appDialog.visible
                }
            }
        }

        Flickable {
            id: pinnedFlick
            width: bar.pinnedVisibleSlots * (bar.iconSlot + bar.itemGap)
            height: parent.height
            contentWidth: pinnedRow.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: pinnedRow
                height: parent.height
                spacing: bar.itemGap
                Repeater {
                    model: tasksModel
                    delegate: TaskIcon {
                        required property var model
                        required property int index
                        taskData: model
                        taskIndex: index
                        pinned: true
                        taskbar: bar
                        sourceModel: tasksModel
                    }
                }
            }
            WheelHandler {
                target: null
                onWheel: event => {
                    const delta = event.angleDelta.y || event.angleDelta.x
                    if (Plasmoid.configuration.stackCount > 1) {
                        bar.showStack(bar.activeStack + (delta < 0 ? 1 : -1))
                    } else {
                        pinnedFlick.contentX = Math.max(0, Math.min(pinnedFlick.contentWidth - pinnedFlick.width,
                            pinnedFlick.contentX - delta / 3))
                    }
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: divider
            width: 2
            height: Math.max(18, parent.height - 16)
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: Kirigami.Theme.textColor
            opacity: 0.55
        }

        Flickable {
            id: runningFlick
            width: Math.max(0, bar.width - menuButton.width - pinnedFlick.width
                - divider.width - 3 * barRow.spacing)
            height: parent.height
            contentWidth: runningRow.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: runningRow
                height: parent.height
                spacing: bar.itemGap
                Repeater {
                    model: tasksModel
                    delegate: TaskIcon {
                        required property var model
                        required property int index
                        taskData: model
                        taskIndex: index
                        pinned: false
                        taskbar: bar
                        sourceModel: tasksModel
                    }
                }
            }
            WheelHandler {
                target: null
                onWheel: event => {
                    runningFlick.contentX = Math.max(0, Math.min(runningFlick.contentWidth - runningFlick.width,
                        runningFlick.contentX - (event.angleDelta.y || event.angleDelta.x) / 3))
                    event.accepted = true
                }
            }
        }

    }

    PlasmaCore.Dialog {
        id: appDialog
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: menuButton
        onVisibleChanged: {
            if (visible) {
                appSearch.forceActiveFocus()
            }
            else appSearch.text = ""
        }

        mainItem: Item {
            width: Math.min(Screen.width * 0.8,
                pinnedFlick.width + 2 * (menuButton.width + barRow.spacing))
            height: Math.min(500, Screen.height * 0.66)
            focus: true
            Keys.onEscapePressed: appDialog.visible = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    PlasmaComponents3.Label {
                        text: Plasmoid.configuration.stackCount > 1
                            ? "Applicazioni · " + (bar.activeStack + 1) + "/" + Plasmoid.configuration.stackCount
                            : "Tutte le applicazioni"
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        elide: Text.ElideRight
                    }
                    PlasmaComponents3.ToolButton {
                        visible: Plasmoid.configuration.stackCount > 1
                        icon.name: "go-previous"
                        onClicked: bar.showStack(bar.activeStack - 1)
                    }
                    PlasmaComponents3.ToolButton {
                        visible: Plasmoid.configuration.stackCount > 1
                        icon.name: "go-next"
                        onClicked: bar.showStack(bar.activeStack + 1)
                    }
                }

                PlasmaComponents3.TextField {
                    id: appSearch
                    Layout.fillWidth: true
                    placeholderText: "Cerca un'applicazione…"
                    clearButtonShown: true
                    Keys.onEscapePressed: appDialog.visible = false
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: appsGrid
                        x: (appDialog.mainItem.width - width) / 2 - 8
                        width: pinnedFlick.width
                        height: parent.height
                        model: searchedApplications
                        clip: true
                        cellWidth: bar.iconSlot + bar.itemGap
                        cellHeight: 72

                        QQC2.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                            parent: appsGrid.parent
                            x: appsGrid.x + appsGrid.width + 4
                            y: appsGrid.y
                            height: appsGrid.height
                            width: 5
                            policy: QQC2.ScrollBar.AsNeeded
                        }

                        delegate: Item {
                            id: appItem
                            width: appsGrid.cellWidth
                            height: appsGrid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 5
                                color: appMouse.containsMouse ? Kirigami.Theme.highlightColor : "transparent"
                                opacity: 0.2
                            }
                            Kirigami.Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 9
                                width: Math.min(28, appItem.width - 8)
                                height: width
                                source: model.decoration
                            }
                            PlasmaComponents3.Label {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                horizontalAlignment: Text.AlignHCenter
                                text: model.display
                                elide: Text.ElideRight
                                font.pixelSize: 9
                            }
                            PlasmaCore.ToolTipArea {
                                anchors.fill: parent
                                mainText: model.display
                                location: Plasmoid.location
                            }
                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    const originalIndex = searchedApplications.mapToSource(searchedApplications.index(index, 0))
                                    applications.allApplicationsModel.trigger(originalIndex.row, "", null)
                                    appDialog.visible = false
                                }
                            }
                            Kirigami.Icon {
                                id: pinButton
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                width: Math.min(12, appItem.width / 3)
                                height: width
                                source: bar.isPinned(model.url) && bar.stackFor(model.url) === bar.activeStack
                                    ? "list-remove" : "list-add"
                                opacity: pinMouse.containsMouse ? 1 : 0.65
                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (bar.isPinned(model.url) && bar.stackFor(model.url) === bar.activeStack)
                                            bar.unpinLauncher(model.url)
                                        else bar.pinLauncher(model.url)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: previewLoadTimer
        interval: 180
        onTriggered: bar.previewReady = true
    }
    Timer {
        id: previewCloseTimer
        interval: 350
        onTriggered: previewDialog.visible = false
    }

    PlasmaCore.Dialog {
        id: previewDialog
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        location: Plasmoid.location
        visualParent: bar.previewAnchor
        onVisibleChanged: {
            if (!visible) {
                previewLoadTimer.stop()
                bar.previewReady = false
                taskBackend.cancelHighlightWindows()
            }
        }

        mainItem: Item {
            width: Math.min(Screen.width * 0.8, Math.max(196, Math.min(4, bar.previewEntries.length) * 182 + 14))
            height: Math.min(Screen.height * 0.55,
                Math.ceil(bar.previewEntries.length / Math.max(1, Math.floor(width / 182))) * 155 + 14)
            Keys.onEscapePressed: previewDialog.visible = false

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) previewCloseTimer.stop()
                    else previewCloseTimer.restart()
                }
            }

            GridView {
                id: previewGrid
                anchors.fill: parent
                anchors.margins: 7
                clip: true
                cellWidth: 182
                cellHeight: 155
                cacheBuffer: 0
                model: bar.previewEntries

                delegate: Item {
                    id: previewCard
                    required property var modelData
                    required property int index
                    width: previewGrid.cellWidth
                    height: previewGrid.cellHeight

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) previewGrid.currentIndex = index
                            if (modelData.winId !== undefined)
                                taskBackend.windowsHovered([modelData.winId], hovered)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 9
                        color: Kirigami.Theme.backgroundColor
                        opacity: 0.72
                        border.width: 1
                        border.color: Kirigami.Theme.highlightColor
                    }
                    WindowPreview {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: titleLabel.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: 9
                        windowId: modelData.winId
                        icon: modelData.icon
                        minimized: modelData.minimized
                        active: bar.previewReady && previewDialog.visible
                            && previewCard.y + previewCard.height > previewGrid.contentY
                            && previewCard.y < previewGrid.contentY + previewGrid.height
                    }
                    PlasmaComponents3.Label {
                        id: titleLabel
                        anchors.left: parent.left
                        anchors.right: closeButton.left
                        anchors.top: parent.top
                        anchors.margins: 9
                        height: 20
                        text: modelData.title
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 27
                        onClicked: bar.activatePreviewEntry(modelData)
                    }
                    Kirigami.Icon {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: titleLabel.verticalCenter
                        width: 16
                        height: 16
                        source: "window-close"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const ix = modelData.child >= 0
                                    ? tasksModel.makeModelIndex(modelData.row, modelData.child)
                                    : tasksModel.makeModelIndex(modelData.row)
                                tasksModel.requestClose(ix)
                                previewDialog.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
