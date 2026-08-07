pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/QmlUtils.js" as QmlUtils

DankDropdown {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey

    width: parent?.width ?? 0
    addHorizontalPadding: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.primary, root.isHighlighted ? 0.2 : 0)
        visible: root.isHighlighted

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Component.onCompleted: {
        if (!settingKey)
            return;
        var key = settingKey;
        Qt.callLater(() => {
            if (!root.parent)
                return;
            var flickable = QmlUtils.findParentFlickable(root.parent);
            if (flickable)
                SettingsSearchService.registerCard(key, root, flickable);
        });
    }

    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey);
    }
}
