import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    readonly property var log: Log.scoped("DankLauncherV2ModalStandalone")

    property var modalHandle: root

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

    readonly property bool frameOwnsConnectedChrome: SettingsData.connectedFrameModeActive && !!effectiveScreen && SettingsData.isScreenInPreferences(effectiveScreen, SettingsData.frameScreenPreferences)
    readonly property string resolvedConnectedBarSide: frameOwnsConnectedChrome ? (SettingsData.frameLauncherEmergeSide || "bottom") : ""

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
    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (Theme.elevationEnabled && SettingsData.modalElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, Theme.elevationLightDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowPad: Theme.snap(shadowRenderPadding, dpr)
    readonly property real alignedWidth: Theme.px(modalWidth, dpr)
    readonly property real alignedHeight: Theme.px(modalHeight, dpr)
    readonly property real alignedX: Theme.snap(modalX, dpr)
    readonly property real alignedY: Theme.snap(modalY, dpr)
    readonly property real windowX: Math.max(0, Theme.snap(alignedX - shadowPad, dpr))
    readonly property real windowY: Math.max(0, Theme.snap(alignedY - shadowPad, dpr))
    readonly property real contentX: Theme.snap(alignedX - windowX, dpr)
    readonly property real contentY: Theme.snap(alignedY - windowY, dpr)
    readonly property real windowWidth: alignedWidth + contentX + shadowPad
    readonly property real windowHeight: alignedHeight + contentY + shadowPad

    readonly property color backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    readonly property bool useBackgroundDarken: !SettingsData.frameEnabled && SettingsData.modalDarkenBackground
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
        ModalManager.openModal(modalHandle);
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

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
        openedFromOverview = false;
        isClosing = true;
        contentVisible = false;

        keyboardActive = false;
        spotlightOpen = false;
        focusGrab.active = false;
        ModalManager.closeModal(modalHandle);

        closeCleanupTimer.start();
    }

    function toggle() {
        spotlightOpen ? hide() : show();
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
            if (excludedModal !== modalHandle && spotlightOpen) {
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
        id: clickCatcher
        screen: launcherWindow.screen
        visible: spotlightOpen || isClosing
        color: "transparent"
        updatesEnabled: root.useBackgroundDarken && (spotlightOpen || isClosing)

        WlrLayershell.namespace: "dms:spotlight:clickcatcher"
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: outsideClickMask

            Region {
                item: outsideClickHole
                intersection: Intersection.Subtract
            }
        }

        Item {
            id: outsideClickMask
            visible: false
            anchors.fill: parent
        }

        Rectangle {
            id: outsideClickHole
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

        Rectangle {
            id: backgroundDarken
            anchors.fill: parent
            color: "black"
            opacity: contentVisible && root.useBackgroundDarken ? 0.5 : 0
            visible: (spotlightOpen || isClosing) && (root.useBackgroundDarken || opacity > 0)

            Behavior on opacity {
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                }
            }
        }
    }

    PanelWindow {
        id: launcherWindow
        visible: spotlightOpen || isClosing
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WindowBlur {
            targetWindow: launcherWindow
            readonly property real s: Math.min(1, modalContainer.publishedScale)
            readonly property real op: Math.max(0, Math.min(1, (modalContainer.opacity - 0.06) * 2))
            blurX: modalContainer.x + modalContainer.width * (1 - s * op) * 0.5
            blurY: modalContainer.y + modalContainer.height * (1 - s * op) * 0.5
            blurWidth: contentVisible ? modalContainer.width * s * op : 0
            blurHeight: contentVisible ? modalContainer.height * s * op : 0
            blurRadius: root.cornerRadius
        }

        WlrLayershell.namespace: "dms:spotlight"
        WlrLayershell.layer: {
            if (root.useBackgroundDarken)
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
        WlrLayershell.keyboardFocus: keyboardActive ? (root.useHyprlandFocusGrab ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
        }

        WlrLayershell.margins {
            left: root.windowX
            top: root.windowY
            right: 0
            bottom: 0
        }

        implicitWidth: root.windowWidth
        implicitHeight: root.windowHeight

        mask: Region {
            item: launcherInputMask
        }

        Rectangle {
            id: launcherInputMask
            visible: false
            color: "transparent"
            x: modalContainer.x
            y: modalContainer.y
            width: modalContainer.width
            height: modalContainer.height
        }

        Item {
            id: modalContainer
            x: root.contentX
            y: root.contentY
            width: root.alignedWidth
            height: root.alignedHeight
            visible: _renderActive

            property bool _renderActive: contentVisible
            property real publishedScale: contentVisible ? 1 : 0.96

            opacity: contentVisible ? 1 : 0
            scale: contentVisible ? 1 : 0.96
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                    onRunningChanged: if (!running && !root.contentVisible)
                        modalContainer._renderActive = false
                }
            }

            Behavior on scale {
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                }
            }

            Behavior on publishedScale {
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: Theme.modalAnimationDuration
                    easing.bezierCurve: contentVisible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
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
                id: launcherShadowLayer
                anchors.fill: parent
                level: root.shadowLevel
                fallbackOffset: root.shadowFallbackOffset
                targetColor: root.backgroundColor
                borderColor: root.borderColor
                borderWidth: root.borderWidth
                targetRadius: root.cornerRadius
                shadowEnabled: Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
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
