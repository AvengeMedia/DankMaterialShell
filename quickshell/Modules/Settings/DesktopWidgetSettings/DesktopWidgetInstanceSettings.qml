import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property bool showAppearance: true
    property bool showPlacement: true
    readonly property var cfg: instanceData?.config ?? {}
    default property alias rows: optionsCard.content

    function updateConfig(key, value) {
        const updates = {};
        updates[key] = value;
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates);
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        id: optionsCard
    }

    SettingsCard {
        title: I18n.tr("Appearance")
        visible: root.showAppearance

        SettingsSliderRow {
            text: I18n.tr("Opacity")
            minimum: 0
            maximum: 100
            value: Math.round((root.cfg.transparency ?? 0.8) * 100)
            onSliderValueChanged: newValue => root.updateConfig("transparency", newValue / 100)
        }

        SettingsColorPicker {
            colorMode: root.cfg.colorMode ?? "primary"
            customColor: root.cfg.customColor ?? "#ffffff"
            onColorModeSelected: mode => root.updateConfig("colorMode", mode)
            onCustomColorSelected: selectedColor => root.updateConfig("customColor", selectedColor.toString())
        }
    }

    SettingsCard {
        title: I18n.tr("Displays")
        visible: root.showPlacement

        SettingsDisplayPicker {
            displayPreferences: root.cfg.displayPreferences ?? ["all"]
            onPreferencesChanged: prefs => root.updateConfig("displayPreferences", prefs)
        }

        SettingsRow {
            iconName: "drag_pan"
            title: I18n.tr("Reset Position")
            clickable: true
            onClicked: SessionData.resetDesktopWidgetInstanceGeometry(root.instanceId, ["x", "y"])
        }

        SettingsRow {
            iconName: "open_in_full"
            title: I18n.tr("Reset Size")
            clickable: true
            onClicked: SessionData.resetDesktopWidgetInstanceGeometry(root.instanceId, ["width", "height"])
        }
    }
}
