import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property string focusedScreenName: (
        CompositorService.isHyprland && typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor ? (Hyprland.focusedWorkspace.monitor.name || "") :
        CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.currentOutput ? NiriService.currentOutput : ""
    )

    readonly property bool isActive: true

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: powerIcon

                anchors.centerIn: parent
                name: "power_settings_new"
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.widgetTextColor
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            var process = Qt.createQmlObject(`
                                            import Quickshell.Io
                                            Process {
                                                command: ["dms", "ipc", "call", "powermenu", "toggle"]
                                                running: true
                                                stdout: StdioCollector {
                                                    onStreamFinished: {}
                                                }
                                            }
                                            `, root)            
        }
    }
}