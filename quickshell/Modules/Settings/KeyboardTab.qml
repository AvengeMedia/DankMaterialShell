import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

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

            NiriInputSetupBanner {
                width: parent.width
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
                        text: I18n.tr("Comma-separated list of layout names. Leave empty to use the system keyboard settings.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.keyboardLayouts
                        placeholderText: "us,de"
                        onTextEdited: SettingsData.set("keyboardLayouts", text)
                    }
                }

                SettingsDropdownRow {
                    tags: ["keyboard", "layout", "switch", "shortcut", "xkb"]
                    settingKey: "keyboardOptions"
                    text: I18n.tr("Switch Layout Shortcut")
                    description: I18n.tr("Choose a shortcut key to cycle between keyboard layouts")
                    options: [I18n.tr("Alt + Shift"), I18n.tr("Ctrl + Shift"), I18n.tr("Caps Lock"), I18n.tr("Super + Space"), I18n.tr("Custom / None")]
                    currentValue: {
                        const opt = SettingsData.keyboardOptions;
                        if (opt.includes("grp:alt_shift_toggle"))
                            return options[0];
                        if (opt.includes("grp:ctrl_shift_toggle"))
                            return options[1];
                        if (opt.includes("grp:caps_toggle"))
                            return options[2];
                        if (opt.includes("grp:win_space_toggle"))
                            return options[3];
                        return options[4];
                    }
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        let opt = SettingsData.keyboardOptions.split(",").filter(o => !o.startsWith("grp:")).join(",");

                        let newGrp = "";
                        switch (idx) {
                        case 0:
                            newGrp = "grp:alt_shift_toggle";
                            break;
                        case 1:
                            newGrp = "grp:ctrl_shift_toggle";
                            break;
                        case 2:
                            newGrp = "grp:caps_toggle";
                            break;
                        case 3:
                            newGrp = "grp:win_space_toggle";
                            break;
                        }

                        if (newGrp)
                            opt = opt ? opt + "," + newGrp : newGrp;
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
                        placeholderText: "compose:ralt,ctrl:nocaps"
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
                        if (!selected)
                            return;
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
                    value: SettingsData.keyboardRepeatDelay || 600
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
                    value: SettingsData.keyboardRepeatRate || 25
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
