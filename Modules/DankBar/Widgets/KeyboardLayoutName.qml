import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property string currentLayout: ""
    property string hyprlandKeyboard: ""

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: contentColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "keyboard"
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (!root.currentLayout) return ""
                        const parts = root.currentLayout.split(" ")
                        if (parts.length > 0) {
                            return parts[0].substring(0, 2).toUpperCase()
                        }
                        return root.currentLayout.substring(0, 2).toUpperCase()
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingS

                StyledText {
                    text: root.currentLayout
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (CompositorService.isNiri) {
                NiriService.cycleKeyboardLayout()
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached([
                    "hyprctl",
                    "switchxkblayout",
                    root.hyprlandKeyboard,
                    "next"
                ])
                updateLayout()
            }
        }
    }

    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            updateLayout()
        }
    }

    Component.onCompleted: {
        updateLayout()
    }

    function updateLayout() {
        if (CompositorService.isNiri) {
            root.currentLayout = NiriService.getCurrentKeyboardLayoutName()
        } else if (CompositorService.isHyprland) {
            Proc.runCommand(null, ["hyprctl", "-j", "devices"], (output, exitCode) => {
                if (exitCode !== 0) {
                    root.currentLayout = "Unknown"
                    return
                }
                try {
                    const data = JSON.parse(output)
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true)
                    root.hyprlandKeyboard = mainKeyboard.name
                    if (mainKeyboard && mainKeyboard.active_keymap) {
                        root.currentLayout = mainKeyboard.active_keymap
                    } else {
                        root.currentLayout = "Unknown"
                    }
                } catch (e) {
                    root.currentLayout = "Unknown"
                }
            })
        }
    }
}
