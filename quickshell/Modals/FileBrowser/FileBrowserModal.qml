import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

FloatingWindow {
    id: fileBrowserModal

    property string browserTitle: "Select File"
    property string browserIcon: "folder_open"
    property string browserType: "generic"
    property var fileExtensions: ["*.*"]
    property alias filterExtensions: fileBrowserModal.fileExtensions
    property bool showHiddenFiles: false
    property bool saveMode: false
    property string defaultFileName: ""
    property var parentModal: null
    property bool shouldHaveFocus: visible
    property bool allowFocusOverride: false
    property bool shouldBeVisible: visible
    property bool allowStacking: true

    signal fileSelected(string path)
    signal dialogClosed

    function open() {
        visible = true;
    }

    function close() {
        visible = false;
    }

    objectName: "fileBrowserModal"
    title: "Files - " + browserTitle
    minimumSize: Qt.size(500, 400)
    implicitWidth: 800
    implicitHeight: 600
    color: Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            if (parentModal) {
                parentModal.shouldHaveFocus = false;
                parentModal.allowFocusOverride = true;
            }
            content.reset();
            Qt.callLater(() => content.forceActiveFocus());
        } else {
            if (parentModal) {
                parentModal.allowFocusOverride = false;
                parentModal.shouldHaveFocus = Qt.binding(() => parentModal.shouldBeVisible);
            }
            dialogClosed();
        }
    }

    FileBrowserContent {
        id: content
        anchors.fill: parent
        focus: true
        closeOnEscape: false
        windowControls: windowControls

        browserTitle: fileBrowserModal.browserTitle
        browserIcon: fileBrowserModal.browserIcon
        browserType: fileBrowserModal.browserType
        fileExtensions: fileBrowserModal.fileExtensions
        showHiddenFiles: fileBrowserModal.showHiddenFiles
        saveMode: fileBrowserModal.saveMode
        defaultFileName: fileBrowserModal.defaultFileName

        Component.onCompleted: initialize()

        onFileSelected: path => fileBrowserModal.fileSelected(path)
        onCloseRequested: fileBrowserModal.close()
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: fileBrowserModal
    }
}
