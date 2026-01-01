pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    property string title: ""
    property string iconName: ""
    property bool collapsible: false
    property bool expanded: true

    default property alias content: contentColumn.children
    property alias headerActions: headerActionsRow.children

    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey

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
    property bool userToggledCollapse: false

    function findParentFlickable() {
        let p = root.parent;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentItem")) {
                return p;
            }
            p = p.parent;
        }
        return null;
    }

    Component.onCompleted: {
        if (settingKey) {
            let flickable = findParentFlickable();
            if (flickable) {
                SettingsSearchService.registerCard(settingKey, root, flickable);
            }
        }
    }

    Component.onDestruction: {
        if (settingKey) {
            SettingsSearchService.unregisterCard(settingKey);
        }
    }

    Behavior on height {
        enabled: root.userToggledCollapse
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
            onRunningChanged: {
                if (!running)
                    root.userToggledCollapse = false;
            }
        }
    }

    Rectangle {
        id: highlightBorder
        anchors.fill: parent
        anchors.margins: -2
        radius: root.radius + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        opacity: root.isHighlighted ? 1 : 0
        visible: opacity > 0
        z: 100

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
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
            height: root.hasHeader ? Math.max(headerIcon.height, headerText.height, headerActionsRow.height) : 0
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

            Row {
                id: headerActionsRow
                anchors.right: caretIcon.left
                anchors.rightMargin: root.collapsible ? Theme.spacingS : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
            }

            DankIcon {
                id: caretIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: root.expanded ? "expand_less" : "expand_more"
                size: Theme.iconSize - 2
                color: Theme.surfaceVariantText
                visible: root.collapsible
            }

            MouseArea {
                anchors.left: parent.left
                anchors.right: headerActionsRow.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.userToggledCollapse = true;
                    root.expanded = !root.expanded;
                }
            }

            MouseArea {
                anchors.left: caretIcon.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: -Theme.spacingS
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.userToggledCollapse = true;
                    root.expanded = !root.expanded;
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.spacingM
            visible: !root.collapsed
        }
    }
}
