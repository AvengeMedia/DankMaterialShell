import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string blurNamespace: "dms:osd"
    WlrLayershell.namespace: blurNamespace

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property var modelData
    property bool shouldBeVisible: false
    property int autoHideInterval: 2000
    property bool enableMouseInteraction: false
    property real osdWidth: Theme.iconSize + Theme.spacingS * 2
    property real osdHeight: Theme.iconSize + Theme.spacingS * 2
    property int animationDuration: Theme.mediumDuration
    property var animationEasing: Theme.emphasizedEasing

    signal osdShown
    signal osdHidden

    function show() {
        if (SessionData.suppressOSD)
            return;
        OSDManager.showOSD(root);
        closeTimer.stop();
        shouldBeVisible = true;
        visible = true;
        hideTimer.restart();
        osdShown();
    }

    function hide() {
        shouldBeVisible = false;
        closeTimer.restart();
    }

    function resetHideTimer() {
        if (shouldBeVisible) {
            hideTimer.restart();
        }
    }

    function updateHoverState() {
        let isHovered = (enableMouseInteraction && mouseArea.containsMouse) || osdContainer.childHovered;
        if (enableMouseInteraction) {
            if (isHovered) {
                hideTimer.stop();
            } else if (shouldBeVisible) {
                hideTimer.restart();
            }
        }
    }

    function setChildHovered(hovered) {
        osdContainer.childHovered = hovered;
        updateHoverState();
    }

    screen: modelData
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    readonly property real dpr: CompositorService.getScreenScale(screen)
    readonly property real screenWidth: screen.width
    readonly property real screenHeight: screen.height
    readonly property real alignedWidth: Theme.px(osdWidth, dpr)
    readonly property real alignedHeight: Theme.px(osdHeight, dpr)

    readonly property bool isVerticalLayout: SettingsData.osdPosition === SettingsData.Position.LeftCenter || SettingsData.osdPosition === SettingsData.Position.RightCenter

    readonly property real barThickness: {
        const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
        if (!defaultBar || !(defaultBar.visible ?? true))
            return 0;
        const innerPadding = defaultBar.innerPadding ?? 4;
        const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
        return Math.max(widgetThickness + innerPadding + 4, Theme.barHeight - 4 - (8 - innerPadding));
    }

    readonly property real barOffset: {
        const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
        if (!defaultBar || !(defaultBar.visible ?? true))
            return 0;
        const spacing = defaultBar.spacing ?? 4;
        const bottomGap = defaultBar.bottomGap ?? 0;
        return barThickness + spacing + bottomGap;
    }

    readonly property real dockThickness: {
        if (!SettingsData.showDock)
            return 0;
        return SettingsData.dockIconSize + SettingsData.dockSpacing * 2 + 10;
    }

    readonly property real dockOffset: {
        if (!SettingsData.showDock || SettingsData.dockAutoHide)
            return 0;
        return dockThickness + SettingsData.dockSpacing + SettingsData.dockBottomGap + SettingsData.dockMargin;
    }

    readonly property real alignedX: {
        const margin = Theme.spacingM;
        const centerX = (screenWidth - alignedWidth) / 2;

        const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
        const barPos = defaultBar?.position ?? SettingsData.Position.Top;

        switch (SettingsData.osdPosition) {
        case SettingsData.Position.Left:
        case SettingsData.Position.Bottom:
            const leftBarOffset = barPos === SettingsData.Position.Left ? barOffset : 0;
            const leftDockOffset = SettingsData.dockPosition === SettingsData.Position.Left ? dockOffset : 0;
            return Theme.snap(margin + Math.max(leftBarOffset, leftDockOffset), dpr);
        case SettingsData.Position.Top:
        case SettingsData.Position.Right:
            const rightBarOffset = barPos === SettingsData.Position.Right ? barOffset : 0;
            const rightDockOffset = SettingsData.dockPosition === SettingsData.Position.Right ? dockOffset : 0;
            return Theme.snap(screenWidth - alignedWidth - margin - Math.max(rightBarOffset, rightDockOffset), dpr);
        case SettingsData.Position.LeftCenter:
            const leftCenterBarOffset = barPos === SettingsData.Position.Left ? barOffset : 0;
            const leftCenterDockOffset = SettingsData.dockPosition === SettingsData.Position.Left ? dockOffset : 0;
            return Theme.snap(margin + Math.max(leftCenterBarOffset, leftCenterDockOffset), dpr);
        case SettingsData.Position.RightCenter:
            const rightCenterBarOffset = barPos === SettingsData.Position.Right ? barOffset : 0;
            const rightCenterDockOffset = SettingsData.dockPosition === SettingsData.Position.Right ? dockOffset : 0;
            return Theme.snap(screenWidth - alignedWidth - margin - Math.max(rightCenterBarOffset, rightCenterDockOffset), dpr);
        case SettingsData.Position.TopCenter:
        case SettingsData.Position.BottomCenter:
        default:
            return Theme.snap(centerX, dpr);
        }
    }

    readonly property real alignedY: {
        const margin = Theme.spacingM;
        const centerY = (screenHeight - alignedHeight) / 2;

        const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
        const barPos = defaultBar?.position ?? SettingsData.Position.Top;

        switch (SettingsData.osdPosition) {
        case SettingsData.Position.Top:
        case SettingsData.Position.Left:
        case SettingsData.Position.TopCenter:
            const topBarOffset = barPos === SettingsData.Position.Top ? barOffset : 0;
            const topDockOffset = SettingsData.dockPosition === SettingsData.Position.Top ? dockOffset : 0;
            return Theme.snap(margin + Math.max(topBarOffset, topDockOffset), dpr);
        case SettingsData.Position.Right:
        case SettingsData.Position.Bottom:
        case SettingsData.Position.BottomCenter:
            const bottomBarOffset = barPos === SettingsData.Position.Bottom ? barOffset : 0;
            const bottomDockOffset = SettingsData.dockPosition === SettingsData.Position.Bottom ? dockOffset : 0;
            return Theme.snap(screenHeight - alignedHeight - margin - Math.max(bottomBarOffset, bottomDockOffset), dpr);
        case SettingsData.Position.LeftCenter:
        case SettingsData.Position.RightCenter:
        default:
            return Theme.snap(centerY, dpr);
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Timer {
        id: hideTimer

        interval: autoHideInterval
        repeat: false
        onTriggered: {
            if (!enableMouseInteraction || !mouseArea.containsMouse) {
                hide();
            } else {
                hideTimer.restart();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false;
                osdHidden();
            }
        }
    }

    Item {
        id: osdContainer
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9

        property bool childHovered: false
        property real shadowBlurPx: 10
        property real shadowSpreadPx: 0
        property real shadowBaseAlpha: 0.60
        readonly property real popupSurfaceAlpha: SettingsData.popupTransparency
        readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha * osdContainer.opacity))

        DankRectangle {
            id: background
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, osdContainer.popupSurfaceAlpha)
            z: -1
        }

        Item {
            id: bgShadowLayer
            anchors.fill: parent
            visible: osdContainer.popupSurfaceAlpha >= 0.95
            layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            layer.smooth: false
            layer.textureSize: Qt.size(Math.round(width * root.dpr), Math.round(height * root.dpr))
            layer.textureMirroring: ShaderEffectSource.MirrorVertically

            readonly property int blurMax: 64

            layer.effect: MultiEffect {
                id: shadowFx
                autoPaddingEnabled: true
                shadowEnabled: true
                blurEnabled: false
                maskEnabled: false
                shadowBlur: Math.max(0, Math.min(1, osdContainer.shadowBlurPx / bgShadowLayer.blurMax))
                shadowScale: 1 + (2 * osdContainer.shadowSpreadPx) / Math.max(1, Math.min(bgShadowLayer.width, bgShadowLayer.height))
                shadowColor: {
                    const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest;
                    return Theme.withAlpha(baseColor, osdContainer.effectiveShadowAlpha);
                }
            }

            DankRectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: enableMouseInteraction
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            z: -1
            onContainsMouseChanged: updateHoverState()
        }

        onChildHoveredChanged: updateHoverState()

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }
    }

    mask: Region {
        item: bgShadowLayer
    }
}
