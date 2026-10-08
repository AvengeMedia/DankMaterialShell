import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor
    readonly property bool valid: !macInvalid && !clonedInvalid && mtuRow.ok

    readonly property string sectionKey: "802-3-ethernet"
    readonly property int revision: editor.revision
    readonly property var eth: {
        revision;
        return editor.draft?.[sectionKey] ?? {};
    }
    readonly property var devices: NetworkService.ethernetDevices
    readonly property bool locked: editor.readOnly

    // Manual is chosen but no valid address has been typed yet, so nothing is written.
    property bool pendingManual: false
    property string macText: ""
    property string clonedText: ""
    property string macStored: ""
    property string clonedStored: ""

    readonly property string clonedMode: pendingManual ? "manual" : CE.clonedMacMode(eth)
    readonly property string linkMode: CE.linkNegotiation(eth)
    readonly property bool macInvalid: macText.trim() !== "" && !CE.isValidMac(macText)
    readonly property bool clonedInvalid: clonedMode === "manual" && !CE.isValidMac(clonedText)

    readonly property string storedDevice: {
        revision;
        return editor.value("connection", "interface-name", "");
    }
    readonly property var deviceOptions: CE.withChoice([
        {
            "value": "",
            "label": I18n.tr("Auto")
        }
    ].concat((devices ?? []).map(d => ({
                "value": d.name,
                "label": d.name
            }))), storedDevice)

    readonly property var clonedOptions: CE.withChoice([
        {
            "value": "default",
            "label": I18n.tr("Default")
        },
        {
            "value": "preserve",
            "label": I18n.tr("Preserve", "cloned MAC: keep the current address")
        },
        {
            "value": "permanent",
            "label": I18n.tr("Permanent", "cloned MAC: the hardware address")
        },
        {
            "value": "random",
            "label": I18n.tr("Random")
        },
        {
            "value": "stable",
            "label": I18n.tr("Stable", "cloned MAC: stable per network")
        },
        {
            "value": "manual",
            "label": I18n.tr("Manual")
        }
    ], clonedMode)

    readonly property string wolCurrent: CE.wolMode(eth["wake-on-lan"])
    readonly property var wolOptions: CE.withChoice([
        {
            "value": "default",
            "label": I18n.tr("Default")
        },
        {
            "value": "disabled",
            "label": I18n.tr("Disabled")
        },
        {
            "value": "magic",
            "label": I18n.tr("Magic packet")
        },
        {
            "value": "ignore",
            "label": I18n.tr("Ignore", "leave as the driver or system configured it")
        }
    ], wolCurrent)

    readonly property var linkOptions: [
        {
            "value": "ignore",
            "label": I18n.tr("Ignore", "leave as the driver or system configured it")
        },
        {
            "value": "auto",
            "label": I18n.tr("Auto")
        },
        {
            "value": "manual",
            "label": I18n.tr("Manual")
        }
    ]

    readonly property string speedCurrent: eth.speed > 0 ? String(eth.speed) : ""
    readonly property var speedOptions: {
        const options = [10, 100, 1000, 2500, 5000, 10000, 25000, 40000, 50000, 100000].map(s => ({
                    "value": String(s),
                    "label": s + " Mbps"
                }));
        return speedCurrent === "" ? options : CE.withChoice(options, speedCurrent);
    }

    readonly property string duplexCurrent: eth.duplex ?? "full"
    readonly property var duplexOptions: CE.withChoice([
        {
            "value": "full",
            "label": I18n.tr("Full")
        },
        {
            "value": "half",
            "label": I18n.tr("Half", "half duplex")
        }
    ], duplexCurrent)

    title: I18n.tr("Ethernet")

    function setEth(obj) {
        editor.setSection(sectionKey, obj);
    }

    function setEthValue(key, value) {
        editor.setValue(sectionKey, key, value);
    }

    // Only fields whose stored value changed are refilled, so half-typed text elsewhere survives.
    function syncTexts() {
        const e = eth ?? {};
        const mac = e["mac-address"] ?? "";
        const cloned = CE.clonedMacAddress(e);
        if (mac !== macStored) {
            macStored = mac;
            if (mac !== macText.trim())
                macText = mac;
        }
        if (cloned !== clonedStored)
            clonedText = clonedStored = cloned;
    }

    function applyManualMac(text) {
        clonedText = text;
        if (!CE.isValidMac(text))
            return;
        pendingManual = false;
        setEth(CE.applyClonedMac(eth, "manual", text));
    }

    function applyLink(mode, speed, duplex) {
        setEth(CE.applyLinkNegotiation(eth, mode, speed, duplex));
    }

    Component.onCompleted: syncTexts()
    onEthChanged: syncTexts()

    SettingsDropdownRow {
        text: I18n.tr("Device")
        enabled: !root.locked
        options: root.deviceOptions.map(c => c.label)
        currentValue: CE.choiceLabel(root.deviceOptions, root.storedDevice)
        onValueChanged: value => {
            const key = CE.choiceValue(root.deviceOptions, value);
            root.editor.setValue("connection", "interface-name", key === "" ? undefined : key);
        }
    }

    SettingsTextFieldRow {
        text: I18n.tr("MAC address")
        enabled: !root.locked
        value: root.macText
        placeholderText: "AA:BB:CC:DD:EE:FF"
        isError: root.macInvalid
        onValueEdited: text => {
            root.macText = text;
            const t = text.trim();
            if (t === "")
                root.setEthValue("mac-address", undefined);
            else if (CE.isValidMac(t))
                root.setEthValue("mac-address", t);
        }
    }

    SettingsDropdownRow {
        text: I18n.tr("Cloned MAC address")
        enabled: !root.locked
        options: root.clonedOptions.map(c => c.label)
        currentValue: CE.choiceLabel(root.clonedOptions, root.clonedMode)
        onValueChanged: value => {
            const mode = CE.choiceValue(root.clonedOptions, value);
            if (mode === root.clonedMode)
                return;
            if (mode === "manual") {
                root.pendingManual = true;
                if (CE.isValidMac(root.clonedText))
                    root.applyManualMac(root.clonedText);
                return;
            }
            root.pendingManual = false;
            root.setEth(CE.applyClonedMac(root.eth, mode, ""));
        }
    }

    SettingsTextFieldRow {
        visible: root.clonedMode === "manual"
        text: I18n.tr("Cloned MAC address")
        enabled: !root.locked
        value: root.clonedText
        placeholderText: "AA:BB:CC:DD:EE:FF"
        isError: root.clonedInvalid
        onValueEdited: text => {
            if (text !== root.clonedText)
                root.applyManualMac(text.trim());
        }
    }

    ConnectionSyncedRow {
        id: mtuRow
        text: "MTU"
        enabled: !root.locked
        placeholderText: I18n.tr("Auto")
        maximumLength: 10
        stored: root.eth.mtu > 0 ? String(root.eth.mtu) : ""
        check: t => /^\d*$/.test(t) && Number(t) <= 4294967295
        commit: t => root.setEthValue("mtu", parseInt(t) > 0 ? parseInt(t) : undefined)
    }

    SettingsDropdownRow {
        text: I18n.tr("Wake on LAN")
        enabled: !root.locked
        options: root.wolOptions.map(c => c.label)
        currentValue: CE.choiceLabel(root.wolOptions, root.wolCurrent)
        onValueChanged: value => root.setEthValue("wake-on-lan", CE.wolValue(CE.choiceValue(root.wolOptions, value)))
    }

    SettingsDropdownRow {
        text: I18n.tr("Link negotiation")
        enabled: !root.locked
        options: root.linkOptions.map(c => c.label)
        currentValue: CE.choiceLabel(root.linkOptions, root.linkMode)
        onValueChanged: value => {
            const mode = CE.choiceValue(root.linkOptions, value);
            if (mode === root.linkMode)
                return;
            root.applyLink(mode, root.eth.speed > 0 ? root.eth.speed : 1000, root.eth.duplex ?? "full");
        }
    }

    SettingsDropdownRow {
        visible: root.linkMode === "manual"
        text: I18n.tr("Speed")
        enabled: !root.locked
        options: root.speedOptions.map(c => c.label)
        currentValue: CE.choiceLabel(root.speedOptions, root.speedCurrent)
        onValueChanged: value => root.applyLink("manual", parseInt(CE.choiceValue(root.speedOptions, value)), root.duplexCurrent)
    }

    SettingsDropdownRow {
        visible: root.linkMode === "manual"
        text: I18n.tr("Duplex")
        enabled: !root.locked
        options: root.duplexOptions.map(c => c.label)
        currentValue: CE.choiceLabel(root.duplexOptions, root.duplexCurrent)
        onValueChanged: value => root.applyLink("manual", root.eth.speed, CE.choiceValue(root.duplexOptions, value))
    }
}
