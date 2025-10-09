import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var notificationGroup
    property bool expanded: (NotificationService.expandedGroups[notificationGroup && notificationGroup.key] || false)
    property bool descriptionExpanded: (NotificationService.expandedMessages[(notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.notification
                                                                              && notificationGroup.latestNotification.notification.id) ? (notificationGroup.latestNotification.notification.id + "_desc") : ""] || false)
    property bool userInitiatedExpansion: false

    property bool isGroupSelected: false
    property int selectedNotificationIndex: -1
    property bool keyboardNavigationActive: false

    width: parent ? parent.width : 400
    height: {
        if (expanded) {
            return expandedContent.height + 28
        }
        const baseHeight = 116
        if (descriptionExpanded) {
            return baseHeight + descriptionText.contentHeight - (descriptionText.font.pixelSize * 1.2 * 2)
        }
        return baseHeight
    }
    radius: Theme.cornerRadius


    Behavior on border.color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    color: {
        if (isGroupSelected && keyboardNavigationActive) {
            return Theme.primaryPressed
        }
        if (keyboardNavigationActive && expanded && selectedNotificationIndex >= 0) {
            return Theme.primaryHoverLight
        }
        return Theme.surfaceContainerHigh
    }
    border.color: {
        if (isGroupSelected && keyboardNavigationActive) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
        }
        if (keyboardNavigationActive && expanded && selectedNotificationIndex >= 0) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
        }
        if (notificationGroup?.latestNotification?.urgency === NotificationUrgency.Critical) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
        }
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
    }
    border.width: {
        if (isGroupSelected && keyboardNavigationActive) {
            return 1.5
        }
        if (keyboardNavigationActive && expanded && selectedNotificationIndex >= 0) {
            return 1
        }
        if (notificationGroup?.latestNotification?.urgency === NotificationUrgency.Critical) {
            return 2
        }
        return 1
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
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.leftMargin: 16
        anchors.rightMargin: 56
        height: 92
        visible: !expanded

        DankCircularImage {
            id: iconContainer
            readonly property bool hasNotificationImage: notificationGroup?.latestNotification?.image && notificationGroup.latestNotification.image !== ""

            width: 63
            height: 63
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 14

            imageSource: {
                if (hasNotificationImage)
                    return notificationGroup.latestNotification.cleanImage
                if (notificationGroup?.latestNotification?.appIcon) {
                    const appIcon = notificationGroup.latestNotification.appIcon
                    if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://"))
                        return appIcon
                    return Quickshell.iconPath(appIcon, true)
                }
                return ""
            }

            hasImage: hasNotificationImage
            fallbackIcon: ""
            fallbackText: {
                const appName = notificationGroup?.appName || "?"
                return appName.charAt(0).toUpperCase()
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
                width: 18
                height: 18
                radius: 9
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
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }
        }

        Rectangle {
            id: textContainer

            anchors.left: iconContainer.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            color: "transparent"

            Item {
                width: parent.width
                height: parent.height
                anchors.top: parent.top
                anchors.topMargin: -2

                Column {
                    width: parent.width
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: {
                            const timeStr = (notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.timeStr) || ""
                            const appName = (notificationGroup && notificationGroup.appName) || ""
                            return timeStr.length > 0 ? `${appName} • ${timeStr}` : appName
                        }
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
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
                        maximumLineCount: descriptionExpanded ? -1 : 2
                        wrapMode: Text.WordWrap
                        visible: text.length > 0
                        linkColor: Theme.primary
                        onLinkActivated: link => Qt.openUrlExternally(link)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : (parent.hasMoreText || descriptionExpanded) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: mouse => {
                                           if (!parent.hoveredLink && (parent.hasMoreText || descriptionExpanded)) {
                                               const messageId = (notificationGroup && notificationGroup.latestNotification && notificationGroup.latestNotification.notification
                                                                  && notificationGroup.latestNotification.notification.id) ? (notificationGroup.latestNotification.notification.id + "_desc") : ""
                                               NotificationService.toggleMessageExpansion(messageId)
                                           }
                                       }

                            propagateComposedEvents: true
                            onPressed: mouse => {
                                           if (parent.hoveredLink) {
                                               mouse.accepted = false
                                           }
                                       }
                            onReleased: mouse => {
                                            if (parent.hoveredLink) {
                                                mouse.accepted = false
                                            }
                                        }
                        }
                    }
                }
            }
        }
    }

    Column {
        id: expandedContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: -1
        visible: expanded

        Item {
            width: parent.width
            height: 40

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 56
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
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.primary
                    visible: (notificationGroup?.count || 0) > 1
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        anchors.centerIn: parent
                        text: (notificationGroup?.count || 0) > 99 ? "99+" : (notificationGroup?.count || 0).toString()
                        color: Theme.primaryText
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 16

            Repeater {
                model: notificationGroup?.notifications?.slice(0, 10) || []

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool messageExpanded: NotificationService.expandedMessages[modelData?.notification?.id] || false
                    readonly property bool isSelected: root.selectedNotificationIndex === index

                    width: parent.width
                    height: {
                        const baseHeight = 120
                        if (messageExpanded) {
                            const twoLineHeight = bodyText.font.pixelSize * 1.2 * 2
                            if (bodyText.implicitHeight > twoLineHeight + 2) {
                                const extraHeight = bodyText.implicitHeight - twoLineHeight
                                return baseHeight + extraHeight
                            }
                        }
                        return baseHeight
                    }
                    radius: Theme.cornerRadius
                    color: isSelected ? Theme.primaryPressed : Theme.surfaceContainerHigh
                    border.color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                    border.width: isSelected ? 1 : 1


                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Behavior on height {
                        enabled: false
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 12
                        anchors.bottomMargin: 8

                        DankCircularImage {
                            id: messageIcon

                            readonly property bool hasNotificationImage: modelData?.image && modelData.image !== ""

                            width: 48
                            height: 48
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 32

                            imageSource: {
                                if (hasNotificationImage)
                                    return modelData.cleanImage

                                if (modelData?.appIcon) {
                                    const appIcon = modelData.appIcon
                                    if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://"))
                                        return appIcon

                                    return Quickshell.iconPath(appIcon, true)
                                }
                                return ""
                            }

                            fallbackIcon: ""

                            fallbackText: {
                                const appName = modelData?.appName || "?"
                                return appName.charAt(0).toUpperCase()
                            }
                        }

                        Item {
                            anchors.left: messageIcon.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: buttonArea.top
                                anchors.bottomMargin: 4
                                spacing: 2

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
                                                           NotificationService.toggleMessageExpansion(modelData?.notification?.id || "")
                                                       }
                                                   }

                                        propagateComposedEvents: true
                                        onPressed: mouse => {
                                                       if (parent.hoveredLink) {
                                                           mouse.accepted = false
                                                       }
                                                   }
                                        onReleased: mouse => {
                                                        if (parent.hoveredLink) {
                                                            mouse.accepted = false
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
                                height: 30

                                Row {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    spacing: 8

                                    Repeater {
                                        model: modelData?.actions || []

                                        Rectangle {
                                            property bool isHovered: false

                                            width: Math.max(actionText.implicitWidth + 12, 50)
                                            height: 24
                                            radius: 4
                                            color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                                            StyledText {
                                                id: actionText
                                                text: {
                                                    const baseText = modelData.text || "View"
                                                    if (keyboardNavigationActive && (isGroupSelected || selectedNotificationIndex >= 0)) {
                                                        return `${baseText} (${index + 1})`
                                                    }
                                                    return baseText
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
                                                        modelData.invoke()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        property bool isHovered: false

                                        width: Math.max(clearText.implicitWidth + 12, 50)
                                        height: 24
                                        radius: 4
                                        color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                                        StyledText {
                                            id: clearText
                                            text: I18n.tr("Clear")
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
        anchors.right: clearButton.left
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 8

        Repeater {
            model: notificationGroup?.latestNotification?.actions || []

            Rectangle {
                property bool isHovered: false

                width: Math.max(actionText.implicitWidth + 12, 50)
                height: 24
                radius: 4
                color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                StyledText {
                    id: actionText
                    text: {
                        const baseText = modelData.text || "View"
                        if (keyboardNavigationActive && isGroupSelected) {
                            return `${baseText} (${index + 1})`
                        }
                        return baseText
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
                            modelData.invoke()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: clearButton

        property bool isHovered: false

        visible: !expanded
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: clearText.width + 16
        height: clearText.height + 8
        radius: 6
        color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

        StyledText {
            id: clearText
            text: I18n.tr("Clear")
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
            root.userInitiatedExpansion = true
            NotificationService.toggleGroupExpansion(notificationGroup?.key || "")
        }
        z: -1
    }

    Item {
        id: fixedControls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 16
        width: 60
        height: 28

        DankActionButton {
            anchors.left: parent.left
            anchors.top: parent.top
            visible: (notificationGroup?.count || 0) > 1
            iconName: expanded ? "expand_less" : "expand_more"
            iconSize: 18
            buttonSize: 28
            onClicked: {
                root.userInitiatedExpansion = true
                NotificationService.toggleGroupExpansion(notificationGroup?.key || "")
            }
        }

        DankActionButton {
            anchors.right: parent.right
            anchors.top: parent.top
            iconName: "close"
            iconSize: 18
            buttonSize: 28
            onClicked: NotificationService.dismissGroup(notificationGroup?.key || "")
        }
    }

    Behavior on height {
        enabled: root.userInitiatedExpansion
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
            onFinished: root.userInitiatedExpansion = false
        }
    }
}
