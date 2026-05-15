import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    property bool value: defaultValue

    width: parent.width
    spacing: Theme.spacingM

    property bool isInitialized: false

    function loadValue() {
        const settings = findSettings();
        if (settings && settings.pluginService) {
            const loadedValue = settings.loadValue(settingKey, defaultValue);
            value = loadedValue;
            isInitialized = true;
        }
    }

    Component.onCompleted: {
        Qt.callLater(loadValue);
    }

    onValueChanged: {
        if (!isInitialized)
            return;
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, value);
        }
    }

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) {
                return item;
            }
            item = item.parent;
        }
        return null;
    }

    Column {
        width: parent.width - toggle.width - Theme.spacingM
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            text: root.label
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.description !== ""
        }
    }

    DankToggle {
        id: toggle
        anchors.verticalCenter: parent.verticalCenter
        checked: root.value
        onToggled: isChecked => {
            root.value = isChecked;
        }
    }
}
