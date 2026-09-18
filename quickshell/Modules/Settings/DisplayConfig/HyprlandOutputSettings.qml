import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

SettingsCard {
    id: root

    property string outputName: ""
    property var outputData: null
    readonly property bool is10Bit: {
        void (DisplayConfigState.pendingHyprlandChanges);
        return DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "bitdepth", 8) === 10;
    }
    readonly property string colorManagement: {
        void (DisplayConfigState.pendingHyprlandChanges);
        return DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "colorManagement", "auto");
    }
    readonly property bool isHdrMode: colorManagement === "hdr" || colorManagement === "hdredid"
    readonly property bool isDisabled: {
        void (DisplayConfigState.pendingHyprlandChanges);
        return DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "disabled", false);
    }

    title: I18n.tr("Compositor")
    collapsible: true
    expanded: false

    SettingsToggleRow {
        text: I18n.tr("Disable output")
        enabled: checked || DisplayConfigState.canDisableOutput()
        description: (!checked && !DisplayConfigState.canDisableOutput()) ? (Object.keys(DisplayConfigState.outputs).length <= 1 ? I18n.tr("Cannot disable the only output") : I18n.tr("At least one output must remain enabled")) : ""
        checked: root.isDisabled
        onToggled: checked => DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "disabled", checked)
    }

    SettingsDropdownRow {
        text: I18n.tr("Mirror display")
        enabled: !root.isDisabled

        options: [I18n.tr("None")].concat(Object.keys(DisplayConfigState.outputs).filter(name => name !== root.outputName))

        currentValue: {
            void (DisplayConfigState.pendingChanges);
            const pending = DisplayConfigState.getPendingValue(root.outputName, "mirror");
            const val = pending !== undefined ? pending : (root.outputData.mirror || "");
            return val === "" ? I18n.tr("None") : val;
        }

        onValueChanged: value => {
            const realVal = value === I18n.tr("None") ? "" : value;
            DisplayConfigState.setPendingChange(root.outputName, "mirror", realVal);
        }
    }

    SettingsToggleRow {
        text: I18n.tr("10-bit color")
        enabled: !root.isDisabled
        checked: root.is10Bit
        onToggled: checked => {
            if (checked) {
                DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "bitdepth", 10);
                return;
            }
            DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "bitdepth", null);
            if (root.isHdrMode)
                DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "colorManagement", "auto");
        }
    }

    SettingsDropdownRow {
        visible: root.is10Bit
        text: I18n.tr("Color gamut")
        enabled: !root.isDisabled
        currentValue: {
            void (DisplayConfigState.pendingHyprlandChanges);
            const val = DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "colorManagement", "auto");
            return cmLabelMap[val] || I18n.tr("Auto (Wide)");
        }
        options: [I18n.tr("Auto (Wide)"), I18n.tr("Wide (BT2020)"), "DCI-P3", "Apple P3", "Adobe RGB", "EDID", "HDR", I18n.tr("HDR (EDID)")]

        property var cmValueMap: ({
                [I18n.tr("Auto (Wide)")]: "auto",
                [I18n.tr("Wide (BT2020)")]: "wide",
                "DCI-P3": "dcip3",
                "Apple P3": "dp3",
                "Adobe RGB": "adobe",
                "EDID": "edid",
                "HDR": "hdr",
                [I18n.tr("HDR (EDID)")]: "hdredid"
            })

        property var cmLabelMap: ({
                "auto": I18n.tr("Auto (Wide)"),
                "wide": I18n.tr("Wide (BT2020)"),
                "dcip3": "DCI-P3",
                "dp3": "Apple P3",
                "adobe": "Adobe RGB",
                "edid": "EDID",
                "hdr": "HDR",
                "hdredid": I18n.tr("HDR (EDID)")
            })

        onValueChanged: value => {
            const cmValue = cmValueMap[value] || "auto";
            DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "colorManagement", cmValue);
        }
    }

    SettingsRow {
        visible: root.is10Bit && root.isHdrMode
        iconName: "warning"
        iconColor: Theme.warning
        title: I18n.tr("Experimental feature")
        titleColor: Theme.warning
        subtitle: I18n.tr("HDR mode is experimental. Verify your monitor supports HDR before enabling.")
    }

    SettingsRow {
        visible: root.is10Bit && root.isHdrMode
        title: I18n.tr("HDR tone mapping")
        enabled: !root.isDisabled

        body: Row {
            width: parent.width
            spacing: Theme.spacingM

            DankTextField {
                outlined: true
                leftIconName: "brightness_6"
                labelText: I18n.tr("SDR brightness")
                width: (parent.width - parent.spacing) / 2
                placeholderText: "1.0 - 2.0"
                text: {
                    void (DisplayConfigState.pendingHyprlandChanges);
                    const val = DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "sdrBrightness", null);
                    return val !== null ? val.toString() : "";
                }
                onEditingFinished: {
                    const trimmed = text.trim();
                    if (!trimmed) {
                        DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrBrightness", null);
                        return;
                    }
                    const val = parseFloat(trimmed);
                    if (isNaN(val) || val < 0.1 || val > 5.0)
                        return;
                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrBrightness", parseFloat(val.toFixed(2)));
                }
            }

            DankTextField {
                outlined: true
                leftIconName: "palette"
                labelText: I18n.tr("SDR saturation")
                width: (parent.width - parent.spacing) / 2
                placeholderText: "0.5 - 1.5"
                text: {
                    void (DisplayConfigState.pendingHyprlandChanges);
                    const val = DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "sdrSaturation", null);
                    return val !== null ? val.toString() : "";
                }
                onEditingFinished: {
                    const trimmed = text.trim();
                    if (!trimmed) {
                        DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrSaturation", null);
                        return;
                    }
                    const val = parseFloat(trimmed);
                    if (isNaN(val) || val < 0.0 || val > 3.0)
                        return;
                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrSaturation", parseFloat(val.toFixed(2)));
                }
            }
        }
    }
}
