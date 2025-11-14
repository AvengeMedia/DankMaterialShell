import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: win

    WlrLayershell.namespace: "dms:notification-popup"

    required property var notificationData
    required property string notificationId
    readonly property bool hasValidData: notificationData && notificationData.notification
    property int screenY: 0
    property bool exiting: false
    property bool _isDestroying: false
    property bool _finalized: false
    readonly property string clearText: I18n.tr("Dismiss")

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
        const envLayer = Quickshell.env("DMS_NOTIFICATION_LAYER")
        if (envLayer) {
            switch (envLayer) {
            case "bottom":
                return WlrLayershell.Bottom
            case "overlay":
                return WlrLayershell.Overlay
            case "background":
                return WlrLayershell.Background
            case "top":
                return WlrLayershell.Top
            }
        }

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

    property bool isTopCenter: SettingsData.notificationPopupPosition === -1

    anchors.top: isTopCenter || SettingsData.notificationPopupPosition === SettingsData.Position.Top || SettingsData.notificationPopupPosition === SettingsData.Position.Left
    anchors.bottom: SettingsData.notificationPopupPosition === SettingsData.Position.Bottom || SettingsData.notificationPopupPosition === SettingsData.Position.Right
    anchors.left: SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom
    anchors.right: SettingsData.notificationPopupPosition === SettingsData.Position.Top || SettingsData.notificationPopupPosition === SettingsData.Position.Right

    margins {
        top: getTopMargin()
        bottom: getBottomMargin()
        left: getLeftMargin()
        right: getRightMargin()
    }

    function getTopMargin() {
        const popupPos = SettingsData.notificationPopupPosition
        const barPos = SettingsData.dankBarPosition
        const isTop = isTopCenter || popupPos === SettingsData.Position.Top || popupPos === SettingsData.Position.Left

        if (!isTop) return 0

        const effectiveBarThickness = Math.max(26 + SettingsData.dankBarInnerPadding * 0.6 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
        const exclusiveZone = effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap

        let base = Theme.popupDistance
        if (barPos === SettingsData.Position.Top) {
            base = exclusiveZone
        }

        return base + screenY
    }

    function getBottomMargin() {
        const popupPos = SettingsData.notificationPopupPosition
        const barPos = SettingsData.dankBarPosition
        const isBottom = popupPos === SettingsData.Position.Bottom || popupPos === SettingsData.Position.Right

        if (!isBottom) return 0

        const effectiveBarThickness = Math.max(26 + SettingsData.dankBarInnerPadding * 0.6 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
        const exclusiveZone = effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap

        let base = Theme.popupDistance
        if (barPos === SettingsData.Position.Bottom) {
            base = exclusiveZone
        }

        return base + screenY
    }

    function getLeftMargin() {
        if (isTopCenter) {
            return (screen.width - implicitWidth) / 2
        }

        const popupPos = SettingsData.notificationPopupPosition
        const barPos = SettingsData.dankBarPosition
        const isLeft = popupPos === SettingsData.Position.Left || popupPos === SettingsData.Position.Bottom

        if (!isLeft) return 0

        const effectiveBarThickness = Math.max(26 + SettingsData.dankBarInnerPadding * 0.6 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
        const exclusiveZone = effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap

        if (barPos === SettingsData.Position.Left) {
            return exclusiveZone
        }

        return Theme.popupDistance
    }

    function getRightMargin() {
        if (isTopCenter) return 0

        const popupPos = SettingsData.notificationPopupPosition
        const barPos = SettingsData.dankBarPosition
        const isRight = popupPos === SettingsData.Position.Top || popupPos === SettingsData.Position.Right

        if (!isRight) return 0

        const effectiveBarThickness = Math.max(26 + SettingsData.dankBarInnerPadding * 0.6 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
        const exclusiveZone = effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap

        if (barPos === SettingsData.Position.Right) {
            return exclusiveZone
        }

        return Theme.popupDistance
    }

    readonly property real dpr: CompositorService.getScreenScale(win.screen)
    readonly property real alignedWidth: Theme.px(implicitWidth, dpr)
    readonly property real alignedHeight: Theme.px(implicitHeight, dpr)

    Item {
        id: content

        x: Theme.snap((win.width - alignedWidth) / 2, dpr)
        y: Theme.snap((win.height - alignedHeight) / 2, dpr)
        width: alignedWidth
        height: alignedHeight
        visible: win.hasValidData

        property real shadowBlurPx: 10
        property real shadowSpreadPx: 0
        property real shadowBaseAlpha: 0.60
        readonly property real popupSurfaceAlpha: SettingsData.popupTransparency
        readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha))

        Item {
            id: bgShadowLayer
            anchors.fill: parent
            anchors.margins: Theme.snap(4, win.dpr)
            layer.enabled: true
            layer.smooth: false
            layer.textureSize: Qt.size(Math.round(width * win.dpr), Math.round(height * win.dpr))
            layer.textureMirroring: ShaderEffectSource.MirrorVertically

            layer.effect: MultiEffect {
                id: shadowFx
                autoPaddingEnabled: true
                shadowEnabled: true
                blurEnabled: false
                maskEnabled: false
                property int blurMax: 64
                shadowBlur: Math.max(0, Math.min(1, content.shadowBlurPx / blurMax))
                shadowScale: 1 + (2 * content.shadowSpreadPx) / Math.max(1, Math.min(bgShadowLayer.width, bgShadowLayer.height))
                shadowColor: {
                    const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest
                    return Theme.withAlpha(baseColor, content.effectiveShadowAlpha)
                }
            }

            Shape {
                id: backgroundShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                readonly property real radius: Theme.cornerRadius
                readonly property color fillColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                readonly property color strokeColor: notificationData && notificationData.urgency === NotificationUrgency.Critical ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.outline, 0.08)
                readonly property real strokeWidth: notificationData && notificationData.urgency === NotificationUrgency.Critical ? 2 : 0

                ShapePath {
                    fillColor: backgroundShape.fillColor
                    strokeColor: backgroundShape.strokeColor
                    strokeWidth: backgroundShape.strokeWidth

                    startX: backgroundShape.radius
                    startY: 0

                    PathLine { x: backgroundShape.width - backgroundShape.radius; y: 0 }
                    PathQuad { x: backgroundShape.width; y: backgroundShape.radius; controlX: backgroundShape.width; controlY: 0 }
                    PathLine { x: backgroundShape.width; y: backgroundShape.height - backgroundShape.radius }
                    PathQuad { x: backgroundShape.width - backgroundShape.radius; y: backgroundShape.height; controlX: backgroundShape.width; controlY: backgroundShape.height }
                    PathLine { x: backgroundShape.radius; y: backgroundShape.height }
                    PathQuad { x: 0; y: backgroundShape.height - backgroundShape.radius; controlX: 0; controlY: backgroundShape.height }
                    PathLine { x: 0; y: backgroundShape.radius }
                    PathQuad { x: backgroundShape.radius; y: 0; controlX: 0; controlY: 0 }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: backgroundShape.radius
                visible: notificationData && notificationData.urgency === NotificationUrgency.Critical
                opacity: 1
                clip: true

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
        }

        Item {
            id: backgroundContainer
            anchors.fill: parent
            anchors.margins: Theme.snap(4, win.dpr)
            clip: true

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
                    fallbackIcon: ""
                    fallbackText: {
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
                width: Math.max(clearTextLabel.implicitWidth + 12, 50)
                height: 24
                radius: 4
                color: isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                z: 20

                StyledText {
                    id: clearTextLabel

                    text: win.clearText
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
                acceptedButtons: Qt.LeftButton | Qt.RightButton
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
                onClicked: (mouse) => {
                    if (!notificationData || win.exiting)
                        return

                    if (mouse.button === Qt.RightButton) {
                        NotificationService.dismissNotification(notificationData)
                    } else if (mouse.button === Qt.LeftButton) {
                        if (notificationData.actions && notificationData.actions.length > 0) {
                            notificationData.actions[0].invoke()
                            NotificationService.dismissNotification(notificationData)
                        } else {
                            notificationData.popup = false
                        }
                    }
                }
            }
        }

        transform: Translate {
            id: tx

            x: {
                if (isTopCenter) return 0
                const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom
                return isLeft ? -Anims.slidePx : Anims.slidePx
            }
            y: isTopCenter ? -Anims.slidePx : 0
        }
    }

    NumberAnimation {
        id: enterX

        target: tx
        property: isTopCenter ? "y" : "x"
        from: {
            if (isTopCenter) return -Anims.slidePx
            const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom
            return isLeft ? -Anims.slidePx : Anims.slidePx
        }
        to: 0
        duration: Anims.durMed
        easing.type: Easing.BezierSpline
        easing.bezierCurve: isTopCenter ? Anims.standardDecel : Anims.emphasizedDecel
        onStopped: {
            if (!win.exiting && !win._isDestroying) {
                if (isTopCenter) {
                    if (Math.abs(tx.y) < 0.5) win.entered()
                } else {
                    if (Math.abs(tx.x) < 0.5) win.entered()
                }
            }
        }
    }

    ParallelAnimation {
        id: exitAnim

        onStopped: finalizeExit("animStopped")

        PropertyAnimation {
            target: tx
            property: isTopCenter ? "y" : "x"
            from: 0
            to: {
                if (isTopCenter) return -Anims.slidePx
                const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom
                return isLeft ? -Anims.slidePx : Anims.slidePx
            }
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
