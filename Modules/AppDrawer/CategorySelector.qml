import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var categories: []
    property string selectedCategory: I18n.tr("All")
    property bool compact: false

    signal categorySelected(string category)

    readonly property int maxCompactItems: 8
    readonly property int itemHeight: 36
    readonly property color selectedBorderColor: "transparent"
    readonly property color unselectedBorderColor: "transparent"

    function handleCategoryClick(category) {
        categorySelected(category)
    }

    function getButtonWidth(itemCount, containerWidth) {
        return itemCount > 0 ? (containerWidth - (itemCount - 1) * Theme.spacingS) / itemCount : 0
    }

    height: compact ? itemHeight : (itemHeight * 2 + Theme.spacingS)

    Row {
        visible: compact
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: categories ? categories.slice(0, Math.min(categories.length || 0, maxCompactItems)) : []

            Rectangle {
                property int itemCount: Math.min(categories ? categories.length || 0 : 0, maxCompactItems)

                height: root.itemHeight
                width: root.getButtonWidth(itemCount, parent.width)
                radius: Theme.cornerRadius
                color: selectedCategory === modelData ? Theme.primary : Theme.surfaceContainerHigh

                StyledText {
                    anchors.centerIn: parent
                    text: modelData
                    color: selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.handleCategoryClick(modelData)
                }
            }
        }
    }

    Column {
        visible: !compact
        width: parent.width
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: categories ? categories.slice(0, Math.min(4, categories.length || 0)) : []

                Rectangle {
                    property int itemCount: Math.min(4, categories ? categories.length || 0 : 0)

                    height: root.itemHeight
                    width: root.getButtonWidth(itemCount, parent.width)
                    radius: Theme.cornerRadius
                    color: selectedCategory === modelData ? Theme.primary : Theme.surfaceContainerHigh
                    border.color: selectedCategory === modelData ? selectedBorderColor : unselectedBorderColor

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        color: selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleCategoryClick(modelData)
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS
            visible: categories && categories.length > 4

            Repeater {
                model: categories && categories.length > 4 ? categories.slice(4) : []

                Rectangle {
                    property int itemCount: categories && categories.length > 4 ? categories.length - 4 : 0

                    height: root.itemHeight
                    width: root.getButtonWidth(itemCount, parent.width)
                    radius: Theme.cornerRadius
                    color: selectedCategory === modelData ? Theme.primary : Theme.surfaceContainerHigh
                    border.color: selectedCategory === modelData ? selectedBorderColor : unselectedBorderColor

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        color: selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleCategoryClick(modelData)
                    }
                }
            }
        }
    }
}
