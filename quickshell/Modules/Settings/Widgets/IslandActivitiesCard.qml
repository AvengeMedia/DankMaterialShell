import QtQuick
import qs.Common
import qs.Modules.Settings
import qs.Services

SettingsCard {
    id: root

    required property var store
    property string keyPrefix: "island"
    readonly property bool usesBarWidgets: SettingsData.isIslandBarConfig(root.store.config) && !SettingsData.isDotBarConfig(root.store.config)
    iconName: "animation"
    title: I18n.tr("Live activities")
    settingKey: root.keyPrefix + "Activities"
    tags: ["island", "activities", "plugins", "media", "color", "ipc"]

    function sourceOverride(source, key) {
        return (root.store.setting("islandActivitySourceOverrides") || {})[source]?.[key] || "activity";
    }

    function setSourceOverride(source, key, value) {
        const overrides = Object.assign({}, root.store.setting("islandActivitySourceOverrides") || {});
        const sourceSettings = Object.assign({}, overrides[source] || {});
        if (value === "activity")
            delete sourceSettings[key];
        else
            sourceSettings[key] = value;
        if (Object.keys(sourceSettings).length)
            overrides[source] = sourceSettings;
        else
            delete overrides[source];
        root.store.apply("islandActivitySourceOverrides", overrides);
    }

    SettingsToggleRow {
        text: I18n.tr("Plugin activities")
        description: I18n.tr("Allow plugins and IPC clients to present activities in this island")
        checked: root.store.setting("islandActivitiesEnabled")
        onToggled: checked => root.store.apply("islandActivitiesEnabled", checked)
    }

    SettingsTextFieldRow {
        text: I18n.tr("Hidden activity sources")
        description: I18n.tr("Comma-separated plugin or IPC source IDs")
        value: (root.store.setting("islandExcludedSources") || []).join(", ")
        onEditingFinished: value => root.store.apply("islandExcludedSources", value.split(",").map(id => id.trim()).filter(id => id))
    }

    SettingsSliderRow {
        text: I18n.tr("Persistent activity slots")
        description: I18n.tr("Maximum number of ongoing activities shown beside the island content")
        minimum: 0
        maximum: 6
        step: 1
        value: root.store.setting("islandActivitySlotLimit")
        onSliderValueChanged: value => root.store.apply("islandActivitySlotLimit", value)
    }

    Repeater {
        model: [...new Set(IslandActivityService.entries.filter(entry => entry.persistent).map(entry => entry.source).concat(Object.keys(root.store.setting("islandActivitySourceOverrides") || {})))]

        Column {
            id: sourceOptions
            required property string modelData
            width: parent.width
            spacing: Theme.spacingXS

            SettingsDropdownRow {
                text: I18n.tr("Activity position") + " · " + sourceOptions.modelData
                readonly property var values: ["activity", "left", "center", "right"]
                options: [I18n.tr("Set by activity"), I18n.tr("Left"), I18n.tr("Center"), I18n.tr("Right")]
                currentValue: options[Math.max(0, values.indexOf(root.sourceOverride(sourceOptions.modelData, "position")))]
                onValueChanged: value => root.setSourceOverride(sourceOptions.modelData, "position", values[options.indexOf(value)])
            }

            SettingsDropdownRow {
                text: I18n.tr("Collapsed content") + " · " + sourceOptions.modelData
                readonly property var values: ["activity", "icon", "label"]
                options: [I18n.tr("Set by activity"), I18n.tr("Icon"), I18n.tr("Label")]
                currentValue: options[Math.max(0, values.indexOf(root.sourceOverride(sourceOptions.modelData, "compact")))]
                onValueChanged: value => root.setSourceOverride(sourceOptions.modelData, "compact", values[options.indexOf(value)])
            }

            SettingsDropdownRow {
                text: I18n.tr("Click action") + " · " + sourceOptions.modelData
                readonly property var values: ["activity", "live", "home", "media", "clipboard", "controlcenter", "notificationcenter"]
                options: [I18n.tr("Set by activity"), I18n.tr("Live activity"), I18n.tr("Dashboard"), I18n.tr("Media"), I18n.tr("Clipboard"), I18n.tr("Control Center"), I18n.tr("Notifications")]
                currentValue: options[Math.max(0, values.indexOf(root.sourceOverride(sourceOptions.modelData, "clickActivity")))]
                onValueChanged: value => root.setSourceOverride(sourceOptions.modelData, "clickActivity", values[options.indexOf(value)])
            }
        }
    }

    SettingsToggleRow {
        visible: !root.usesBarWidgets
        text: I18n.tr("Keep media in the island")
        description: I18n.tr("Show album artwork in the collapsed dashboard while media is available")
        checked: root.store.setting("islandMediaAlwaysVisible")
        onToggled: checked => root.store.apply("islandMediaAlwaysVisible", checked)
    }

    SettingsSliderRow {
        text: I18n.tr("Collapsed island opacity")
        minimum: 0
        maximum: 100
        step: 5
        unit: "%"
        value: Math.round(root.store.setting("islandCompactOpacity") * 100)
        onSliderValueChanged: value => root.store.apply("islandCompactOpacity", value / 100)
    }

    SettingsToggleRow {
        text: I18n.tr("Match bar opacity when expanded")
        description: I18n.tr("Use the bar's opacity setting for the expanded island")
        checked: root.store.setting("islandExpandedOpacity") < 0
        onToggled: checked => root.store.apply("islandExpandedOpacity", checked ? -1 : 1)
    }

    SettingsSliderRow {
        text: I18n.tr("Expanded island opacity")
        minimum: 0
        maximum: 100
        step: 5
        unit: "%"
        value: Math.round(root.store.setting("islandExpandedOpacity") * 100)
        visible: root.store.setting("islandExpandedOpacity") >= 0
        onSliderValueChanged: value => root.store.apply("islandExpandedOpacity", value / 100)
    }

    SettingsToggleRow {
        visible: !root.usesBarWidgets
        text: I18n.tr("Show visualizer while idle")
        description: I18n.tr("Keep the audio bars visible while the player is paused")
        checked: root.store.setting("islandMediaVisualizerIdle")
        onToggled: checked => root.store.apply("islandMediaVisualizerIdle", checked)
    }

    SettingsToggleRow {
        visible: !root.usesBarWidgets
        text: I18n.tr("Circular media artwork")
        description: I18n.tr("Clip album art into a circle in the island")
        checked: root.store.setting("islandMediaArtworkCircular")
        onToggled: checked => root.store.apply("islandMediaArtworkCircular", checked)
    }

    SettingsDropdownRow {
        text: I18n.tr("Activity icon animation")
        readonly property var values: ["activity", "none", "wiggle", "pulse", "spin"]
        options: [I18n.tr("Set by activity"), I18n.tr("None"), I18n.tr("Wiggle"), I18n.tr("Pulse"), I18n.tr("Spin")]
        currentValue: options[Math.max(0, values.indexOf(root.store.setting("islandActivityIconMotion")))]
        onValueChanged: value => root.store.apply("islandActivityIconMotion", values[options.indexOf(value)] || "activity")
    }

    SettingsSliderRow {
        text: I18n.tr("Icon animation speed")
        minimum: 250
        maximum: 1500
        step: 50
        unit: "ms"
        value: root.store.setting("islandActivityIconMotionDuration")
        visible: root.store.setting("islandActivityIconMotion") !== "none"
        onSliderValueChanged: value => root.store.apply("islandActivityIconMotionDuration", value)
    }

    SettingsSliderRow {
        text: I18n.tr("Icon animation intensity")
        minimum: 10
        maximum: 100
        step: 5
        unit: "%"
        value: root.store.setting("islandActivityIconMotionIntensity")
        visible: root.store.setting("islandActivityIconMotion") === "activity" || root.store.setting("islandActivityIconMotion") === "wiggle" || root.store.setting("islandActivityIconMotion") === "pulse"
        onSliderValueChanged: value => root.store.apply("islandActivityIconMotionIntensity", value)
    }

    Repeater {
        model: NotificationInterceptorService.entries

        Column {
            required property var modelData
            width: parent.width
            spacing: Theme.spacingXS

            SettingsToggleRow {
                text: parent.modelData.label
                description: parent.modelData.description || parent.modelData.source + " · " + parent.modelData.id
                checked: NotificationInterceptorService.enabled(parent.modelData)
                onToggled: checked => NotificationInterceptorService.setEnabled(parent.modelData.source, parent.modelData.id, checked)
            }

            SettingsSliderRow {
                text: I18n.tr("Intercept priority")
                minimum: -100
                maximum: 100
                step: 1
                value: NotificationInterceptorService.priority(parent.modelData)
                onSliderValueChanged: value => NotificationInterceptorService.setPriority(parent.modelData.source, parent.modelData.id, value)
            }
        }
    }

    SettingsSliderRow {
        text: I18n.tr("Preview duration")
        minimum: 1000
        maximum: 15000
        step: 500
        unit: "ms"
        value: root.store.setting("islandActivityDuration")
        onSliderValueChanged: value => root.store.apply("islandActivityDuration", value)
    }

    SettingsToggleRow {
        text: I18n.tr("Pill shape")
        description: I18n.tr("Use fully rounded ends for the compact island")
        checked: root.store.setting("islandPillShape")
        onToggled: checked => root.store.apply("islandPillShape", checked)
    }

    Repeater {
        model: [
            {key: "islandCompactColor", label: I18n.tr("Compact background")},
            {key: "islandExpandedColor", label: I18n.tr("Expanded background")}
        ]

        ColorDropdownRow {
            required property var modelData
            text: modelData.label
            settingKey: root.keyPrefix + modelData.key
            resetStore: root.store
            resetKeys: [modelData.key]
            options: [{value: "default", label: I18n.tr("Default")}, {value: "custom", label: I18n.tr("Custom")}]
            currentMode: root.store.setting(modelData.key) ? "custom" : "default"
            customColor: root.store.setting(modelData.key) || Theme.hostSurface
            defaultColor: Theme.hostSurface
            onModeSelected: mode => root.store.apply(modelData.key, mode === "custom" ? customColor.toString() : "")
            onCustomColorSelected: selectedColor => root.store.apply(modelData.key, selectedColor.toString())
        }
    }

    SettingsToggleRow {
        text: I18n.tr("Activity colors")
        description: I18n.tr("Allow temporary activity colors and highlight errors")
        checked: root.store.setting("islandActivityColors")
        onToggled: checked => root.store.apply("islandActivityColors", checked)
    }
}
