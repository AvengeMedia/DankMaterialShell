import QtQuick
import qs.Common

SettingsRow {
    id: root

    property string hint: ""

    subtitle: hint
    resetKeys: []
    clickable: true
    showChevron: true
}
