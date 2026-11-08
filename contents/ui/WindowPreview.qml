import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: preview
    required property var windowId
    required property var icon
    required property bool minimized
    required property bool active

    clip: true

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(48, parent.width / 3)
        height: width
        source: preview.icon
    }

    Loader {
        anchors.fill: parent
        active: preview.active && !preview.minimized && Number.isInteger(preview.windowId)
        asynchronous: true
        sourceComponent: x11Preview
    }

    Loader {
        anchors.fill: parent
        active: preview.active && preview.windowId !== undefined
            && !Number.isInteger(preview.windowId)
        asynchronous: true
        source: "WaylandPreview.qml"
        onLoaded: if (item) item.windowId = String(preview.windowId)
    }

    Component {
        id: x11Preview
        PlasmaCore.WindowThumbnail {
            winId: preview.windowId
        }
    }
}
