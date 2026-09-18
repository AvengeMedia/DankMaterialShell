pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/settings/DockConfig.js" as DockConfig

Item {
    id: root

    property var parentModal: null

    readonly property string dockId: SettingsUiState.selectedDockId
    readonly property bool dockHosted: dockId !== ""
    readonly property string barId: SettingsUiState.selectedBarId
    readonly property string section: SettingsUiState.selectedWidgetSection
    readonly property int index: SettingsUiState.selectedWidgetIndex
    readonly property var entry: {
        if (dockHosted)
            return SettingsData.getDockConfig(dockId)?.widgets.find(item => item.id === SettingsUiState.selectedDockWidgetId) ?? null;
        SettingsData.barConfigs;
        const config = SettingsData.getBarConfig(barId);
        const raw = (config?.[section + "Widgets"] ?? [])[index];
        if (raw === undefined)
            return null;
        return typeof raw === "string" ? ({
                "id": raw,
                "enabled": true
            }) : raw;
    }
    readonly property string widgetType: entry?.widgetId ?? entry?.id ?? ""
    readonly property var store: ({
            "get": key => root.value(key),
            "set": (key, value) => root.set(key, value),
            "isDefault": keys => root.isDefault(keys),
            "resetToDefault": keys => root.resetToDefault(keys)
        })

    // Options the dock surface itself reads live on the dock configuration; a bar keeps per-instance
    // copies under bar-prefixed keys. One options page, two homes.
    readonly property var _barAppKeys: ({
            "maxVisibleApps": "barMaxVisibleApps",
            "maxVisibleRunningApps": "barMaxVisibleRunningApps",
            "showOverflowBadge": "barShowOverflowBadge"
        })

    readonly property var appStore: ({
            "get": key => {
                if (!root.dockHosted)
                    return root.value(root._barAppKeys[key] ?? key);
                const config = SettingsData.getDockConfig(root.dockId);
                return config ? config[key] : DockConfig.create("", "")[key];
            },
            "set": (key, value) => {
                if (!root.dockHosted) {
                    root.set(root._barAppKeys[key] ?? key, value);
                    return;
                }
                SettingsData.updateDockConfig(root.dockId, {
                    [key]: value
                });
            },
            "isDefault": keys => keys.every(key => JSON.stringify(root.appStore.get(key)) === JSON.stringify(root.appDefault(key))),
            "resetToDefault": keys => keys.forEach(key => root.appStore.set(key, root.appDefault(key)))
        })

    function appDefault(key) {
        if (dockHosted)
            return DockConfig.create("", "")[key];
        return defaultOption(_barAppKeys[key] ?? key);
    }

    readonly property var _dockAppsDefaults: ({
            "appsDockHideIndicators": false,
            "appsDockIconSizePercentage": 100
        })

    function defaultOption(key) {
        if (dockHosted && widgetType === "appsDock" && key in _dockAppsDefaults)
            return _dockAppsDefaults[key];
        return SettingsData.widgetDefaults(widgetType)[key];
    }

    function value(key) {
        if (dockHosted && widgetType === "appsDock" && key in _dockAppsDefaults)
            return entry?.[key] ?? _dockAppsDefaults[key];
        return SettingsData.widgetOption(widgetType, entry, key);
    }

    function set(key, newValue) {
        const updates = {};
        updates[key] = newValue;
        if (dockHosted)
            SettingsData.updateDockWidget(dockId, SettingsUiState.selectedDockWidgetId, updates);
        else
            SettingsData.updateBarWidget(barId, section, index, updates);
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

    function load() {
        const file = BarWidgetCatalog.optionsFile(widgetType);
        if (!file) {
            optionsLoader.source = "";
            return;
        }
        optionsLoader.setSource("BarWidgetOptions/" + file, {
            "page": root
        });
    }

    onWidgetTypeChanged: load()
    Component.onCompleted: load()

    SettingsPage {
        SettingsCard {
            visible: root.widgetType === "weather"
            title: I18n.tr("Weather")

            SettingsNavRow {
                title: I18n.tr("Weather")
                iconName: "partly_cloudy_day"
                onClicked: root.parentModal?.navigateTo("weather")
            }
        }

        SettingsCard {
            settingKey: "barWidgetGeneral"

            SettingsToggleRow {
                iconName: SettingsUiState.selectedWidgetIcon
                text: root.dockHosted ? I18n.tr("Show in dock") : I18n.tr("Show in bar")
                description: SettingsUiState.selectedWidgetDescription
                checked: root.entry?.enabled !== false
                onToggled: checked => root.set("enabled", checked)
            }
        }

        Loader {
            id: optionsLoader
            width: parent.width
            asynchronous: true
            opacity: status === Loader.Ready ? 1 : 0

            Behavior on opacity {
                enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                NumberAnimation {
                    duration: SettingsMetrics.fadeDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
        }

        Item {
            width: parent.width
            height: optionsLoader.status === Loader.Loading ? Theme.iconButtonSize * 2 : 0
            visible: optionsLoader.status === Loader.Loading

            DankSpinner {
                anchors.centerIn: parent
            }
        }
    }
}
