pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor

    readonly property string section: "802-11-wireless"
    readonly property int rev: editor.revision
    readonly property var wifi: {
        rev;
        return editor.draft ? (editor.draft[section] ?? {}) : {};
    }

    readonly property bool ssidDecodable: editor.isNew || editor.original?.[section]?.ssid !== undefined
    readonly property string ssid: String(wifi.ssid ?? "")
    readonly property string mode: wifi.mode ?? "infrastructure"
    // Manual is chosen but no valid address has been typed yet, so nothing is written.
    property bool pendingManual: false
    property string clonedText: ""
    property string clonedStored: ""
    readonly property string clonedMode: pendingManual ? "manual" : CE.clonedMacMode(wifi)
    readonly property int powersave: wifi.powersave ?? 0

    readonly property bool bssidValid: !wifi.bssid || CE.isValidMac(wifi.bssid)
    readonly property bool macValid: !wifi["mac-address"] || CE.isValidMac(wifi["mac-address"])
    readonly property bool clonedValid: clonedMode !== "manual" || CE.isValidMac(clonedText)
    readonly property bool valid: (!ssidDecodable || ssid !== "") && bssidValid && macValid && clonedValid

    readonly property var modeChoices: [
        {
            "label": I18n.tr("Infrastructure", "Wi-Fi mode: client of an access point"),
            "value": "infrastructure"
        },
        {
            "label": I18n.tr("Ad-hoc", "Wi-Fi mode"),
            "value": "adhoc"
        },
        {
            "label": I18n.tr("Hotspot"),
            "value": "ap"
        }
    ]
    readonly property var bandChoices: [
        {
            "label": I18n.tr("Auto"),
            "value": ""
        },
        {
            "label": I18n.tr("2.4 GHz"),
            "value": "bg"
        },
        {
            "label": I18n.tr("5 GHz"),
            "value": "a"
        },
        {
            "label": I18n.tr("6 GHz", "WiFi band option"),
            "value": "6GHz"
        }
    ]
    readonly property var clonedChoices: [
        {
            "label": I18n.tr("Default"),
            "value": "default"
        },
        {
            "label": I18n.tr("Preserve", "cloned MAC: keep the current address"),
            "value": "preserve"
        },
        {
            "label": I18n.tr("Permanent", "cloned MAC: the hardware address"),
            "value": "permanent"
        },
        {
            "label": I18n.tr("Random"),
            "value": "random"
        },
        {
            "label": I18n.tr("Stable", "cloned MAC: stable per network"),
            "value": "stable"
        },
        {
            "label": I18n.tr("Manual"),
            "value": "manual"
        }
    ]
    readonly property var powersaveChoices: [
        {
            "label": I18n.tr("Default"),
            "value": 0
        },
        {
            "label": I18n.tr("Enabled"),
            "value": 3
        },
        {
            "label": I18n.tr("Disabled"),
            "value": 2
        },
        {
            "label": I18n.tr("Ignore", "leave as the driver or system configured it"),
            "value": 1
        }
    ]

    function _setNumber(key, text) {
        const n = parseInt(text, 10);
        editor.setValue(section, key, n > 0 ? n : undefined);
    }

    function _setText(key, text) {
        const t = text.trim();
        editor.setValue(section, key, t === "" ? undefined : t);
    }

    function applyManualMac(text) {
        clonedText = text;
        if (!CE.isValidMac(text))
            return;
        pendingManual = false;
        editor.setSection(section, CE.applyClonedMac(wifi, "manual", text));
    }

    // Refill only when the stored address changed, so half-typed text survives other edits.
    function syncClonedText() {
        const cloned = CE.clonedMacAddress(wifi ?? {});
        if (cloned !== clonedStored)
            clonedText = clonedStored = cloned;
    }

    Component.onCompleted: syncClonedText()
    onWifiChanged: syncClonedText()

    title: I18n.tr("Wi-Fi")
    enabled: !editor.readOnly

    SettingsTextFieldRow {
        text: I18n.tr("Network Name (SSID)")
        enabled: root.ssidDecodable
        value: root.ssidDecodable ? root.ssid : I18n.tr("Unknown")
        isError: root.ssidDecodable && root.ssid === ""
        onValueEdited: value => {
            if (root.ssidDecodable)
                root.editor.setValue(root.section, "ssid", value);
        }
    }

    SettingsDropdownRow {
        readonly property var choices: CE.withChoice(root.modeChoices, root.mode)
        text: I18n.tr("Mode")
        options: choices.map(c => c.label)
        currentValue: CE.choiceLabel(choices, root.mode)
        onValueChanged: value => {
            const v = CE.choiceValue(choices, value);
            if (v !== undefined && v !== root.mode)
                root.editor.setValue(root.section, "mode", v);
        }
    }

    SettingsToggleRow {
        text: I18n.tr("Hidden")
        checked: root.wifi.hidden === true
        onToggled: checked => root.editor.setValue(root.section, "hidden", checked)
    }

    SettingsDropdownRow {
        readonly property string band: root.wifi.band ?? ""
        readonly property var choices: CE.withChoice(root.bandChoices, band)
        text: I18n.tr("Band")
        options: choices.map(c => c.label)
        currentValue: CE.choiceLabel(choices, band)
        onValueChanged: value => {
            const v = CE.choiceValue(choices, value);
            if (v !== undefined && v !== band)
                root.editor.setValue(root.section, "band", v === "" ? undefined : v);
        }
    }

    ConnectionSyncedRow {
        visible: root.mode !== "infrastructure"
        text: I18n.tr("Channel")
        stored: String(root.wifi.channel ?? "")
        validator: IntValidator {
            bottom: 0
        }
        commit: t => root._setNumber("channel", t)
    }

    SettingsTextFieldRow {
        text: "BSSID"
        value: root.wifi.bssid ?? ""
        placeholderText: "AA:BB:CC:DD:EE:FF"
        isError: !root.bssidValid
        onValueEdited: value => root._setText("bssid", value)
    }

    SettingsTextFieldRow {
        text: I18n.tr("MAC address", "network hardware setting")
        value: root.wifi["mac-address"] ?? ""
        placeholderText: "AA:BB:CC:DD:EE:FF"
        isError: !root.macValid
        onValueEdited: value => root._setText("mac-address", value)
    }

    SettingsDropdownRow {
        readonly property var choices: CE.withChoice(root.clonedChoices, root.clonedMode)
        text: I18n.tr("Cloned MAC address", "network hardware setting")
        options: choices.map(c => c.label)
        currentValue: CE.choiceLabel(choices, root.clonedMode)
        onValueChanged: value => {
            const v = CE.choiceValue(choices, value);
            if (v === undefined || v === root.clonedMode)
                return;
            if (v === "manual") {
                root.pendingManual = true;
                if (CE.isValidMac(root.clonedText))
                    root.applyManualMac(root.clonedText);
                return;
            }
            root.pendingManual = false;
            root.editor.setSection(root.section, CE.applyClonedMac(root.wifi, v, ""));
        }
    }

    SettingsTextFieldRow {
        visible: root.clonedMode === "manual"
        text: I18n.tr("Cloned MAC address", "network hardware setting")
        value: root.clonedText
        placeholderText: "AA:BB:CC:DD:EE:FF"
        isError: !root.clonedValid
        onValueEdited: value => {
            if (value !== root.clonedText)
                root.applyManualMac(value.trim());
        }
    }

    ConnectionSyncedRow {
        text: "MTU"
        stored: String(root.wifi.mtu ?? "")
        placeholderText: I18n.tr("Auto")
        validator: IntValidator {
            bottom: 0
        }
        commit: t => root._setNumber("mtu", t)
    }

    SettingsDropdownRow {
        readonly property var choices: CE.withChoice(root.powersaveChoices, root.powersave)
        text: I18n.tr("Power saving", "WiFi setting")
        options: choices.map(c => c.label)
        currentValue: CE.choiceLabel(choices, root.powersave)
        onValueChanged: value => {
            const v = CE.choiceValue(choices, value);
            if (v !== undefined && v !== root.powersave)
                root.editor.setValue(root.section, "powersave", v === 0 ? undefined : v);
        }
    }
}
