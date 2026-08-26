import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "../../../DankCommon/Common/LayoutCodes.js" as LayoutCodes

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: widgetData?.keyboardLayoutNameCompactMode !== undefined ? widgetData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode
    property bool showIcon: widgetData?.keyboardLayoutNameShowIcon !== undefined ? widgetData.keyboardLayoutNameShowIcon : SettingsData.keyboardLayoutNameShowIcon
    readonly property var validVariants: ["US", "UK", "GB", "AZERTY", "QWERTY", "Dvorak", "Colemak", "Mac", "Intl", "International"]
    property string currentLayout: {
        if (CompositorService.isNiri) {
            return NiriService.getCurrentKeyboardLayoutName();
        } else if (CompositorService.isMango) {
            return MangoService.currentKeyboardLayout;
        }
        return "";
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
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showIcon
                }

                StyledText {
                    text: {
                        return LayoutCodes.layoutCode(root.currentLayout);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "keyboard"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcon
                }

                StyledText {
                    text: {
                        if (!root.currentLayout)
                            return "";
                        if (root.compactMode && !CompositorService.isHyprland) {
                            const match = root.currentLayout.match(/^(\S+)(?:.*\(([^)]+)\))?/);
                            if (match) {
                                const lang = match[1].toLowerCase();
                                const code = LayoutCodes.LANG_CODES[lang] || lang.substring(0, 2);
                                if (match[2]) {
                                    const variant = match[2].trim();
                                    const isValid = root.validVariants.some(v => variant.toUpperCase().includes(v.toUpperCase())) || variant.length <= 3;
                                    if (isValid)
                                        return code + "-" + variant;
                                }
                                return code.toUpperCase();
                            }
                            return LayoutCodes.layoutCode(root.currentLayout);
                        }
                        return root.currentLayout;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        z: 1
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
        }
        onClicked: {
            if (CompositorService.isNiri) {
                NiriService.cycleKeyboardLayout();
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", root.hyprlandKeyboard, "next"]);
            } else if (CompositorService.isMango) {
                MangoService.cycleKeyboardLayout();
            } else if (CompositorService.isSway) {
                I3.dispatch("input type:keyboard xkb_switch_layout next");
            }
        }
    }

    Loader {
        active: CompositorService.isSway
        sourceComponent: I3IpcListener {
            subscriptions: ["input"]
            onIpcEvent: event => {
                if (event.type !== "input")
                    return;
                try {
                    const payload = JSON.parse(event.data);
                    if (payload.change !== "xkb_layout")
                        return;
                    const name = payload.input?.xkb_active_layout_name;
                    if (name)
                        root.currentLayout = name;
                } catch (e) {}
            }
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                updateLayout();
            }
        }
    }

    Component.onCompleted: {
        if (CompositorService.isHyprland || CompositorService.isSway) {
            updateLayout();
        }
    }

    function updateLayout() {
        if (CompositorService.isSway) {
            Proc.runCommand(null, ["swaymsg", "-t", "get_inputs", "-r"], (output, exitCode) => {
                if (exitCode !== 0)
                    return;
                try {
                    const inputs = JSON.parse(output);
                    const kb = inputs.find(i => i.type === "keyboard" && i.xkb_active_layout_name);
                    if (kb)
                        root.currentLayout = kb.xkb_active_layout_name;
                } catch (e) {}
            });
            return;
        }
        if (CompositorService.isHyprland) {
            Proc.runCommand(null, ["hyprctl", "-j", "devices"], (output, exitCode) => {
                if (exitCode !== 0) {
                    root.currentLayout = "Unknown";
                    return;
                }
                try {
                    const data = JSON.parse(output);
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true);
                    root.hyprlandKeyboard = mainKeyboard.name;

                    if (mainKeyboard) {
                        const layout = mainKeyboard.layout;
                        const variant = mainKeyboard.variant;
                        const index = mainKeyboard.active_layout_index;

                        if (root.compactMode && layout && index !== undefined) {
                            const layouts = mainKeyboard.layout.split(",");
                            const variants = mainKeyboard.variant.split(",");
                            const index = mainKeyboard.active_layout_index;

                            if (layouts[index] && variants[index] !== undefined) {
                                if (variants[index] === "") {
                                    root.currentLayout = layouts[index];
                                } else {
                                    root.currentLayout = layouts[index] + "-" + variants[index];
                                }
                            } else {
                                root.currentLayout = layouts[index];
                            }
                        } else if (mainKeyboard && mainKeyboard.active_keymap) {
                            root.currentLayout = mainKeyboard.active_keymap;
                        } else {
                            root.currentLayout = "Unknown";
                        }
                    } else {
                        root.currentLayout = "Unknown";
                    }
                } catch (e) {
                    root.currentLayout = "Unknown";
                }
            });
        }
    }
}
