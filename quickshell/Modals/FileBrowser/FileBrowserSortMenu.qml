import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: sortMenu

    property string sortBy: "name"
    property bool sortAscending: true

    signal sortBySelected(string value)
    signal sortOrderSelected(bool ascending)

    width: 200
    height: sortColumn.height + Theme.spacingM * 2
    color: Theme.surfaceContainer
    radius: Theme.cornerRadius
    border.color: Theme.outlineMedium
    border.width: 1
    visible: false
    z: 100

    Column {
        id: sortColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS

        StyledText {
            text: "Sort By"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            font.weight: Font.Medium
        }

        Repeater {
            model: [
                {
                    "name": "Name",
                    "value": "name"
                },
                {
                    "name": "Size",
                    "value": "size"
                },
                {
                    "name": "Modified",
                    "value": "modified"
                },
                {
                    "name": "Type",
                    "value": "type"
                }
            ]

            StyledRect {
                width: sortColumn?.width ?? 0
                height: 32
                radius: Theme.cornerRadius
                color: sortMouseArea.containsMouse ? Theme.surfaceVariant : (sortBy === modelData?.value ? Theme.surfacePressed : "transparent")

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        name: sortBy === modelData?.value ? "check" : ""
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sortBy === modelData?.value
                    }

                    StyledText {
                        text: modelData?.name ?? ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: sortBy === modelData?.value ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: sortMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sortMenu.sortBySelected(modelData?.value ?? "name");
                        sortMenu.visible = false;
                    }
                }
            }
        }

        StyledRect {
            width: sortColumn.width
            height: 1
            color: Theme.outline
        }

        StyledText {
            text: "Order"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            font.weight: Font.Medium
            topPadding: Theme.spacingXS
        }

        StyledRect {
            width: sortColumn?.width ?? 0
            height: 32
            radius: Theme.cornerRadius
            color: ascMouseArea.containsMouse ? Theme.surfaceVariant : (sortAscending ? Theme.surfacePressed : "transparent")

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                spacing: Theme.spacingS

                DankIcon {
                    name: "arrow_upward"
                    size: Theme.iconSizeSmall
                    color: sortAscending ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Ascending"
                    font.pixelSize: Theme.fontSizeMedium
                    color: sortAscending ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: ascMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sortMenu.sortOrderSelected(true);
                    sortMenu.visible = false;
                }
            }
        }

        StyledRect {
            width: sortColumn?.width ?? 0
            height: 32
            radius: Theme.cornerRadius
            color: descMouseArea.containsMouse ? Theme.surfaceVariant : (!sortAscending ? Theme.surfacePressed : "transparent")

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                spacing: Theme.spacingS

                DankIcon {
                    name: "arrow_downward"
                    size: Theme.iconSizeSmall
                    color: !sortAscending ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Descending"
                    font.pixelSize: Theme.fontSizeMedium
                    color: !sortAscending ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: descMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sortMenu.sortOrderSelected(false);
                    sortMenu.visible = false;
                }
            }
        }
    }
}
