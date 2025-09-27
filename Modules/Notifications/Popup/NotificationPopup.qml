import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: win

    WlrLayershell.namespace: "quickshell:notification"

    required property var notificationData
    required property string notificationId
    readonly property bool hasValidData: notificationData && notificationData.notification
    property int screenY: 0
    property bool exiting: false
    property bool _isDestroying: false
    property bool _finalized: false

    signal entered
    signal exitFinished

    function startExit() {
        if (exiting || _isDestroying) {
            return
        }
        exiting = true
        exitAnim.restart()
        exitWatchdog.restart()
        if (NotificationService.removeFromVisibleNotifications)
            NotificationService.removeFromVisibleNotifications(win.notificationData)
    }

    function forceExit() {
        if (_isDestroying) {
            return
        }
        _isDestroying = true
        exiting = true
        visible = false
        exitWatchdog.stop()
        finalizeExit("forced")
    }

    function finalizeExit(reason) {
        if (_finalized) {
            return
        }

        _finalized = true
        _isDestroying = true
        exitWatchdog.stop()
        wrapperConn.enabled = false
        wrapperConn.target = null
        win.exitFinished()
    }

    visible: hasValidData
    WlrLayershell.layer: {
        if (!notificationData)
            return WlrLayershell.Top

        SettingsData.notificationOverlayEnabled

        const shouldUseOverlay = (SettingsData.notificationOverlayEnabled) || (notificationData.urgency === NotificationUrgency.Critical)

        return shouldUseOverlay ? WlrLayershell.Overlay : WlrLayershell.Top
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 122
    onScreenYChanged: {
        if (SettingsData.dankBarAtBottom) {
            margins.bottom = Theme.barHeight - 4 + SettingsData.dankBarSpacing + 4 + screenY
        } else {
            margins.top = Theme.barHeight - 4 + SettingsData.dankBarSpacing + 4 + screenY
        }
    }
    onHasValidDataChanged: {
        if (!hasValidData && !exiting && !_isDestroying) {
            forceExit()
        }
    }
    Component.onCompleted: {
        if (hasValidData) {
            Qt.callLater(() => enterX.restart())
        } else {
            forceExit()
        }
    }
    onNotificationDataChanged: {
        if (!_isDestroying) {
            wrapperConn.target = win.notificationData || null
            notificationConn.target = (win.notificationData && win.notificationData.notification && win.notificationData.notification.Retainable) || null
        }
    }
    onEntered: {
        if (!_isDestroying) {
            enterDelay.start()
        }
    }
    Component.onDestruction: {
        _isDestroying = true
        exitWatchdog.stop()
        if (notificationData && notificationData.timer) {
            notificationData.timer.stop()
        }
    }

    anchors {
        top: !SettingsData.dankBarAtBottom
        bottom: SettingsData.dankBarAtBottom
        right: true
    }

    margins {
        top: SettingsData.dankBarAtBottom ? 0 : (Theme.barHeight - 4 + SettingsData.dankBarSpacing + 4)
        bottom: SettingsData.dankBarAtBottom ? (Theme.barHeight - 4 + SettingsData.dankBarSpacing + 4) : 0
        right: 12
    }

    Item {
        id: content

        anchors.fill: parent
        visible: win.hasValidData
        layer.enabled: (enterX.running || exitAnim.running)
        layer.smooth: true

        Rectangle {
            property var shadowLayers: [shadowLayer1, shadowLayer2, shadowLayer3]

            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.cornerRadius
            color: Theme.popupBackground()
            border.color: notificationData && notificationData.urgency === NotificationUrgency.Critical ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: notificationData && notificationData.urgency === NotificationUrgency.Critical ? 2 : 0
            clip: true

            Rectangle {
                id: shadowLayer1

                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"
                radius: parent.radius + 3
                border.color: Qt.rgba(0, 0, 0, 0.05)
                border.width: 1
                z: -3
            }

            Rectangle {
                id: shadowLayer2

                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                radius: parent.radius + 2
                border.color: Qt.rgba(0, 0, 0, 0.08)
                border.width: 1
                z: -2
            }

            Rectangle {
                id: shadowLayer3

                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                radius: parent.radius
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: notificationData && notificationData.urgency === NotificationUrgency.Critical
                opacity: 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
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
                id: notificationContent

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 12
                anchors.leftMargin: 16
                anchors.rightMargin: 56
                height: 98

                DankCircularImage {
                    id: iconContainer

                    readonly property bool hasNotificationImage: notificationData && notificationData.image && notificationData.image !== ""

                    width: 63
                    height: 63
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    imageSource: {
                        if (!notificationData)
                            return ""

                        if (hasNotificationImage)
                            return notificationData.cleanImage || ""

                        if (notificationData.appIcon) {
                            const appIcon = notificationData.appIcon
                            if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://"))
                                return appIcon

                            return Quickshell.iconPath(appIcon, true)
                        }
                        return ""
                    }

                    hasImage: hasNotificationImage
                    fallbackIcon: notificationData?.appIcon || "notifications"
                    fallbackText: {
                        if (hasNotificationImage || (notificationData?.appIcon && notificationData.appIcon !== ""))
                            return ""
                        const appName = notificationData?.appName || "?"
                        return appName.charAt(0).toUpperCase()
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
                                    if (!notificationData)
                                        return ""

                                    const appName = notificationData.appName || ""
                                    const timeStr = notificationData.timeStr || ""
                                    if (timeStr.length > 0)
                                        return appName + " • " + timeStr
                                    else
                                        return appName
                                }
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            StyledText {
                                text: notificationData ? (notificationData.summary || "") : ""
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                width: parent.width
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text.length > 0
                            }

                            StyledText {
                                text: notificationData ? (notificationData.htmlBody || "") : ""
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                width: parent.width
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                visible: text.length > 0
                                linkColor: Theme.primary
                                onLinkActivated: link => {
                                                     return Qt.openUrlExternally(link)
                                                 }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                }
                            }
                        }
                    }
                }
            }

            DankActionButton {
                id: closeButton

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.rightMargin: 16
                iconName: "close"
                iconSize: 18
                buttonSize: 28
                z: 15
                onClicked: {
                    if (notificationData && !win.exiting)
                        notificationData.popup = false
                }
            }

            Row {
                anchors.right: clearButton.left
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 8
                z: 20

                Repeater {
                    model: notificationData ? (notificationData.actions || []) : []

                    Rectangle {
                        property bool isHovered: false

                        width: Math.max(actionText.implicitWidth + 12, 50)
                        height: 24
                        radius: 4
                        color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"

                        StyledText {
                            id: actionText

                            text: modelData.text || "View"
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
                            acceptedButtons: Qt.LeftButton
                            onEntered: parent.isHovered = true
                            onExited: parent.isHovered = false
                            onClicked: {
                                if (modelData && modelData.invoke)
                                    modelData.invoke()

                                if (notificationData && !win.exiting)
                                    notificationData.popup = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: clearButton

                property bool isHovered: false

                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: Math.max(clearText.implicitWidth + 12, 50)
                height: 24
                radius: 4
                color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                z: 20

                StyledText {
                    id: clearText

                    text: "Clear"
                    color: clearButton.isHovered ? Theme.primary : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: clearButton.isHovered = true
                    onExited: clearButton.isHovered = false
                    onClicked: {
                        if (notificationData && !win.exiting)
                            NotificationService.dismissNotification(notificationData)
                    }
                }
            }

            MouseArea {
                id: cardHoverArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                z: -1
                onEntered: {
                    if (notificationData && notificationData.timer)
                        notificationData.timer.stop()
                }
                onExited: {
                    if (notificationData && notificationData.popup && notificationData.timer)
                        notificationData.timer.restart()
                }
                onClicked: {
                    if (notificationData && !win.exiting)
                        notificationData.popup = false
                }
            }
        }

        transform: Translate {
            id: tx

            x: Anims.slidePx
        }
    }

    NumberAnimation {
        id: enterX

        target: tx
        property: "x"
        from: Anims.slidePx
        to: 0
        duration: Anims.durMed
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
        onStopped: {
            if (!win.exiting && !win._isDestroying && Math.abs(tx.x) < 0.5) {
                win.entered()
            }
        }
    }

    ParallelAnimation {
        id: exitAnim

        onStopped: finalizeExit("animStopped")

        PropertyAnimation {
            target: tx
            property: "x"
            from: 0
            to: Anims.slidePx
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: content
            property: "opacity"
            from: 1
            to: 0
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.standardAccel
        }

        NumberAnimation {
            target: content
            property: "scale"
            from: 1
            to: 0.98
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }
    }

    Connections {
        id: wrapperConn

        function onPopupChanged() {
            if (!win.notificationData || win._isDestroying)
                return

            if (!win.notificationData.popup && !win.exiting)
                startExit()
        }

        target: win.notificationData || null
        ignoreUnknownSignals: true
        enabled: !win._isDestroying
    }

    Connections {
        id: notificationConn

        function onDropped() {
            if (!win._isDestroying && !win.exiting)
                forceExit()
        }

        target: (win.notificationData && win.notificationData.notification && win.notificationData.notification.Retainable) || null
        ignoreUnknownSignals: true
        enabled: !win._isDestroying
    }

    Timer {
        id: enterDelay

        interval: 160
        repeat: false
        onTriggered: {
            if (notificationData && notificationData.timer && !exiting && !_isDestroying)
                notificationData.timer.start()
        }
    }

    Timer {
        id: exitWatchdog

        interval: 600
        repeat: false
        onTriggered: finalizeExit("watchdog")
    }

    Behavior on screenY {
        id: screenYAnim

        enabled: !exiting && !_isDestroying

        NumberAnimation {
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.standardDecel
        }
    }
}
