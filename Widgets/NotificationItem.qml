import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../Common"
import "../Services"

Rectangle {
    id: root

    required property var notificationWrapper
    readonly property bool hasImage: notificationWrapper.hasImage
    readonly property bool hasAppIcon: notificationWrapper.hasAppIcon
    readonly property bool isConversation: notificationWrapper.isConversation
    readonly property bool isMedia: notificationWrapper.isMedia
    readonly property bool isUrgent: notificationWrapper.urgency === 2
    readonly property bool isPopup: notificationWrapper.popup

    property bool expanded: false

    width: 380
    height: Math.max(contentColumn.height + Theme.spacingL * 2, 80)
    radius: Theme.cornerRadiusLarge
    color: isUrgent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.popupBackground()
    border.color: isUrgent ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    // Priority indicator for urgent notifications
    Rectangle {
        width: 4
        height: parent.height - 16
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        radius: 2
        color: Theme.primary
        visible: isUrgent
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onEntered: notificationWrapper.timer.stop()
        onExited: notificationWrapper.timer.start()

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                NotificationService.dismissNotification(notificationWrapper)
            } else {
                // Handle notification action
                const actions = notificationWrapper.actions;
                if (actions && actions.length === 1) {
                    actions[0].invoke();
                }
            }
        }
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingM
            
            // Image/Icon container
            Item {
                width: 48
                height: 48
                anchors.top: parent.top

                // Notification image (Discord avatars, media artwork, etc.)
                Loader {
                    id: imageLoader
                    active: root.hasImage
                    anchors.fill: parent

                    sourceComponent: Rectangle {
                        radius: 24 // Fully rounded
                        color: Theme.surfaceContainer
                        clip: true

                        Image {
                            id: notifImage
                            anchors.fill: parent
                            source: root.notificationWrapper.image
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            asynchronous: true
                            smooth: true

                            onStatusChanged: {
                                if (status === Image.Error) {
                                    console.warn("Failed to load notification image:", source)
                                }
                            }
                        }
                    }
                }

                // App icon (shown when no image, or as badge when image present)
                Loader {
                    active: root.hasAppIcon || !root.hasImage
                    
                    // Position as overlay badge when image is present, center when no image
                    anchors.centerIn: root.hasImage ? undefined : parent
                    anchors.bottom: root.hasImage ? parent.bottom : undefined
                    anchors.right: root.hasImage ? parent.right : undefined

                    sourceComponent: Rectangle {
                        width: root.hasImage ? 20 : 48
                        height: root.hasImage ? 20 : 48
                        radius: width / 2
                        color: getIconBackgroundColor()
                        border.color: root.hasImage ? Theme.surface : "transparent"
                        border.width: root.hasImage ? 2 : 0

                        function getIconBackgroundColor() {
                            if (root.hasImage) {
                                return Theme.surface // Badge background
                            } else if (root.isConversation) {
                                return Theme.primaryContainer
                            } else if (root.isMedia) {
                                return Qt.rgba(1, 0.42, 0.21, 0.2) // Orange tint
                            }
                            return Theme.primaryContainer
                        }

                        IconImage {
                            id: iconImage
                            width: root.hasImage ? 14 : 32
                            height: root.hasImage ? 14 : 32
                            anchors.centerIn: parent
                            asynchronous: true
                            visible: status === Image.Ready
                            source: {
                                if (root.hasAppIcon) {
                                    return Quickshell.iconPath(root.notificationWrapper.appIcon, "")
                                }
                                // Special cases for specific apps
                                if (root.notificationWrapper.appName === "niri" && root.notificationWrapper.summary === "Screenshot captured") {
                                    return Quickshell.iconPath("camera-photo", "")
                                }
                                // Fallback icons
                                if (root.isConversation) return Quickshell.iconPath("chat", "")
                                if (root.isMedia) return Quickshell.iconPath("music_note", "")
                                return Quickshell.iconPath("dialog-information", "")
                            }

                            // Color overlay for symbolic icons when used as badge
                            layer.enabled: root.hasImage && root.notificationWrapper.appIcon.endsWith("symbolic")
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: Theme.surfaceText
                            }
                        }

                        // Elegant fallback when icon fails to load
                        Rectangle {
                            width: root.hasImage ? 14 : 32
                            height: root.hasImage ? 14 : 32
                            anchors.centerIn: parent
                            visible: iconImage.status === Image.Error || iconImage.status === Image.Null
                            radius: width / 2
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (root.isConversation) return "💬"
                                    if (root.isMedia) return "🎵"
                                    if (root.notificationWrapper.appName === "niri") return "📷"
                                    return "📋"
                                }
                                font.pixelSize: root.hasImage ? 8 : 16
                                color: Theme.primary
                            }
                        }
                    }
                }

                // Fallback when no app icon and no image
                Loader {
                    active: !root.hasAppIcon && !root.hasImage
                    anchors.centerIn: parent

                    sourceComponent: Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: Theme.primaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: getFallbackIconText()
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: Theme.primaryText

                            function getFallbackIconText() {
                                if (root.isConversation) return "chat"
                                if (root.isMedia) return "music_note"
                                return "apps"
                            }
                        }
                    }
                }
            }

            // Content area
            Column {
                width: parent.width - 48 - Theme.spacingM - 24 - Theme.spacingS
                spacing: Theme.spacingXS

                // Header row: App name and timestamp combined
                Text {
                    text: {
                        const appName = root.notificationWrapper.appName || "Unknown"
                        const timeStr = root.notificationWrapper.timeStr || "now"
                        return appName + " • " + timeStr
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                }

                // Summary (title)
                Text {
                    text: root.notificationWrapper.summary
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                // Body text - use full available width
                Text {
                    text: root.notificationWrapper.body
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.expanded ? -1 : 2
                    elide: Text.ElideRight
                    visible: text.length > 0
                    textFormat: Text.MarkdownText

                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                        NotificationService.dismissNotification(root.notificationWrapper)
                    }
                }
            }

            // Close button
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: closeArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.dismissNotification(root.notificationWrapper)
                }
            }

        }

        // Actions (if present)
        Row {
            width: parent.width
            spacing: Theme.spacingS
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 48 + Theme.spacingM + Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            visible: root.notificationWrapper.actions && root.notificationWrapper.actions.length > 0

            Repeater {
                model: root.notificationWrapper.actions || []

                delegate: Rectangle {
                    required property NotificationAction modelData

                    width: actionText.width + Theme.spacingM * 2
                    height: 32
                    radius: Theme.cornerRadius
                    color: actionArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                    border.color: Theme.outline
                    border.width: 1

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: modelData.text
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }


    // Animations
    Behavior on height {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }
}