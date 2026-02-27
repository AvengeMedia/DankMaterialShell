import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root

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
    property color backgroundColor: Theme.surfaceContainer
    property color borderColor: Theme.outlineMedium
    property real borderWidth: 0
    property real cornerRadius: Theme.cornerRadius
    property bool enableShadow: true
    property alias modalFocusScope: focusScope
    property bool shouldBeVisible: false
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
    readonly property bool useBackground: showBackground && SettingsData.modalDarkenBackground
    readonly property bool useSingleWindow: CompositorService.isHyprland || useBackground

    signal opened
    signal dialogClosed
    signal backgroundClicked

    property bool animationsEnabled: true

    function open() {
        closeTimer.stop();
        const focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen) {
            contentWindow.screen = focusedScreen;
            if (!useSingleWindow)
                clickCatcher.screen = focusedScreen;
        }
        ModalManager.openModal(root);
        shouldBeVisible = true;
        if (!useSingleWindow)
            clickCatcher.visible = true;
        contentWindow.visible = true;
        shouldHaveFocus = false;
        Qt.callLater(() => shouldHaveFocus = Qt.binding(() => shouldBeVisible));
    }

    function close() {
        shouldBeVisible = false;
        shouldHaveFocus = false;
        ModalManager.closeModal(root);
        closeTimer.restart();
    }

    function instantClose() {
        animationsEnabled = false;
        shouldBeVisible = false;
        shouldHaveFocus = false;
        ModalManager.closeModal(root);
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
            if (excludedModal !== root && !allowStacking && shouldBeVisible)
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
            contentWindow.visible = false;
            if (!useSingleWindow)
                clickCatcher.visible = false;
            dialogClosed();
        }
    }

    readonly property real shadowBuffer: Theme.elevationBlurMax * 1.5 + 24
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

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            if (root.useOverlayLayer)
                return WlrLayershell.Overlay;
            switch (Quickshell.env("DMS_MODAL_LAYER")) {
            case "bottom":
                console.error("DankModal: 'bottom' layer is not valid for modals. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                console.error("DankModal: 'background' layer is not valid for modals. Defaulting to 'top' layer.");
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
                DankAnim {
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

            property real animX: 0
            property real animY: 0
            property real scaleValue: root.animationScaleCollapsed

            onOffsetXChanged: animX = Theme.snap(root.shouldBeVisible ? 0 : offsetX, root.dpr)
            onOffsetYChanged: animY = Theme.snap(root.shouldBeVisible ? 0 : offsetY, root.dpr)

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    modalContainer.animX = Theme.snap(root.shouldBeVisible ? 0 : modalContainer.offsetX, root.dpr);
                    modalContainer.animY = Theme.snap(root.shouldBeVisible ? 0 : modalContainer.offsetY, root.dpr);
                    modalContainer.scaleValue = root.shouldBeVisible ? 1.0 : root.animationScaleCollapsed;
                }
            }

            Behavior on animX {
                enabled: root.animationsEnabled
                DankAnim {
                    duration: root.animationDuration
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on animY {
                enabled: root.animationsEnabled
                DankAnim {
                    duration: root.animationDuration
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on scaleValue {
                enabled: root.animationsEnabled
                DankAnim {
                    duration: root.animationDuration
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

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

                    readonly property var elev: Theme.elevationLevel3
                    readonly property real shadowBlurNorm: Math.max(0, Math.min(1, (elev && elev.blurPx !== undefined ? elev.blurPx : 12) / Theme.elevationBlurMax))

                    Item {
                        id: modalShadowLayer
                        anchors.fill: parent
                        layer.enabled: root.enableShadow && Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"

                        layer.effect: MultiEffect {
                            autoPaddingEnabled: true
                            shadowEnabled: true
                            blurEnabled: false
                            maskEnabled: false
                            shadowBlur: animatedContent.shadowBlurNorm
                            shadowScale: 1
                            shadowVerticalOffset: animatedContent.elev && animatedContent.elev.offsetY !== undefined ? animatedContent.elev.offsetY : 6
                            shadowHorizontalOffset: 0
                            blurMax: Theme.elevationBlurMax
                            shadowColor: Theme.elevationShadowColor(Theme.elevationLevel3)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root.cornerRadius
                            color: root.backgroundColor
                            border.color: root.borderColor
                            border.width: root.borderWidth
                        }
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
