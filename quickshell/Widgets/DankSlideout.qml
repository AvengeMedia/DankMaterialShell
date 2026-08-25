pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string layerNamespace: "dms:slideout"
    WlrLayershell.namespace: layerNamespace

    property bool isVisible: false
    property bool hoverDismissEnabled: false
    property bool hoverDismissSuspended: false
    property var targetScreen: null
    property var modelData: null
    property bool triggerUsesOverlayLayer: false
    // Drop off the Overlay layer (back to Top) while an overlay modal
    property bool suppressOverlayLayer: false
    property real slideoutWidth: 480
    property bool expandable: false
    property bool expandedWidth: false
    property real expandedWidthValue: 960
    property real edgeGap: 0
    property string slideEdge: "right"
    readonly property bool slideFromLeft: slideEdge === "left"
    readonly property real surfaceOriginX: slideFromLeft ? 0 : Math.max(0, (modelData?.width ?? width) - width)
    property Component content: null
    property string title: ""
    property alias container: contentContainer
    property alias loadedItem: contentLoader.item
    property real customTransparency: -1
    property bool mappedVisible: false
    signal aboutToHide
    signal revealed

    function show() {
        mappedVisible = true;
        Qt.callLater(() => {
            isVisible = true;
            revealed();
        });
    }

    function hide() {
        aboutToHide();
        isVisible = false;
    }

    function hideFromHoverDismiss() {
        if (hoverDismissSuspended)
            return;
        hoverDismissEnabled = false;
        slideContainer.slideSlowExit = true;
        hide();
    }

    function cancelHoverDismiss() {
        hoverDismissTracker.cancelPending();
    }

    function containsGlobalPoint(gx, gy) {
        if (!isVisible || !modelData)
            return false;
        const padding = 24;
        const topLeft = slideContainer.mapToItem(null, 0, 0);
        const globalX = surfaceOriginX + topLeft.x;
        return gx >= globalX - padding && gx < globalX + slideContainer.width + padding && gy >= topLeft.y - padding && gy < topLeft.y + slideContainer.height + padding;
    }

    function toggle() {
        if (isVisible) {
            hide();
        } else {
            show();
        }
    }

    visible: root.mappedVisible
    screen: modelData

    anchors.top: true
    anchors.bottom: true
    anchors.right: !root.slideFromLeft
    anchors.left: root.slideFromLeft

    implicitWidth: expandable ? expandedWidthValue : slideoutWidth
    implicitHeight: modelData ? modelData.height : 800

    color: "transparent"

    HoverDismissTracker {
        id: hoverDismissTracker
        parent: root.contentItem
        enabled: root.hoverDismissEnabled && !root.hoverDismissSuspended && root.isVisible
        shouldDismiss: function () {
            return !PopoutManager.cursorOverBar(PopoutManager.hoverCursorGlobalX, PopoutManager.hoverCursorGlobalY);
        }
        onDismissRequested: root.hideFromHoverDismiss()
        onHoverMoved: (sceneX, sceneY) => PopoutManager.updateHoverCursor(root.surfaceOriginX + sceneX, sceneY)
    }

    readonly property bool slideoutBlurActive: root.visible && BlurService.enabled && Theme.connectedSurfaceBlurEnabled

    readonly property string _slideoutScreenName: modelData?.name ?? ""

    WlrLayershell.layer: (!suppressOverlayLayer && (triggerUsesOverlayLayer || CompositorService.framePeerSurfacesUseOverlayForScreen(modelData))) ? WlrLayershell.Overlay : WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible && !ModalManager.currentModalsByScreen[_slideoutScreenName] ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property real dpr: CompositorService.getScreenScale(root.screen)
    readonly property real alignedWidth: Theme.px(expandable && expandedWidth ? expandedWidthValue : slideoutWidth, dpr)
    onAlignedWidthChanged: widthSpring.retarget(alignedWidth)
    readonly property real alignedHeight: Theme.px(modelData ? modelData.height : 800, dpr)
    readonly property real alignedEdgeGap: Theme.px(edgeGap, dpr)
    readonly property real slideoutSlideSnapX: Theme.snap(slideContainer.slideOffset, dpr)

    mask: Region {
        item: Rectangle {
            x: root.slideFromLeft ? root.alignedEdgeGap : (root.width - slideContainer.width - root.alignedEdgeGap)
            y: root.alignedEdgeGap
            width: slideContainer.width
            height: root.height - root.alignedEdgeGap * 2
        }
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: root.slideFromLeft ? undefined : parent.right
        anchors.left: root.slideFromLeft ? parent.left : undefined
        anchors.topMargin: root.alignedEdgeGap
        anchors.bottomMargin: root.alignedEdgeGap
        anchors.rightMargin: root.alignedEdgeGap
        anchors.leftMargin: root.alignedEdgeGap

        property bool slideSlowExit: false
        readonly property var slideSpringParams: Theme.springPreset("default", slideSlowExit ? Math.round(Theme.expressiveDurations.expressiveDefaultSpatial) : 450)
        readonly property var widthSpringParams: Theme.springPreset("default", Theme.popoutAnimationDuration)

        SpringMotion {
            id: slideSpring
            reducedMotion: false
            positionEpsilon: 0.05
            velocityEpsilon: 0.05
            stiffness: slideContainer.slideSpringParams.stiffness
            damping: slideContainer.slideSpringParams.damping
            value: root.slideFromLeft ? -root.alignedWidth : root.alignedWidth

            Component.onCompleted: snapTo(root.slideFromLeft ? -root.alignedWidth : root.alignedWidth)

            onRunningChanged: {
                if (running)
                    return;
                if (!root.isVisible)
                    root.mappedVisible = false;
                slideContainer.slideSlowExit = false;
            }
        }

        SpringMotion {
            id: widthSpring
            enabled: root.expandable
            reducedMotion: Theme.popoutAnimationDuration <= 0
            positionEpsilon: 0.05
            velocityEpsilon: 0.05
            stiffness: slideContainer.widthSpringParams.stiffness
            damping: slideContainer.widthSpringParams.damping
            value: root.alignedWidth

            Component.onCompleted: snapTo(root.alignedWidth)
        }

        property real slideOffset: slideSpring.value

        width: widthSpring.value
        height: root.alignedHeight - root.alignedEdgeGap * 2

        Connections {
            target: root
            function onIsVisibleChanged() {
                const target = root.isVisible ? 0 : (root.slideFromLeft ? -slideContainer.width : slideContainer.width);
                slideSpring.retarget(target);
            }
        }

        Item {
            id: contentRect
            layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            layer.smooth: false
            layer.textureSize: Qt.size(0, 0)
            opacity: 1

            readonly property color slideoutSurfaceColor: {
                if (root.customTransparency >= 0)
                    return Theme.withAlpha(Theme.surfaceContainer, root.customTransparency);
                if (Theme.isConnectedEffect)
                    return Theme.connectedSurfaceColor;
                return Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency);
            }

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: root.slideoutSlideSnapX

            Rectangle {
                anchors.fill: parent
                color: contentRect.slideoutSurfaceColor
                radius: Theme.connectedSurfaceRadius
                border.color: Theme.isConnectedEffect ? Theme.withAlpha(BlurService.borderColor, 0) : BlurService.borderColor
                border.width: Theme.isConnectedEffect ? 0 : BlurService.borderWidth
            }

            Column {
                id: headerColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM
                visible: root.title !== ""

                Row {
                    width: parent.width
                    height: 32

                    Column {
                        width: parent.width - buttonRow.width
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: root.title
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        id: buttonRow
                        spacing: Theme.spacingXS

                        DankActionButton {
                            id: expandButton
                            iconName: root.expandedWidth ? "unfold_less" : "unfold_more"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            visible: root.expandable
                            onClicked: root.expandedWidth = !root.expandedWidth

                            transform: Rotation {
                                angle: 90
                                origin.x: expandButton.width / 2
                                origin.y: expandButton.height / 2
                            }
                        }

                        DankActionButton {
                            id: closeButton
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.hide()
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                anchors.top: root.title !== "" ? headerColumn.bottom : parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: root.title !== "" ? 0 : Theme.spacingL
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.bottomMargin: Theme.spacingL

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: root.content
                }
            }
        }
    }

    WindowBlur {
        targetWindow: root
        blurX: root.slideoutBlurActive ? slideContainer.x + root.slideoutSlideSnapX : 0
        blurY: root.slideoutBlurActive ? slideContainer.y : 0
        blurWidth: root.slideoutBlurActive ? slideContainer.width : 0
        blurHeight: root.slideoutBlurActive ? slideContainer.height : 0
        blurRadius: Theme.connectedSurfaceRadius
    }
}
