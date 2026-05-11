import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: root
    readonly property var log: Log.scoped("DankOSD")

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
        if (shouldBeVisible) {
            hideTimer.restart();
            return;
        }
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

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.visible && !root.shouldBeVisible)
                return;
            const currentScreenName = root.screen?.name;
            if (!currentScreenName) {
                root.hide();
                return;
            }
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === currentScreenName)
                    return;
            }
            root.shouldBeVisible = false;
            root.visible = false;
            hideTimer.stop();
            closeTimer.stop();
            osdHidden();
        }
    }

    WlrLayershell.layer: {
        switch (Quickshell.env("DMS_OSD_LAYER")) {
        case "bottom":
            log.warn("'bottom' layer is not valid for OSDs. Defaulting to 'overlay' layer.");
            return WlrLayershell.Overlay;
        case "background":
            log.warn("'background' layer is not valid for OSDs. Defaulting to 'overlay' layer.");
            return WlrLayershell.Overlay;
        case "top":
            return WlrLayershell.Top;
        default:
            return WlrLayershell.Overlay;
        }
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    WindowBlur {
        targetWindow: root
        blurX: shadowBuffer
        blurY: shadowBuffer
        blurWidth: shouldBeVisible ? alignedWidth : 0
        blurHeight: shouldBeVisible ? alignedHeight : 0
        blurRadius: Theme.cornerRadius
    }

    color: "transparent"

    readonly property real dpr: CompositorService.getScreenScale(screen)
    readonly property real screenWidth: screen.width
    readonly property real screenHeight: screen.height
    readonly property real shadowBuffer: 15
    readonly property real alignedWidth: Theme.px(osdWidth, dpr)
    readonly property real alignedHeight: Theme.px(osdHeight, dpr)

    readonly property bool isVerticalLayout: SettingsData.osdPosition === SettingsData.Position.LeftCenter || SettingsData.osdPosition === SettingsData.Position.RightCenter

    readonly property var barEdgeOffsets: {
        const offsets = {
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        };
        const configs = SettingsData.barConfigs;
        if (!screen || !configs)
            return offsets;
        const defaultBar = configs[0] || SettingsData.getBarConfig("default");
        for (var i = 0; i < configs.length; i++) {
            const bc = configs[i];
            if (!bc || !(bc.enabled ?? true) || !(bc.visible ?? true))
                continue;
            const prefs = bc.screenPreferences || ["all"];
            if (!prefs.includes("all") && !SettingsData.isScreenInPreferences(screen, prefs))
                continue;
            const innerPadding = bc.innerPadding ?? (defaultBar?.innerPadding ?? 4);
            const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
            const thickness = Math.max(widgetThickness + innerPadding + 4, Theme.barHeight - 4 - (8 - innerPadding));
            const spacing = bc.spacing ?? (defaultBar?.spacing ?? 4);
            const bottomGap = bc.bottomGap ?? (defaultBar?.bottomGap ?? 0);
            const offset = thickness + spacing + bottomGap;
            switch (bc.position ?? SettingsData.Position.Top) {
            case SettingsData.Position.Top:
                offsets.top = Math.max(offsets.top, offset);
                break;
            case SettingsData.Position.Bottom:
                offsets.bottom = Math.max(offsets.bottom, offset);
                break;
            case SettingsData.Position.Left:
                offsets.left = Math.max(offsets.left, offset);
                break;
            case SettingsData.Position.Right:
                offsets.right = Math.max(offsets.right, offset);
                break;
            }
        }
        return offsets;
    }

    readonly property real dockThickness: {
        if (!SettingsData.showDock)
            return 0;
        return SettingsData.dockIconSize + SettingsData.dockSpacing * 2 + 10;
    }

    readonly property real dockOffset: {
        if (!SettingsData.showDock || SettingsData.dockAutoHide || SettingsData.dockSmartAutoHide)
            return 0;
        return dockThickness + SettingsData.dockSpacing + SettingsData.dockBottomGap + SettingsData.dockMargin;
    }

    readonly property real alignedX: {
        const margin = Theme.spacingM;
        const centerX = (screenWidth - alignedWidth) / 2;

        switch (SettingsData.osdPosition) {
        case SettingsData.Position.Left:
        case SettingsData.Position.Bottom:
        case SettingsData.Position.LeftCenter:
            const leftDockOffset = SettingsData.dockPosition === SettingsData.Position.Left ? dockOffset : 0;
            return Theme.snap(margin + Math.max(barEdgeOffsets.left, leftDockOffset), dpr);
        case SettingsData.Position.Top:
        case SettingsData.Position.Right:
        case SettingsData.Position.RightCenter:
            const rightDockOffset = SettingsData.dockPosition === SettingsData.Position.Right ? dockOffset : 0;
            return Theme.snap(screenWidth - alignedWidth - margin - Math.max(barEdgeOffsets.right, rightDockOffset), dpr);
        case SettingsData.Position.TopCenter:
        case SettingsData.Position.BottomCenter:
        default:
            return Theme.snap(centerX, dpr);
        }
    }

    readonly property real alignedY: {
        const margin = Theme.spacingM;
        const centerY = (screenHeight - alignedHeight) / 2;

        switch (SettingsData.osdPosition) {
        case SettingsData.Position.Top:
        case SettingsData.Position.Left:
        case SettingsData.Position.TopCenter:
            const topDockOffset = SettingsData.dockPosition === SettingsData.Position.Top ? dockOffset : 0;
            return Theme.snap(margin + Math.max(barEdgeOffsets.top, topDockOffset), dpr);
        case SettingsData.Position.Right:
        case SettingsData.Position.Bottom:
        case SettingsData.Position.BottomCenter:
            const bottomDockOffset = SettingsData.dockPosition === SettingsData.Position.Bottom ? dockOffset : 0;
            return Theme.snap(screenHeight - alignedHeight - margin - Math.max(barEdgeOffsets.bottom, bottomDockOffset), dpr);
        case SettingsData.Position.LeftCenter:
        case SettingsData.Position.RightCenter:
        default:
            return Theme.snap(centerY, dpr);
        }
    }

    anchors {
        top: true
        left: true
    }

    WlrLayershell.margins {
        left: Math.max(0, Theme.snap(alignedX - shadowBuffer, dpr))
        top: Math.max(0, Theme.snap(alignedY - shadowBuffer, dpr))
    }

    implicitWidth: alignedWidth + (shadowBuffer * 2)
    implicitHeight: alignedHeight + (shadowBuffer * 2)

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
        x: shadowBuffer
        y: shadowBuffer
        width: alignedWidth
        height: alignedHeight
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9

        property bool childHovered: false
        readonly property real popupSurfaceAlpha: Theme.popupTransparency

        Rectangle {
            id: background
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: "transparent"
            border.color: BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium
            border.width: BlurService.enabled ? BlurService.borderWidth : 1
            z: -1
        }

        ElevationShadow {
            id: bgShadowLayer
            anchors.fill: parent
            z: -1
            level: Theme.elevationLevel3
            fallbackOffset: 6
            targetRadius: Theme.cornerRadius
            targetColor: Theme.withAlpha(Theme.surfaceContainer, osdContainer.popupSurfaceAlpha)
            borderColor: Theme.outlineMedium
            borderWidth: 1
            shadowEnabled: Theme.elevationEnabled && SettingsData.popoutElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            layer.textureSize: Qt.size(Math.round(width * root.dpr), Math.round(height * root.dpr))
            layer.textureMirroring: ShaderEffectSource.MirrorVertically
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
