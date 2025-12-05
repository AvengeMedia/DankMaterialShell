pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string tab: ""
    property var tags: []

    property string title: ""
    property string iconName: ""
    property bool collapsible: false
    property bool expanded: true

    default property alias content: contentColumn.children

    width: parent?.width ?? 0
    height: {
        var hasHeader = root.title !== "" || root.iconName !== "";
        if (collapsed)
            return headerRow.height + Theme.spacingL * 2;
        var h = Theme.spacingL * 2 + contentColumn.height;
        if (hasHeader)
            h += headerRow.height + Theme.spacingM;
        return h;
    }
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    readonly property bool collapsed: collapsible && !expanded
    readonly property bool hasHeader: root.title !== "" || root.iconName !== ""
    property bool animationsEnabled: false

    Component.onCompleted: Qt.callLater(() => animationsEnabled = true)

    Behavior on height {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Column {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: root.hasHeader ? Theme.spacingM : 0
        clip: true

        Item {
            id: headerRow
            width: parent.width
            height: root.hasHeader ? Math.max(headerIcon.height, headerText.height) : 0
            visible: root.hasHeader

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
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

            DankIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: root.expanded ? "expand_less" : "expand_more"
                size: Theme.iconSize - 2
                color: Theme.surfaceVariantText
                visible: root.collapsible
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!root.collapsible)
                        return;
                    root.expanded = !root.expanded;
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.spacingM
            visible: !root.collapsed
            opacity: root.collapsed ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }
}
