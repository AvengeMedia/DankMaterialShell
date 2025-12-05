pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string tab: ""
    property var tags: []

    property string title: ""
    property string description: ""
    property string iconName: ""
    property bool checked: false
    property bool enabled: true

    default property alias content: expandedContent.children
    readonly property bool hasContent: expandedContent.children.length > 0

    signal toggled(bool checked)

    width: parent?.width ?? 0
    height: Theme.spacingL * 2 + mainColumn.height
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingM

        Item {
            width: parent.width
            height: headerColumn.height

            Column {
                id: headerColumn
                anchors.left: parent.left
                anchors.right: toggleSwitch.left
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingXS

                Row {
                    spacing: Theme.spacingM

                    DankIcon {
                        id: headerIcon
                        name: root.iconName
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.iconName !== ""
                    }

                    StyledText {
                        id: headerText
                        text: root.title
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.title !== ""
                    }
                }

                StyledText {
                    id: descriptionText
                    text: root.description
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                    visible: root.description !== ""
                }
            }

            DankToggle {
                id: toggleSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                hideText: true
                checked: root.checked
                enabled: root.enabled
                onToggled: checked => root.toggled(checked)
            }

            StateLayer {
                anchors.fill: parent
                disabled: !root.enabled
                stateColor: Theme.primary
                cornerRadius: root.radius
                onClicked: {
                    if (!root.enabled)
                        return;
                    root.toggled(!root.checked);
                }
            }
        }

        Column {
            id: expandedContent
            width: parent.width
            spacing: Theme.spacingM
            visible: root.checked && root.hasContent
        }
    }
}
