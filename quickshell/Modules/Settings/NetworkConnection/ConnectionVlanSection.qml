import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets
import "../../../Common/ConnectionEditor.js" as CE

SettingsCard {
    id: root

    required property var editor

    readonly property string sectionKey: "vlan"
    readonly property int rev: editor.revision
    readonly property var vlan: {
        rev;
        return editor.draft?.[sectionKey] ?? {};
    }
    readonly property string ownUuid: {
        rev;
        return String(editor.profile?.uuid ?? editor.value("connection", "uuid", ""));
    }
    readonly property string parentValue: String(vlan.parent ?? "")
    readonly property string storedIfname: {
        rev;
        return String(editor.value("connection", "interface-name", ""));
    }
    // vlan.flags absent means reorder-headers only.
    readonly property int flags: vlan.flags ?? 1

    property string ifText: ""
    property string ifStored: ""
    property string lastDefault: ""
    property bool ifTouched: false

    readonly property bool ifValid: ifText.trim() !== "" && CE.isValidIfname(ifText.trim())
    readonly property bool parentValid: parentValue !== ""
    readonly property bool valid: parentValid && idRow.ok && ifValid

    readonly property var parentChoices: {
        const names = (NetworkService.ethernetDevices ?? []).map(d => d.name);
        (editor.profiles ?? []).forEach(p => {
            if ((p.type === "bond" || p.type === "bridge") && p.uuid !== ownUuid && p.interfaceName && !names.includes(p.interfaceName))
                names.push(p.interfaceName);
        });
        const list = names.map(n => ({
                    "label": n,
                    "value": n
                }));
        return parentValue === "" ? list : CE.withChoice(list, parentValue);
    }

    title: "VLAN"
    enabled: !editor.readOnly

    function defaultName() {
        const v = editor.draft?.[sectionKey] ?? {};
        return CE.defaultVlanIfname(String(v.parent ?? ""), String(v.id ?? ""));
    }

    // Refills a field only when its stored value changed and differs from what was typed.
    function syncTexts() {
        if (storedIfname !== ifStored) {
            ifStored = storedIfname;
            if (storedIfname !== ifText.trim())
                ifText = storedIfname;
        }
    }

    // The name follows parent.id until the user edits it or it was set to something else.
    function followDefault() {
        const def = defaultName();
        if (def === lastDefault)
            return;
        const previous = lastDefault;
        lastDefault = def;
        const stored = String(editor.value("connection", "interface-name", ""));
        if (ifTouched || (!editor.isNew && stored !== previous))
            return;
        if (def !== "" && stored !== def)
            editor.setValue("connection", "interface-name", def);
    }

    function setFlag(bit, on) {
        editor.setValue(sectionKey, "flags", on ? (flags | bit) : (flags & ~bit));
    }

    onStoredIfnameChanged: syncTexts()

    Component.onCompleted: {
        syncTexts();
        lastDefault = defaultName();
    }

    SettingsDropdownRow {
        text: I18n.tr("Parent", "parent network interface of a VLAN or PPPoE connection")
        options: root.parentChoices.map(c => c.label)
        emptyText: I18n.tr("Select", "verb, dropdown placeholder or option that opens a picker")
        currentValue: CE.choiceLabel(root.parentChoices, root.parentValue)
        onValueChanged: value => {
            const parent = CE.choiceValue(root.parentChoices, value);
            if (parent === undefined || parent === root.parentValue)
                return;
            root.editor.setValue(root.sectionKey, "parent", parent);
            root.followDefault();
        }
    }

    ConnectionSyncedRow {
        id: idRow
        text: "VLAN ID"
        placeholderText: "0-4094"
        maximumLength: 4
        stored: root.vlan.id === undefined || root.vlan.id === null ? "" : String(root.vlan.id)
        check: t => /^\d{1,4}$/.test(t) && Number(t) <= 4094
        commit: t => {
            root.editor.setValue(root.sectionKey, "id", Number(t));
            root.followDefault();
        }
    }

    SettingsTextFieldRow {
        text: I18n.tr("Interface")
        value: root.ifText
        isError: !root.ifValid
        onValueEdited: text => {
            if (text === root.ifText)
                return;
            root.ifText = text;
            root.ifTouched = true;
            const t = text.trim();
            if (t === "" || !CE.isValidIfname(t))
                return;
            root.ifStored = t;
            root.editor.setValue("connection", "interface-name", t);
        }
    }

    SettingsToggleRow {
        text: I18n.tr("Reorder headers", "VLAN flag")
        checked: (root.flags & 1) !== 0
        onToggled: checked => root.setFlag(1, checked)
    }

    SettingsToggleRow {
        text: "GVRP"
        checked: (root.flags & 2) !== 0
        onToggled: checked => root.setFlag(2, checked)
    }

    SettingsToggleRow {
        text: I18n.tr("Loose binding", "VLAN flag: don't follow the parent's link state")
        checked: (root.flags & 4) !== 0
        onToggled: checked => root.setFlag(4, checked)
    }

    SettingsToggleRow {
        text: "MVRP"
        checked: (root.flags & 8) !== 0
        onToggled: checked => root.setFlag(8, checked)
    }
}
