import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modals.DankLauncherV2
import qs.Services

Scope {
    id: niriOverviewScope

    property bool searchActive: false
    property string searchActiveScreen: ""
    property bool isClosing: false
    property bool releaseKeyboard: false
    readonly property bool spotlightModalOpen: PopoutService.dankLauncherV2Modal?.spotlightOpen ?? false
    property bool overlayActive: NiriService.inOverview || searchActive

    function showSpotlight(screenName) {
        isClosing = false;
        releaseKeyboard = false;
        searchActive = true;
        searchActiveScreen = screenName;
    }

    function hideSpotlight() {
        if (!searchActive)
            return;
        isClosing = true;
    }

    function hideAndReleaseKeyboard() {
        releaseKeyboard = true;
        hideSpotlight();
    }

    function resetState() {
        searchActive = false;
        searchActiveScreen = "";
        isClosing = false;
        releaseKeyboard = false;
    }

    Connections {
        target: NiriService
        function onInOverviewChanged() {
            if (NiriService.inOverview) {
                resetState();
                return;
            }
            if (!searchActive) {
                resetState();
                return;
            }
            isClosing = true;
        }

        function onCurrentOutputChanged() {
            if (!NiriService.inOverview || !searchActive || searchActiveScreen === "" || searchActiveScreen === NiriService.currentOutput)
                return;
            hideSpotlight();
        }
    }

    onSpotlightModalOpenChanged: {
        if (spotlightModalOpen && searchActive)
            hideSpotlight();
    }

    Loader {
        id: niriOverlayLoader
        active: overlayActive || isClosing
        asynchronous: false
        sourceComponent: Variants {
            id: overlayVariants
            model: Quickshell.screens

            PanelWindow {
                id: overlayWindow
                required property var modelData

                readonly property real dpr: CompositorService.getScreenScale(screen)
                readonly property bool isActiveScreen: screen.name === NiriService.currentOutput
                readonly property bool shouldShowSpotlight: niriOverviewScope.searchActive && screen.name === niriOverviewScope.searchActiveScreen && !niriOverviewScope.isClosing
                readonly property bool isSpotlightScreen: screen.name === niriOverviewScope.searchActiveScreen
                readonly property bool overlayVisible: NiriService.inOverview || niriOverviewScope.isClosing
                property bool hasActivePopout: !!PopoutManager.currentPopoutsByScreen[screen.name]
                property bool hasActiveModal: !!ModalManager.currentModalsByScreen[screen.name]

                Connections {
                    target: PopoutManager
                    function onPopoutChanged() {
                        overlayWindow.hasActivePopout = !!PopoutManager.currentPopoutsByScreen[overlayWindow.screen.name];
                    }
                }

                Connections {
                    target: ModalManager
                    function onModalChanged() {
                        overlayWindow.hasActiveModal = !!ModalManager.currentModalsByScreen[overlayWindow.screen.name];
                    }
                }

                screen: modelData
                visible: overlayVisible
                color: "transparent"

                WlrLayershell.namespace: "dms:niri-overview-spotlight"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: {
                    if (!NiriService.inOverview)
                        return WlrKeyboardFocus.None;
                    if (!isActiveScreen)
                        return WlrKeyboardFocus.None;
                    if (niriOverviewScope.releaseKeyboard)
                        return WlrKeyboardFocus.None;
                    if (hasActivePopout || hasActiveModal)
                        return WlrKeyboardFocus.None;
                    return WlrKeyboardFocus.Exclusive;
                }

                mask: Region {
                    item: overlayVisible && spotlightContainer.visible ? spotlightContainer : null
                }

                onShouldShowSpotlightChanged: {
                    if (shouldShowSpotlight) {
                        if (launcherContent?.controller) {
                            launcherContent.controller.searchMode = SessionData.niriOverviewLastMode || "apps";
                            launcherContent.controller.performSearch();
                        }
                        return;
                    }
                    if (!isActiveScreen)
                        return;
                    Qt.callLater(() => keyboardFocusScope.forceActiveFocus());
                }

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                FocusScope {
                    id: keyboardFocusScope
                    anchors.fill: parent
                    focus: true

                    Keys.onPressed: event => {
                        if (overlayWindow.shouldShowSpotlight || niriOverviewScope.isClosing)
                            return;
                        if ([Qt.Key_Escape, Qt.Key_Return].includes(event.key)) {
                            NiriService.toggleOverview();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Left) {
                            NiriService.moveColumnLeft();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Right) {
                            NiriService.moveColumnRight();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Up) {
                            NiriService.moveWorkspaceUp();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Down) {
                            NiriService.moveWorkspaceDown();
                            event.accepted = true;
                            return;
                        }

                        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier) || [Qt.Key_Delete, Qt.Key_Backspace].includes(event.key)) {
                            event.accepted = false;
                            return;
                        }

                        if (event.isAutoRepeat || !event.text)
                            return;
                        if (!launcherContent?.searchField)
                            return;
                        const trimmedText = event.text.trim();
                        launcherContent.searchField.text = trimmedText;
                        launcherContent.controller.setSearchQuery(trimmedText);
                        niriOverviewScope.showSpotlight(overlayWindow.screen.name);
                        Qt.callLater(() => launcherContent.searchField.forceActiveFocus());
                        event.accepted = true;
                    }
                }

                Item {
                    id: spotlightContainer
                    x: Theme.snap((parent.width - width) / 2, overlayWindow.dpr)
                    y: Theme.snap((parent.height - height) / 2, overlayWindow.dpr)

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
                    width: Math.min(baseWidth, overlayWindow.screen.width - 100)
                    height: Math.min(baseHeight, overlayWindow.screen.height - 100)

                    readonly property bool animatingOut: niriOverviewScope.isClosing && overlayWindow.isSpotlightScreen

                    scale: overlayWindow.shouldShowSpotlight ? 1.0 : 0.96
                    opacity: overlayWindow.shouldShowSpotlight ? 1 : 0
                    visible: overlayWindow.shouldShowSpotlight || animatingOut
                    enabled: overlayWindow.shouldShowSpotlight

                    layer.enabled: visible
                    layer.smooth: false
                    layer.textureSize: layer.enabled ? Qt.size(Math.round(width * overlayWindow.dpr), Math.round(height * overlayWindow.dpr)) : Qt.size(0, 0)

                    Behavior on scale {
                        id: scaleAnimation
                        NumberAnimation {
                            duration: Theme.expressiveDurations.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: spotlightContainer.visible ? Theme.expressiveCurves.expressiveFastSpatial : Theme.expressiveCurves.standardAccel
                            onRunningChanged: {
                                if (running || !spotlightContainer.animatingOut)
                                    return;
                                niriOverviewScope.resetState();
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.expressiveDurations.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: spotlightContainer.visible ? Theme.expressiveCurves.expressiveFastSpatial : Theme.expressiveCurves.standardAccel
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                        radius: Theme.cornerRadius
                        border.color: Theme.outlineMedium
                        border.width: 1
                    }

                    LauncherContent {
                        id: launcherContent
                        anchors.fill: parent
                        anchors.margins: 0

                        property var fakeParentModal: QtObject {
                            property bool spotlightOpen: spotlightContainer.visible
                            property bool isClosing: niriOverviewScope.isClosing
                            function hide() {
                                if (niriOverviewScope.searchActive) {
                                    niriOverviewScope.hideSpotlight();
                                    return;
                                }
                                NiriService.toggleOverview();
                            }
                        }

                        Connections {
                            target: launcherContent.searchField
                            function onTextChanged() {
                                if (launcherContent.searchField.text.length > 0 || !niriOverviewScope.searchActive)
                                    return;
                                niriOverviewScope.hideSpotlight();
                            }
                        }

                        Component.onCompleted: {
                            parentModal = fakeParentModal;
                        }

                        Connections {
                            target: launcherContent.controller
                            function onItemExecuted() {
                                niriOverviewScope.releaseKeyboard = true;
                            }
                            function onModeChanged(mode) {
                                if (launcherContent.controller.autoSwitchedToFiles)
                                    return;
                                SessionData.setNiriOverviewLastMode(mode);
                            }
                        }
                    }
                }
            }
        }
    }
}
