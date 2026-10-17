pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Modules.Settings.Widgets
import qs.DCommon.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor
    readonly property bool valid: gatewayText.trim() !== ""

    readonly property int revision: editor.revision
    readonly property var vpnData: {
        revision;
        return editor.draft?.vpn?.data ?? {};
    }
    readonly property bool locked: editor.readOnly

    readonly property string protocolKey: vpnData.protocol ?? "anyconnect"
    readonly property var protocols: CE.withChoice([["Cisco AnyConnect", "anyconnect"], ["Juniper Network Connect", "nc"], ["GlobalProtect", "gp"], ["Pulse Connect Secure", "pulse"], ["F5", "f5"], ["Fortinet", "fortinet"], ["Array Networks", "array"]].map(p => ({
                "label": p[0],
                "value": p[1]
            })), protocolKey)

    readonly property string gatewayText: vpnData.gateway ?? ""

    property string browseKey: ""
    property var browserLoader: LazyLoader {
        active: false

        FileBrowserModal {
            bucket: "certificate"
            filters: ["*.pem", "*.crt", "*.cer", "*.der", "*.p12", "*.pfx", "*.key", "*"]
            onAccepted: paths => root.setData(root.browseKey, paths[0])
        }
    }

    title: "OpenConnect"

    // Writes one vpn.data entry (empty removes it); other keys, including the *-flags ones, are kept.
    function setData(key, value) {
        const next = Object.assign({}, vpnData);
        const t = (value ?? "").trim();
        if (t === "")
            delete next[key];
        else
            next[key] = t;
        editor.setValue("vpn", "data", Object.keys(next).length === 0 ? undefined : next);
    }

    function browse(key) {
        browseKey = key;
        browserLoader.active = true;
        if (browserLoader.item)
            browserLoader.item.open();
    }

    component DataRow: ConnectionSyncedRow {
        id: dataRow
        required property string dataKey

        enabled: !root.locked
        stored: root.vpnData[dataKey] ?? ""
        commit: t => root.setData(dataRow.dataKey, t)
    }

    DataRow {
        dataKey: "gateway"
        text: I18n.tr("Gateway", "network IP setting label")
        isError: root.gatewayText.trim() === ""
    }

    SettingsDropdownRow {
        text: I18n.tr("Protocol")
        enabled: !root.locked
        options: root.protocols.map(c => c.label)
        currentValue: CE.choiceLabel(root.protocols, root.protocolKey)
        onValueChanged: value => root.setData("protocol", CE.choiceValue(root.protocols, value) ?? value)
    }

    Repeater {
        model: [
            {
                "key": "cacert",
                "label": I18n.tr("CA certificate", "network authentication certificate file field")
            },
            {
                "key": "usercert",
                "label": I18n.tr("Client certificate", "network authentication certificate file field")
            },
            {
                "key": "userkey",
                "label": I18n.tr("Private key", "network authentication key file field")
            }
        ]

        DataRow {
            id: pathRow

            required property var modelData

            dataKey: modelData.key
            text: modelData.label
            actions: DActionButton {
                iconName: "folder_open"
                tooltipText: I18n.tr("Select File")
                Accessible.name: pathRow.text + ": " + tooltipText
                onClicked: root.browse(pathRow.modelData.key)
            }
        }
    }

    DataRow {
        dataKey: "proxy"
        text: I18n.tr("Proxy", "VPN proxy server field")
    }
}
