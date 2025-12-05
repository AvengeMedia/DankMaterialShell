import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modals.Spotlight
import qs.Services

Scope {
    id: niriOverviewScope

    property bool searchActive: false
    property string searchActiveScreen: ""
    property bool isClosing: false
    property bool releaseKeyboard: false
    property bool overlayActive: (NiriService.inOverview && !(PopoutService.spotlightModal?.spotlightOpen ?? false)) || searchActive

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

    function completeHide() {
        searchActive = false;
        searchActiveScreen = "";
        isClosing = false;
        releaseKeyboard = false;
    }

    Connections {
        target: NiriService
        function onInOverviewChanged() {
            if (!NiriService.inOverview) {
                if (searchActive) {
                    isClosing = true;
                    return;
                }
                searchActive = false;
                searchActiveScreen = "";
                isClosing = false;
                return;
            }
            searchActive = false;
            searchActiveScreen = "";
            isClosing = false;
        }

        function onCurrentOutputChanged() {
            if (!NiriService.inOverview || !searchActive || searchActiveScreen === "" || searchActiveScreen === NiriService.currentOutput)
                return;
            hideSpotlight();
        }
    }

    Connections {
        target: PopoutService.spotlightModal
        function onSpotlightOpenChanged() {
            if (!PopoutService.spotlightModal?.spotlightOpen || !searchActive)
                return;
            hideSpotlight();
        }
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

                screen: modelData
                visible: NiriService.inOverview || niriOverviewScope.isClosing
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
                    return WlrKeyboardFocus.Exclusive;
                }

                mask: Region {
                    item: spotlightContainer.visible ? spotlightContainer : null
                }

                onShouldShowSpotlightChanged: {
                    if (shouldShowSpotlight || !isActiveScreen)
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
                        if (!spotlightContent?.searchField)
                            return;
                        const trimmedText = event.text.trim();
                        spotlightContent.searchField.text = trimmedText;
                        if (spotlightContent.appLauncher) {
                            spotlightContent.appLauncher.searchQuery = trimmedText;
                        }
                        niriOverviewScope.showSpotlight(overlayWindow.screen.name);
                        Qt.callLater(() => spotlightContent.searchField.forceActiveFocus());
                        event.accepted = true;
                    }
                }

                Item {
                    id: spotlightContainer
                    x: Theme.snap((parent.width - width) / 2, overlayWindow.dpr)
                    y: Theme.snap((parent.height - height) / 2, overlayWindow.dpr)
                    width: Theme.px(500, overlayWindow.dpr)
                    height: Theme.px(600, overlayWindow.dpr)

                    readonly property bool animatingOut: niriOverviewScope.isClosing && overlayWindow.isSpotlightScreen

                    scale: overlayWindow.shouldShowSpotlight ? 1.0 : 0.96
                    opacity: overlayWindow.shouldShowSpotlight ? 1 : 0
                    visible: overlayWindow.shouldShowSpotlight || animatingOut
                    enabled: overlayWindow.shouldShowSpotlight

                    layer.enabled: true
                    layer.smooth: false
                    layer.textureSize: Qt.size(Math.round(width * overlayWindow.dpr), Math.round(height * overlayWindow.dpr))

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: spotlightContainer.visible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                            onRunningChanged: {
                                if (running || !spotlightContainer.animatingOut)
                                    return;
                                niriOverviewScope.completeHide();
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: spotlightContainer.visible ? Theme.expressiveCurves.expressiveDefaultSpatial : Theme.expressiveCurves.emphasized
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                        radius: Theme.cornerRadius
                        border.color: Theme.outlineMedium
                        border.width: 1
                    }

                    SpotlightContent {
                        id: spotlightContent
                        anchors.fill: parent
                        anchors.margins: 0
                        usePopupContextMenu: true

                        property var fakeParentModal: QtObject {
                            property bool spotlightOpen: spotlightContainer.visible
                            function hide() {
                                if (spotlightContent.searchField.text.length > 0) {
                                    niriOverviewScope.hideSpotlight();
                                    return;
                                }
                                NiriService.toggleOverview();
                            }
                        }

                        Connections {
                            target: spotlightContent.searchField
                            function onTextChanged() {
                                if (spotlightContent.searchField.text.length > 0 || !niriOverviewScope.searchActive)
                                    return;
                                niriOverviewScope.hideSpotlight();
                            }
                        }

                        Component.onCompleted: {
                            parentModal = fakeParentModal;
                        }

                        Connections {
                            target: spotlightContent.appLauncher
                            function onAppLaunched() {
                                niriOverviewScope.releaseKeyboard = true;
                            }
                        }

                        Connections {
                            target: spotlightContent.fileSearchController
                            function onFileOpened() {
                                niriOverviewScope.releaseKeyboard = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
