pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.DCommon.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor

    readonly property int rev: editor.revision
    readonly property var pppoe: {
        rev;
        return editor.draft?.pppoe ?? {};
    }
    readonly property bool passwordSaved: CE.secretSaved(pppoe, "password")
    readonly property bool valid: String(pppoe.username ?? "").trim() !== ""
    readonly property string storedParent: pppoe.parent ?? ""

    // Only wired devices are offered; a stored value that isn't one stays selectable as a literal.
    readonly property var parentChoices: CE.withChoice([
        {
            "label": I18n.tr("Auto"),
            "value": ""
        }
    ].concat((NetworkService.ethernetDevices ?? []).map(d => ({
                "label": d.name,
                "value": d.name
            }))), storedParent)

    function setKey(key, v) {
        editor.setValue("pppoe", key, v);
    }

    function setText(key, text) {
        const t = text.trim();
        setKey(key, t === "" ? undefined : t);
    }

    function setSaved(saved) {
        setKey("password-flags", saved ? undefined : 2);
        // An unsaved password is asked on connect, so neither a typed nor a stored one is kept.
        if (!saved)
            setKey("password", undefined);
    }

    component TextRow: ConnectionSyncedRow {
        id: textRow
        required property string dataKey

        stored: root.pppoe[dataKey] ?? ""
        commit: t => root.setText(textRow.dataKey, t)
    }

    title: "DSL"
    enabled: !editor.readOnly

    SettingsDropdownRow {
        text: I18n.tr("Parent", "parent network interface of a VLAN or PPPoE connection")
        options: root.parentChoices.map(c => c.label)
        currentValue: CE.choiceLabel(root.parentChoices, root.storedParent)
        onValueChanged: value => {
            const v = CE.choiceValue(root.parentChoices, value);
            if (v !== undefined && v !== root.storedParent)
                root.setKey("parent", v === "" ? undefined : v);
        }
    }

    TextRow {
        dataKey: "service"
        text: I18n.tr("Service", "PPPoE service name")
    }

    TextRow {
        dataKey: "username"
        text: I18n.tr("Username")
        isError: !root.valid
    }

    SettingsRow {
        body: DTextField {
            width: parent.width
            outlined: true
            controlHeight: Theme.fieldHeightLarge
            leftIconName: "lock"
            font.pixelSize: Theme.fontSizeMedium
            textColor: Theme.surfaceText
            placeholderText: I18n.tr("Password")
            echoMode: TextInput.Password
            showPasswordToggle: true
            enabled: root.passwordSaved
            text: root.pppoe.password ?? ""
            onTextEdited: root.setKey("password", text === "" ? undefined : text)
        }
    }

    SettingsToggleRow {
        text: I18n.tr("Save password")
        checked: root.passwordSaved
        onToggled: checked => root.setSaved(checked)
    }
}
