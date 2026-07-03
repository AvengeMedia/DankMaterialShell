pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

SettingsDropdownRow {
    id: root

    property string currentFont: ""
    signal fontSelected(string family)

    property var _families: ["Default"]
    property bool _enumerated: false

    function _enumerate() {
        if (_enumerated)
            return;
        var fonts = Qt.fontFamilies().filter(f => !f.startsWith("."));
        fonts.sort();
        fonts.unshift("Default");
        _families = fonts;
        _enumerated = true;
    }

    enableFuzzySearch: true
    popupWidthOffset: 100
    maxPopupHeight: 400
    options: _families
    currentValue: (root.currentFont === "" || root.currentFont === Theme.defaultFontFamily) ? "Default" : root.currentFont
    onValueChanged: value => root.fontSelected(value === "Default" ? "" : value)

    Component.onCompleted: Qt.callLater(_enumerate)
}
