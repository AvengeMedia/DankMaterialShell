import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor

    readonly property string sectionKey: "bridge"
    readonly property int rev: editor.revision
    readonly property var br: {
        rev;
        return editor.draft?.[sectionKey] ?? {};
    }
    readonly property bool stp: br.stp !== false
    readonly property bool valid: ifaceRow.ok && macRow.ok && priorityRow.ok && delayRow.ok && helloRow.ok && ageRow.ok && agingRow.ok

    title: I18n.tr("Bridge", "network connection type: network bridge")
    enabled: !editor.readOnly

    ConnectionSyncedRow {
        id: ifaceRow
        text: I18n.tr("Interface")
        stored: {
            root.rev;
            return String(root.editor.value("connection", "interface-name", ""));
        }
        check: t => CE.isValidIfname(t)
        commit: t => root.editor.setValue("connection", "interface-name", t)
    }

    ConnectionSyncedRow {
        id: macRow
        text: I18n.tr("MAC address", "network hardware setting")
        placeholderText: "AA:BB:CC:DD:EE:FF"
        stored: {
            root.rev;
            return String(root.br["mac-address"] ?? "");
        }
        check: t => t === "" || CE.isValidMac(t)
        commit: t => root.editor.setValue(root.sectionKey, "mac-address", t === "" ? undefined : t)
    }

    SettingsToggleRow {
        text: "STP"
        checked: root.stp
        onToggled: checked => {
            const stored = root.editor.original?.[root.sectionKey]?.stp !== undefined;
            root.editor.setValue(root.sectionKey, "stp", checked && !stored ? undefined : checked);
        }
    }

    ConnectionNumberRow {
        id: priorityRow
        editor: root.editor
        section: root.sectionKey
        key: "priority"
        text: I18n.tr("Priority")
        max: 65535
        placeholderText: "32768"
        enabled: root.stp
    }

    ConnectionNumberRow {
        id: delayRow
        editor: root.editor
        section: root.sectionKey
        key: "forward-delay"
        text: I18n.tr("Forward delay", "bridge STP, seconds")
        min: 2
        max: 30
        placeholderText: "15"
        enabled: root.stp
    }

    ConnectionNumberRow {
        id: helloRow
        editor: root.editor
        section: root.sectionKey
        key: "hello-time"
        text: I18n.tr("Hello time", "bridge STP, seconds")
        min: 1
        max: 10
        placeholderText: "2"
        enabled: root.stp
    }

    ConnectionNumberRow {
        id: ageRow
        editor: root.editor
        section: root.sectionKey
        key: "max-age"
        text: I18n.tr("Max age", "bridge STP, seconds")
        min: 6
        max: 40
        placeholderText: "20"
        enabled: root.stp
    }

    ConnectionNumberRow {
        id: agingRow
        editor: root.editor
        section: root.sectionKey
        key: "ageing-time"
        text: I18n.tr("Aging time", "bridge MAC address table, seconds")
        max: 1000000
        placeholderText: "300"
    }
}
