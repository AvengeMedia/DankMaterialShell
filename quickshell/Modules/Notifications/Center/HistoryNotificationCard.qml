import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    required property var historyItem
    property bool isSelected: false
    property bool keyboardNavigationActive: false
    property bool descriptionExpanded: NotificationService.expandedMessages[historyItem?.id ? (historyItem.id + "_hist") : ""] || false
    property bool __initialized: false

    Component.onCompleted: {
        Qt.callLater(() => {
            if (root)
                root.__initialized = true;
        });
    }

    readonly property bool compactMode: SettingsData.notificationCompactMode
    readonly property real cardPadding: compactMode ? Theme.notificationCardPaddingCompact : Theme.notificationCardPadding
    readonly property real iconSize: compactMode ? Theme.notificationIconSizeCompact : Theme.notificationIconSizeNormal
    readonly property real contentSpacing: compactMode ? Theme.spacingXS : Theme.spacingS
    readonly property real collapsedContentHeight: iconSize + cardPadding
    readonly property real baseCardHeight: cardPadding * 2 + collapsedContentHeight

    width: parent ? parent.width : 400
    height: baseCardHeight + contentItem.extraHeight
    radius: Theme.cornerRadius
    clip: true

    color: {
        if (isSelected && keyboardNavigationActive)
            return Theme.primaryPressed;
        return Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency);
    }
    border.color: {
        if (isSelected && keyboardNavigationActive)
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5);
        if (historyItem.urgency === 2)
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05);
    }
    border.width: {
        if (isSelected && keyboardNavigationActive)
            return 1.5;
        if (historyItem.urgency === 2)
            return 2;
        return 1;
    }

    Behavior on border.color {
        enabled: root.__initialized
        ColorAnimation {
            duration: root.__initialized ? Theme.shortDuration : 0
            easing.type: Theme.standardEasing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: historyItem.urgency === 2
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
    }

    Item {
        id: contentItem

        readonly property real expandedTextHeight: descriptionText.contentHeight
        readonly property real twoLineHeight: descriptionText.font.pixelSize * 1.2 * 2
        readonly property real extraHeight: (descriptionExpanded && expandedTextHeight > twoLineHeight + 2) ? (expandedTextHeight - twoLineHeight) : 0

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: cardPadding
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL + Theme.notificationHoverRevealMargin
        height: collapsedContentHeight + extraHeight

        DankCircularImage {
            id: iconContainer
            readonly property string rawImage: historyItem.image || ""
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
                    return historyItem.image;
                if (imageHasSpecialPrefix)
                    return "";
                const appIcon = historyItem.appIcon;
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
                return historyItem.appIcon || iconFromImage || "";
            }
            fallbackText: {
                const appName = historyItem.appName || "?";
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
        }

        Rectangle {
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
                spacing: Theme.notificationContentSpacing

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS
                    readonly property real reservedTrailingWidth: historySeparator.implicitWidth + Math.max(historyTimeText.implicitWidth, 72) + spacing

                    StyledText {
                        id: historyTitleText
                        width: Math.min(implicitWidth, Math.max(0, parent.width - parent.reservedTrailingWidth))
                        text: {
                            let title = historyItem.summary || "";
                            const appName = historyItem.appName || "";
                            const prefix = appName + " • ";
                            if (appName && title.toLowerCase().startsWith(prefix.toLowerCase())) {
                                title = title.substring(prefix.length);
                            }
                            return title;
                        }
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                    StyledText {
                        id: historySeparator
                        text: (historyTitleText.text.length > 0 && historyTimeText.text.length > 0) ? " • " : ""
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Normal
                    }
                    StyledText {
                        id: historyTimeText
                        text: NotificationService.formatHistoryTime(historyItem.timestamp)
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Normal
                        visible: text.length > 0
                    }
                }

                StyledText {
                    id: descriptionText
                    property bool hasMoreText: truncated

                    text: historyItem.htmlBody || historyItem.body || ""
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width
                    elide: descriptionExpanded ? Text.ElideNone : Text.ElideRight
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
                                const messageId = historyItem?.id ? (historyItem.id + "_hist") : "";
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

    DankActionButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: cardPadding
        anchors.rightMargin: Theme.spacingL
        iconName: "close"
        iconSize: compactMode ? 16 : 18
        buttonSize: compactMode ? 24 : 28
        onClicked: NotificationService.removeFromHistory(historyItem.id)
    }
}
