import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Notepad

DankFloatingWindow {
    id: win

    property alias shouldBeVisible: win.visible
    property alias notepad: notepad

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    title: I18n.tr("Notepad")
    minimumSize: Qt.size(360, 320)
    implicitWidth: 640
    implicitHeight: 760
    surfaceColor: Theme.notepadWindowSurface
    visible: false

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(notepad.externalSync);
        } else {
            notepad.flushAutoSave();
        }
    }

    onClosed: win.visible = false

    Item {
        anchors.fill: parent

        DankWindowHeader {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            z: 10
            controls: windowControls
            title: I18n.tr("Notepad")
            onCloseRequested: win.hide()
        }

        Notepad {
            id: notepad
            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.spacingM
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.bottomMargin: Theme.spacingM
            inPopout: true
            surfaceVisible: win.visible
            onHideRequested: win.hide()
            onDockRequested: {
                win.hide();
                PopoutService.openNotepadSlideout();
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: win
    }
}
