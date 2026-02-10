import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var notificationGroup
    property bool expanded: (NotificationService.expandedGroups[notificationGroup && notificationGroup.key] || false)
    property bool descriptionExpanded: (NotificationService.expandedMessages[(notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.notification && notificationGroup.latestNotification.notification.id) ? (notificationGroup.latestNotification.notification.id + "_desc") : ""] || false)
    property bool userInitiatedExpansion: false
    property bool isAnimating: false
    property bool animateExpansion: true

    property bool isGroupSelected: false
    property int selectedNotificationIndex: -1
    property bool keyboardNavigationActive: false

    readonly property bool compactMode: SettingsData.notificationCompactMode
    readonly property real cardPadding: compactMode ? Theme.spacingS : Theme.spacingM
    readonly property real iconSize: compactMode ? 48 : 63
    readonly property real contentSpacing: compactMode ? Theme.spacingXS : Theme.spacingS
    readonly property real badgeSize: compactMode ? 16 : 18
    readonly property real actionButtonHeight: compactMode ? 20 : 24
    readonly property real collapsedContentHeight: iconSize
    readonly property real baseCardHeight: cardPadding * 2 + collapsedContentHeight + actionButtonHeight + contentSpacing

    width: parent ? parent.width : 400
    height: expanded ? (expandedContent.height + cardPadding * 2) : (baseCardHeight + collapsedContent.extraHeight)
    readonly property real targetHeight: expanded ? (expandedContent.height + cardPadding * 2) : (baseCardHeight + collapsedContent.extraHeight)
    radius: Theme.cornerRadius
    property bool __initialized: false

    Component.onCompleted: {
        Qt.callLater(() => {
            __initialized = true;
        });
    }

    Behavior on border.color {
        enabled: root.__initialized
        ColorAnimation {
            duration: root.__initialized ? Theme.shortDuration : 0
            easing.type: Theme.standardEasing
        }
    }

    color: {
        if (isGroupSelected && keyboardNavigationActive) {
            return Theme.primaryPressed;
        }
        if (keyboardNavigationActive && expanded && selectedNotificationIndex >= 0) {
            return Theme.primaryHoverLight;
        }
        return Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency);
    }
    border.color: {
        if (isGroupSelected && keyboardNavigationActive) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5);
        }
        if (keyboardNavigationActive && expanded && selectedNotificationIndex >= 0) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2);
        }
        if (notificationGroup?.latestNotification?.urgency === NotificationUrgency.Critical) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
        }
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05);
    }
    border.width: {
        if (isGroupSelected && keyboardNavigationActive) {
            return 1.5;
        }
        if (keyboardNavigationActive && expanded && selectedNotificationIndex >= 0) {
            return 1;
        }
        if (notificationGroup?.latestNotification?.urgency === NotificationUrgency.Critical) {
            return 2;
        }
        return 1;
    }
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: notificationGroup?.latestNotification?.urgency === NotificationUrgency.Critical
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Theme.primary
            }
            GradientStop {
                position: 0.02
                color: Theme.primary
            }
            GradientStop {
                position: 0.021
                color: "transparent"
            }
        }
        opacity: 1.0
    }

    Item {
        id: collapsedContent

        readonly property real expandedTextHeight: descriptionText.contentHeight
        readonly property real twoLineHeight: descriptionText.font.pixelSize * 1.2 * 2
        readonly property real extraHeight: (descriptionExpanded && expandedTextHeight > twoLineHeight + 2) ? (expandedTextHeight - twoLineHeight) : 0

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: cardPadding
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL + (compactMode ? 32 : 40)
        height: collapsedContentHeight + extraHeight
        visible: !expanded

        DankCircularImage {
            id: iconContainer
            readonly property string rawImage: notificationGroup?.latestNotification?.image || ""
            readonly property string iconFromImage: {
                if (rawImage.startsWith("image://icon/"))
                    return rawImage.substring(13);
                return "";
            }
            readonly property bool imageHasSpecialPrefix: {
                const icon = iconFromImage;
                return icon.startsWith("material:") || icon.startsWith("svg:") || icon.startsWith("unicode:") || icon.startsWith("image:");
            }
            readonly property bool hasNotificationImage: rawImage !== "" && !rawImage.startsWith("image://icon/")

            width: iconSize
            height: iconSize
            anchors.left: parent.left
            anchors.top: parent.top

            imageSource: {
                if (hasNotificationImage)
                    return notificationGroup.latestNotification.cleanImage;
                if (imageHasSpecialPrefix)
                    return "";
                const appIcon = notificationGroup?.latestNotification?.appIcon;
                if (!appIcon)
                    return iconFromImage ? "image://icon/" + iconFromImage : "";
                if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://") || appIcon.includes("/"))
                    return appIcon;
                if (appIcon.startsWith("material:") || appIcon.startsWith("svg:") || appIcon.startsWith("unicode:") || appIcon.startsWith("image:"))
                    return "";
                return Quickshell.iconPath(appIcon, true);
            }

            hasImage: hasNotificationImage
            fallbackIcon: {
                if (imageHasSpecialPrefix)
                    return iconFromImage;
                return notificationGroup?.latestNotification?.appIcon || iconFromImage || "";
            }
            fallbackText: {
                const appName = notificationGroup?.appName || "?";
                return appName.charAt(0).toUpperCase();
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: width / 2
                color: "transparent"
                border.color: root.color
                border.width: 5
                visible: parent.hasImage
                antialiasing: true
            }

            Rectangle {
                width: badgeSize
                height: badgeSize
                radius: badgeSize / 2
                color: Theme.primary
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -2
                anchors.rightMargin: -2
                visible: (notificationGroup?.count || 0) > 1

                StyledText {
                    anchors.centerIn: parent
                    text: (notificationGroup?.count || 0) > 99 ? "99+" : (notificationGroup?.count || 0).toString()
                    color: Theme.primaryText
                    font.pixelSize: compactMode ? 8 : 9
                    font.weight: Font.Bold
                }
            }
        }

        Rectangle {
            id: textContainer

            anchors.left: iconContainer.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: contentSpacing
            color: "transparent"

            Column {
                width: parent.width
                anchors.top: parent.top
                spacing: compactMode ? 1 : 2

                StyledText {
                    width: parent.width
                    text: {
                        const timeStr = (notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.timeStr) || "";
                        const appName = (notificationGroup && notificationGroup.appName) || "";
                        return timeStr.length > 0 ? `${appName} • ${timeStr}` : appName;
                    }
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                StyledText {
                    text: (notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.summary) || ""
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                StyledText {
                    id: descriptionText
                    property string fullText: (notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.htmlBody) || ""
                    property bool hasMoreText: truncated

                    text: fullText
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: descriptionExpanded ? -1 : (compactMode ? 1 : 2)
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                    linkColor: Theme.primary
                    onLinkActivated: link => Qt.openUrlExternally(link)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : (parent.hasMoreText || descriptionExpanded) ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: mouse => {
                            if (!parent.hoveredLink && (parent.hasMoreText || descriptionExpanded)) {
                                const messageId = (notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.notification && notificationGroup.latestNotification.notification.id) ? (notificationGroup.latestNotification.notification.id + "_desc") : "";
                                NotificationService.toggleMessageExpansion(messageId);
                            }
                        }

                        propagateComposedEvents: true
                        onPressed: mouse => {
                            if (parent.hoveredLink)
                                mouse.accepted = false;
                        }
                        onReleased: mouse => {
                            if (parent.hoveredLink)
                                mouse.accepted = false;
                        }
                    }
                }
            }
        }
    }

    Column {
        id: expandedContent
        objectName: "expandedContent"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: cardPadding
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: compactMode ? Theme.spacingXS : Theme.spacingS
        visible: expanded

        Item {
            width: parent.width
            height: compactMode ? 32 : 40

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingL + (compactMode ? 32 : 40)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                StyledText {
                    text: notificationGroup?.appName || ""
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    width: badgeSize
                    height: badgeSize
                    radius: badgeSize / 2
                    color: Theme.primary
                    visible: (notificationGroup?.count || 0) > 1
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        anchors.centerIn: parent
                        text: (notificationGroup?.count || 0) > 99 ? "99+" : (notificationGroup?.count || 0).toString()
                        color: Theme.primaryText
                        font.pixelSize: compactMode ? 8 : 9
                        font.weight: Font.Bold
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: compactMode ? Theme.spacingS : Theme.spacingL

            Repeater {
                id: notificationRepeater
                objectName: "notificationRepeater"
                model: ScriptModel {
                    values: notificationGroup?.notifications?.slice(0, 10) || []
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool messageExpanded: NotificationService.expandedMessages[modelData?.notification?.id] || false
                    readonly property bool isSelected: root.selectedNotificationIndex === index
                    readonly property real expandedIconSize: compactMode ? 40 : 48
                    readonly property real expandedItemPadding: compactMode ? Theme.spacingS : Theme.spacingM
                    readonly property real expandedBaseHeight: expandedItemPadding * 2 + expandedIconSize + actionButtonHeight + contentSpacing * 2
                    property bool __delegateInitialized: false

                    Component.onCompleted: {
                        Qt.callLater(() => {
                            __delegateInitialized = true;
                        });
                    }

                    width: parent.width
                    height: {
                        if (!messageExpanded)
                            return expandedBaseHeight;
                        const twoLineHeight = bodyText.font.pixelSize * 1.2 * 2;
                        if (bodyText.implicitHeight > twoLineHeight + 2)
                            return expandedBaseHeight + bodyText.implicitHeight - twoLineHeight;
                        return expandedBaseHeight;
                    }
                    radius: Theme.cornerRadius
                    color: isSelected ? Theme.primaryPressed : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                    border.width: 1

                    Behavior on border.color {
                        enabled: __delegateInitialized
                        ColorAnimation {
                            duration: __delegateInitialized ? Theme.shortDuration : 0
                            easing.type: Theme.standardEasing
                        }
                    }

                    Behavior on height {
                        enabled: false
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: compactMode ? Theme.spacingS : Theme.spacingM
                        anchors.bottomMargin: contentSpacing

                        DankCircularImage {
                            id: messageIcon

                            readonly property string rawImage: modelData?.image || ""
                            readonly property string iconFromImage: {
                                if (rawImage.startsWith("image://icon/"))
                                    return rawImage.substring(13);
                                return "";
                            }
                            readonly property bool imageHasSpecialPrefix: {
                                const icon = iconFromImage;
                                return icon.startsWith("material:") || icon.startsWith("svg:") || icon.startsWith("unicode:") || icon.startsWith("image:");
                            }
                            readonly property bool hasNotificationImage: rawImage !== "" && !rawImage.startsWith("image://icon/")

                            width: expandedIconSize
                            height: expandedIconSize
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: compactMode ? Theme.spacingM : Theme.spacingXL

                            imageSource: {
                                if (hasNotificationImage)
                                    return modelData.cleanImage;
                                if (imageHasSpecialPrefix)
                                    return "";
                                const appIcon = modelData?.appIcon;
                                if (!appIcon)
                                    return iconFromImage ? "image://icon/" + iconFromImage : "";
                                if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://") || appIcon.includes("/"))
                                    return appIcon;
                                if (appIcon.startsWith("material:") || appIcon.startsWith("svg:") || appIcon.startsWith("unicode:") || appIcon.startsWith("image:"))
                                    return "";
                                return Quickshell.iconPath(appIcon, true);
                            }

                            fallbackIcon: {
                                if (imageHasSpecialPrefix)
                                    return iconFromImage;
                                return modelData?.appIcon || iconFromImage || "";
                            }

                            fallbackText: {
                                const appName = modelData?.appName || "?";
                                return appName.charAt(0).toUpperCase();
                            }
                        }

                        Item {
                            anchors.left: messageIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: buttonArea.top
                                anchors.bottomMargin: contentSpacing
                                spacing: compactMode ? 1 : 2

                                StyledText {
                                    width: parent.width
                                    text: modelData?.timeStr || ""
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    visible: text.length > 0
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData?.summary || ""
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    visible: text.length > 0
                                }

                                StyledText {
                                    id: bodyText
                                    property bool hasMoreText: truncated

                                    text: modelData?.htmlBody || ""
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    width: parent.width
                                    elide: messageExpanded ? Text.ElideNone : Text.ElideRight
                                    maximumLineCount: messageExpanded ? -1 : 2
                                    wrapMode: Text.WordWrap
                                    visible: text.length > 0
                                    linkColor: Theme.primary
                                    onLinkActivated: link => Qt.openUrlExternally(link)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : (bodyText.hasMoreText || messageExpanded) ? Qt.PointingHandCursor : Qt.ArrowCursor

                                        onClicked: mouse => {
                                            if (!parent.hoveredLink && (bodyText.hasMoreText || messageExpanded)) {
                                                NotificationService.toggleMessageExpansion(modelData?.notification?.id || "");
                                            }
                                        }

                                        propagateComposedEvents: true
                                        onPressed: mouse => {
                                            if (parent.hoveredLink) {
                                                mouse.accepted = false;
                                            }
                                        }
                                        onReleased: mouse => {
                                            if (parent.hoveredLink) {
                                                mouse.accepted = false;
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: buttonArea
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: actionButtonHeight + contentSpacing

                                Row {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    spacing: contentSpacing

                                    Repeater {
                                        model: modelData?.actions || []

                                        Rectangle {
                                            property bool isHovered: false

                                            width: Math.max(expandedActionText.implicitWidth + Theme.spacingM, compactMode ? 40 : 50)
                                            height: actionButtonHeight
                                            radius: Theme.spacingXS
                                            color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                                            StyledText {
                                                id: expandedActionText
                                                text: {
                                                    const baseText = modelData.text || "View";
                                                    if (keyboardNavigationActive && (isGroupSelected || selectedNotificationIndex >= 0))
                                                        return `${baseText} (${index + 1})`;
                                                    return baseText;
                                                }
                                                color: parent.isHovered ? Theme.primary : Theme.surfaceVariantText
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                anchors.centerIn: parent
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: parent.isHovered = true
                                                onExited: parent.isHovered = false
                                                onClicked: {
                                                    if (modelData && modelData.invoke)
                                                        modelData.invoke();
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        property bool isHovered: false

                                        width: Math.max(expandedClearText.implicitWidth + Theme.spacingM, compactMode ? 40 : 50)
                                        height: actionButtonHeight
                                        radius: Theme.spacingXS
                                        color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                                        StyledText {
                                            id: expandedClearText
                                            text: I18n.tr("Dismiss")
                                            color: parent.isHovered ? Theme.primary : Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.isHovered = true
                                            onExited: parent.isHovered = false
                                            onClicked: NotificationService.dismissNotification(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        visible: !expanded
        anchors.right: clearButton.visible ? clearButton.left : parent.right
        anchors.rightMargin: clearButton.visible ? contentSpacing : Theme.spacingL
        anchors.top: collapsedContent.bottom
        anchors.topMargin: contentSpacing
        spacing: contentSpacing

        Repeater {
            model: notificationGroup?.latestNotification?.actions || []

            Rectangle {
                property bool isHovered: false

                width: Math.max(collapsedActionText.implicitWidth + Theme.spacingM, compactMode ? 40 : 50)
                height: actionButtonHeight
                radius: Theme.spacingXS
                color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                StyledText {
                    id: collapsedActionText
                    text: {
                        const baseText = modelData.text || "View";
                        if (keyboardNavigationActive && isGroupSelected) {
                            return `${baseText} (${index + 1})`;
                        }
                        return baseText;
                    }
                    color: parent.isHovered ? Theme.primary : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    anchors.centerIn: parent
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.isHovered = true
                    onExited: parent.isHovered = false
                    onClicked: {
                        if (modelData && modelData.invoke) {
                            modelData.invoke();
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: clearButton

        property bool isHovered: false
        readonly property int actionCount: (notificationGroup?.latestNotification?.actions || []).length

        visible: !expanded && actionCount < 3
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL
        anchors.top: collapsedContent.bottom
        anchors.topMargin: contentSpacing
        width: Math.max(collapsedClearText.implicitWidth + Theme.spacingM, compactMode ? 40 : 50)
        height: actionButtonHeight
        radius: Theme.spacingXS
        color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

        StyledText {
            id: collapsedClearText
            text: I18n.tr("Dismiss")
            color: clearButton.isHovered ? Theme.primary : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: clearButton.isHovered = true
            onExited: clearButton.isHovered = false
            onClicked: NotificationService.dismissGroup(notificationGroup?.key || "")
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: !expanded && (notificationGroup?.count || 0) > 1 && !descriptionExpanded
        onClicked: {
            root.userInitiatedExpansion = true;
            NotificationService.toggleGroupExpansion(notificationGroup?.key || "");
        }
        z: -1
    }

    Item {
        id: fixedControls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: cardPadding
        anchors.rightMargin: Theme.spacingL
        width: compactMode ? 52 : 60
        height: compactMode ? 24 : 28

        DankActionButton {
            anchors.left: parent.left
            anchors.top: parent.top
            visible: (notificationGroup?.count || 0) > 1
            iconName: expanded ? "expand_less" : "expand_more"
            iconSize: compactMode ? 16 : 18
            buttonSize: compactMode ? 24 : 28
            onClicked: {
                root.userInitiatedExpansion = true;
                NotificationService.toggleGroupExpansion(notificationGroup?.key || "");
            }
        }

        DankActionButton {
            anchors.right: parent.right
            anchors.top: parent.top
            iconName: "close"
            iconSize: compactMode ? 16 : 18
            buttonSize: compactMode ? 24 : 28
            onClicked: NotificationService.dismissGroup(notificationGroup?.key || "")
        }
    }

    Behavior on height {
        enabled: root.userInitiatedExpansion && root.animateExpansion
        NumberAnimation {
            duration: Theme.expressiveDurations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.standard
            onRunningChanged: {
                if (running) {
                    root.isAnimating = true;
                } else {
                    root.isAnimating = false;
                    root.userInitiatedExpansion = false;
                }
            }
        }
    }
}
