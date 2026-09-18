pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.Settings.BarWidgetOptions

Item {
    id: root

    property var parentModal: null
    property int catalogRevision: 0
    property string confirmingRemoveId: ""

    readonly property bool dockHosted: true
    readonly property var appsEntry: dock.config?.widgets.find(item => item.widgetId === "appsDock") ?? null
    readonly property var appStore: ({
            "get": key => dock.config?.[key],
            "set": (key, value) => dock.setOption(key, value),
            "isDefault": keys => dock.isDefault(keys),
            "resetToDefault": keys => dock.resetToDefault(keys)
        })
    readonly property var _dockAppsDefaults: ({
            "appsDockHideIndicators": false,
            "appsDockIconSizePercentage": 100,
            "runningAppsCurrentWorkspace": false
        })

    function defaultOption(key) {
        if (key in _dockAppsDefaults)
            return _dockAppsDefaults[key];
        return SettingsData.widgetDefaults("appsDock")[key];
    }

    function value(key) {
        if (key in _dockAppsDefaults)
            return appsEntry?.[key] ?? _dockAppsDefaults[key];
        return SettingsData.widgetOption("appsDock", appsEntry, key);
    }

    function isDefault(keys) {
        return keys.every(key => defaultOption(key) === undefined || JSON.stringify(value(key)) === JSON.stringify(defaultOption(key)));
    }

    function resetToDefault(keys) {
        for (const key of keys) {
            const fallback = defaultOption(key);
            if (fallback !== undefined)
                set(key, fallback);
        }
    }

    function set(key, value) {
        if (!appsEntry)
            return;
        SettingsData.updateDockWidget(dock.selectedDockId, appsEntry.id, {
            [key]: value
        });
    }

    DockSelectionState {
        id: dock

        onSelectedDockIdChanged: root.confirmingRemoveId = ""
    }

    Connections {
        target: PluginService

        function onPluginStateChanged() {
            root.catalogRevision++;
        }
        function onPluginDataChanged() {
            root.catalogRevision++;
        }
        function onPluginListUpdated() {
            root.catalogRevision++;
        }
        function onPluginLoaded() {
            root.catalogRevision++;
        }
    }

    readonly property var widgetChoices: {
        catalogRevision;
        return BarWidgetCatalog.widgets.concat(PluginService.getAllPluginVariants().filter(variant => variant.loaded).map(variant => ({
                    id: variant.fullId,
                    text: variant.name,
                    icon: variant.icon
                })));
    }

    function widgetEntry(id) {
        return widgetChoices.find(widget => widget.id === id) ?? null;
    }

    readonly property var slotOptions: ({
            "dockLauncher": "launcherEnabled",
            "dockTrash": "showTrash"
        })

    // The bar names this widget "Apps dock", which reads wrong once it is listed inside a dock.
    function widgetName(id) {
        switch (id) {
        case "appsDock":
            return I18n.tr("Apps");
        case "dockLauncher":
            return I18n.tr("Launcher button");
        case "dockTrash":
            return I18n.tr("Trash");
        default:
            return widgetEntry(id)?.text ?? id;
        }
    }

    function widgetIcon(id) {
        switch (id) {
        case "dockLauncher":
            return "apps";
        case "dockTrash":
            return "delete";
        default:
            return widgetEntry(id)?.icon ?? "widgets";
        }
    }

    function updateWidgets(widgets) {
        root.confirmingRemoveId = "";
        if (!dock.hasConfig)
            return;
        SettingsData.updateDockConfig(dock.selectedDockId, {
            widgets
        });
    }

    function configureWidget(item) {
        SettingsUiState.selectedDockId = dock.selectedDockId;
        SettingsUiState.selectedDockWidgetId = item.id;
        SettingsUiState.selectedWidgetTitle = root.widgetName(item.widgetId);
        SettingsUiState.selectedWidgetDescription = "";
        SettingsUiState.selectedWidgetIcon = root.widgetIcon(item.widgetId);
        root.parentModal?.navigateTo("bar_widget");
    }

    SettingsPage {
        SettingsCard {
            width: parent.width
            visible: dock.hasConfig
            iconName: "widgets"
            title: I18n.tr("Apps & widgets")
            settingKey: "dockWidgets"
            tags: ["dock", "widgets", "apps", "add", "remove", "order"]

            SettingsButtonGroupRow {
                resetStore: dock
                resetKeys: ["widgetExpansion"]
                readonly property var modes: ["popout", "inline"]

                text: I18n.tr("Open widgets")
                model: [I18n.tr("Popout"), I18n.tr("Inline", "adjective, dock widgets open inside the dock instead of a popout")]
                currentIndex: Math.max(0, modes.indexOf(dock.config?.widgetExpansion ?? "popout"))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    dock.setOption("widgetExpansion", modes[index]);
                }
            }

            Repeater {
                model: dock.config?.widgets ?? []

                delegate: SettingsRow {
                    id: widgetRow

                    required property var modelData
                    readonly property bool confirmingRemove: root.confirmingRemoveId === modelData.id
                    readonly property string slotOption: root.slotOptions[modelData.widgetId] ?? ""
                    readonly property bool shown: slotOption ? dock.config[slotOption] === true : modelData.enabled !== false

                    title: root.widgetName(modelData.widgetId)
                    iconName: root.widgetIcon(modelData.widgetId)
                    subtitle: confirmingRemove ? I18n.tr("Confirm Delete") : ""
                    subtitleColor: Theme.error
                    body: SettingsSliderRow {
                        width: parent.width
                        visible: widgetRow.modelData.widgetId === "spacer"
                        height: visible ? implicitHeight : 0
                        text: I18n.tr("Size")
                        minimum: 0
                        maximum: 200
                        value: widgetRow.modelData.size ?? 20
                        onSliderValueChanged: value => SettingsData.updateDockWidget(dock.selectedDockId, widgetRow.modelData.id, {
                                size: value
                            })
                    }

                    Row {
                        spacing: Theme.spacingXS

                        DankActionButton {
                            iconName: "settings"
                            visible: widgetRow.modelData.widgetId !== "appsDock" && !!BarWidgetCatalog.optionsFile(widgetRow.modelData.widgetId)
                            Accessible.name: I18n.tr("Settings")
                            onClicked: root.configureWidget(widgetRow.modelData)
                        }

                        DankActionButton {
                            iconName: widgetRow.shown ? "visibility" : "visibility_off"
                            Accessible.name: widgetRow.shown ? I18n.tr("Hide") : I18n.tr("Show")
                            onClicked: {
                                if (widgetRow.slotOption) {
                                    dock.setOption(widgetRow.slotOption, !widgetRow.shown);
                                    return;
                                }
                                SettingsData.updateDockWidget(dock.selectedDockId, widgetRow.modelData.id, {
                                    enabled: !widgetRow.shown
                                });
                            }
                        }

                        DankActionButton {
                            visible: !widgetRow.slotOption
                            iconName: widgetRow.confirmingRemove ? "warning" : "delete"
                            iconColor: widgetRow.confirmingRemove ? Theme.error : Theme.surfaceVariantText
                            Accessible.name: widgetRow.confirmingRemove ? I18n.tr("Confirm Delete") : I18n.tr("Remove")
                            onClicked: {
                                if (!widgetRow.confirmingRemove) {
                                    root.confirmingRemoveId = widgetRow.modelData.id;
                                    return;
                                }
                                root.updateWidgets(dock.config.widgets.filter(item => item.id !== widgetRow.modelData.id));
                            }
                        }
                    }
                }
            }

            SettingsNavRow {
                title: I18n.tr("Add widget")
                iconName: "add"
                onClicked: {
                    picker.widgets = root.widgetChoices.filter(widget => widget.id !== "appsDock" || !dock.config.widgets.some(item => item.widgetId === "appsDock"));
                    picker.show();
                }
            }
        }

        Loader {
            width: parent.width
            active: root.appsEntry !== null
            visible: active
            sourceComponent: AppsDockOptions {
                page: root
            }
        }
    }

    WidgetSelectionPopup {
        id: picker

        parentModal: root.parentModal
        onWidgetSelected: widgetId => root.updateWidgets(dock.config.widgets.concat([
                {
                    id: dock.selectedDockId + "_" + Date.now(),
                    widgetId,
                    enabled: true
                }
            ]))
    }
}
