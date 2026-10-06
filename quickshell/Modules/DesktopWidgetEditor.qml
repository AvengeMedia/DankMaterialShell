import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Plugins

Scope {
    Variants {
        model: DesktopWidgetRegistry.editing ? Quickshell.screens : []

        PanelWindow {
            id: editorWindow

            required property var modelData

            screen: modelData
            visible: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "dms:desktop-widget-editor"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            color: "transparent"

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (widgetLayer.handleKey(event))
                        event.accepted = true;
                }
                Keys.onEscapePressed: overlay.dismiss()

                Rectangle {
                    anchors.fill: parent
                    color: Theme.scrimColor
                    opacity: Theme.scrimAlpha
                }

                WidgetEditLayer {
                    id: widgetLayer
                    anchors.fill: parent
                    screenName: editorWindow.screen?.name ?? ""
                    editMode: true
                    bottomInset: overlay.fabReserved
                    onOptionsRequested: instanceData => overlay.showOptions(instanceData)
                }

                WidgetEditorOverlay {
                    id: overlay
                    anchors.fill: parent
                    editLayer: widgetLayer
                    onFinished: DesktopWidgetRegistry.editing = false
                }
            }
        }
    }
}
