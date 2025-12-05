import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modals.Common

DankModal {
    id: fileBrowserSurfaceModal

    property string browserTitle: "Select File"
    property string browserIcon: "folder_open"
    property string browserType: "generic"
    property var fileExtensions: ["*.*"]
    property alias filterExtensions: fileBrowserSurfaceModal.fileExtensions
    property bool showHiddenFiles: false
    property bool saveMode: false
    property string defaultFileName: ""
    property var parentPopout: null

    signal fileSelected(string path)

    layerNamespace: "dms:filebrowser"
    modalWidth: 800
    modalHeight: 600
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    closeOnEscapeKey: true
    closeOnBackgroundClick: true
    allowStacking: true
    keepPopoutsOpen: true

    onBackgroundClicked: close()

    onOpened: {
        if (parentPopout) {
            parentPopout.customKeyboardFocus = WlrKeyboardFocus.None;
        }
        content.reset();
        Qt.callLater(() => content.forceActiveFocus());
    }

    onDialogClosed: {
        if (parentPopout) {
            parentPopout.customKeyboardFocus = null;
        }
    }

    directContent: FileBrowserContent {
        id: content
        focus: true

        browserTitle: fileBrowserSurfaceModal.browserTitle
        browserIcon: fileBrowserSurfaceModal.browserIcon
        browserType: fileBrowserSurfaceModal.browserType
        fileExtensions: fileBrowserSurfaceModal.fileExtensions
        showHiddenFiles: fileBrowserSurfaceModal.showHiddenFiles
        saveMode: fileBrowserSurfaceModal.saveMode
        defaultFileName: fileBrowserSurfaceModal.defaultFileName

        Component.onCompleted: initialize()

        onFileSelected: path => fileBrowserSurfaceModal.fileSelected(path)
        onCloseRequested: fileBrowserSurfaceModal.close()
    }
}
