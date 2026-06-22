import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    readonly property var log: Log.scoped("DankLauncherV2ModalSpotlight")

    property var modalHandle: root
    property bool triggerUsesOverlayLayer: false

    visible: false

    property bool spotlightOpen: false
    property bool keyboardActive: false
    property bool contentVisible: false
    property var spotlightContent: contentLoader.item
    property bool openedFromOverview: false
    property bool isClosing: false
    property bool _pendingInitialize: false
    property string _pendingQuery: ""
    property string _pendingMode: ""

    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab
    readonly property var effectiveScreen: launcherWindow.screen
    readonly property real screenWidth: effectiveScreen?.width ?? 1920
    readonly property real screenHeight: effectiveScreen?.height ?? 1080
    readonly property real dpr: effectiveScreen ? CompositorService.getScreenScale(effectiveScreen) : 1
    readonly property bool useBackgroundDarken: !SettingsData.frameEnabled && SettingsData.modalDarkenBackground
    readonly property bool usesOverlayLayer: useBackgroundDarken || SettingsData.launcherUseOverlayLayer || triggerUsesOverlayLayer
    readonly property var effectiveLauncherLayer: LayerShell.fromEnv("DMS_MODAL_LAYER", root.usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top, {
        "allow": ["top", "overlay"],
        "invalidLayer": WlrLayer.Top,
        "label": "modals",
        "error": true
    })

    readonly property int _openDuration: 50
    readonly property int _closeDuration: 40
    readonly property int _motionDuration: 60

    // Connected frame mode clamps the centered surface inside frame insets.
    readonly property bool frameConnected: CompositorService.usesConnectedFrameChromeForScreen(effectiveScreen)

    function _frameEdgeInset(side) {
        if (!effectiveScreen || !frameConnected)
            return 0;
        return SettingsData.frameEdgeInsetForSide(effectiveScreen, side);
    }

    // Fixed 680px width, centered horizontally (respecting frame insets)
    readonly property int modalWidth: Math.min(680, screenWidth - 80)
    readonly property real modalX: {
        const insetL = _frameEdgeInset("left");
        const insetR = _frameEdgeInset("right");
        const usable = Math.max(0, screenWidth - insetL - insetR);
        return insetL + Math.max(0, (usable - modalWidth) / 2);
    }
    // Keep the search bar centered; results expand downward unless the screen edge clamps it.
    readonly property real modalY: {
        const insetT = _frameEdgeInset("top");
        const insetB = _frameEdgeInset("bottom");
        const searchBarH = 56;
        const usableH = Math.max(searchBarH, screenHeight - insetT - insetB);
        const preferred = insetT + Math.max(0, usableH * 0.33 - searchBarH / 2);
        const maxY = Math.max(insetT, screenHeight - insetB - 56);
        return Math.max(insetT, Math.min(preferred, maxY));
    }

    // Dynamic height from content
    readonly property real _contentImplicitH: contentLoader.item?.implicitHeight ?? 56
    readonly property int modalHeight: _contentImplicitH

    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (Theme.elevationEnabled && SettingsData.modalElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, Theme.elevationLightDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowPad: Theme.snap(shadowRenderPadding, dpr)

    readonly property real alignedWidth: Theme.px(modalWidth, dpr)
    readonly property real alignedX: Theme.snap(modalX, dpr)
    readonly property real alignedY: Theme.snap(modalY, dpr)

    // Extra headroom above the content for the slide-in animation
    readonly property real _animHeadroom: 16
    readonly property real windowX: Math.max(0, Theme.snap(alignedX - shadowPad, dpr))
    readonly property real windowY: Math.max(0, Theme.snap(alignedY - shadowPad - _animHeadroom, dpr))
    readonly property real contentX: Theme.snap(alignedX - windowX, dpr)
    readonly property real contentY: Theme.snap(alignedY - windowY, dpr)
    readonly property real _animatedContentH: Theme.snap(_contentImplicitH, dpr)
    readonly property real windowWidth: alignedWidth + contentX + shadowPad
    readonly property real windowHeight: _animatedContentH + contentY + shadowPad + _animHeadroom

    readonly property color backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    readonly property real cornerRadius: Theme.cornerRadius

    readonly property color borderColor: {
        if (!SettingsData.dankLauncherV2BorderEnabled)
            return Theme.outlineMedium;
        switch (SettingsData.dankLauncherV2BorderColor) {
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "outline":
            return Theme.outline;
        case "surfaceText":
            return Theme.surfaceText;
        default:
            return Theme.primary;
        }
    }
    readonly property int borderWidth: SettingsData.dankLauncherV2BorderEnabled ? SettingsData.dankLauncherV2BorderThickness : 0
    readonly property bool useSingleWindow: CompositorService.isHyprland || useBackgroundDarken

    signal dialogClosed

    function _ensureContentLoadedAndInitialize(query, mode) {
        _pendingQuery = query || "";
        _pendingMode = mode || "";
        _pendingInitialize = true;
        contentVisible = true;
        contentLoader.active = true;

        if (spotlightContent) {
            _initializeContent(_pendingQuery, _pendingMode);
            _pendingInitialize = false;
        }
    }

    function _initializeContent(query, mode) {
        if (!spotlightContent)
            return;
        contentVisible = true;
        spotlightContent.closeTransientUi?.();

        const targetQuery = query || (SettingsData.rememberLastQuery ? (SessionData.launcherLastQuery || "") : "");
        const targetMode = mode || SessionData.getLauncherRestoreMode();

        if (spotlightContent.searchField) {
            spotlightContent.searchField.text = targetQuery;
        }
        if (spotlightContent.controller) {
            spotlightContent.controller.reset();
            spotlightContent.controller.searchMode = targetMode;
            spotlightContent.controller.historyIndex = -1;
            if (targetQuery.length > 0)
                spotlightContent.controller.setSearchQuery(targetQuery);
        }
        if (spotlightContent.resetScroll) {
            spotlightContent.resetScroll();
        }
        if (spotlightContent.searchField) {
            spotlightContent.searchField.forceActiveFocus();
            spotlightContent.searchField.cursorPosition = spotlightContent.searchField.text.length;
        }
    }

    function _finishShow(query, mode) {
        spotlightOpen = true;
        isClosing = false;
        openedFromOverview = false;
        keyboardActive = true;
        ModalManager.openModal(modalHandle);
        _ensureContentLoadedAndInitialize(query || "", mode || "");
    }

    function _openCommon(query, mode) {
        closeCleanupTimer.stop();
        const focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen && launcherWindow.screen !== focusedScreen) {
            spotlightOpen = false;
            isClosing = false;
            launcherWindow.screen = focusedScreen;
            Qt.callLater(() => root._finishShow(query, mode));
            return;
        }
        _finishShow(query, mode);
    }

    function show() {
        _openCommon("", "");
    }
    function showWithQuery(query) {
        _openCommon(query, "");
    }
    function showWithMode(mode) {
        _openCommon("", mode);
    }

    function hide() {
        if (!spotlightOpen)
            return;
        spotlightContent?.closeTransientUi?.();
        openedFromOverview = false;
        isClosing = true;
        contentVisible = false;
        keyboardActive = false;
        spotlightOpen = false;
        ModalManager.closeModal(modalHandle);
        closeCleanupTimer.start();
    }

    function toggle() {
        spotlightOpen ? hide() : show();
    }

    function toggleWithMode(mode) {
        spotlightOpen ? hide() : showWithMode(mode);
    }

    function toggleWithQuery(query) {
        spotlightOpen ? hide() : showWithQuery(query);
    }

    Timer {
        id: closeCleanupTimer
        interval: root._motionDuration + 30
        repeat: false
        onTriggered: {
            isClosing = false;
            dialogClosed();
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [launcherWindow]
        active: root.useHyprlandFocusGrab && root.keyboardActive
        onCleared: {
            if (spotlightOpen)
                hide();
        }
    }

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== modalHandle && spotlightOpen)
                hide();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Quickshell.screens.length === 0)
                return;
            const screenName = launcherWindow.screen?.name;
            if (screenName) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === screenName)
                        return;
                }
            }
            if (spotlightOpen)
                hide();
            const newScreen = CompositorService.getFocusedScreen() ?? Quickshell.screens[0];
            if (newScreen)
                launcherWindow.screen = newScreen;
        }
    }

    // Background click catcher
    PanelWindow {
        id: clickCatcher
        screen: launcherWindow.screen
        visible: (spotlightOpen || isClosing) && !root.useSingleWindow
        color: "transparent"
        updatesEnabled: false

        WlrLayershell.namespace: "dms:spotlight:clickcatcher"
        WlrLayershell.layer: root.effectiveLauncherLayer
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: bgMask

            Region {
                item: bgHole
                intersection: Intersection.Subtract
            }
        }

        Item {
            id: bgMask
            visible: false
            anchors.fill: parent
        }

        Rectangle {
            id: bgHole
            visible: false
            color: "transparent"
            x: root.windowX
            y: root.windowY
            width: root.windowWidth
            height: root.windowHeight
        }

        MouseArea {
            anchors.fill: parent
            enabled: spotlightOpen
            onClicked: root.hide()
        }
    }

    // Launcher window
    PanelWindow {
        id: launcherWindow
        visible: spotlightOpen || isClosing
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WindowBlur {
            targetWindow: launcherWindow
            readonly property real op: Math.max(0, Math.min(1, (modalContainer.opacity - 0.06) * 2))
            blurX: modalContainer.x
            blurY: modalContainer.y + modalContainer.slideOffset
            blurWidth: contentVisible ? root.alignedWidth * op : 0
            blurHeight: contentVisible ? root._contentImplicitH * op : 0
            blurRadius: root.cornerRadius
        }

        WlrLayershell.namespace: "dms:spotlight"
        WlrLayershell.layer: root.effectiveLauncherLayer
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: KeyboardFocus.keyboardFocus(keyboardActive, null)

        anchors {
            top: true
            left: true
            right: root.useSingleWindow
            bottom: root.useSingleWindow
        }

        WlrLayershell.margins {
            left: root.useSingleWindow ? 0 : root.windowX
            top: root.useSingleWindow ? 0 : root.windowY
            right: 0
            bottom: 0
        }

        implicitWidth: root.useSingleWindow ? 0 : root.windowWidth
        implicitHeight: root.useSingleWindow ? 0 : root.windowHeight

        mask: Region {
            item: inputMask
        }

        Rectangle {
            id: inputMask
            visible: false
            color: "transparent"
            x: root.useSingleWindow ? 0 : modalContainer.x
            y: root.useSingleWindow ? 0 : modalContainer.y + modalContainer.slideOffset
            width: root.useSingleWindow ? launcherWindow.width : root.alignedWidth
            height: root.useSingleWindow ? launcherWindow.height : root._contentImplicitH
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.useSingleWindow && spotlightOpen
            z: -2
            onClicked: root.hide()
        }

        Rectangle {
            id: backgroundDarken
            anchors.fill: parent
            color: "black"
            opacity: contentVisible && root.useBackgroundDarken ? 0.5 : 0
            visible: (spotlightOpen || isClosing) && (root.useBackgroundDarken || opacity > 0)
            z: -3

            Behavior on opacity {
                NumberAnimation {
                    duration: contentVisible ? root._openDuration : root._closeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: contentVisible ? [0.0, 0.0, 0.2, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                }
            }
        }

        Item {
            id: modalContainer
            x: root.useSingleWindow ? root.alignedX : root.contentX
            y: root.useSingleWindow ? root.alignedY : root.contentY
            width: root.alignedWidth
            height: root._animatedContentH
            visible: _renderActive
            z: 0

            MouseArea {
                anchors.fill: parent
                enabled: spotlightOpen
                hoverEnabled: false
                acceptedButtons: Qt.AllButtons
                onPressed: mouse.accepted = true
                onClicked: mouse.accepted = true
                z: -1
            }

            property bool _renderActive: contentVisible
            property real slideOffset: contentVisible ? 0 : -root._animHeadroom

            opacity: contentVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: contentVisible ? root._openDuration : root._closeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: contentVisible ? [0.0, 0.0, 0.2, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                    onRunningChanged: {
                        if (!running && !root.contentVisible)
                            modalContainer._renderActive = false;
                    }
                }
            }

            Behavior on slideOffset {
                NumberAnimation {
                    duration: root._motionDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: contentVisible ? [0.2, 0.0, 0.0, 1.0, 1.0, 1.0] : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                }
            }

            Connections {
                target: root
                function onContentVisibleChanged() {
                    if (root.contentVisible)
                        modalContainer._renderActive = true;
                }
            }

            ElevationShadow {
                anchors.fill: contentWrapper
                level: root.shadowLevel
                fallbackOffset: root.shadowFallbackOffset
                targetColor: root.backgroundColor
                borderColor: root.borderColor
                borderWidth: root.borderWidth
                targetRadius: root.cornerRadius
                shadowEnabled: Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            }

            Item {
                id: contentWrapper
                x: 0
                y: modalContainer.slideOffset
                width: parent.width
                height: root._animatedContentH

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => mouse.accepted = true
                }

                FocusScope {
                    anchors.fill: parent
                    focus: keyboardActive

                    Loader {
                        id: contentLoader
                        anchors.fill: parent
                        active: root.spotlightOpen || root.isClosing || root.contentVisible || root._pendingInitialize
                        asynchronous: false
                        sourceComponent: SpotlightLauncherContent {
                            focus: true
                            parentModal: root
                        }

                        onLoaded: {
                            if (root._pendingInitialize) {
                                root._initializeContent(root._pendingQuery, root._pendingMode);
                                root._pendingInitialize = false;
                            }
                        }
                    }

                    Keys.onPressed: event => root.spotlightContent?.activeContextMenu?.handleKey(event)

                    Keys.onEscapePressed: event => {
                        root.spotlightContent?.activeContextMenu?.handleKey(event);
                        if (!event.accepted)
                            root.hide();
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
