pragma ComponentBehavior: Bound

import QtQuick
import qs.Widgets

DankDropdown {
    id: root

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    width: parent?.width ?? 0
    addHorizontalPadding: true
}
