pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    readonly property var log: Log.scoped("DankModalStandalone")

    property var modalHandle: root
    property string layerNamespace: "dms:modal"
    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Item directContent: null
    property real modalWidth: 400
    property real modalHeight: 300
    property var targetScreen
    readonly property var effectiveScreen: contentWindow.screen ?? targetScreen
    readonly property real screenWidth: effectiveScreen?.width ?? 1920
    readonly property real screenHeight: effectiveScreen?.height ?? 1080
    readonly property real dpr: effectiveScreen ? CompositorService.getScreenScale(effectiveScreen) : 1
    property bool showBackground: true
    property real backgroundOpacity: 0.5
    property string positioning: "center"
    property point customPosition: Qt.point(0, 0)
    property bool closeOnEscapeKey: true
    property bool closeOnBackgroundClick: true
    property string animationType: "scale"
    property int animationDuration: Theme.modalAnimationDuration
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property color backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    property color borderColor: Theme.outlineMedium
    property real borderWidth: 0
    property real cornerRadius: Theme.cornerRadius
    property bool enableShadow: true
    property alias modalFocusScope: focusScope
    property bool shouldBeVisible: false
    property bool isClosing: false
    property bool shouldHaveFocus: shouldBeVisible
    property bool allowFocusOverride: false
    property bool allowStacking: false
    property bool keepContentLoaded: false
    property bool keepPopoutsOpen: false
    property var customKeyboardFocus: null
    property bool useOverlayLayer: false
    readonly property alias contentWindow: contentWindow
    readonly property alias clickCatcher: clickCatcher
    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab
    readonly property bool useBackground: showBackground && !SettingsData.frameEnabled && SettingsData.modalDarkenBackground
    readonly property bool useSingleWindow: CompositorService.isHyprland || useBackground

    signal opened
    signal dialogClosed
    signal backgroundClicked

    property bool animationsEnabled: true

    function open() {
        closeTimer.stop();
        isClosing = false;
        const focusedScreen = CompositorService.getFocusedScreen();
        const screenChanged = focusedScreen && contentWindow.screen !== focusedScreen;
        if (focusedScreen) {
            if (screenChanged)
                contentWindow.visible = false;
            contentWindow.screen = focusedScreen;
            if (!useSingleWindow) {
                if (screenChanged)
                    clickCatcher.visible = false;
                clickCatcher.screen = focusedScreen;
            }
        }
        if (screenChanged) {
            Qt.callLater(() => root._finishOpen());
        } else {
            _finishOpen();
        }
    }

    function _finishOpen() {
        ModalManager.openModal(modalHandle);
        shouldBeVisible = true;
        if (!useSingleWindow)
            clickCatcher.visible = true;
        contentWindow.visible = true;
        shouldHaveFocus = false;
        Qt.callLater(() => shouldHaveFocus = Qt.binding(() => shouldBeVisible));
    }

    function close() {
        isClosing = true;
        shouldBeVisible = false;
        shouldHaveFocus = false;
        ModalManager.closeModal(modalHandle);
        closeTimer.restart();
    }

    function instantClose() {
        animationsEnabled = false;
        isClosing = false;
        shouldBeVisible = false;
        shouldHaveFocus = false;
        ModalManager.closeModal(modalHandle);
        closeTimer.stop();
        contentWindow.visible = false;
        if (!useSingleWindow)
            clickCatcher.visible = false;
        dialogClosed();
        Qt.callLater(() => animationsEnabled = true);
    }

    function toggle() {
        shouldBeVisible ? close() : open();
    }

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== modalHandle && !allowStacking && shouldBeVisible)
                close();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!contentWindow.screen)
                return;
            const currentScreenName = contentWindow.screen.name;
            let screenStillExists = false;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === currentScreenName) {
                    screenStillExists = true;
                    break;
                }
            }
            if (screenStillExists)
                return;
            const newScreen = CompositorService.getFocusedScreen();
            if (newScreen) {
                contentWindow.screen = newScreen;
                if (!useSingleWindow)
                    clickCatcher.screen = newScreen;
            }
        }
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (shouldBeVisible)
                return;
            isClosing = false;
            contentWindow.visible = false;
            if (!useSingleWindow)
                clickCatcher.visible = false;
            dialogClosed();
        }
    }

    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (root.enableShadow && Theme.elevationEnabled && SettingsData.modalElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, Theme.elevationLightDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowMotionPadding: animationType === "slide" ? 30 : Math.max(0, animationOffset)
    readonly property real shadowBuffer: Theme.snap(shadowRenderPadding + shadowMotionPadding, dpr)
    readonly property real alignedWidth: Theme.px(modalWidth, dpr)
    readonly property real alignedHeight: Theme.px(modalHeight, dpr)

    readonly property real alignedX: Theme.snap((() => {
            switch (positioning) {
            case "center":
                return (screenWidth - alignedWidth) / 2;
            case "top-right":
                return Math.max(Theme.spacingL, screenWidth - alignedWidth - Theme.spacingL);
            case "custom":
                return customPosition.x;
            default:
                return 0;
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
            switch (positioning) {
            case "center":
                return (screenHeight - alignedHeight) / 2;
            case "top-right":
                return Theme.barHeight + Theme.spacingXS;
            case "custom":
                return customPosition.y;
            default:
                return 0;
            }
        })(), dpr)

    PanelWindow {
        id: clickCatcher
        visible: false
        color: "transparent"

        WlrLayershell.namespace: root.layerNamespace + ":clickcatcher"
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        mask: Region {
            item: Rectangle {
                x: root.alignedX
                y: root.alignedY
                width: root.alignedWidth
                height: root.alignedHeight
            }
            intersection: Intersection.Xor
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.closeOnBackgroundClick && root.shouldBeVisible
            onClicked: root.backgroundClicked()
        }
    }

    PanelWindow {
        id: contentWindow
        visible: false
        color: "transparent"

        WindowBlur {
            targetWindow: contentWindow
            readonly property real s: Math.min(1, modalContainer.scaleValue)
            readonly property real op: Math.max(0, Math.min(1, (morph.openProgress - 0.06) * 2))
            blurX: modalContainer.x + modalContainer.width * (1 - s * op) * 0.5 + Theme.snap(modalContainer.animX, root.dpr)
            blurY: modalContainer.y + modalContainer.height * (1 - s * op) * 0.5 + Theme.snap(modalContainer.animY, root.dpr)
            blurWidth: root.shouldBeVisible ? modalContainer.width * s * op : 0
            blurHeight: root.shouldBeVisible ? modalContainer.height * s * op : 0
            blurRadius: root.cornerRadius
        }

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            if (root.useOverlayLayer)
                return WlrLayershell.Overlay;
            switch (Quickshell.env("DMS_MODAL_LAYER")) {
            case "bottom":
                log.error("'bottom' layer is not valid for modals. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                log.error("'background' layer is not valid for modals. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "overlay":
                return WlrLayershell.Overlay;
            default:
                return WlrLayershell.Top;
            }
        }
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: {
            if (customKeyboardFocus !== null)
                return customKeyboardFocus;
            if (!shouldHaveFocus)
                return WlrKeyboardFocus.None;
            if (root.useHyprlandFocusGrab)
                return WlrKeyboardFocus.OnDemand;
            return WlrKeyboardFocus.Exclusive;
        }

        anchors {
            left: true
            top: true
            right: root.useSingleWindow
            bottom: root.useSingleWindow
        }

        WlrLayershell.margins {
            left: root.useSingleWindow ? 0 : Math.max(0, Theme.snap(root.alignedX - shadowBuffer, dpr))
            top: root.useSingleWindow ? 0 : Math.max(0, Theme.snap(root.alignedY - shadowBuffer, dpr))
            right: 0
            bottom: 0
        }

        implicitWidth: root.useSingleWindow ? 0 : root.alignedWidth + (shadowBuffer * 2)
        implicitHeight: root.useSingleWindow ? 0 : root.alignedHeight + (shadowBuffer * 2)

        onVisibleChanged: {
            if (visible) {
                opened();
            } else {
                if (Qt.inputMethod) {
                    Qt.inputMethod.hide();
                    Qt.inputMethod.reset();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.useSingleWindow && root.closeOnBackgroundClick && root.shouldBeVisible
            z: -2
            onClicked: root.backgroundClicked()
        }

        Rectangle {
            anchors.fill: parent
            z: -1
            color: "black"
            opacity: root.useBackground ? (root.shouldBeVisible ? root.backgroundOpacity : 0) : 0
            visible: root.useBackground

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: root.animationDuration
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }
        }

        Item {
            id: modalContainer
            x: root.useSingleWindow ? root.alignedX : shadowBuffer
            y: root.useSingleWindow ? root.alignedY : shadowBuffer

            width: root.alignedWidth
            height: root.alignedHeight

            MouseArea {
                anchors.fill: parent
                enabled: root.useSingleWindow && root.shouldBeVisible
                hoverEnabled: false
                acceptedButtons: Qt.AllButtons
                onPressed: mouse.accepted = true
                onClicked: mouse.accepted = true
                z: -1
            }

            readonly property bool slide: root.animationType === "slide"
            readonly property real offsetX: slide ? 15 : 0
            readonly property real offsetY: slide ? -30 : root.animationOffset

            // openProgress: 0 = closed (at offset, scaleCollapsed), 1 = open (at 0, scale 1).
            QtObject {
                id: morph
                property real openProgress: root.shouldBeVisible ? 1 : 0
                Behavior on openProgress {
                    enabled: root.animationsEnabled
                    DankAnim {
                        duration: root.animationDuration
                        easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                    }
                }
            }

            readonly property real animX: modalContainer.offsetX * (1 - morph.openProgress)
            readonly property real animY: modalContainer.offsetY * (1 - morph.openProgress)
            readonly property real scaleValue: root.animationScaleCollapsed + (1.0 - root.animationScaleCollapsed) * morph.openProgress

            Item {
                id: contentContainer
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                clip: false

                Item {
                    id: animatedContent
                    anchors.fill: parent
                    clip: false

                    opacity: root.shouldBeVisible ? 1 : 0
                    scale: modalContainer.scaleValue
                    x: Theme.snap(modalContainer.animX, root.dpr) + (parent.width - width) * (1 - modalContainer.scaleValue) * 0.5
                    y: Theme.snap(modalContainer.animY, root.dpr) + (parent.height - height) * (1 - modalContainer.scaleValue) * 0.5

                    Behavior on opacity {
                        enabled: root.animationsEnabled
                        NumberAnimation {
                            duration: animationDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                        }
                    }

                    ElevationShadow {
                        id: modalShadowLayer
                        anchors.fill: parent
                        level: root.shadowLevel
                        fallbackOffset: root.shadowFallbackOffset
                        targetRadius: root.cornerRadius
                        targetColor: root.backgroundColor
                        borderColor: root.borderColor
                        borderWidth: root.borderWidth
                        shadowEnabled: root.enableShadow && Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: "transparent"
                        border.color: BlurService.borderColor
                        border.width: BlurService.borderWidth
                        z: 100
                    }

                    FocusScope {
                        anchors.fill: parent
                        focus: root.shouldBeVisible
                        clip: false

                        Item {
                            id: directContentWrapper
                            anchors.fill: parent
                            visible: root.directContent !== null
                            focus: true
                            clip: false

                            Component.onCompleted: {
                                if (root.directContent) {
                                    root.directContent.parent = directContentWrapper;
                                    root.directContent.anchors.fill = directContentWrapper;
                                    Qt.callLater(() => root.directContent.forceActiveFocus());
                                }
                            }

                            Connections {
                                target: root
                                function onDirectContentChanged() {
                                    if (root.directContent) {
                                        root.directContent.parent = directContentWrapper;
                                        root.directContent.anchors.fill = directContentWrapper;
                                        Qt.callLater(() => root.directContent.forceActiveFocus());
                                    }
                                }
                            }
                        }

                        Loader {
                            id: contentLoader
                            anchors.fill: parent
                            active: root.directContent === null && (root.keepContentLoaded || root.shouldBeVisible || contentWindow.visible)
                            asynchronous: false
                            focus: true
                            clip: false
                            visible: root.directContent === null

                            onLoaded: {
                                if (item) {
                                    Qt.callLater(() => item.forceActiveFocus());
                                }
                            }
                        }
                    }
                }
            }
        }

        FocusScope {
            id: focusScope
            objectName: "modalFocusScope"
            anchors.fill: parent
            visible: root.shouldBeVisible || contentWindow.visible
            focus: root.shouldBeVisible
            Keys.onEscapePressed: event => {
                if (root.closeOnEscapeKey && shouldHaveFocus) {
                    root.close();
                    event.accepted = true;
                }
            }
        }
    }
}
