import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    clip: false
    property var dockApps: null
    property int index: -1
    property bool longPressing: false
    property bool dragging: false
    property point dragStartPos: Qt.point(0, 0)
    property real dragAxisOffset: 0
    property int targetIndex: -1
    property int originalIndex: -1
    property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    property bool isHovered: mouseArea.containsMouse && !dragging
    property bool showTooltip: mouseArea.containsMouse && !dragging
    property real actualIconSize: 40

    readonly property string tooltipText: I18n.tr("Applications")

    readonly property color effectiveLogoColor: {
        const override = SettingsData.dockLauncherLogoColorOverride;
        if (override === "primary")
            return Theme.primary;
        if (override === "surface")
            return Theme.surfaceText;
        if (override !== "")
            return override;
        return Theme.surfaceText;
    }

    onIsHoveredChanged: {
        if (mouseArea.pressed || dragging)
            return;
        if (isHovered) {
            exitAnimation.stop();
            if (!bounceAnimation.running) {
                bounceAnimation.restart();
            }
        } else {
            bounceAnimation.stop();
            exitAnimation.restart();
        }
    }

    readonly property bool animateX: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    readonly property real animationDistance: actualIconSize
    readonly property real animationDirection: {
        if (SettingsData.dockPosition === SettingsData.Position.Bottom)
            return -1;
        if (SettingsData.dockPosition === SettingsData.Position.Top)
            return 1;
        if (SettingsData.dockPosition === SettingsData.Position.Right)
            return -1;
        if (SettingsData.dockPosition === SettingsData.Position.Left)
            return 1;
        return -1;
    }

    SequentialAnimation {
        id: bounceAnimation

        running: false

        NumberAnimation {
            target: root
            property: "hoverAnimOffset"
            to: animationDirection * animationDistance * 0.25
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: root
            property: "hoverAnimOffset"
            to: animationDirection * animationDistance * 0.2
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    NumberAnimation {
        id: exitAnimation

        running: false
        target: root
        property: "hoverAnimOffset"
        to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }

    Timer {
        id: longPressTimer

        interval: 500
        repeat: false
        onTriggered: {
            longPressing = true;
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: true
        preventStealing: dragging || longPressing
        cursorShape: longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) {
                dragStartPos = Qt.point(mouse.x, mouse.y);
                longPressTimer.start();
            }
        }
        onReleased: mouse => {
            longPressTimer.stop();

            const wasDragging = dragging;
            const didReorder = wasDragging && targetIndex >= 0 && dockApps;

            if (didReorder) {
                SessionData.setDockLauncherPosition(targetIndex);
            }

            longPressing = false;
            dragging = false;
            dragAxisOffset = 0;
            targetIndex = -1;
            originalIndex = -1;

            if (dockApps) {
                dockApps.draggedIndex = -1;
                dockApps.dropTargetIndex = -1;
            }

            if (wasDragging || mouse.button !== Qt.LeftButton)
                return;

            PopoutService.toggleDankLauncherV2();
        }
        onPositionChanged: mouse => {
            if (longPressing && !dragging) {
                const distance = Math.sqrt(Math.pow(mouse.x - dragStartPos.x, 2) + Math.pow(mouse.y - dragStartPos.y, 2));
                if (distance > 5) {
                    dragging = true;
                    targetIndex = index;
                    originalIndex = index;
                    if (dockApps) {
                        dockApps.draggedIndex = index;
                        dockApps.dropTargetIndex = index;
                    }
                }
            }

            if (!dragging || !dockApps)
                return;

            const axisOffset = isVertical ? (mouse.y - dragStartPos.y) : (mouse.x - dragStartPos.x);
            dragAxisOffset = axisOffset;

            const spacing = Math.min(8, Math.max(4, actualIconSize * 0.08));
            const itemSize = actualIconSize * 1.2 + spacing;
            const slotOffset = Math.round(axisOffset / itemSize);
            const newTargetIndex = Math.max(0, Math.min(dockApps.pinnedAppCount, originalIndex + slotOffset));

            if (newTargetIndex !== targetIndex) {
                targetIndex = newTargetIndex;
                dockApps.dropTargetIndex = newTargetIndex;
            }
        }
    }

    property real hoverAnimOffset: 0

    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            x: dragging && !isVertical ? dragAxisOffset : (!dragging && isVertical ? hoverAnimOffset : 0)
            y: dragging && isVertical ? dragAxisOffset : (!dragging && !isVertical ? hoverAnimOffset : 0)
        }

        Item {
            anchors.centerIn: parent
            width: actualIconSize
            height: actualIconSize

            DankIcon {
                visible: SettingsData.dockLauncherLogoMode === "apps"
                anchors.centerIn: parent
                name: "apps"
                size: actualIconSize - 4
                color: Theme.widgetIconColor
            }

            SystemLogo {
                visible: SettingsData.dockLauncherLogoMode === "os"
                anchors.centerIn: parent
                width: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                height: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                colorOverride: effectiveLogoColor
                brightnessOverride: SettingsData.dockLauncherLogoBrightness
                contrastOverride: SettingsData.dockLauncherLogoContrast
            }

            IconImage {
                visible: SettingsData.dockLauncherLogoMode === "dank"
                anchors.centerIn: parent
                width: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                height: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                smooth: true
                mipmap: true
                asynchronous: true
                source: "file://" + Theme.shellDir + "/assets/danklogo.svg"
                layer.enabled: effectiveLogoColor !== ""
                layer.smooth: true
                layer.mipmap: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: effectiveLogoColor
                }
            }

            IconImage {
                visible: SettingsData.dockLauncherLogoMode === "compositor" && (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isDwl || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle || CompositorService.isLabwc)
                anchors.centerIn: parent
                width: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                height: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                smooth: true
                asynchronous: true
                source: {
                    if (CompositorService.isNiri) {
                        return "file://" + Theme.shellDir + "/assets/niri.svg";
                    } else if (CompositorService.isHyprland) {
                        return "file://" + Theme.shellDir + "/assets/hyprland.svg";
                    } else if (CompositorService.isDwl) {
                        return "file://" + Theme.shellDir + "/assets/mango.png";
                    } else if (CompositorService.isSway) {
                        return "file://" + Theme.shellDir + "/assets/sway.svg";
                    } else if (CompositorService.isScroll) {
                        return "file://" + Theme.shellDir + "/assets/sway.svg";
                    } else if (CompositorService.isMiracle) {
                        return "file://" + Theme.shellDir + "/assets/miraclewm.svg";
                    } else if (CompositorService.isLabwc) {
                        return "file://" + Theme.shellDir + "/assets/labwc.png";
                    }
                    return "";
                }
                layer.enabled: effectiveLogoColor !== ""
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: effectiveLogoColor
                    brightness: {
                        SettingsData.dockLauncherLogoBrightness;
                    }
                    contrast: {
                        SettingsData.dockLauncherLogoContrast;
                    }
                }
            }

            IconImage {
                visible: SettingsData.dockLauncherLogoMode === "custom" && SettingsData.dockLauncherLogoCustomPath !== ""
                anchors.centerIn: parent
                width: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                height: actualIconSize + SettingsData.dockLauncherLogoSizeOffset
                smooth: true
                asynchronous: true
                source: SettingsData.dockLauncherLogoCustomPath ? "file://" + SettingsData.dockLauncherLogoCustomPath.replace("file://", "") : ""
                layer.enabled: effectiveLogoColor !== ""
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: effectiveLogoColor
                    brightness: SettingsData.dockLauncherLogoBrightness
                    contrast: SettingsData.dockLauncherLogoContrast
                }
            }
        }
    }
}
