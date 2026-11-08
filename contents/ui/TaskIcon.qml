import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager

Item {
    id: button

    required property var taskData
    required property int taskIndex
    required property bool pinned
    required property var taskbar
    required property var sourceModel

    readonly property bool shown: pinned
        ? Boolean(taskData.IsLauncher)
            && taskbar.stackFor(taskData.LauncherUrlWithoutIcon) === taskbar.activeStack
        : (Boolean(taskData.IsWindow) || Boolean(taskData.IsGroupParent))
            && !taskbar.isPinned(taskData.LauncherUrlWithoutIcon)
    readonly property int runningIndex: pinned ? taskbar.runningIndexFor(taskData.LauncherUrlWithoutIcon) : taskIndex
    readonly property bool running: runningIndex >= 0
    readonly property bool active: running && taskbar.isTaskActive(runningIndex)
    readonly property int extent: taskbar.iconSlot
    readonly property int openCount: running
        ? taskbar.windowCount(runningIndex, taskbar.taskRevision) : 0
    readonly property var player: taskbar.mediaModel.playerForLauncherUrl(
        taskData.LauncherUrlWithoutIcon, taskData.AppPid || 0)
    property var generatedMenuItems: []
    property bool menuOpen: false
    property bool draggingPinned: false
    property bool pinDragPending: false
    property bool pinDragActive: false
    property bool pinDragHoldReady: false
    property bool suppressNextClick: false
    property point pinDragStart: Qt.point(0, 0)

    visible: shown
    width: shown ? extent : 0
    height: taskbar.height
    onXChanged: if (taskbar) taskbar.scheduleGeometryPublish()
    onYChanged: if (taskbar) taskbar.scheduleGeometryPublish()
    onVisibleChanged: if (taskbar) taskbar.scheduleGeometryPublish()
    onWidthChanged: if (taskbar) taskbar.scheduleGeometryPublish()
    z: draggingPinned ? 20 : 0
    transform: Translate {
        x: !button.pinned ? 0 : button.draggingPinned
            ? button.taskbar.pinnedDragOffset
            : button.taskbar.pinnedShift(button.taskData.LauncherUrlWithoutIcon)
        Behavior on x {
            enabled: !button.draggingPinned
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(button.extent - 2, button.height - 4)
        height: width
        radius: 4
        color: pointer.containsMouse || button.active ? Kirigami.Theme.highlightColor : "transparent"
        opacity: button.draggingPinned ? 0.36 : (button.active ? 0.24 : 0.14)
        scale: button.draggingPinned ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(button.taskbar.plasmoid.configuration.iconSize, button.height - 10)
        height: width
        source: button.taskData.decoration
    }

    Row {
        visible: button.running || opacity > 0
        opacity: button.running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 170 } }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        spacing: 3

        Repeater {
            model: button.taskbar.plasmoid.configuration.indicatorStyle === 2
                ? Math.min(5, button.openCount) : 1
            delegate: Rectangle {
                width: button.taskbar.plasmoid.configuration.indicatorStyle === 0
                    ? (button.active ? 17 : 9) : 4
                height: button.taskbar.plasmoid.configuration.indicatorStyle === 0 ? 3 : 4
                radius: height / 2
                color: button.taskbar.indicatorColor
                opacity: button.active ? 1 : 0.72
            }
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: !button.running || !button.taskbar.plasmoid.configuration.showPreviews
        mainText: button.taskData.AppName || button.taskData.display || "Applicazione"
        subText: button.openCount > 1 ? button.openCount + " finestre" :
            (button.pinned ? (button.running ? "Attiva" : "Avvia") : "Attiva · clic centrale per chiudere")
        location: button.taskbar.plasmoid.location
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: button.pinned
        cursorShape: button.pinDragHoldReady || button.pinDragActive
            ? Qt.SizeAllCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onWheel: wheel => {
            if (button.pinned) {
                button.taskbar.wheelPinned(wheel.angleDelta.y || wheel.angleDelta.x
                    || wheel.pixelDelta.y || wheel.pixelDelta.x)
                wheel.accepted = true
            } else {
                wheel.accepted = false
            }
        }

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton && button.pinned && button.shown) {
                button.taskbar.pinnedPressActive = true
                hoverPreviewTimer.stop()
                button.taskbar.dismissPreview()
                button.pinDragStart = Qt.point(mouse.x, mouse.y)
                button.pinDragPending = true
                button.pinDragActive = false
                button.pinDragHoldReady = false
                button.suppressNextClick = false
                button.taskbar.setPanelDragInhibited(true)
                pinCursorDelay.restart()
            }
        }
        onPositionChanged: mouse => {
            if (!button.pinDragPending || !(mouse.buttons & Qt.LeftButton)) return
            const dx = mouse.x - button.pinDragStart.x
            const dy = mouse.y - button.pinDragStart.y
            const threshold = 6
            if (!button.pinDragActive && Math.sqrt(dx * dx + dy * dy) >= threshold) {
                button.pinDragActive = true
                button.pinDragHoldReady = true
                pinCursorDelay.stop()
                button.draggingPinned = true
                hoverPreviewTimer.stop()
                button.taskbar.dismissPreview()
                button.taskbar.beginPinnedDrag(button.taskData.LauncherUrlWithoutIcon,
                    pointer, button.pinDragStart.x, button.pinDragStart.y)
            }
            if (button.pinDragActive)
                button.taskbar.updatePinnedDrop(pointer, mouse.x, mouse.y)
        }
        onReleased: mouse => {
            pinCursorDelay.stop()
            let targetIndex = -1
            let targetKey = ""
            let sourceUrl = ""
            if (button.pinDragActive) {
                button.taskbar.updatePinnedDrop(pointer, mouse.x, mouse.y)
                targetIndex = button.taskbar.pinnedDropIndex
                targetKey = button.taskbar.pinnedDragKeys[targetIndex] || ""
                sourceUrl = button.taskData.LauncherUrlWithoutIcon
                button.suppressNextClick = true
            } else if (button.pinDragHoldReady) {
                button.suppressNextClick = true
            }
            if (targetKey)
                button.taskbar.movePinnedLauncher(sourceUrl, targetKey)
            button.pinDragPending = false
            button.pinDragActive = false
            button.pinDragHoldReady = false
            button.draggingPinned = false
            button.taskbar.pinnedPressActive = false
            button.taskbar.endPinnedDrag()
        }
        onCanceled: {
            pinCursorDelay.stop()
            const targetIndex = button.pinDragActive ? button.taskbar.pinnedDropIndex : -1
            const targetKey = button.taskbar.pinnedDragKeys[targetIndex] || ""
            const sourceUrl = button.taskData.LauncherUrlWithoutIcon
            if (targetKey)
                button.taskbar.movePinnedLauncher(sourceUrl, targetKey)
            button.taskbar.endPinnedDrag()
            button.pinDragPending = false
            button.pinDragActive = false
            button.pinDragHoldReady = false
            button.draggingPinned = false
            button.taskbar.pinnedPressActive = false
        }
        onEntered: {
            button.taskbar.previewCloseControl.stop()
            if (!button.taskbar.allowTaskHover()) return
            if (!button.taskbar.pinnedPressActive && !button.menuOpen && button.running
                && button.taskbar.plasmoid.configuration.showPreviews)
                hoverPreviewTimer.restart()
        }
        onExited: {
            hoverPreviewTimer.stop()
            button.taskbar.previewCloseControl.restart()
        }

        onClicked: mouse => {
            if (button.suppressNextClick) {
                button.suppressNextClick = false
                return
            }
            if (mouse.button === Qt.RightButton) {
                button.showContextMenu()
            } else if (mouse.button === Qt.MiddleButton) {
                if (button.running) {
                    button.sourceModel.requestClose(button.sourceModel.makeModelIndex(button.runningIndex))
                }
            } else if (button.pinned) {
                button.taskbar.previewAnchor = button
                button.taskbar.activatePinned(button.taskData.LauncherUrlWithoutIcon, button.taskIndex)
            } else {
                button.taskbar.previewAnchor = button
                button.taskbar.activateTask(button.taskIndex)
            }
        }
    }

    Timer {
        id: pinCursorDelay
        interval: 300
        onTriggered: if (button.pinDragPending) button.pinDragHoldReady = true
    }

    Timer {
        id: hoverPreviewTimer
        interval: button.taskbar.plasmoid.configuration.previewDelay
        onTriggered: if (!button.pinDragPending && !button.draggingPinned)
            button.taskbar.openPreview(button, button.runningIndex)
    }

    Timer {
        id: contextOpenTimer
        interval: 100
        onTriggered: button.openTaskMenu()
    }

    function showContextMenu() {
        hoverPreviewTimer.stop()
        taskbar.dismissPreview()
        menuOpen = true
        contextOpenTimer.restart()
    }

    function openTaskMenu() {
        for (const item of generatedMenuItems) item.destroy()
        generatedMenuItems = []
        const url = taskData.LauncherUrlWithoutIcon
        const actions = taskbar.backend.placesActions(url, true, taskMenu)
            .concat(taskbar.backend.jumpListActions(url, taskMenu))
        for (const action of actions) {
            if (typeof action === "string") continue
            const item = dynamicActionComponent.createObject(taskMenu, {action: action})
            if (item) {
                taskMenu.addMenuItem(item, pinItem)
                generatedMenuItems.push(item)
            }
        }
        taskMenu.openRelative()
    }

    Component {
        id: dynamicActionComponent
        PlasmaExtras.MenuItem {}
    }

    PlasmaExtras.Menu {
        id: taskMenu
        visualParent: button
        minimumWidth: button.width
        placement: {
            const edge = button.taskbar.plasmoid.location
            if (edge === PlasmaCore.Types.TopEdge) return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
            if (edge === PlasmaCore.Types.LeftEdge) return PlasmaExtras.Menu.RightPosedTopAlignedPopup
            if (edge === PlasmaCore.Types.RightEdge) return PlasmaExtras.Menu.LeftPosedTopAlignedPopup
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        }
        onStatusChanged: {
            if (status === PlasmaExtras.Menu.Closed) button.menuOpen = false
        }

        PlasmaExtras.MenuItem {
            icon: "window-new"
            text: "Apri una nuova finestra"
            onClicked: button.sourceModel.requestNewInstance(button.sourceModel.makeModelIndex(button.taskIndex))
        }
        PlasmaExtras.MenuItem {
            id: pinItem
            icon: button.pinned ? "list-remove" : "list-add"
            text: button.pinned ? "Rimuovi dalle app fissate" : "Fissa alla barra"
            onClicked: {
                if (button.pinned) {
                    button.taskbar.unpinLauncher(button.taskData.LauncherUrlWithoutIcon)
                } else {
                    button.taskbar.pinLauncher(button.taskData.LauncherUrlWithoutIcon)
                }
            }
        }
        PlasmaExtras.MenuItem {
            visible: button.player && (button.player.canPlay || button.player.canPause)
            icon: button.player && button.player.playbackStatus === Mpris.PlaybackStatus.Playing
                ? "media-playback-pause" : "media-playback-start"
            text: button.player && button.player.playbackStatus === Mpris.PlaybackStatus.Playing
                ? "Pausa" : "Riproduci"
            onClicked: {
                if (!button.player) return
                if (button.player.playbackStatus === Mpris.PlaybackStatus.Playing) button.player.Pause()
                else button.player.Play()
            }
        }
        PlasmaExtras.MenuItem {
            visible: button.player && button.player.canGoPrevious
            icon: "media-skip-backward"
            text: "Traccia precedente"
            onClicked: if (button.player) button.player.Previous()
        }
        PlasmaExtras.MenuItem {
            visible: button.player && button.player.canGoNext
            icon: "media-skip-forward"
            text: "Traccia successiva"
            onClicked: if (button.player) button.player.Next()
        }
        PlasmaExtras.MenuItem {
            visible: button.running
            icon: "window-close"
            text: button.openCount > 1 ? "Chiudi tutte le finestre" : "Chiudi finestra"
            onClicked: button.sourceModel.requestClose(button.sourceModel.makeModelIndex(button.runningIndex))
        }
    }
}
