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
    property alias spotlightContent: launcherContent
    property bool openedFromOverview: false
    property bool isClosing: false
    property bool _windowEnabled: true

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
    readonly property int borderWidth: SettingsData.dankLauncherV2BorderEnabled ? SettingsData.dankLauncherV2BorderThickness : 1

    signal dialogClosed

    function _initializeAndShow(query, mode) {
        contentVisible = true;
        spotlightContent.searchField.forceActiveFocus();

        if (spotlightContent.searchField) {
            spotlightContent.searchField.text = query;
        }
        if (spotlightContent.controller) {
            var targetMode = mode || "all";
            spotlightContent.controller.searchMode = targetMode;
            spotlightContent.controller.activePluginId = "";
            spotlightContent.controller.activePluginName = "";
            spotlightContent.controller.pluginFilter = "";
            spotlightContent.controller.collapsedSections = {};
            if (query) {
                spotlightContent.controller.setSearchQuery(query);
            } else {
                spotlightContent.controller.searchQuery = "";
                spotlightContent.controller.performSearch();
            }
        }
        if (spotlightContent.resetScroll) {
            spotlightContent.resetScroll();
        }
        if (spotlightContent.actionPanel) {
            spotlightContent.actionPanel.hide();
        }
    }

    function show() {
        closeCleanupTimer.stop();
        isClosing = false;
        openedFromOverview = false;

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen)
            launcherWindow.screen = focusedScreen;

        spotlightOpen = true;
        keyboardActive = true;
        ModalManager.openModal(root);
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

        _initializeAndShow("");
    }

    function showWithQuery(query) {
        closeCleanupTimer.stop();
        isClosing = false;
        openedFromOverview = false;

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen)
            launcherWindow.screen = focusedScreen;

        spotlightOpen = true;
        keyboardActive = true;
        ModalManager.openModal(root);
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

        _initializeAndShow(query);
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
        isClosing = false;
        openedFromOverview = false;

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen)
            launcherWindow.screen = focusedScreen;

        spotlightOpen = true;
        keyboardActive = true;
        ModalManager.openModal(root);
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

        _initializeAndShow("", mode);
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
        interval: Theme.expressiveDurations.expressiveFastSpatial + 50
        repeat: false
        onTriggered: {
            isClosing = false;
            dialogClosed();
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

            const screen = launcherWindow.screen;
            const screenName = screen?.name;

            let needsReset = !screen || !screenName;
            if (!needsReset) {
                needsReset = true;
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === screenName) {
                        needsReset = false;
                        break;
                    }
                }
            }

            if (!needsReset)
                return;

            const newScreen = CompositorService.getFocusedScreen() ?? Quickshell.screens[0];
            if (!newScreen)
                return;

            root._windowEnabled = false;
            launcherWindow.screen = newScreen;
            Qt.callLater(() => {
                root._windowEnabled = true;
            });
        }
    }

    PanelWindow {
        id: launcherWindow
        visible: root._windowEnabled
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

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
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveFastSpatial : Theme.expressiveCurves.emphasized
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
                NumberAnimation {
                    duration: Theme.expressiveDurations.fast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveFastSpatial : Theme.expressiveCurves.standardAccel
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.expressiveDurations.fast
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveFastSpatial : Theme.expressiveCurves.standardAccel
                }
            }

            DankRectangle {
                anchors.fill: parent
                color: root.backgroundColor
                borderColor: root.borderColor
                borderWidth: root.borderWidth
                radius: root.cornerRadius
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            FocusScope {
                anchors.fill: parent
                focus: keyboardActive

                LauncherContent {
                    id: launcherContent
                    anchors.fill: parent
                    parentModal: root
                }

                Keys.onEscapePressed: event => {
                    root.hide();
                    event.accepted = true;
                }
            }
        }
    }
}
