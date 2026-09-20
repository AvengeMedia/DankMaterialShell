pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var parentModal: null
    property string confirmingRemoveId: ""
    property string editingDockId: ""
    property string renameDraft: ""

    function finishRename(value) {
        const id = editingDockId;
        editingDockId = "";
        const name = value.trim();
        if (!id || !name || SettingsData.dockConfigs.some(config => config.id !== id && config.name === name))
            return;
        SettingsData.updateDockConfig(id, {
            name: name
        });
    }

    function addDock() {
        confirmingRemoveId = "";
        dock.selectedDockId = SettingsData.createDockConfig();
        if (!dock.config?.enabled)
            ToastService.showWarning(I18n.tr("Every edge of this display is already taken"));
    }

    function removeDock(id) {
        if (confirmingRemoveId !== id) {
            confirmingRemoveId = id;
            return;
        }
        confirmingRemoveId = "";
        SettingsData.removeDockConfig(id);
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    DockSelectionState {
        id: dock

        onSelectedDockIdChanged: {
            root.editingDockId = "";
            root.confirmingRemoveId = "";
        }
    }

    SettingsCard {
        width: parent.width
        iconName: "dock_to_bottom"
        title: I18n.tr("Docks", "noun plural, settings card title listing configured docks")
        settingKey: "dockConfiguration"
        tags: ["dock", "configuration", "add", "remove", "name", "show", "enable"]
        headerActions: DankButton {
            text: I18n.tr("Add", "verb, button that adds a new item to a list")
            iconName: "add"
            buttonHeight: Theme.buttonHeightXS
            onClicked: root.addDock()
        }

        Repeater {
            model: SettingsData.dockConfigs

            delegate: SettingsInstanceRow {
                required property var modelData

                title: modelData.name
                summary: dock.summaryFor(modelData)
                selected: dock.selectedDockId === modelData.id
                checked: modelData.enabled
                deletable: SettingsData.dockConfigs.length > 1
                confirmingDelete: root.confirmingRemoveId === modelData.id
                onClicked: dock.selectedDockId = modelData.id
                onToggled: checked => {
                    dock.selectedDockId = modelData.id;
                    dock.setEnabled(checked);
                }
                onDeleteRequested: root.removeDock(modelData.id)
            }
        }

        SettingsRow {
            title: I18n.tr("Name")
            subtitle: root.editingDockId ? "" : dock.config?.name ?? ""
            visible: dock.hasConfig

            DankActionButton {
                iconName: root.editingDockId ? "check" : "edit"
                Accessible.name: root.editingDockId ? I18n.tr("Save") : I18n.tr("Rename")
                onClicked: {
                    if (root.editingDockId) {
                        root.finishRename(root.renameDraft);
                        return;
                    }
                    root.renameDraft = dock.config.name;
                    root.editingDockId = dock.selectedDockId;
                }
            }
            DankActionButton {
                visible: root.editingDockId !== ""
                iconName: "close"
                Accessible.name: I18n.tr("Cancel")
                onClicked: root.editingDockId = ""
            }

            body: Loader {
                width: parent.width
                active: root.editingDockId !== ""
                visible: active
                sourceComponent: DankTextField {
                    id: renameField
                    width: parent.width
                    outlined: true
                    labelText: I18n.tr("Name")
                    text: root.renameDraft
                    onTextEdited: root.renameDraft = renameField.text
                    onAccepted: root.finishRename(renameField.text)
                    Keys.onEscapePressed: root.editingDockId = ""
                    Component.onCompleted: {
                        renameField.forceActiveFocus();
                        renameField.selectAll();
                    }
                }
            }
        }
    }

    SettingsCard {
        width: parent.width
        visible: dock.hasConfig
        iconName: "dock_to_bottom"
        title: I18n.tr("Layout")
        settingKey: "dockPlacement"
        tags: ["dock", "layout", "placement", "position", "edge"]

        SettingsLayoutPicker {
            dockPlacement: true
            choices: [SettingsData.Position.Top, SettingsData.Position.Bottom, SettingsData.Position.Left, SettingsData.Position.Right].map(position => ({
                        key: String(position),
                        label: dock.positionLabel(position),
                        enabled: dock.positionChoices.includes(position)
                    }))
            selectedKey: String(dock.config?.position ?? SettingsData.Position.Bottom)
            onSelected: key => dock.setEnabled(true, Number(key))
        }
    }
}
