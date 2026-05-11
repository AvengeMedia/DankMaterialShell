import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: win

    readonly property bool connectedFrameMode: SettingsData.frameEnabled && Theme.isConnectedEffect && SettingsData.isScreenInPreferences(win.screen, SettingsData.frameScreenPreferences)
    readonly property string notifBarSide: {
        const pos = SettingsData.notificationPopupPosition;
        if (pos === -1)
            return "top";
        switch (pos) {
        case SettingsData.Position.Top:
            return "right";
        case SettingsData.Position.Left:
            return "left";
        case SettingsData.Position.BottomCenter:
            return "bottom";
        case SettingsData.Position.Right:
            return "right";
        case SettingsData.Position.Bottom:
            return "left";
        default:
            return "top";
        }
    }
    readonly property int inlineExpandDuration: Theme.notificationInlineExpandDuration
    readonly property int inlineCollapseDuration: Theme.notificationInlineCollapseDuration
    property bool inlineHeightAnimating: false

    WindowBlur {
        targetWindow: win
        readonly property real s: Math.min(1, content.scale) * Math.max(0, content.opacity)
        readonly property real innerW: Math.max(0, content.width - content.cardInset * 2)
        readonly property real innerH: Math.max(0, content.height - content.cardInset * 2)
        blurX: content.x + content.cardInset + swipeTx.x + tx.x + innerW * (1 - s) * 0.5
        blurY: content.y + content.cardInset + swipeTx.y + tx.y + innerH * (1 - s) * 0.5
        blurWidth: !win._finalized && !win.connectedFrameMode ? innerW * s : 0
        blurHeight: !win._finalized && !win.connectedFrameMode ? innerH * s : 0
        blurRadius: win.connectedFrameMode ? Theme.connectedSurfaceRadius : Theme.cornerRadius
    }

    WlrLayershell.namespace: "dms:notification-popup"

    required property var notificationData
    required property string notificationId
    readonly property bool hasValidData: notificationData && notificationData.notification
    readonly property alias hovered: cardHoverHandler.hovered
    readonly property alias swipeActive: content.swipeActive
    readonly property alias swipeDismissing: content.swipeDismissing
    readonly property bool swipeDismissTowardEdge: {
        if (content.swipeDismissing)
            return _swipeDismissesTowardFrameEdge();
        if (content.swipeActive)
            return content.swipeOffset * _frameEdgeSwipeDirection() > 0;
        return false;
    }
    property int screenY: 0
    property bool exiting: false
    property bool _isDestroying: false
    property bool _finalized: false
    property real _lastReportedAlignedHeight: -1
    property real _storedTopMargin: 0
    property real _storedBottomMargin: 0
    property bool _inlineGeometryReady: false
    readonly property bool directionalEffect: Theme.isDirectionalEffect
    readonly property bool depthEffect: Theme.isDepthEffect
    readonly property real entryTravel: {
        const base = Math.abs(Theme.effectAnimOffset);
        if (directionalEffect) {
            if (isCenterPosition)
                return Math.max(base, Math.round(content.height * 1.1));
            return Math.max(base, Math.round(content.width * 0.95));
        }
        if (depthEffect)
            return Math.max(base, 44);
        return base;
    }
    readonly property real exitTravel: {
        if (directionalEffect) {
            if (isCenterPosition)
                return Math.max(1, content.height);
            return Math.max(1, content.width);
        }
        if (depthEffect)
            return Math.round(entryTravel * 1.35);
        return Anims.slidePx;
    }
    readonly property string clearText: I18n.tr("Dismiss")
    property bool descriptionExpanded: false
    readonly property bool hasExpandableBody: (notificationData?.htmlBody || "").replace(/<[^>]*>/g, "").trim().length > 0
    onDescriptionExpandedChanged: {
        if (connectedFrameMode)
            popupChromeGeometryChanged();
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
    signal popupChromeGeometryChanged

    function startExit() {
        if (exiting || _isDestroying) {
            return;
        }
        exiting = true;
        exitStarted();
        popupChromeGeometryChanged();
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
    readonly property real contentImplicitWidth: screen ? Math.min(400, Math.max(320, screen.width * 0.23)) : 380
    readonly property real contentImplicitHeight: {
        if (SettingsData.notificationPopupPrivacyMode && !descriptionExpanded)
            return basePopupHeightPrivacy;
        if (!descriptionExpanded)
            return basePopupHeight;
        const bodyTextHeight = expandedBodyMeasure.contentHeight || bodyText.contentHeight || 0;
        const collapsedBodyHeight = Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2);
        if (bodyTextHeight > collapsedBodyHeight + 2)
            return basePopupHeight + bodyTextHeight - collapsedBodyHeight;
        return basePopupHeight;
    }
    readonly property real targetAlignedHeight: Theme.px(Math.max(0, contentImplicitHeight), dpr)
    property real renderedAlignedHeight: targetAlignedHeight
    property real allocatedAlignedHeight: targetAlignedHeight
    readonly property bool inlineGeometryGrowing: targetAlignedHeight >= renderedAlignedHeight
    readonly property bool contentAnchorsTop: isTopCenter || SettingsData.notificationPopupPosition === SettingsData.Position.Top || SettingsData.notificationPopupPosition === SettingsData.Position.Left
    readonly property real renderedContentOffsetY: contentAnchorsTop ? 0 : Math.max(0, allocatedAlignedHeight - renderedAlignedHeight)
    implicitWidth: contentImplicitWidth + (windowShadowPad * 2)
    implicitHeight: allocatedAlignedHeight + (windowShadowPad * 2)

    function inlineMotionDuration(growing) {
        return growing ? inlineExpandDuration : inlineCollapseDuration;
    }

    function syncInlineTargetHeight() {
        const target = Math.max(0, Number(targetAlignedHeight));
        if (isNaN(target))
            return;

        if (!_inlineGeometryReady) {
            renderedHeightAnim.stop();
            renderedAlignedHeight = target;
            allocatedAlignedHeight = target;
            _lastReportedAlignedHeight = target;
            return;
        }

        const currentRendered = Math.max(0, Number(renderedAlignedHeight));
        const nextAllocation = Math.max(target, currentRendered, allocatedAlignedHeight);
        if (Math.abs(nextAllocation - allocatedAlignedHeight) >= 0.5)
            allocatedAlignedHeight = nextAllocation;

        if (Math.abs(target - renderedAlignedHeight) < 0.5) {
            finishInlineHeightAnimation();
            return;
        }

        renderedAlignedHeight = target;
        if (connectedFrameMode)
            popupChromeGeometryChanged();
        if (inlineMotionDuration(target >= currentRendered) <= 0)
            Qt.callLater(() => finishInlineHeightAnimation());
    }

    function finishInlineHeightAnimation() {
        const target = Math.max(0, Number(targetAlignedHeight));
        if (isNaN(target))
            return;
        if (Math.abs(renderedAlignedHeight - target) >= 0.5)
            renderedAlignedHeight = target;
        if (Math.abs(allocatedAlignedHeight - target) >= 0.5)
            allocatedAlignedHeight = target;
        _lastReportedAlignedHeight = renderedAlignedHeight;
        popupHeightChanged();
        if (connectedFrameMode)
            popupChromeGeometryChanged();
    }

    onTargetAlignedHeightChanged: syncInlineTargetHeight()
    onAllocatedAlignedHeightChanged: {
        if (connectedFrameMode)
            popupChromeGeometryChanged();
    }

    Behavior on renderedAlignedHeight {
        enabled: !win.exiting && !win._isDestroying
        NumberAnimation {
            id: renderedHeightAnim
            duration: win.inlineMotionDuration(win.inlineGeometryGrowing)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.inlineGeometryGrowing ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve
            onRunningChanged: win.inlineHeightAnimating = running
            onFinished: win.finishInlineHeightAnimation()
        }
    }

    onHasValidDataChanged: {
        if (!hasValidData && !exiting && !_isDestroying) {
            forceExit();
        }
    }
    Component.onCompleted: {
        renderedHeightAnim.stop();
        renderedAlignedHeight = targetAlignedHeight;
        allocatedAlignedHeight = targetAlignedHeight;
        _inlineGeometryReady = true;
        _lastReportedAlignedHeight = renderedAlignedHeight;
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
    readonly property real maxPopupShadowBlurPx: Math.max((Theme.elevationLevel3 && Theme.elevationLevel3.blurPx !== undefined) ? Theme.elevationLevel3.blurPx : 12, (Theme.elevationLevel4 && Theme.elevationLevel4.blurPx !== undefined) ? Theme.elevationLevel4.blurPx : 16)
    readonly property real maxPopupShadowOffsetXPx: Math.max(Math.abs(Theme.elevationOffsetX(Theme.elevationLevel3)), Math.abs(Theme.elevationOffsetX(Theme.elevationLevel4)))
    readonly property real maxPopupShadowOffsetYPx: Math.max(Math.abs(Theme.elevationOffsetY(Theme.elevationLevel3, 6)), Math.abs(Theme.elevationOffsetY(Theme.elevationLevel4, 8)))
    readonly property bool popupWindowShadowActive: Theme.elevationEnabled && SettingsData.notificationPopupShadowEnabled && !connectedFrameMode
    readonly property real windowShadowPad: popupWindowShadowActive ? Theme.snap(Math.max(16, maxPopupShadowBlurPx + Math.max(maxPopupShadowOffsetXPx, maxPopupShadowOffsetYPx) + 8), dpr) : 0

    anchors.top: true
    anchors.left: true
    anchors.bottom: false
    anchors.right: false

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
        top: getWindowTopMargin()
        bottom: 0
        left: getWindowLeftMargin()
        right: 0
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

    function _frameEdgeInset(side) {
        if (!screen)
            return 0;
        const raw = SettingsData.frameEdgeInsetForSide(screen, side);
        return Math.max(0, Math.round(Theme.px(raw, dpr)));
    }

    readonly property bool frameOnlyNoConnected: SettingsData.frameEnabled && !connectedFrameMode && !!screen && SettingsData.isScreenInPreferences(screen, SettingsData.frameScreenPreferences)

    // Frame ON + Connected OFF. frameEdgeInset is the full bar/frame inset
    function _frameGapMargin(side) {
        return _frameEdgeInset(side) + Theme.popupDistance;
    }

    function getTopMargin() {
        const popupPos = SettingsData.notificationPopupPosition;
        const isTop = isTopCenter || popupPos === SettingsData.Position.Top || popupPos === SettingsData.Position.Left;
        if (!isTop)
            return 0;

        if (connectedFrameMode) {
            const cornerClear = (isCenterPosition || SettingsData.frameCloseGaps) ? 0 : (Theme.px(SettingsData.frameRounding, dpr) + Theme.px(Theme.connectedCornerRadius, dpr));
            return _frameEdgeInset("top") + cornerClear + screenY;
        }
        if (frameOnlyNoConnected)
            return _frameGapMargin("top") + screenY;
        const barInfo = getBarInfo();
        const base = barInfo.topBar > 0 ? barInfo.topBar : Theme.popupDistance;
        return base + screenY;
    }

    function getBottomMargin() {
        const popupPos = SettingsData.notificationPopupPosition;
        const isBottom = isBottomCenter || popupPos === SettingsData.Position.Bottom || popupPos === SettingsData.Position.Right;
        if (!isBottom)
            return 0;

        if (connectedFrameMode) {
            const cornerClear = (isCenterPosition || SettingsData.frameCloseGaps) ? 0 : (Theme.px(SettingsData.frameRounding, dpr) + Theme.px(Theme.connectedCornerRadius, dpr));
            return _frameEdgeInset("bottom") + cornerClear + screenY;
        }
        if (frameOnlyNoConnected)
            return _frameGapMargin("bottom") + screenY;
        const barInfo = getBarInfo();
        const base = barInfo.bottomBar > 0 ? barInfo.bottomBar : Theme.popupDistance;
        return base + screenY;
    }

    function getLeftMargin() {
        if (isCenterPosition)
            return screen ? (screen.width - alignedWidth) / 2 : 0;

        const popupPos = SettingsData.notificationPopupPosition;
        const isLeft = popupPos === SettingsData.Position.Left || popupPos === SettingsData.Position.Bottom;
        if (!isLeft)
            return 0;

        if (connectedFrameMode)
            return _frameEdgeInset("left");
        if (frameOnlyNoConnected)
            return _frameGapMargin("left");
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

        if (connectedFrameMode)
            return _frameEdgeInset("right");
        if (frameOnlyNoConnected)
            return _frameGapMargin("right");
        const barInfo = getBarInfo();
        return barInfo.rightBar > 0 ? barInfo.rightBar : Theme.popupDistance;
    }

    function getContentX() {
        if (!screen)
            return 0;

        const popupPos = SettingsData.notificationPopupPosition;
        const barLeft = getLeftMargin();
        const barRight = getRightMargin();

        if (isCenterPosition)
            return Theme.snap((screen.width - alignedWidth) / 2, dpr);
        if (popupPos === SettingsData.Position.Left || popupPos === SettingsData.Position.Bottom)
            return Theme.snap(barLeft, dpr);
        return Theme.snap(screen.width - alignedWidth - barRight, dpr);
    }

    function getAllocatedContentY() {
        if (!screen)
            return 0;

        const popupPos = SettingsData.notificationPopupPosition;
        const barTop = getTopMargin();
        const barBottom = getBottomMargin();
        const isTop = isTopCenter || popupPos === SettingsData.Position.Top || popupPos === SettingsData.Position.Left;
        if (isTop)
            return Theme.snap(barTop, dpr);
        return Theme.snap(screen.height - allocatedAlignedHeight - barBottom, dpr);
    }

    function getContentY() {
        return Theme.snap(getAllocatedContentY() + renderedContentOffsetY, dpr);
    }

    function getWindowLeftMargin() {
        if (!screen)
            return 0;
        return Theme.snap(getContentX() - windowShadowPad, dpr);
    }

    function getWindowTopMargin() {
        if (!screen)
            return 0;
        return Theme.snap(getAllocatedContentY() - windowShadowPad, dpr);
    }

    function _swipeDismissTarget() {
        return (content.swipeDismissDirection < 0 ? -1 : 1) * content.width;
    }

    function _frameEdgeSwipeDirection() {
        const popupPos = SettingsData.notificationPopupPosition;
        return (popupPos === SettingsData.Position.Left || popupPos === SettingsData.Position.Bottom) ? -1 : 1;
    }

    function _swipeDismissesTowardFrameEdge() {
        return content.swipeDismissDirection === _frameEdgeSwipeDirection();
    }

    function popupChromeMotionActive() {
        return popupChromeOpenProgress() < 1 || exiting || content.swipeActive || content.swipeDismissing || Math.abs(content.swipeOffset) > 0.5;
    }

    function popupLayoutReservesSlot() {
        return !content.swipeDismissing;
    }

    function popupChromeReservesSlot() {
        return !content.swipeDismissing;
    }

    function _chromeMotionOffset() {
        return isCenterPosition ? tx.y : tx.x;
    }

    function _chromeCardTravel() {
        return Math.max(1, isCenterPosition ? alignedHeight : alignedWidth);
    }

    function popupChromeOpenProgress() {
        if (exiting || content.swipeDismissing)
            return 1;
        return Math.max(0, Math.min(1, 1 - Math.abs(_chromeMotionOffset()) / _chromeCardTravel()));
    }

    function popupChromeReleaseProgress() {
        if (exiting) {
            const exitRel = Math.max(0, Math.min(1, Math.abs(_chromeMotionOffset()) / _chromeCardTravel()));
            if (content.swipeDismissing) {
                const swipeRel = Math.max(0, Math.min(1, Math.abs(content.swipeOffset) / Math.max(1, content.swipeTravelDistance)));
                return Math.max(exitRel, swipeRel);
            }
            return exitRel;
        }
        if (content.swipeDismissing)
            return Math.max(0, Math.min(1, Math.abs(content.swipeOffset) / Math.max(1, content.swipeTravelDistance)));
        if (content.swipeActive && content.swipeOffset * _frameEdgeSwipeDirection() > 0)
            return Math.max(0, Math.min(1, Math.abs(content.swipeOffset) / Math.max(1, content.swipeTravelDistance)));
        return 0;
    }

    function popupChromeFollowsCardMotion() {
        return false;
    }

    function popupChromeMotionX() {
        if (!popupChromeMotionActive() || isCenterPosition)
            return 0;
        const motion = content.swipeOffset + tx.x;
        if (content.swipeDismissing && !_swipeDismissesTowardFrameEdge())
            return exiting ? Theme.snap(tx.x, dpr) : 0;
        if (content.swipeActive && motion * _frameEdgeSwipeDirection() < 0)
            return 0;
        return Theme.snap(motion, dpr);
    }

    function popupChromeMotionY() {
        return popupChromeMotionActive() ? Theme.snap(tx.y, dpr) : 0;
    }

    readonly property bool screenValid: win.screen && !_isDestroying
    readonly property real dpr: screenValid ? CompositorService.getScreenScale(win.screen) : 1
    readonly property real alignedWidth: Theme.px(Math.max(0, implicitWidth - (windowShadowPad * 2)), dpr)
    readonly property real alignedHeight: renderedAlignedHeight
    onScreenYChanged: if (connectedFrameMode)
        popupChromeGeometryChanged()
    onScreenChanged: if (connectedFrameMode)
        popupChromeGeometryChanged()
    // Intentionally unconditional: Manager needs the signal when frame mode toggles off
    onConnectedFrameModeChanged: popupChromeGeometryChanged()
    onAlignedWidthChanged: if (connectedFrameMode)
        popupChromeGeometryChanged()
    onAlignedHeightChanged: if (connectedFrameMode)
        popupChromeGeometryChanged()

    Item {
        id: content

        x: Theme.snap(windowShadowPad, dpr)
        y: Theme.snap(windowShadowPad + renderedContentOffsetY, dpr)
        width: alignedWidth
        height: alignedHeight
        visible: !win._finalized && !chromeOnlyExit
        transformOrigin: Item.Center

        property real chromeScale: (!win.inlineHeightAnimating && cardHoverHandler.hovered) ? 1.01 : 1.0

        Behavior on chromeScale {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        property real swipeOffset: 0
        property real swipeDismissDirection: 1
        property bool chromeOnlyExit: false
        readonly property real dismissThreshold: width * 0.35
        readonly property real swipeFadeStartRatio: 0.75
        readonly property real swipeTravelDistance: width
        readonly property real swipeFadeStartOffset: swipeTravelDistance * swipeFadeStartRatio
        readonly property real swipeFadeDistance: Math.max(1, swipeTravelDistance - swipeFadeStartOffset)
        readonly property bool swipeActive: swipeDragHandler.active
        property bool swipeDismissing: false
        onSwipeDismissingChanged: {
            if (!win.connectedFrameMode)
                return;
            win.popupHeightChanged();
            win.popupChromeGeometryChanged();
        }
        onSwipeOffsetChanged: {
            if (win.connectedFrameMode)
                win.popupChromeGeometryChanged();
        }

        readonly property bool shadowsAllowed: win.popupWindowShadowActive
        readonly property var elevLevel: cardHoverHandler.hovered ? Theme.elevationLevel4 : Theme.elevationLevel3
        readonly property real cardInset: Theme.snap(4, win.dpr)
        readonly property real shadowRenderPadding: shadowsAllowed ? Theme.snap(Math.max(16, shadowBlurPx + Math.max(Math.abs(shadowOffsetX), Math.abs(shadowOffsetY)) + 8), win.dpr) : 0
        property real shadowBlurPx: shadowsAllowed ? (elevLevel && elevLevel.blurPx !== undefined ? elevLevel.blurPx : 12) : 0
        property real shadowOffsetX: shadowsAllowed ? Theme.elevationOffsetX(elevLevel) : 0
        property real shadowOffsetY: shadowsAllowed ? Theme.elevationOffsetY(elevLevel, 6) : 0

        Behavior on shadowBlurPx {
            NumberAnimation {
                duration: win.inlineHeightAnimating ? win.inlineExpandDuration : Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on shadowOffsetX {
            NumberAnimation {
                duration: win.inlineHeightAnimating ? win.inlineExpandDuration : Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on shadowOffsetY {
            NumberAnimation {
                duration: win.inlineHeightAnimating ? win.inlineExpandDuration : Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        ElevationShadow {
            id: bgShadowLayer
            anchors.fill: parent
            anchors.margins: -content.shadowRenderPadding
            scale: content.chromeScale
            transformOrigin: Item.Center
            level: content.elevLevel
            fallbackOffset: 6
            shadowBlurPx: content.shadowBlurPx
            shadowOffsetX: content.shadowOffsetX
            shadowOffsetY: content.shadowOffsetY
            shadowColor: content.shadowsAllowed && content.elevLevel ? Theme.elevationShadowColor(content.elevLevel) : "transparent"
            shadowEnabled: !win._isDestroying && win.screenValid && content.shadowsAllowed && !win.connectedFrameMode
            layer.textureSize: Qt.size(Math.round(width * win.dpr), Math.round(height * win.dpr))
            layer.textureMirroring: ShaderEffectSource.MirrorVertically

            sourceRect.anchors.fill: undefined
            sourceRect.x: content.shadowRenderPadding + content.cardInset
            sourceRect.y: content.shadowRenderPadding + content.cardInset
            sourceRect.width: Math.max(0, content.width - (content.cardInset * 2))
            sourceRect.height: Math.max(0, content.height - (content.cardInset * 2))
            sourceRect.radius: win.connectedFrameMode ? Theme.connectedSurfaceRadius : Theme.cornerRadius
            sourceRect.color: win.connectedFrameMode ? Theme.floatingSurface : Theme.readableSurface
            sourceRect.antialiasing: true
            sourceRect.layer.enabled: false
            sourceRect.layer.textureSize: Qt.size(0, 0)
            sourceRect.border.color: notificationData && notificationData.urgency === NotificationUrgency.Critical ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.outline, 0.08)
            sourceRect.border.width: notificationData && notificationData.urgency === NotificationUrgency.Critical ? 2 : 0
        }

        // Keep critical accent outside shadow rendering so connected mode still shows it.
        Rectangle {
            x: content.cardInset
            y: content.cardInset
            width: Math.max(0, content.width - content.cardInset * 2)
            height: Math.max(0, content.height - content.cardInset * 2)
            radius: win.connectedFrameMode ? Theme.connectedSurfaceRadius : Theme.cornerRadius
            visible: win.notificationData && win.notificationData.urgency === NotificationUrgency.Critical
            opacity: 1
            clip: true
            scale: content.chromeScale
            transformOrigin: Item.Center

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

        Rectangle {
            anchors.fill: parent
            anchors.margins: content.cardInset
            radius: win.connectedFrameMode ? Theme.connectedSurfaceRadius : Theme.cornerRadius
            color: "transparent"
            border.color: win.connectedFrameMode ? "transparent" : BlurService.borderColor
            border.width: win.connectedFrameMode ? 0 : BlurService.borderWidth
            z: 100
            scale: content.chromeScale
            transformOrigin: Item.Center
        }

        Item {
            id: backgroundContainer
            anchors.fill: parent
            anchors.margins: content.cardInset
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

            StyledText {
                id: expandedBodyMeasure

                visible: false
                width: Math.max(0, backgroundContainer.width - Theme.spacingL - (Theme.spacingL + Theme.notificationHoverRevealMargin) - popupIconSize - Theme.spacingM)
                text: notificationData ? (notificationData.htmlBody || "") : ""
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideNone
                horizontalAlignment: Text.AlignLeft
                maximumLineCount: -1
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            Item {
                id: notificationContent

                readonly property real expandedTextHeight: expandedBodyMeasure.contentHeight || bodyText.contentHeight || 0
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
                            return "";
                        if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://") || appIcon.includes("/"))
                            return appIcon;
                        return "";
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

                            propagateComposedEvents: false
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
            xAxis.enabled: true
            yAxis.enabled: false

            onActiveChanged: {
                if (active || win.exiting || content.swipeDismissing)
                    return;

                if (Math.abs(content.swipeOffset) > content.dismissThreshold) {
                    content.swipeDismissDirection = content.swipeOffset < 0 ? -1 : 1;
                    content.swipeDismissing = true;
                    swipeDismissAnim.start();
                } else {
                    content.swipeOffset = 0;
                }
            }

            onTranslationChanged: {
                if (win.exiting || content.swipeDismissing)
                    return;

                content.swipeOffset = translation.x;
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
            enabled: !content.swipeActive && !content.swipeDismissing
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
            to: win._swipeDismissTarget()
            duration: Theme.notificationExitDuration
            easing.type: Easing.OutCubic
            onStopped: {
                const inwardConnectedExit = win.connectedFrameMode && !win.isCenterPosition && !win._swipeDismissesTowardFrameEdge();
                if (inwardConnectedExit)
                    content.chromeOnlyExit = true;
                if (win.connectedFrameMode) {
                    win.startExit();
                    NotificationService.dismissNotification(notificationData);
                } else {
                    NotificationService.dismissNotification(notificationData);
                    win.forceExit();
                }
            }
        }

        transform: [
            Translate {
                id: swipeTx
                x: content.swipeOffset
                y: 0
            },
            Translate {
                id: tx
                x: {
                    if (isCenterPosition)
                        return 0;
                    const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
                    return isLeft ? -entryTravel : entryTravel;
                }
                y: isTopCenter ? -entryTravel : isBottomCenter ? entryTravel : 0
                onXChanged: {
                    if (win.connectedFrameMode)
                        win.popupChromeGeometryChanged();
                }
                onYChanged: {
                    if (win.connectedFrameMode)
                        win.popupChromeGeometryChanged();
                }
            }
        ]
    }

    NumberAnimation {
        id: enterX

        target: tx
        property: isCenterPosition ? "y" : "x"
        from: {
            if (isTopCenter)
                return -entryTravel;
            if (isBottomCenter)
                return entryTravel;
            const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
            return isLeft ? -entryTravel : entryTravel;
        }
        to: 0
        duration: Theme.notificationEnterDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.variantPopoutEnterCurve
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
                    return -exitTravel;
                if (isBottomCenter)
                    return exitTravel;
                const isLeft = SettingsData.notificationPopupPosition === SettingsData.Position.Left || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom;
                return isLeft ? -exitTravel : exitTravel;
            }
            duration: Theme.notificationExitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantPopoutExitCurve
        }

        NumberAnimation {
            target: content
            property: "opacity"
            to: Theme.isDirectionalEffect ? 1 : 0
            duration: Theme.notificationExitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantPopoutExitCurve
        }

        NumberAnimation {
            target: content
            property: "scale"
            to: Theme.isDirectionalEffect ? 1 : Theme.effectScaleCollapsed
            duration: Theme.notificationExitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantPopoutExitCurve
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
