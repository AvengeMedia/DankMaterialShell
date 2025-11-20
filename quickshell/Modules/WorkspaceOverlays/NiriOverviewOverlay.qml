import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: niriOverviewScope

    // Only show overlay when in overview and spotlight is not open
    property bool overlayActive: NiriService.inOverview && !(PopoutService.spotlightModal?.spotlightOpen ?? false)

    Loader {
        id: niriOverlayLoader
        active: NiriService.inOverview
        asynchronous: false

        sourceComponent: Variants {
            id: overlayVariants
            model: Quickshell.screens

            PanelWindow {
                id: overlayWindow
                required property var modelData

                screen: modelData
                visible: niriOverviewScope.overlayActive
                color: "transparent"

                WlrLayershell.namespace: "dms:niri-overview-overlay"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: niriOverviewScope.overlayActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                implicitWidth: 0
                implicitHeight: 0

                anchors {
                    top: true
                    left: true
                    right: false
                    bottom: false
                }

                FocusScope {
                    id: keyboardFocusScope
                    anchors.fill: parent
                    visible: niriOverviewScope.overlayActive
                    focus: niriOverviewScope.overlayActive

                    Keys.onPressed: event => {

                                        // Handle arrow keys and escape for navigation, mimicking niri's harcoded keybinds
                                        if ([Qt.Key_Escape, Qt.Key_Return].includes(event.key)) {
                                            NiriService.toggleOverview()
                                            event.accepted = true
                                            return
                                        }

                                        if (event.key === Qt.Key_Left) {
                                            NiriService.moveColumnLeft()
                                            event.accepted = true
                                            return
                                        }

                                        if (event.key === Qt.Key_Right) {
                                            NiriService.moveColumnRight()
                                            event.accepted = true
                                            return
                                        }

                                        if (event.key === Qt.Key_Up) {
                                            NiriService.moveWorkspaceUp()
                                            event.accepted = true
                                            return
                                        }

                                        if (event.key === Qt.Key_Down) {
                                            NiriService.moveWorkspaceDown()
                                            event.accepted = true
                                            return
                                        }

                                        // Allowing delete and backspace will produce a broken text
                                        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier) || [Qt.Key_Delete, Qt.Key_Backspace].includes(event.key)) {
                                            event.accepted = false
                                            return
                                        }

                                        // For any other key (printable characters), open spotlight
                                        if (!event.isAutoRepeat) {
                                            Qt.callLater(() => {
                                                             if (PopoutService.spotlightModal) {
                                                                 if (event.text) {
                                                                     PopoutService.spotlightModal.showWithQuery(event.text.trim())
                                                                 }
                                                             }
                                                         })

                                            event.accepted = true
                                        }
                                    }

                    Connections {
                        target: niriOverviewScope
                        function onOverlayActiveChanged() {
                            if (niriOverviewScope.overlayActive) {
                                Qt.callLater(() => keyboardFocusScope.forceActiveFocus())
                            }
                        }
                    }
                }
            }
        }
    }
}
