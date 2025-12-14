import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

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
    property int animationDuration: Theme.expressiveDurations.expressiveDefaultSpatial
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property color backgroundColor: Theme.surfaceContainer
    property color borderColor: Theme.outlineMedium
    property real borderWidth: 1
    property real cornerRadius: Theme.cornerRadius
    property bool enableShadow: false
    property alias modalFocusScope: focusScope
    property bool shouldBeVisible: false
    property bool shouldHaveFocus: shouldBeVisible
    property bool allowFocusOverride: false
    property bool allowStacking: false
    property bool keepContentLoaded: false
    property bool keepPopoutsOpen: false
    property var customKeyboardFocus: null
    property bool useOverlayLayer: false

    readonly property alias backgroundWindow: contentWindow
    readonly property alias contentWindow: contentWindow
    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab

    signal opened
    signal dialogClosed
    signal backgroundClicked

    property bool animationsEnabled: true

    readonly property bool useBackgroundWindow: false

    function open() {
        ModalManager.openModal(root);
        closeTimer.stop();
        const focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen) {
            contentWindow.screen = focusedScreen;
        }
        shouldBeVisible = true;
        contentWindow.visible = false;
        Qt.callLater(() => {
            contentWindow.visible = true;
            shouldHaveFocus = false;
            Qt.callLater(() => {
                shouldHaveFocus = Qt.binding(() => shouldBeVisible);
            });
        });
    }

    function close() {
        shouldBeVisible = false;
        shouldHaveFocus = false;
        closeTimer.restart();
    }

    function instantClose() {
        animationsEnabled = false;
        shouldBeVisible = false;
        shouldHaveFocus = false;
        closeTimer.stop();
        contentWindow.visible = false;
        dialogClosed();
        Qt.callLater(() => animationsEnabled = true);
    }

    function toggle() {
        shouldBeVisible ? close() : open();
    }

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== root && !allowStacking && shouldBeVisible) {
                close();
            }
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
            }
        }
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 120
        onTriggered: {
            if (!shouldBeVisible) {
                contentWindow.visible = false;
                dialogClosed();
            }
        }
    }

    readonly property real shadowBuffer: 5
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
        id: contentWindow
        visible: false
        color: "transparent"

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            if (root.useOverlayLayer)
                return WlrLayershell.Overlay;
            switch (Quickshell.env("DMS_MODAL_LAYER")) {
            case "bottom":
            case "background":
                console.error("DankModal: 'bottom'/'background' layer is not valid. Defaulting to 'top'.");
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
            right: true
            bottom: true
        }

        WlrLayershell.margins {
            left: 0
            top: 0
            right: 0
            bottom: 0
        }

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
            enabled: root.closeOnBackgroundClick && root.shouldBeVisible
            z: -2
            onClicked: root.backgroundClicked()
        }

        Rectangle {
            id: background
            anchors.fill: parent
            z: -1
            color: "black"
            opacity: root.showBackground && SettingsData.modalDarkenBackground ? (root.shouldBeVisible ? root.backgroundOpacity : 0) : 0

            Behavior on opacity {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }
        }

        Item {
            id: modalContainer
            x: root.alignedX
            y: root.alignedY
            width: root.alignedWidth
            height: root.alignedHeight

            MouseArea {
                anchors.fill: parent
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
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on animY {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on scaleValue {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
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

                    DankRectangle {
                        anchors.fill: parent
                        color: root.backgroundColor
                        borderColor: root.borderColor
                        borderWidth: root.borderWidth
                        radius: root.cornerRadius
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
