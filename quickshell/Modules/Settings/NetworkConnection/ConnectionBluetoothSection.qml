import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

SettingsCard {
    id: root

    required property var editor

    readonly property int rev: editor.revision
    readonly property var bt: {
        rev;
        return editor.draft?.bluetooth ?? {};
    }
    readonly property bool valid: true

    title: I18n.tr("Bluetooth")

    SettingsTextFieldRow {
        text: I18n.tr("Device")
        enabled: false
        value: String(root.bt.bdaddr ?? "")
    }

    SettingsTextFieldRow {
        text: I18n.tr("Type")
        enabled: false
        value: String(root.bt.type ?? "").toUpperCase()
    }
}
