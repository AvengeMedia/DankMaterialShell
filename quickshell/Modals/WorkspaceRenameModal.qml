import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: root
    readonly property var log: Log.scoped("WorkspaceRenameModal")

    property var aqueousWorkspace: null
    property bool renaming: false

    objectName: "workspaceRenameModal"
    title: I18n.tr("Rename Workspace")
    minimumSize: Qt.size(400, renameDialog.implicitHeight)
    maximumSize: Qt.size(400, renameDialog.implicitHeight)
    visible: false

    onClosed: hide()

    function show(name) {
        if (CompositorService.isAqueous) {
            if (renaming)
                return false;
            const workspace = AqueousService.workspaces.find(ws => ws.output === AqueousService.seat?.output && ws.active);
            if (!AqueousService.available || !AqueousService.seat || !workspace || !AqueousService.capabilities.commands || AqueousService.locked) {
                ToastService.showError(I18n.tr("Error"), I18n.tr("Unavailable"));
                return false;
            }
            aqueousWorkspace = {
                id: workspace.id,
                session: workspace.aqueousSession
            };
            name = workspace.name;
        }
        nameInput.text = name;
        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
        return true;
    }

    function hide() {
        visible = false;
    }

    function submitAndClose() {
        if (aqueousWorkspace || CompositorService.isAqueous) {
            if (!aqueousWorkspace || renaming)
                return;
            const target = aqueousWorkspace;
            renaming = true;
            AqueousService.command("workspace.rename", {
                id: target.id,
                session: target.session,
                name: nameInput.text
            }, success => {
                if (root.aqueousWorkspace !== target)
                    return;
                root.renaming = false;
                if (success)
                    root.hide();
            });
            return;
        }
        renameWorkspace(nameInput.text);
        hide();
    }

    function renameWorkspace(name) {
        if (CompositorService.isNiri) {
            NiriService.renameWorkspace(name);
        } else if (CompositorService.isHyprland) {
            HyprlandService.renameWorkspace(name);
        } else {
            log.warn("rename not supported for this compositor");
        }
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => nameInput.forceActiveFocus());
            return;
        }
        nameInput.text = "";
        aqueousWorkspace = null;
        renaming = false;
    }

    DankDialog {
        id: renameDialog

        anchors.fill: parent
        windowControls: renameWindowControls
        title: root.title
        supportingText: I18n.tr("Enter a new name for this workspace")
        acceptEnabled: !root.renaming
        onAccepted: root.submitAndClose()
        onRejected: root.hide()

        DankTextField {
            id: nameInput

            width: parent.width
            outlined: true
            controlHeight: Theme.fieldHeightLarge
            labelText: I18n.tr("Workspace name")
            leftIconName: "edit"
            enabled: root.visible && !root.renaming
            onAccepted: root.submitAndClose()
        }

        actions: [
            DankButton {
                maximumWidth: renameDialog.actionWidth
                wrapText: true
                text: I18n.tr("Cancel")
                backgroundColor: "transparent"
                textColor: Theme.primary
                onClicked: root.hide()
            },
            DankButton {
                maximumWidth: renameDialog.actionWidth
                wrapText: true
                text: I18n.tr("Rename", "verb, rename button")
                enabled: !root.renaming
                busy: root.renaming
                onClicked: root.submitAndClose()
            }
        ]
    }

    FloatingWindowControls {
        id: renameWindowControls
        targetWindow: root
    }
}
