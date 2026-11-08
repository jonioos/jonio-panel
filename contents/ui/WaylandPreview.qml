import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

PipeWire.PipeWireSourceItem {
    id: sourceItem
    property string windowId: ""
    nodeId: screencast.nodeId

    TaskManager.ScreencastingRequest {
        id: screencast
        uuid: sourceItem.windowId
    }
}
