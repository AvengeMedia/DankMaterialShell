import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
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
    readonly property alias hovered: cardHoverHandler.hovered
    property int screenY: 0
    property bool exiting: false
    property bool _isDestroying: false
    property bool _finalized: false
    property real _lastReportedAlignedHeight: -1
    property real _storedTopMargin: 0
    property real _storedBottomMargin: 0
    readonly property string clearText: I18n.tr("Dismiss")
    property bool descriptionExpanded: false
    readonly property bool hasExpandableBody: (notificationData?.htmlBody || "").replace(/<[^>]*>/g, "").trim().length > 0
    onDescriptionExpandedChanged: {
        popupHeightChanged();
    }
    onImplicitHeightChanged: {
        const aligned = Theme.px(implicitHeight, dpr);
        if (Math.abs(aligned - _lastReportedAlignedHeight) < 0.5)
            return;
        _lastReportedAlignedHeight = aligned;
        popupHeightChanged();
    }

    readonly property bool compactMode: SettingsData.notificationCompactMode
    readonly property real cardPadding: compactMode ? Theme.notificationCardPaddingCompact : Theme.notificationCardPadding
    readonly property real popupIconSize: compactMode ? Theme.notificationIconSizeCompact : Theme.notificationIconSizeNormal
    readonly property real contentSpacing: compactMode ? Theme.spacingXS : Theme.spacingS
    readonly property real contentBottomClearance: 8
    readonly property real actionButtonHeight: compactMode ? 20 : 24
    readonly property real collapsedContentHeight: Math.max(popupIconSize, Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2 + Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2)) + contentBottomClearance
    readonly property real privacyCollapsedContentHeight: Math.max(popupIconSize, Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2) + contentBottomClearance
    readonly property real basePopupHeight: cardPadding * 2 + collapsedContentHeight + actionButtonHeight + contentSpacing
    readonly property real basePopupHeightPrivacy: cardPadding * 2 + privacyCollapsedContentHeight + actionButtonHeight + contentSpacing

    signal entered
    signal exitStarted
    signal exitFinished
    signal popupHeightChanged

    function startExit() {
        if (exiting || _isDestroying) {
            return;
        }
        exiting = true;
        exitStarted();
        exitAnim.restart();
        exitWatchdog.restart();
        if (NotificationService.removeFromVisibleNotifications)
            NotificationService.removeFromVisibleNotifications(win.notificationData);
    }

    function forceExit() {
        if (_isDestroying) {
            return;
        }
        _isDestroying = true;
        exiting = true;
        visible = false;
        exitWatchdog.stop();
        finalizeExit("forced");
    }

    function finalizeExit(reason) {
        if (_finalized) {
            return;
        }

        _finalized = true;
        _isDestroying = true;
        exitWatchdog.stop();
        wrapperConn.enabled = false;
        wrapperConn.target = null;
        win.exitFinished();
    }

    visible: !_finalized
    WlrLayershell.layer: {
        const envLayer = Quickshell.env("DMS_NOTIFICATION_LAYER");
        if (envLayer) {
            switch (envLayer) {
            case "bottom":
                return WlrLayershell.Bottom;
            case "overlay":
                return WlrLayershell.Overlay;
            case "background":
                return WlrLayershell.Background;
            case "top":
                return WlrLayershell.Top;
            }
        }

        if (!notificationData)
            return WlrLayershell.Top;

        SettingsData.notificationOverlayEnabled;

        const shouldUseOverlay = (SettingsData.notificationOverlayEnabled) || (notificationData.urgency === NotificationUrgency.Critical);

        return shouldUseOverlay ? WlrLayershell.Overlay : WlrLayershell.Top;
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: screen ? Math.min(400, Math.max(320, screen.width * 0.23)) : 380
    implicitHeight: {
        if (SettingsData.notificationPopupPrivacyMode && !descriptionExpanded)
            return basePopupHeightPrivacy;
        if (!descriptionExpanded)
            return basePopupHeight;
        const bodyTextHeight = bodyText.contentHeight || 0;
        const collapsedBodyHeight = Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2);
        if (bodyTextHeight > collapsedBodyHeight + 2)
            return basePopupHeight + bodyTextHeight - collapsedBodyHeight;
        return basePopupHeight;
    }

    Behavior on implicitHeight {
        enabled: !exiting && !_isDestroying
        NumberAnimation {
            id: implicitHeightAnim
            duration: descriptionExpanded ? Theme.notificationExpandDuration : Theme.notificationCollapseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasized
        }
    }

    onHasValidDataChanged: {
        if (!hasValidData && !exiting && !_isDestroying) {
            forceExit();
        }
    }
    Component.onCompleted: {
        _lastReportedAlignedHeight = Theme.px(implicitHeight, dpr);
        _storedTopMargin = getTopMargin();
        _storedBottomMargin = getBottomMargin();
        if (SettingsData.notificationPopupPrivacyMode)
            descriptionExpanded = false;
        if (hasValidData) {
            Qt.callLater(() => enterX.restart());
        } else {
            forceExit();
        }
    }
    onNotificationDataChanged: {
        if (!_isDestroying) {
            if (SettingsData.notificationPopupPrivacyMode)
                descriptionExpanded = false;
            wrapperConn.target = win.notificationData || null;
            notificationConn.target = (win.notificationData && win.notificationData.notification && win.notificationData.notification.Retainable) || null;
        }
    }
    onEntered: {
        if (!_isDestroying) {
            enterDelay.start();
        }
    }
    Component.onDestruction: {
        _isDestroying = true;
        exitWatchdog.stop();
        if (notificationData && notificationData.timer) {
            notificationData.timer.stop();
        }
    }

    property bool isTopCenter: SettingsData.notificationPopupPosition === -1
    property bool isBottomCenter: SettingsData.notificationPopupPosition === SettingsData.Position.BottomCenter
    property bool isCenterPosition: isTopCenter || isBottomCenter

    anchors.top: true
    anchors.bottom: true
    anchors.left: SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom
    anchors.right: SettingsData.notificationPopupPosition === SettingsData.Position.Top || SettingsData.notificationPopupPosition === SettingsData.Position.Right

    mask: contentInputMask

    Region {
        id: contentInputMask
        item: contentMaskRect
    }

    Item {
        id: contentMaskRect
        visible: false
        x: content.x
        y: content.y
        width: alignedWidth
        height: alignedHeight
    }

    margins {
        top: _storedTopMargin
        bottom: _storedBottomMargin
        left: getLeftMargin()
        right: getRightMargin()
    }

    function getBarInfo() {
        if (!screen)
            return {
                topBar: 0,
                bottomBar: 0,
                leftBar: 0,
                rightBar: 0
            };
        return SettingsData.getAdjacentBarInfo(screen, SettingsData.notificationPopupPosition, {
            id: "notification-popup",
            screenPreferences: [screen.name],
            autoHide: false
        });
    }

    function getTopMargin() {
        const popupPos = SettingsData.notificationPopupPosition;
        const isTop = isTopCenter || popupPos === SettingsData.Position.Top || popupPos === SettingsData.Position.Left;
        if (!isTop)
            return 0;

        const barInfo = getBarInfo();
        const base = barInfo.topBar > 0 ? barInfo.topBar : Theme.popupDistance;
        return base + screenY;
    }

    function getBottomMargin() {
        const popupPos = SettingsData.notificationPopupPosition;
        const isBottom = isBottomCenter || popupPos === SettingsData.Position.Bottom || popupPos === SettingsData.Position.Right;
        if (!isBottom)
            return 0;

        const barInfo = getBarInfo();
        const base = barInfo.bottomBar > 0 ? barInfo.bottomBar : Theme.popupDistance;
        return base + screenY;
    }

    function getLeftMargin() {
        if (isCenterPosition)
            return screen ? (screen.width - implicitWidth) / 2 : 0;

        const popupPos = SettingsData.notificationPopupPosition;
        const isLeft = popupPos === SettingsData.Position.Left || popupPos === SettingsData.Position.Bottom;
        if (!isLeft)
            return 0;

        const barInfo = getBarInfo();
        return barInfo.leftBar > 0 ? barInfo.leftBar : Theme.popupDistance;
    }

    function getRightMargin() {
        if (isCenterPosition)
            return 0;

        const popupPos = SettingsData.notificationPopupPosition;
        const isRight = popupPos === SettingsData.Position.Top || popupPos === SettingsData.Position.Right;
        if (!isRight)
            return 0;

        const barInfo = getBarInfo();
        return barInfo.rightBar > 0 ? barInfo.rightBar : Theme.popupDistance;
    }

    readonly property bool screenValid: win.screen && !_isDestroying
    readonly property real dpr: screenValid ? CompositorService.getScreenScale(win.screen) : 1
    readonly property real alignedWidth: Theme.px(implicitWidth, dpr)
    readonly property real alignedHeight: Theme.px(implicitHeight, dpr)

    Item {
        id: content

        x: Theme.snap((win.width - alignedWidth) / 2, dpr)
        y: {
            const isTop = isTopCenter || SettingsData.notificationPopupPosition === SettingsData.Position.Top || SettingsData.notificationPopupPosition === SettingsData.Position.Left;
            if (isTop) {
                return Theme.snap(screenY, dpr);
            } else {
                return Theme.snap(win.height - alignedHeight - screenY, dpr);
            }
        }
        width: alignedWidth
        height: alignedHeight
        visible: !win._finalized
        scale: cardHoverHandler.hovered ? 1.01 : 1.0
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        property real swipeOffset: 0
        readonly property real dismissThreshold: isCenterPosition ? height * 0.4 : width * 0.35
        readonly property real swipeFadeStartRatio: 0.75
        readonly property real swipeTravelDistance: isCenterPosition ? height : width
        readonly property real swipeFadeStartOffset: swipeTravelDistance * swipeFadeStartRatio
        readonly property real swipeFadeDistance: Math.max(1, swipeTravelDistance - swipeFadeStartOffset)
        readonly property bool swipeActive: swipeDragHandler.active
        property bool swipeDismissing: false

        readonly property real radiusForShadow: Theme.cornerRadius
        property real shadowBlurPx: SettingsData.notificationPopupShadowEnabled ? ((2 + radiusForShadow * 0.2) * (cardHoverHandler.hovered ? 1.2 : 1)) : 0
        property real shadowSpreadPx: SettingsData.notificationPopupShadowEnabled ? (radiusForShadow * (cardHoverHandler.hovered ? 0.06 : 0)) : 0
        property real shadowBaseAlpha: 0.35
        readonly property real popupSurfaceAlpha: SettingsData.popupTransparency
        readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha))

        Behavior on shadowBlurPx {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on shadowSpreadPx {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Item {
            id: bgShadowLayer
            anchors.fill: parent
            anchors.margins: Theme.snap(4, win.dpr)
            layer.enabled: !win._isDestroying && win.screenValid
            layer.smooth: false
            layer.textureSize: Qt.size(Math.round(width * win.dpr), Math.round(height * win.dpr))
            layer.textureMirroring: ShaderEffectSource.MirrorVertically

            readonly property int blurMax: 64

            layer.effect: MultiEffect {
                id: shadowFx
                autoPaddingEnabled: true
                shadowEnabled: SettingsData.notificationPopupShadowEnabled
                blurEnabled: false
                maskEnabled: false
                shadowBlur: Math.max(0, Math.min(1, content.shadowBlurPx / bgShadowLayer.blurMax))
                shadowScale: 1 + (2 * content.shadowSpreadPx) / Math.max(1, Math.min(bgShadowLayer.width, bgShadowLayer.height))
                shadowColor: {
                    const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest;
                    return Theme.withAlpha(baseColor, content.effectiveShadowAlpha);
                }
            }

            Rectangle {
                id: shadowShapeSource
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                border.color: notificationData && notificationData.urgency === NotificationUrgency.Critical ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.outline, 0.08)
                border.width: notificationData && notificationData.urgency === NotificationUrgency.Critical ? 2 : 0
            }

            Rectangle {
                anchors.fill: parent
                radius: shadowShapeSource.radius
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

            HoverHandler {
                id: cardHoverHandler
            }

            Connections {
                target: cardHoverHandler
                function onHoveredChanged() {
                    if (!notificationData || win.exiting || win._isDestroying)
                        return;
                    if (cardHoverHandler.hovered) {
                        if (notificationData.timer)
                            notificationData.timer.stop();
                    } else if (notificationData.popup && notificationData.timer) {
                        notificationData.timer.restart();
                    }
                }
            }

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            Item {
                id: notificationContent

                readonly property real expandedTextHeight: bodyText.contentHeight || 0
                readonly property real collapsedBodyHeight: Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2)
                readonly property real effectiveCollapsedHeight: (SettingsData.notificationPopupPrivacyMode && !descriptionExpanded) ? win.privacyCollapsedContentHeight : win.collapsedContentHeight
                readonly property real extraHeight: (descriptionExpanded && expandedTextHeight > collapsedBodyHeight + 2) ? (expandedTextHeight - collapsedBodyHeight) : 0

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: cardPadding
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL + Theme.notificationHoverRevealMargin
                height: effectiveCollapsedHeight + extraHeight
                clip: SettingsData.notificationPopupPrivacyMode && !descriptionExpanded

                DankCircularImage {
                    id: iconContainer

                    readonly property string rawImage: notificationData?.image || ""
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
                    readonly property bool needsImagePersist: hasNotificationImage && rawImage.startsWith("image://qsimage/") && !notificationData.persistedImagePath

                    width: popupIconSize
                    height: popupIconSize
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: {
                        if (SettingsData.notificationPopupPrivacyMode && !descriptionExpanded) {
                            const headerSummary = Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2;
                            return Math.max(0, headerSummary / 2 - popupIconSize / 2);
                        }
                        if (descriptionExpanded)
                            return Math.max(0, Theme.fontSizeSmall * 1.2 + (Theme.fontSizeMedium * 1.2 + Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2)) / 2 - popupIconSize / 2);
                        return Math.max(0, Theme.fontSizeSmall * 1.2 + (textContainer.height - Theme.fontSizeSmall * 1.2) / 2 - popupIconSize / 2);
                    }

                    imageSource: {
                        if (!notificationData)
                            return "";
                        if (hasNotificationImage)
                            return notificationData.cleanImage || "";
                        if (imageHasSpecialPrefix)
                            return "";
                        const appIcon = notificationData.appIcon;
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
                        return notificationData?.appIcon || iconFromImage || "";
                    }
                    fallbackText: {
                        const appName = notificationData?.appName || "?";
                        return appName.charAt(0).toUpperCase();
                    }

                    onImageStatusChanged: {
                        if (imageStatus === Image.Ready && needsImagePersist) {
                            const cachePath = NotificationService.getImageCachePath(notificationData);
                            saveImageToFile(cachePath);
                        }
                    }

                    onImageSaved: filePath => {
                        if (!notificationData)
                            return;
                        notificationData.persistedImagePath = filePath;
                        const wrapperId = notificationData.notification?.id?.toString() || "";
                        if (wrapperId)
                            NotificationService.updateHistoryImage(wrapperId, filePath);
                    }
                }

                Column {
                    id: textContainer

                    anchors.left: iconContainer.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Theme.notificationContentSpacing

                    Row {
                        id: headerRow
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: headerAppNameText.text.length > 0 || headerTimeText.text.length > 0

                        StyledText {
                            id: headerAppNameText
                            text: notificationData ? (notificationData.appName || "") : ""
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, parent.width - headerSeparator.implicitWidth - headerTimeText.implicitWidth - parent.spacing * 2)
                        }

                        StyledText {
                            id: headerSeparator
                            text: (headerAppNameText.text.length > 0 && headerTimeText.text.length > 0) ? " • " : ""
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Normal
                        }

                        StyledText {
                            id: headerTimeText
                            text: notificationData ? (notificationData.timeStr || "") : ""
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Normal
                        }
                    }

                    StyledText {
                        text: notificationData ? (notificationData.summary || "") : ""
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        width: parent.width
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        maximumLineCount: 1
                        visible: text.length > 0
                    }

                    StyledText {
                        id: bodyText
                        property bool hasMoreText: truncated

                        text: notificationData ? (notificationData.htmlBody || "") : ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        width: parent.width
                        elide: descriptionExpanded ? Text.ElideNone : Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        maximumLineCount: descriptionExpanded ? -1 : (compactMode ? 1 : 2)
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        visible: text.length > 0
                        opacity: (SettingsData.notificationPopupPrivacyMode && !descriptionExpanded) ? 0 : 1
                        linkColor: Theme.primary
                        onLinkActivated: link => Qt.openUrlExternally(link)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : (bodyText.hasMoreText || descriptionExpanded) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: mouse => {
                                if (!parent.hoveredLink && (bodyText.hasMoreText || descriptionExpanded))
                                    win.descriptionExpanded = !win.descriptionExpanded;
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

                    StyledText {
                        text: I18n.tr("Message Content", "notification privacy mode placeholder")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        width: parent.width
                        visible: SettingsData.notificationPopupPrivacyMode && !descriptionExpanded && win.hasExpandableBody
                    }
                }
            }

            DankActionButton {
                id: closeButton

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: cardPadding
                anchors.rightMargin: Theme.spacingL
                iconName: "close"
                iconSize: compactMode ? 14 : 16
                buttonSize: compactMode ? 20 : 24
                z: 15

                onClicked: {
                    if (notificationData && !win.exiting)
                        notificationData.popup = false;
                }
            }

            DankActionButton {
                id: expandButton

                anchors.right: closeButton.left
                anchors.rightMargin: Theme.spacingXS
                anchors.top: parent.top
                anchors.topMargin: cardPadding
                iconName: descriptionExpanded ? "expand_less" : "expand_more"
                iconSize: compactMode ? 14 : 16
                buttonSize: compactMode ? 20 : 24
                z: 15
                visible: SettingsData.notificationPopupPrivacyMode && win.hasExpandableBody

                onClicked: {
                    if (win.hasExpandableBody)
                        win.descriptionExpanded = !win.descriptionExpanded;
                }
            }

            Row {
                visible: cardHoverHandler.hovered
                opacity: visible ? 1 : 0
                anchors.right: clearButton.visible ? clearButton.left : parent.right
                anchors.rightMargin: clearButton.visible ? contentSpacing : Theme.spacingL
                anchors.top: notificationContent.bottom
                anchors.topMargin: contentSpacing
                spacing: contentSpacing
                z: 20

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Repeater {
                    model: notificationData ? (notificationData.actions || []) : []

                    Rectangle {
                        property bool isHovered: false

                        width: Math.max(actionText.implicitWidth + Theme.spacingM, Theme.notificationActionMinWidth)
                        height: actionButtonHeight
                        radius: Theme.notificationButtonCornerRadius
                        color: isHovered ? Theme.withAlpha(Theme.primary, Theme.stateLayerHover) : "transparent"

                        StyledText {
                            id: actionText

                            text: modelData.text || "Open"
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
                                    modelData.invoke();
                                if (notificationData && !win.exiting)
                                    notificationData.popup = false;
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: clearButton

                property bool isHovered: false
                readonly property int actionCount: notificationData ? (notificationData.actions || []).length : 0

                visible: actionCount < 3 && cardHoverHandler.hovered
                opacity: visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingL
                anchors.top: notificationContent.bottom
                anchors.topMargin: contentSpacing
                width: Math.max(clearTextLabel.implicitWidth + Theme.spacingM, Theme.notificationActionMinWidth)
                height: actionButtonHeight
                radius: Theme.notificationButtonCornerRadius
                color: isHovered ? Theme.withAlpha(Theme.primary, Theme.stateLayerHover) : "transparent"
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
                            NotificationService.dismissNotification(notificationData);
                    }
                }
            }

            MouseArea {
                id: cardHoverArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: true
                z: -1
                onClicked: mouse => {
                    if (!notificationData || win.exiting)
                        return;
                    if (mouse.button === Qt.RightButton) {
                        popupContextMenu.popup();
                    } else if (mouse.button === Qt.LeftButton) {
                        const canExpand = bodyText.hasMoreText || win.descriptionExpanded || (SettingsData.notificationPopupPrivacyMode && win.hasExpandableBody);
                        if (canExpand) {
                            win.descriptionExpanded = !win.descriptionExpanded;
                        } else if (notificationData.actions && notificationData.actions.length > 0) {
                            notificationData.actions[0].invoke();
                            NotificationService.dismissNotification(notificationData);
                        } else {
                            notificationData.popup = false;
                        }
                    }
                }
            }
        }

        DragHandler {
            id: swipeDragHandler
            target: null
            xAxis.enabled: !isCenterPosition
            yAxis.enabled: isCenterPosition

            onActiveChanged: {
                if (active || win.exiting || content.swipeDismissing)
                    return;

                if (Math.abs(content.swipeOffset) > content.dismissThreshold) {
                    content.swipeDismissing = true;
                    swipeDismissAnim.start();
                } else {
                    content.swipeOffset = 0;
                }
            }

            onTranslationChanged: {
                if (win.exiting)
                    return;

                const raw = isCenterPosition ? translation.y : translation.x;
                if (isTopCenter) {
                    content.swipeOffset = Math.min(0, raw);
                } else if (isBottomCenter) {
                    content.swipeOffset = Math.max(0, raw);
                } else {
                    const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
                    content.swipeOffset = isLeft ? Math.min(0, raw) : Math.max(0, raw);
                }
            }
        }

        opacity: {
            const swipeAmount = Math.abs(content.swipeOffset);
            if (swipeAmount <= content.swipeFadeStartOffset)
                return 1;
            const fadeProgress = (swipeAmount - content.swipeFadeStartOffset) / content.swipeFadeDistance;
            return Math.max(0, 1 - fadeProgress);
        }

        Behavior on opacity {
            enabled: !content.swipeActive
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }

        Behavior on swipeOffset {
            enabled: !content.swipeActive && !content.swipeDismissing
            NumberAnimation {
                duration: Theme.notificationExitDuration
                easing.type: Theme.standardEasing
            }
        }

        NumberAnimation {
            id: swipeDismissAnim
            target: content
            property: "swipeOffset"
            to: isTopCenter ? -content.height : isBottomCenter ? content.height : (SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom ? -content.width : content.width)
            duration: Theme.notificationExitDuration
            easing.type: Easing.OutCubic
            onStopped: {
                NotificationService.dismissNotification(notificationData);
                win.forceExit();
            }
        }

        transform: [
            Translate {
                id: swipeTx
                x: isCenterPosition ? 0 : content.swipeOffset
                y: isCenterPosition ? content.swipeOffset : 0
            },
            Translate {
                id: tx
                x: {
                    if (isCenterPosition)
                        return 0;
                    const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
                    return isLeft ? -Anims.slidePx : Anims.slidePx;
                }
                y: isTopCenter ? -Anims.slidePx : isBottomCenter ? Anims.slidePx : 0
            }
        ]
    }

    NumberAnimation {
        id: enterX

        target: tx
        property: isCenterPosition ? "y" : "x"
        from: {
            if (isTopCenter)
                return -Anims.slidePx;
            if (isBottomCenter)
                return Anims.slidePx;
            const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
            return isLeft ? -Anims.slidePx : Anims.slidePx;
        }
        to: 0
        duration: Theme.notificationEnterDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: isCenterPosition ? Theme.expressiveCurves.standardDecel : Theme.expressiveCurves.emphasizedDecel
        onStopped: {
            if (!win.exiting && !win._isDestroying) {
                if (isCenterPosition) {
                    if (Math.abs(tx.y) < 0.5)
                        win.entered();
                } else {
                    if (Math.abs(tx.x) < 0.5)
                        win.entered();
                }
            }
        }
    }

    ParallelAnimation {
        id: exitAnim

        onStopped: finalizeExit("animStopped")

        PropertyAnimation {
            target: tx
            property: isCenterPosition ? "y" : "x"
            from: 0
            to: {
                if (isTopCenter)
                    return -Anims.slidePx;
                if (isBottomCenter)
                    return Anims.slidePx;
                const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
                return isLeft ? -Anims.slidePx : Anims.slidePx;
            }
            duration: Theme.notificationExitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedAccel
        }

        NumberAnimation {
            target: content
            property: "opacity"
            from: 1
            to: 0
            duration: Theme.notificationExitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.standardAccel
        }

        NumberAnimation {
            target: content
            property: "scale"
            from: 1
            to: 0.98
            duration: Theme.notificationExitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedAccel
        }
    }

    Connections {
        id: wrapperConn

        function onPopupChanged() {
            if (!win.notificationData || win._isDestroying)
                return;
            if (!win.notificationData.popup && !win.exiting)
                startExit();
        }

        target: win.notificationData || null
        ignoreUnknownSignals: true
        enabled: !win._isDestroying
    }

    Connections {
        id: notificationConn

        function onDropped() {
            if (!win._isDestroying && !win.exiting)
                forceExit();
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
                notificationData.timer.start();
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
            duration: Theme.shortDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.standardDecel
        }
    }

    Menu {
        id: popupContextMenu
        width: 220
        contentHeight: 130
        margins: -1
        popupType: Popup.Window
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            id: setNotificationRulesItem
            text: I18n.tr("Set notification rules")

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                const appName = notificationData?.appName || "";
                const desktopEntry = notificationData?.desktopEntry || "";
                SettingsData.addNotificationRuleForNotification(appName, desktopEntry);
                PopoutService.openSettingsWithTab("notifications");
            }
        }

        MenuItem {
            id: muteUnmuteItem
            readonly property bool isMuted: SettingsData.isAppMuted(notificationData?.appName || "", notificationData?.desktopEntry || "")
            text: isMuted ? I18n.tr("Unmute popups for %1").arg(notificationData?.appName || I18n.tr("this app")) : I18n.tr("Mute popups for %1").arg(notificationData?.appName || I18n.tr("this app"))

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                const appName = notificationData?.appName || "";
                const desktopEntry = notificationData?.desktopEntry || "";
                if (isMuted) {
                    SettingsData.removeMuteRuleForApp(appName, desktopEntry);
                } else {
                    SettingsData.addMuteRuleForApp(appName, desktopEntry);
                    if (notificationData && !exiting)
                        NotificationService.dismissNotification(notificationData);
                }
            }
        }

        MenuItem {
            text: I18n.tr("Dismiss")

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                if (notificationData && !exiting)
                    NotificationService.dismissNotification(notificationData);
            }
        }
    }
}
