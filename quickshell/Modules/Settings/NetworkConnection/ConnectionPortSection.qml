import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.DCommon.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor

    readonly property string sectionKey: "bridge-port"
    readonly property int rev: editor.revision
    readonly property var port: {
        rev;
        return CE.portOf(editor.draft);
    }
    readonly property var bp: {
        rev;
        return editor.draft?.[sectionKey] ?? {};
    }
    readonly property var controller: (editor.profiles ?? []).find(p => p.uuid === port?.controller || p.interfaceName === port?.controller) ?? null
    readonly property string portType: port?.type || controller?.type || ""
    readonly property bool isBridge: portType === "bridge"
    readonly property string typeLabel: portType === "bond" ? I18n.tr("Bond", "network connection type: bonded interfaces") : portType === "bridge" ? I18n.tr("Bridge", "network connection type: network bridge") : (portType || (port?.controller ?? ""))
    readonly property bool valid: priorityRow.ok && costRow.ok

    title: typeLabel

    SettingsRow {
        title: root.typeLabel
        subtitle: root.controller?.id ?? root.port?.controller ?? ""

        DActionButton {
            enabled: !root.editor.dirty && root.controller !== null
            buttonSize: Theme.iconButtonSize
            iconName: "tune"
            tooltipText: I18n.tr("Configure")
            onClicked: SettingsUiState.selectConnection(root.controller.uuid, root.controller.id, "")
        }
    }

    ConnectionNumberRow {
        id: priorityRow
        editor: root.editor
        section: root.sectionKey
        key: "priority"
        visible: root.isBridge
        enabled: !root.editor.readOnly
        text: I18n.tr("Priority")
        max: 63
        placeholderText: "32"
    }

    ConnectionNumberRow {
        id: costRow
        editor: root.editor
        section: root.sectionKey
        key: "path-cost"
        visible: root.isBridge
        enabled: !root.editor.readOnly
        text: I18n.tr("Path cost", "bridge port STP cost")
        min: 1
        max: 65535
        placeholderText: "100"
    }

    SettingsToggleRow {
        visible: root.isBridge
        enabled: !root.editor.readOnly
        text: I18n.tr("Hairpin mode", "bridge port option")
        checked: root.bp["hairpin-mode"] === true
        onToggled: checked => {
            const stored = root.editor.original?.[root.sectionKey]?.["hairpin-mode"] !== undefined;
            root.editor.setValue(root.sectionKey, "hairpin-mode", !checked && !stored ? undefined : checked);
        }
    }
}
