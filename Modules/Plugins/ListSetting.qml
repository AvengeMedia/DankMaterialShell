import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property var defaultValue: []
    property var items: defaultValue
    property Component delegate: null

    width: parent.width
    spacing: Theme.spacingM

    Component.onCompleted: {
        const settings = findSettings()
        if (settings) {
            items = settings.loadValue(settingKey, defaultValue)
        }
    }

    onItemsChanged: {
        const settings = findSettings()
        if (settings) {
            settings.saveValue(settingKey, items)
        }
    }

    function findSettings() {
        let item = parent
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) {
                return item
            }
            item = item.parent
        }
        return null
    }

    function addItem(item) {
        items = items.concat([item])
    }

    function removeItem(index) {
        const newItems = items.slice()
        newItems.splice(index, 1)
        items = newItems
    }

    StyledText {
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
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

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.items
            delegate: root.delegate ? root.delegate : defaultDelegate
        }

        StyledText {
            text: I18n.tr("No items added yet")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: root.items.length === 0
        }
    }

    Component {
        id: defaultDelegate
        StyledRect {
            width: parent.width
            height: 40
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 0

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: Theme.surfaceText
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 28
                color: removeArea.containsMouse ? Theme.errorHover : Theme.error
                radius: Theme.cornerRadius

                StyledText {
                    anchors.centerIn: parent
                    text: I18n.tr("Remove")
                    color: Theme.errorText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: removeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.removeItem(index)
                    }
                }
            }
        }
    }
}
