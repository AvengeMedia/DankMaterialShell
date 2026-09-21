import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modals.Common

DankModal {
    id: fileBrowserSurfaceModal

    property string browserTitle: "Select File"
    property string browserIcon: "folder_open" // !TODO: plugin compat, the window header no longer draws an icon
    property string browserType: "generic"
    property var fileExtensions: ["*.*"]
    property alias filterExtensions: fileBrowserSurfaceModal.fileExtensions
    property bool showHiddenFiles: false
    property bool saveMode: false
    property bool folderMode: false
    property string defaultFileName: ""
    property string revealPath: ""
    property var parentPopout: null

    signal fileSelected(string path)

    layerNamespace: "dms:filebrowser"
    modalWidth: 800
    modalHeight: 600
    backgroundColor: Theme.floatingWindowSurface
    closeOnEscapeKey: true
    closeOnBackgroundClick: true
    allowStacking: true
    useOverlayLayer: true
    keepPopoutsOpen: true

    onBackgroundClicked: close()

    onOpened: {
        if (parentPopout) {
            parentPopout.customKeyboardFocus = WlrKeyboardFocus.None;
        }
        Qt.callLater(() => {
            if (contentLoader.item) {
                contentLoader.item.reset();
                contentLoader.item.forceActiveFocus();
            }
        });
    }

    onDialogClosed: {
        if (parentPopout) {
            parentPopout.customKeyboardFocus = null;
        }
    }

    content: FileBrowserContent {
        focus: true

        browserTitle: fileBrowserSurfaceModal.browserTitle
        browserType: fileBrowserSurfaceModal.browserType
        fileExtensions: fileBrowserSurfaceModal.fileExtensions
        showHiddenFiles: fileBrowserSurfaceModal.showHiddenFiles
        saveMode: fileBrowserSurfaceModal.saveMode
        folderMode: fileBrowserSurfaceModal.folderMode
        defaultFileName: fileBrowserSurfaceModal.defaultFileName
        revealPath: fileBrowserSurfaceModal.revealPath

        Component.onCompleted: initialize()

        onFileSelected: path => fileBrowserSurfaceModal.fileSelected(path)
        onCloseRequested: fileBrowserSurfaceModal.close()
    }
}
