import QtQuick
import qs.Services
import "../../../Common/QmlUtils.js" as QmlUtils

QtObject {
    id: root

    required property Item target
    property string settingKey: ""

    readonly property Item flickable: QmlUtils.findParentFlickable(target.parent)
    readonly property bool pageVisible: flickable?.visible ?? false

    function sync() {
        if (!settingKey)
            return;
        if (!pageVisible) {
            SettingsSearchService.unregisterCard(settingKey, target);
            return;
        }
        SettingsSearchService.registerCard(settingKey, target, flickable, QmlUtils.findParentCollapsible(target.parent));
    }

    onPageVisibleChanged: Qt.callLater(sync)

    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey, target);
    }
}
