import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property string focusedScreenName: (
        CompositorService.isHyprland && typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor ? (Hyprland.focusedWorkspace.monitor.name || "") :
        CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.currentOutput ? NiriService.currentOutput : ""
    )

    function resolveNotepadInstance() {
        if (typeof notepadSlideoutVariants === "undefined" || !notepadSlideoutVariants || !notepadSlideoutVariants.instances) {
            return null
        }

        const targetScreen = focusedScreenName
        if (targetScreen) {
            for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
                var slideout = notepadSlideoutVariants.instances[i]
                if (slideout.modelData && slideout.modelData.name === targetScreen) {
                    return slideout
                }
            }
        }

        return notepadSlideoutVariants.instances.length > 0 ? notepadSlideoutVariants.instances[0] : null
    }

    readonly property var notepadInstance: resolveNotepadInstance()
    readonly property bool isActive: notepadInstance?.isVisible ?? false

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: notepadIcon

                anchors.centerIn: parent
                name: "assignment"
                size: Theme.barIconSize(root.barThickness, -4)
                color: root.isActive ? Theme.primary : Theme.surfaceText
            }

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: Theme.primary
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: SettingsData.dankBarNoBackground ? 0 : 4
                anchors.topMargin: SettingsData.dankBarNoBackground ? 0 : 4
                visible: NotepadStorageService.tabs && NotepadStorageService.tabs.length > 0
                opacity: 0.8
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: {
            const inst = root.notepadInstance
            if (inst) {
                inst.toggle()
            }
        }
    }
}