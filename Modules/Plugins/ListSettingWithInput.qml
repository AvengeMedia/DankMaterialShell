import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property var fields: []
    property var defaultValue: []
    property var items: defaultValue

    width: parent.width
    spacing: Theme.spacingM

    property bool isLoading: false

    Component.onCompleted: {
        loadValue()
    }

    function loadValue() {
        const settings = findSettings()
        if (settings) {
            isLoading = true
            items = settings.loadValue(settingKey, defaultValue)
            isLoading = false
        }
    }

    onItemsChanged: {
        if (isLoading) {
            return
        }
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

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.fields

            StyledText {
                text: modelData.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: modelData.width || 200
            }
        }
    }

    Flow {
        id: inputRow
        width: parent.width
        spacing: Theme.spacingS

        property var inputFields: []

        Repeater {
            id: inputRepeater
            model: root.fields

            DankTextField {
                width: modelData.width || 200
                placeholderText: modelData.placeholder || ""

                Component.onCompleted: {
                    inputRow.inputFields.push(this)
                }

                Keys.onReturnPressed: {
                    addButton.clicked()
                }
            }
        }

        DankButton {
            id: addButton
            width: 50
            height: 36
            text: I18n.tr("Add")

            onClicked: {
                let newItem = {}
                let hasValue = false

                for (let i = 0; i < root.fields.length; i++) {
                    const field = root.fields[i]
                    const input = inputRow.inputFields[i]
                    const value = input.text.trim()

                    if (value !== "") {
                        hasValue = true
                    }

                    if (field.required && value === "") {
                        return
                    }

                    newItem[field.id] = value || (field.default || "")
                }

                if (hasValue) {
                    root.addItem(newItem)
                    for (let i = 0; i < inputRow.inputFields.length; i++) {
                        inputRow.inputFields[i].text = ""
                    }
                    if (inputRow.inputFields.length > 0) {
                        inputRow.inputFields[0].forceActiveFocus()
                    }
                }
            }
        }
    }

    StyledText {
        text: I18n.tr("Current Items")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
        visible: root.items.length > 0
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.items

            StyledRect {
                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 0

                required property int index
                required property var modelData

                Row {
                    id: itemRow
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    property var itemData: parent.modelData

                    Repeater {
                        model: root.fields

                        StyledText {
                            required property int index
                            required property var modelData

                            text: {
                                const field = modelData
                                const item = itemRow.itemData
                                if (!field || !field.id || !item) {
                                    return ""
                                }
                                const value = item[field.id]
                                return value || ""
                            }
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            width: modelData ? (modelData.width || 200) : 200
                            elide: Text.ElideRight
                        }
                    }
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
                        color: Theme.onError
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

        StyledText {
            text: I18n.tr("No items added yet")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: root.items.length === 0
        }
    }
}
