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
                            text: I18n.tr("Click 'Setup' to link keyboard settings and add include to your compositor config.")
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
                tags: ["keyboard", "layout", "language", "input", "xkb"]
                title: I18n.tr("Keyboard Layouts")
                settingKey: "keyboardLayoutsSettings"
                iconName: "keyboard"

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Keyboard Layouts")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Comma-separated list of layout names.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.keyboardLayouts
                        placeholderText: "us, vn"
                        onTextEdited: SettingsData.set("keyboardLayouts", text)
                    }
                }

                SettingsDropdownRow {
                    tags: ["keyboard", "layout", "switch", "shortcut", "xkb"]
                    settingKey: "keyboardOptions"
                    text: I18n.tr("Switch Layout Shortcut")
                    description: I18n.tr("Choose a shortcut key to cycle between keyboard layouts")
                    options: [
                        I18n.tr("Alt + Shift"),
                        I18n.tr("Ctrl + Shift"),
                        I18n.tr("Caps Lock"),
                        I18n.tr("Super + Space"),
                        I18n.tr("Custom / None")
                    ]
                    currentValue: {
                        const opt = SettingsData.keyboardOptions;
                        if (opt.includes("grp:alt_shift_toggle")) return options[0];
                        if (opt.includes("grp:ctrl_shift_toggle")) return options[1];
                        if (opt.includes("grp:caps_toggle")) return options[2];
                        if (opt.includes("grp:win_space_toggle")) return options[3];
                        return options[4];
                    }
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        let opt = SettingsData.keyboardOptions;
                        // Clean existing switcher options
                        opt = opt.split(',').filter(o => !o.startsWith("grp:")).join(',');

                        let newGrp = "";
                        if (idx === 0) newGrp = "grp:alt_shift_toggle";
                        else if (idx === 1) newGrp = "grp:ctrl_shift_toggle";
                        else if (idx === 2) newGrp = "grp:caps_toggle";
                        else if (idx === 3) newGrp = "grp:win_space_toggle";

                        if (newGrp) {
                            opt = opt ? opt + "," + newGrp : newGrp;
                        }
                        SettingsData.set("keyboardOptions", opt);
                    }
                }

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("XKB Options")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Advanced comma-separated libxkbcommon options.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.keyboardOptions
                        placeholderText: "compose:ralt, ctrl:nocaps"
                        onTextEdited: SettingsData.set("keyboardOptions", text)
                    }
                }

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Keyboard Variant")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Optional layout variant.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.keyboardVariants
                        placeholderText: "colemak"
                        onTextEdited: SettingsData.set("keyboardVariants", text)
                    }
                }

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Keyboard Model")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Optional keyboard hardware model.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.keyboardModel
                        placeholderText: "pc104"
                        onTextEdited: SettingsData.set("keyboardModel", text)
                    }
                }

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Keymap File Path")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Direct path to a .xkb keymap file. Overrides layouts/variants above.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.keyboardKeymapFile
                        placeholderText: "~/.config/keymap.xkb"
                        onTextEdited: SettingsData.set("keyboardKeymapFile", text)
                    }
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["keyboard", "repeat", "delay", "rate", "numlock", "behavior"]
                title: I18n.tr("Keyboard Behavior")
                settingKey: "keyboardBehaviorSettings"
                iconName: "settings"

                SettingsButtonGroupRow {
                    tags: ["keyboard", "track", "layout"]
                    settingKey: "keyboardTrackLayout"
                    text: I18n.tr("Remember Layout")
                    description: I18n.tr("How layout changes are remembered across apps")
                    model: [I18n.tr("Globally"), I18n.tr("Per Window")]
                    currentIndex: SettingsData.keyboardTrackLayout === "window" ? 1 : 0
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return;
                        SettingsData.set("keyboardTrackLayout", index === 1 ? "window" : "global");
                    }
                }

                SettingsToggleRow {
                    tags: ["keyboard", "numlock", "startup"]
                    settingKey: "keyboardNumlock"
                    text: I18n.tr("Enable Num Lock")
                    description: I18n.tr("Automatically turn on Num Lock at startup")
                    checked: SettingsData.keyboardNumlock
                    onToggled: checked => SettingsData.set("keyboardNumlock", checked)
                }

                 SettingsSliderRow {
                    tags: ["keyboard", "repeat", "delay", "speed"]
                    settingKey: "keyboardRepeatDelay"
                    text: I18n.tr("Repeat Delay")
                    description: I18n.tr("Delay before characters start repeating")
                    value: SettingsData.keyboardRepeatDelay
                    minimum: 100
                    maximum: 2000
                    step: 50
                    defaultValue: 600
                    unit: "ms"
                    onSliderValueChanged: newValue => SettingsData.set("keyboardRepeatDelay", newValue)
                }

                SettingsSliderRow {
                    tags: ["keyboard", "repeat", "rate", "speed"]
                    settingKey: "keyboardRepeatRate"
                    text: I18n.tr("Repeat Rate")
                    description: I18n.tr("Characters per second while holding down key")
                    value: SettingsData.keyboardRepeatRate
                    minimum: 1
                    maximum: 100
                    step: 1
                    defaultValue: 25
                    unit: ""
                    onSliderValueChanged: newValue => SettingsData.set("keyboardRepeatRate", newValue)
                }
            }
        }
    }
}
