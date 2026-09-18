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
    property string editingBarId: ""
    property string renameDraft: ""

    BarSelectionState {
        id: bar

        onSelectedBarIdChanged: {
            root.editingBarId = "";
            root.confirmingRemoveId = "";
        }
    }

    function finishRename(value) {
        const id = editingBarId;
        editingBarId = "";
        const name = value.trim();
        if (!id || !name || SettingsData.barConfigs.some(config => config.id !== id && config.name === name))
            return;
        SettingsData.updateBarConfig(id, {
            name: name
        });
    }

    // A new bar shows up right away on every display, on an edge nothing else holds when there is one.
    function createNewBar() {
        if (SettingsData.barConfigs.length >= 4)
            return;
        const defaultBar = SettingsData.getBarConfig("default");
        if (!defaultBar)
            return;
        const newId = "bar" + Date.now();
        const freeEdge = SettingsData.firstFreeEdge(newId, ["all"], [SettingsData.Position.Top, SettingsData.Position.Bottom, SettingsData.Position.Left, SettingsData.Position.Right]);
        const newBar = Object.assign(JSON.parse(JSON.stringify(defaultBar)), {
            id: newId,
            name: "Bar " + (SettingsData.barConfigs.length + 1),
            enabled: true,
            position: freeEdge >= 0 ? freeEdge : (defaultBar.position ?? 0),
            screenPreferences: ["all"],
            showOnLastDisplay: true
        });
        delete newBar.island;
        SettingsData.addBarConfig(newBar);
        bar.selectedBarId = newId;
    }

    function canDeleteBar(config) {
        return config.id !== "default" && (SettingsData.getBarKindConfigs().length > 1 || SettingsData.isIslandBarConfig(config));
    }

    function deleteBar(barId) {
        if (confirmingRemoveId !== barId) {
            confirmingRemoveId = barId;
            return;
        }
        confirmingRemoveId = "";
        SettingsData.deleteBarConfig(barId);
        bar.selectedBarId = "default";
    }

    function canToggleBar(config) {
        return config.id !== "default" || SettingsData.isIslandBarConfig(config);
    }

    function setBarEnabled(barId, enabled) {
        SettingsData.updateBarConfig(barId, {
            enabled
        });
    }

    function barSummary(config) {
        const parts = [bar.positionLabel(config.position ?? SettingsData.Position.Top)];
        const prefs = config.screenPreferences || ["all"];
        if (prefs.includes("all"))
            parts.push(I18n.tr("All displays"));
        else
            parts.push(prefs.length === 1 ? I18n.tr("%1 display", "singular, bar summary of assigned monitors, %1 is 1").arg(prefs.length) : I18n.tr("%1 displays", "plural, bar summary of assigned monitors, %1 is a count").arg(prefs.length));
        if (SettingsData.isIslandBarConfig(config))
            parts.push(I18n.tr("Island"));
        return parts.join(" • ");
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        iconName: "dashboard"
        title: I18n.tr("Bars", "plural noun, the shell bars or panels, settings title")
        settingKey: "barConfigurations"
        tags: ["bar", "configuration", "add", "remove", "enable", "multiple", "name"]
        headerActions: DankButton {
            text: I18n.tr("Add")
            iconName: "add"
            buttonHeight: Theme.buttonHeightXS
            visible: SettingsData.barConfigs.length < 4
            onClicked: root.createNewBar()
        }

        Repeater {
            model: SettingsData.barConfigs

            delegate: SettingsInstanceRow {
                required property var modelData
                required property int index

                title: modelData.name || I18n.tr("Bar %1", "numbered name for an unnamed bar, %1 is its position").arg(index + 1)
                summary: root.barSummary(modelData)
                selected: bar.selectedBarId === modelData.id
                checked: modelData.enabled ?? false
                toggleVisible: root.canToggleBar(modelData)
                deletable: root.canDeleteBar(modelData)
                confirmingDelete: root.confirmingRemoveId === modelData.id
                onClicked: bar.selectedBarId = modelData.id
                onToggled: checked => {
                    bar.selectedBarId = modelData.id;
                    root.setBarEnabled(modelData.id, checked);
                }
                onDeleteRequested: root.deleteBar(modelData.id)
            }
        }

        SettingsRow {
            title: I18n.tr("Name")
            subtitle: root.editingBarId ? "" : bar.selectedBarName
            visible: !!bar.selectedBarConfig

            DankActionButton {
                iconName: root.editingBarId ? "check" : "edit"
                Accessible.name: root.editingBarId ? I18n.tr("Save") : I18n.tr("Rename")
                onClicked: {
                    if (root.editingBarId) {
                        root.finishRename(root.renameDraft);
                        return;
                    }
                    root.renameDraft = bar.selectedBarName;
                    root.editingBarId = bar.selectedBarId;
                }
            }
            DankActionButton {
                visible: root.editingBarId !== ""
                iconName: "close"
                Accessible.name: I18n.tr("Cancel")
                onClicked: root.editingBarId = ""
            }

            body: Loader {
                width: parent.width
                active: root.editingBarId !== ""
                visible: active
                sourceComponent: DankTextField {
                    id: renameField
                    width: parent.width
                    outlined: true
                    labelText: I18n.tr("Name")
                    text: root.renameDraft
                    onTextEdited: root.renameDraft = renameField.text
                    onAccepted: root.finishRename(renameField.text)
                    Keys.onEscapePressed: root.editingBarId = ""
                    Component.onCompleted: {
                        renameField.forceActiveFocus();
                        renameField.selectAll();
                    }
                }
            }
        }
    }

    SettingsCard {
        iconName: "toolbar"
        title: I18n.tr("Layout", "noun, settings section title for arrangement options")
        settingKey: "barLayout"
        tags: ["layout", "standard", "frame", "island", "mode", "bar"]

        SettingsLayoutPicker {}
    }
}
