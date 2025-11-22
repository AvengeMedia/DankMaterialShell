import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool compactMode: SettingsData.keyboardLayoutNameCompactMode
    property string currentLayout: {
        if (CompositorService.isNiri) {
            return NiriService.getCurrentKeyboardLayoutName()
        } else if (CompositorService.isDwl) {
            return DwlService.currentKeyboardLayout
        }
        return ""
    }
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
                    color: Theme.widgetTextColor
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
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
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
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
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
            } else if (CompositorService.isDwl) {
                Quickshell.execDetached(["mmsg", "-d", "switch_keyboard_layout"])
            }
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                updateLayout()
            }
        }
    }

    Component.onCompleted: {
        if (CompositorService.isHyprland) {
            updateLayout()
        }
    }

    function updateLayout() {
        if (CompositorService.isHyprland) {
            Proc.runCommand(null, ["hyprctl", "-j", "devices"], (output, exitCode) => {
                if (exitCode !== 0) {
                    root.currentLayout = "Unknown"
                    return
                }
                try {
                    const data = JSON.parse(output)
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true)
                    root.hyprlandKeyboard = mainKeyboard.name

                    if (mainKeyboard) {
    					const layout = mainKeyboard.layout
    					const variant = mainKeyboard.variant
    					const index = mainKeyboard.active_layout_index

                        if (root.compactMode && layout && variant && index !== undefined) {
    						const layouts = mainKeyboard.layout.split(",")
    						const variants = mainKeyboard.variant.split(",")
    						const index = mainKeyboard.active_layout_index
    						
    						if (layouts[index] && variants[index] !== undefined) {
    							if (variants[index] === "") {
    								root.currentLayout = layouts[index]
                                } else {
    								root.currentLayout = layouts[index] + "-" + variants[index]
                                }
                            } else {
    							root.currentLayout = "Unknown"
                            }
                        } else if (mainKeyboard && mainKeyboard.active_keymap) {
                            root.currentLayout = mainKeyboard.active_keymap
                        } else {
                            root.currentLayout = "Unknown"
                        }
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
