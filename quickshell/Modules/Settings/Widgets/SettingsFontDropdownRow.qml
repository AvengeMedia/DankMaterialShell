pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DankCommon.Common as DankCommon

SettingsDropdownRow {
    id: root

    property string currentFont: ""
    property string defaultFamily: Theme.defaultFontFamily
    signal fontSelected(string family)

    property var _families: ["Default"]
    property bool _enumerated: false

    function _enumerate() {
        if (_enumerated)
            return;
        const bundled = DankCommon.Fonts.bundledFamilies.filter(f => f !== root.defaultFamily);
        const system = Qt.fontFamilies().filter(f => !f.startsWith(".") && f !== root.defaultFamily && !bundled.includes(f));
        system.sort();
        _families = ["Default"].concat(bundled, system);
        _enumerated = true;
    }

    enableFuzzySearch: true
    popupWidthOffset: SettingsMetrics.fontMenuExtraWidth
    options: _families
    currentValue: (root.currentFont === "" || root.currentFont === root.defaultFamily) ? "Default" : root.currentFont
    onValueChanged: value => root.fontSelected(value === "Default" ? "" : value)

    Component.onCompleted: Qt.callLater(_enumerate)
}
