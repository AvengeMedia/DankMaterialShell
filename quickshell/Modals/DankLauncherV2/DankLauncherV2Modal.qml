import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    visible: false

    property bool spotlightOpen: false
    property bool keyboardActive: false
    property bool contentVisible: false
    property var spotlightContent: launcherContentLoader.item
    property bool openedFromOverview: false
    property bool isClosing: false
    property bool _pendingInitialize: false
    property string _pendingQuery: ""
    property string _pendingMode: ""
    readonly property bool unloadContentOnClose: SettingsData.dankLauncherV2UnloadOnClose

    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab
    readonly property var effectiveScreen: launcherWindow.screen
    readonly property real screenWidth: effectiveScreen?.width ?? 1920
    readonly property real screenHeight: effectiveScreen?.height ?? 1080
    readonly property real dpr: effectiveScreen ? CompositorService.getScreenScale(effectiveScreen) : 1

    readonly property int baseWidth: {
        switch (SettingsData.dankLauncherV2Size) {
        case "micro":
            return 500;
        case "medium":
            return 720;
        case "large":
            return 860;
        default:
            return 620;
        }
    }
    readonly property int baseHeight: {
        switch (SettingsData.dankLauncherV2Size) {
        case "micro":
            return 480;
        case "medium":
            return 720;
        case "large":
            return 860;
        default:
            return 600;
        }
    }
    readonly property int modalWidth: Math.min(baseWidth, screenWidth - 100)
    readonly property int modalHeight: Math.min(baseHeight, screenHeight - 100)
    readonly property real modalX: (screenWidth - modalWidth) / 2
    readonly property real modalY: (screenHeight - modalHeight) / 2

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

    signal dialogClosed

    function _ensureContentLoadedAndInitialize(query, mode) {
        _pendingQuery = query || "";
        _pendingMode = mode || "";
        _pendingInitialize = true;
        contentVisible = true;
        launcherContentLoader.active = true;

        if (spotlightContent) {
            _initializeAndShow(_pendingQuery, _pendingMode);
            _pendingInitialize = false;
        }
    }

    function _initializeAndShow(query, mode) {
        if (!spotlightContent)
            return;
        contentVisible = true;
        spotlightContent.searchField.forceActiveFocus();

        var targetQuery = "";

        if (query) {
            targetQuery = query;
        } else if (SettingsData.rememberLastQuery) {
            targetQuery = SessionData.launcherLastQuery || "";
        }

        if (spotlightContent.searchField) {
            spotlightContent.searchField.text = targetQuery;
        }
        if (spotlightContent.controller) {
            var targetMode = mode || SessionData.launcherLastMode || "all";
            spotlightContent.controller.searchMode = targetMode;
            spotlightContent.controller.activePluginId = "";
            spotlightContent.controller.activePluginName = "";
            spotlightContent.controller.pluginFilter = "";
            spotlightContent.controller.fileSearchType = "all";
            spotlightContent.controller.fileSearchExt = "";
            spotlightContent.controller.fileSearchFolder = "";
            spotlightContent.controller.fileSearchSort = "score";
            spotlightContent.controller.collapsedSections = {};
            spotlightContent.controller.selectedFlatIndex = 0;
            spotlightContent.controller.selectedItem = null;
            spotlightContent.controller.historyIndex = -1;
            spotlightContent.controller.searchQuery = targetQuery;

            spotlightContent.controller.performSearch();
        }
        if (spotlightContent.resetScroll) {
            spotlightContent.resetScroll();
        }
        if (spotlightContent.actionPanel) {
            spotlightContent.actionPanel.hide();
        }
    }

    function _finishShow(query, mode) {
        spotlightOpen = true;
        isClosing = false;
        openedFromOverview = false;

        keyboardActive = true;
        ModalManager.openModal(root);
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

        _ensureContentLoadedAndInitialize(query || "", mode || "");
    }

    function show() {
        closeCleanupTimer.stop();

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen && launcherWindow.screen !== focusedScreen) {
            spotlightOpen = false;
            isClosing = false;
            launcherWindow.screen = focusedScreen;
            Qt.callLater(() => root._finishShow("", ""));
            return;
        }

        _finishShow("", "");
    }

    function showWithQuery(query) {
        closeCleanupTimer.stop();

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen && launcherWindow.screen !== focusedScreen) {
            spotlightOpen = false;
            isClosing = false;
            launcherWindow.screen = focusedScreen;
            Qt.callLater(() => root._finishShow(query, ""));
            return;
        }

        _finishShow(query, "");
    }

    function hide() {
        if (!spotlightOpen)
            return;
        openedFromOverview = false;
        isClosing = true;
        contentVisible = false;

        keyboardActive = false;
        spotlightOpen = false;
        focusGrab.active = false;
        ModalManager.closeModal(root);

        closeCleanupTimer.start();
    }

    function toggle() {
        spotlightOpen ? hide() : show();
    }

    function showWithMode(mode) {
        closeCleanupTimer.stop();

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen && launcherWindow.screen !== focusedScreen) {
            spotlightOpen = false;
            isClosing = false;
            launcherWindow.screen = focusedScreen;
            Qt.callLater(() => root._finishShow("", mode));
            return;
        }

        spotlightOpen = true;
        isClosing = false;
        openedFromOverview = false;

        keyboardActive = true;
        ModalManager.openModal(root);
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

        _ensureContentLoadedAndInitialize("", mode);
    }

    function toggleWithMode(mode) {
        if (spotlightOpen) {
            hide();
        } else {
            showWithMode(mode);
        }
    }

    function toggleWithQuery(query) {
        if (spotlightOpen) {
            hide();
        } else {
            showWithQuery(query);
        }
    }

    Timer {
        id: closeCleanupTimer
        interval: Theme.modalAnimationDuration + 50
        repeat: false
        onTriggered: {
            isClosing = false;
            if (root.unloadContentOnClose)
                launcherContentLoader.active = false;
            dialogClosed();
        }
    }

    Connections {
        target: spotlightContent?.controller ?? null

        function onModeChanged(mode) {
            if (spotlightContent.controller.autoSwitchedToFiles)
                return;
            SessionData.setLauncherLastMode(mode);
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [launcherWindow]
        active: false

        onCleared: {
            if (spotlightOpen) {
                hide();
            }
        }
    }

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== root && spotlightOpen) {
                hide();
            }
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

    PanelWindow {
        id: launcherWindow
        visible: spotlightOpen || isClosing
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WindowBlur {
            targetWindow: launcherWindow
            readonly property real s: Math.min(1, modalContainer.scale)
            blurX: root.modalX + root.modalWidth * (1 - s) * 0.5
            blurY: root.modalY + root.modalHeight * (1 - s) * 0.5
            blurWidth: (contentVisible && modalContainer.opacity > 0) ? root.modalWidth * s : 0
            blurHeight: (contentVisible && modalContainer.opacity > 0) ? root.modalHeight * s : 0
            blurRadius: root.cornerRadius
        }

        WlrLayershell.namespace: "dms:spotlight"
        WlrLayershell.layer: {
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
        WlrLayershell.keyboardFocus: keyboardActive ? (root.useHyprlandFocusGrab ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: spotlightOpen ? fullScreenMask : null
        }

        Item {
            id: fullScreenMask
            anchors.fill: parent
        }

        Rectangle {
            id: backgroundDarken
            anchors.fill: parent
            color: "black"
            opacity: contentVisible && SettingsData.modalDarkenBackground ? 0.5 : 0
            visible: contentVisible || opacity > 0

            Behavior on opacity {
                DankAnim {
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: spotlightOpen
            onClicked: mouse => {
                var contentX = modalContainer.x;
                var contentY = modalContainer.y;
                var contentW = modalContainer.width;
                var contentH = modalContainer.height;

                if (mouse.x < contentX || mouse.x > contentX + contentW || mouse.y < contentY || mouse.y > contentY + contentH) {
                    root.hide();
                }
            }
        }

        Item {
            id: modalContainer
            x: root.modalX
            y: root.modalY
            width: root.modalWidth
            height: root.modalHeight
            visible: contentVisible || opacity > 0

            opacity: contentVisible ? 1 : 0
            scale: contentVisible ? 1 : 0.96
            transformOrigin: Item.Center

            Behavior on opacity {
                DankAnim {
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                }
            }

            Behavior on scale {
                DankAnim {
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                }
            }

            ElevationShadow {
                id: launcherShadowLayer
                anchors.fill: parent
                level: Theme.elevationLevel3
                fallbackOffset: 6
                targetColor: root.backgroundColor
                borderColor: root.borderColor
                borderWidth: root.borderWidth
                targetRadius: root.cornerRadius
                shadowEnabled: Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !BlurService.enabled
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            FocusScope {
                anchors.fill: parent
                focus: keyboardActive

                Loader {
                    id: launcherContentLoader
                    anchors.fill: parent
                    active: !root.unloadContentOnClose || root.spotlightOpen || root.isClosing || root.contentVisible || root._pendingInitialize
                    asynchronous: false
                    sourceComponent: LauncherContent {
                        focus: true
                        parentModal: root
                    }

                    onLoaded: {
                        if (root._pendingInitialize) {
                            root._initializeAndShow(root._pendingQuery, root._pendingMode);
                            root._pendingInitialize = false;
                        }
                    }
                }

                Keys.onEscapePressed: event => {
                    root.hide();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: "transparent"
                border.color: BlurService.borderColor
                border.width: BlurService.borderWidth
            }
        }
    }
}
