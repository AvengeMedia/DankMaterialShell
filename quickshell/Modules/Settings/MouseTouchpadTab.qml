import QtCore
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/ConfigIncludeResolve.js" as ConfigIncludeResolve

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var inputIncludeStatus: ({
            "exists": false,
            "included": false,
            "configFormat": "",
            "readOnly": false
        })
    property bool checkingInclude: false
    property bool fixingInclude: false

    function getInputConfigPaths() {
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        if (CompositorService.compositor !== "niri")
            return null;
        return {
            "configFile": configDir + "/niri/config.kdl",
            "layoutFile": configDir + "/niri/dms/input.kdl",
            "grepPattern": 'include.*"dms/input.kdl"',
            "includeLine": 'include "dms/input.kdl"'
        };
    }

    function checkInputIncludeStatus() {
        if (CompositorService.compositor !== "niri") {
            inputIncludeStatus = {
                "exists": false,
                "included": false,
                "configFormat": "",
                "readOnly": false
            };
            return;
        }

        checkingInclude = true;
        Proc.runCommand("check-input-include", [Proc.dmsBin, "config", "resolve-include", "niri", "input.kdl"], (output, exitCode) => {
            checkingInclude = false;
            if (exitCode !== 0) {
                inputIncludeStatus = {
                    "exists": false,
                    "included": false,
                    "configFormat": "",
                    "readOnly": false
                };
                return;
            }
            try {
                inputIncludeStatus = JSON.parse(output.trim());
            } catch (e) {
                inputIncludeStatus = {
                    "exists": false,
                    "included": false,
                    "configFormat": "",
                    "readOnly": false
                };
            }
        });
    }

    function fixInputInclude() {
        const paths = getInputConfigPaths();
        if (!paths)
            return;

        fixingInclude = true;
        const unixTime = Math.floor(Date.now() / 1000);
        const backupFile = paths.configFile + ".backup" + unixTime;
        const script = ConfigIncludeResolve.buildRepairScript({
            configFile: paths.configFile,
            backupFile: backupFile,
            fragmentFile: paths.layoutFile,
            grepPattern: paths.grepPattern,
            includeLine: paths.includeLine
        });
        Proc.runCommand("fix-input-include", ["sh", "-c", script], (output, exitCode) => {
            fixingInclude = false;
            if (exitCode !== 0)
                return;
            checkInputIncludeStatus();
            SettingsData.updateCompositorInput();
        });
    }

    Component.onCompleted: {
        if (CompositorService.isNiri) {
            checkInputIncludeStatus();
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: settingsColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: settingsColumn

            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            StyledRect {
                id: warningBox
                width: parent.width
                height: warningContent.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius

                readonly property bool showSetup: !root.inputIncludeStatus.included

                color: showSetup ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0)
                border.color: showSetup ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0)
                border.width: 1
                visible: showSetup && !root.checkingInclude && CompositorService.isNiri

                Row {
                    id: warningContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "warning"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - (fixButton.visible ? fixButton.width + Theme.spacingM : 0) - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: I18n.tr("First Time Setup")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.primary
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        StyledText {
                            text: I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg("dms/input")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    DankButton {
                        id: fixButton
                        visible: warningBox.showSetup
                        text: root.fixingInclude ? I18n.tr("Setting up...") : I18n.tr("Setup")
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        enabled: !root.fixingInclude
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.fixInputInclude()
                    }
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["mouse", "input", "sensitivity", "acceleration", "pointer"]
                title: I18n.tr("Mouse Settings")
                settingKey: "mouseSettings"
                iconName: "mouse"

                SettingsToggleRow {
                    tags: ["mouse", "left", "handed", "button", "swap"]
                    settingKey: "mouseLeftHanded"
                    text: I18n.tr("Left-Handed Mode")
                    description: I18n.tr("Swap primary and secondary mouse buttons")
                    checked: SettingsData.mouseLeftHanded
                    onToggled: checked => SettingsData.set("mouseLeftHanded", checked)
                }

                SettingsSliderRow {
                    tags: ["mouse", "sensitivity", "speed", "accel"]
                    settingKey: "mouseAccelSpeed"
                    text: I18n.tr("Pointer Speed")
                    description: I18n.tr("Adjust pointer sensitivity speed")
                    value: Math.round(SettingsData.mouseAccelSpeed * 10)
                    minimum: -10
                    maximum: 10
                    step: 1
                    defaultValue: 0
                    onSliderValueChanged: newValue => SettingsData.set("mouseAccelSpeed", newValue / 10.0)
                }

                SettingsButtonGroupRow {
                    tags: ["mouse", "acceleration", "profile"]
                    settingKey: "mouseAccelProfile"
                    text: I18n.tr("Acceleration Profile")
                    description: I18n.tr("Flat uses constant speed; Adaptive scales with movement speed")
                    model: [I18n.tr("Default"), I18n.tr("Flat"), I18n.tr("Adaptive")]
                    currentIndex: {
                        if (SettingsData.mouseAccelProfile === "flat") return 1;
                        if (SettingsData.mouseAccelProfile === "adaptive") return 2;
                        return 0;
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return;
                        const profiles = ["default", "flat", "adaptive"];
                        SettingsData.set("mouseAccelProfile", profiles[index]);
                    }
                }

                SettingsToggleRow {
                    tags: ["mouse", "natural", "scroll", "direction"]
                    settingKey: "mouseNaturalScroll"
                    text: I18n.tr("Natural Scrolling")
                    description: I18n.tr("Reverse mouse wheel scrolling direction")
                    checked: SettingsData.mouseNaturalScroll
                    onToggled: checked => SettingsData.set("mouseNaturalScroll", checked)
                }

                SettingsSliderRow {
                    tags: ["mouse", "scroll", "speed", "factor"]
                    settingKey: "mouseScrollFactor"
                    text: I18n.tr("Scrolling Speed")
                    description: I18n.tr("Adjust scrolling sensitivity multiplier")
                    value: Math.round(SettingsData.mouseScrollFactor * 10)
                    minimum: 1
                    maximum: 30
                    step: 1
                    defaultValue: 10
                    onSliderValueChanged: newValue => SettingsData.set("mouseScrollFactor", newValue / 10.0)
                }

                SettingsButtonGroupRow {
                    tags: ["mouse", "scroll", "method"]
                    settingKey: "mouseScrollMethod"
                    text: I18n.tr("Scroll Method")
                    description: I18n.tr("Choose when to generate scrolling events")
                    model: [I18n.tr("Default"), I18n.tr("No Scroll"), I18n.tr("On Button Down")]
                    currentIndex: {
                        if (SettingsData.mouseScrollMethod === "no-scroll") return 1;
                        if (SettingsData.mouseScrollMethod === "on-button-down") return 2;
                        return 0;
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return;
                        const methods = ["default", "no-scroll", "on-button-down"];
                        SettingsData.set("mouseScrollMethod", methods[index]);
                    }
                }

                SettingsToggleRow {
                    tags: ["mouse", "middle", "click", "emulation"]
                    settingKey: "mouseMiddleEmulation"
                    text: I18n.tr("Middle Click Emulation")
                    description: I18n.tr("Emulate middle click by pressing left and right buttons")
                    checked: SettingsData.mouseMiddleEmulation
                    onToggled: checked => SettingsData.set("mouseMiddleEmulation", checked)
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["touchpad", "input", "sensitivity", "tap", "click", "natural"]
                title: I18n.tr("Touchpad Settings")
                settingKey: "touchpadSettings"
                iconName: "trackpad_input_2"

                SettingsToggleRow {
                    tags: ["touchpad", "tap", "click"]
                    settingKey: "touchpadTapToClick"
                    text: I18n.tr("Tap to Click")
                    description: I18n.tr("Tap the touchpad surface to trigger left click clicks")
                    checked: SettingsData.touchpadTapToClick
                    onToggled: checked => SettingsData.set("touchpadTapToClick", checked)
                }

                SettingsToggleRow {
                    tags: ["touchpad", "tap", "drag"]
                    settingKey: "touchpadTapAndDrag"
                    text: I18n.tr("Tap and Drag")
                    description: I18n.tr("Tap and drag on the touchpad to move items")
                    checked: SettingsData.touchpadTapAndDrag
                    onToggled: checked => SettingsData.set("touchpadTapAndDrag", checked)
                }

                SettingsToggleRow {
                    tags: ["touchpad", "drag", "lock"]
                    settingKey: "touchpadDragLock"
                    text: I18n.tr("Drag Lock")
                    description: I18n.tr("Keep dragging when finger is briefly lifted")
                    checked: SettingsData.touchpadDragLock
                    onToggled: checked => SettingsData.set("touchpadDragLock", checked)
                }

                SettingsSliderRow {
                    tags: ["touchpad", "sensitivity", "speed", "accel"]
                    settingKey: "touchpadAccelSpeed"
                    text: I18n.tr("Touchpad Speed")
                    description: I18n.tr("Adjust touchpad pointer speed")
                    value: Math.round(SettingsData.touchpadAccelSpeed * 10)
                    minimum: -10
                    maximum: 10
                    step: 1
                    defaultValue: 0
                    onSliderValueChanged: newValue => SettingsData.set("touchpadAccelSpeed", newValue / 10.0)
                }

                SettingsButtonGroupRow {
                    tags: ["touchpad", "acceleration", "profile"]
                    settingKey: "touchpadAccelProfile"
                    text: I18n.tr("Acceleration Profile")
                    description: I18n.tr("Flat uses constant speed; Adaptive scales with movement speed")
                    model: [I18n.tr("Default"), I18n.tr("Flat"), I18n.tr("Adaptive")]
                    currentIndex: {
                        if (SettingsData.touchpadAccelProfile === "flat") return 1;
                        if (SettingsData.touchpadAccelProfile === "adaptive") return 2;
                        return 0;
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return;
                        const profiles = ["default", "flat", "adaptive"];
                        SettingsData.set("touchpadAccelProfile", profiles[index]);
                    }
                }

                SettingsToggleRow {
                    tags: ["touchpad", "natural", "scroll", "direction"]
                    settingKey: "touchpadNaturalScroll"
                    text: I18n.tr("Natural Scrolling")
                    description: I18n.tr("Reverse two-finger scrolling direction")
                    checked: SettingsData.touchpadNaturalScroll
                    onToggled: checked => SettingsData.set("touchpadNaturalScroll", checked)
                }

                SettingsSliderRow {
                    tags: ["touchpad", "scroll", "speed", "factor"]
                    settingKey: "touchpadScrollFactor"
                    text: I18n.tr("Scrolling Speed")
                    description: I18n.tr("Adjust scrolling sensitivity multiplier")
                    value: Math.round(SettingsData.touchpadScrollFactor * 10)
                    minimum: 1
                    maximum: 30
                    step: 1
                    defaultValue: 10
                    onSliderValueChanged: newValue => SettingsData.set("touchpadScrollFactor", newValue / 10.0)
                }

                SettingsButtonGroupRow {
                    tags: ["touchpad", "scroll", "method"]
                    settingKey: "touchpadScrollMethod"
                    text: I18n.tr("Scroll Method")
                    description: I18n.tr("Choose when to generate scrolling events")
                    model: [I18n.tr("Default"), I18n.tr("Two Finger"), I18n.tr("Edge"), I18n.tr("No Scroll"), I18n.tr("On Button Down")]
                    currentIndex: {
                        if (SettingsData.touchpadScrollMethod === "two-finger") return 1;
                        if (SettingsData.touchpadScrollMethod === "edge") return 2;
                        if (SettingsData.touchpadScrollMethod === "no-scroll") return 3;
                        if (SettingsData.touchpadScrollMethod === "on-button-down") return 4;
                        return 0;
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return;
                        const methods = ["default", "two-finger", "edge", "no-scroll", "on-button-down"];
                        SettingsData.set("touchpadScrollMethod", methods[index]);
                    }
                }

                SettingsToggleRow {
                    tags: ["touchpad", "disable", "typing", "dwt"]
                    settingKey: "touchpadDisableWhileTyping"
                    text: I18n.tr("Disable While Typing")
                    description: I18n.tr("Prevent accidental cursor jumps while typing")
                    checked: SettingsData.touchpadDisableWhileTyping
                    onToggled: checked => SettingsData.set("touchpadDisableWhileTyping", checked)
                }

                SettingsToggleRow {
                    tags: ["touchpad", "disable", "external", "mouse"]
                    settingKey: "touchpadDisableOnExternalMouse"
                    text: I18n.tr("Disable on External Mouse")
                    description: I18n.tr("Disable touchpad when an external mouse is connected")
                    checked: SettingsData.touchpadDisableOnExternalMouse
                    onToggled: checked => SettingsData.set("touchpadDisableOnExternalMouse", checked)
                }

                SettingsToggleRow {
                    tags: ["touchpad", "middle", "click", "emulation"]
                    settingKey: "touchpadMiddleEmulation"
                    text: I18n.tr("Middle Click Emulation")
                    description: I18n.tr("Emulate middle click by pressing left and right buttons")
                    checked: SettingsData.touchpadMiddleEmulation
                    onToggled: checked => SettingsData.set("touchpadMiddleEmulation", checked)
                }
            }
        }
    }
}
