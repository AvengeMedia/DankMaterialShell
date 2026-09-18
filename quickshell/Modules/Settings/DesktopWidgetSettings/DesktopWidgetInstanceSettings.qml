import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property bool showAppearance: true
    property bool showPlacement: true
    readonly property var cfg: instanceData?.config ?? {}
    default property alias rows: rowsColumn.data

    function updateConfig(key, value) {
        const updates = {};
        updates[key] = value;
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates);
    }

    width: parent?.width ?? 400
    spacing: 0

    Column {
        id: rowsColumn
        width: parent.width
        spacing: 0
    }

    SettingsDivider {
        visible: root.showAppearance
    }

    SettingsSliderRow {
        visible: root.showAppearance
        text: I18n.tr("Opacity")
        minimum: 0
        maximum: 100
        value: Math.round((root.cfg.transparency ?? 0.8) * 100)
        onSliderValueChanged: newValue => root.updateConfig("transparency", newValue / 100)
    }

    SettingsDivider {
        visible: root.showAppearance
    }

    SettingsColorPicker {
        visible: root.showAppearance
        colorMode: root.cfg.colorMode ?? "primary"
        customColor: root.cfg.customColor ?? "#ffffff"
        onColorModeSelected: mode => root.updateConfig("colorMode", mode)
        onCustomColorSelected: selectedColor => root.updateConfig("customColor", selectedColor.toString())
    }

    SettingsDivider {
        visible: root.showAppearance && root.showPlacement
    }

    SettingsDisplayPicker {
        visible: root.showPlacement
        displayPreferences: root.cfg.displayPreferences ?? ["all"]
        onPreferencesChanged: prefs => root.updateConfig("displayPreferences", prefs)
    }

    SettingsDivider {
        visible: root.showPlacement
    }

    Item {
        visible: root.showPlacement
        width: parent.width
        height: resetRow.height + Theme.spacingM * 2

        Row {
            id: resetRow
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            DankButton {
                text: I18n.tr("Reset Position")
                backgroundColor: Theme.chipSurface
                textColor: Theme.surfaceText
                onClicked: SessionData.resetDesktopWidgetInstanceGeometry(root.instanceId, ["x", "y"])
            }

            DankButton {
                text: I18n.tr("Reset Size")
                backgroundColor: Theme.chipSurface
                textColor: Theme.surfaceText
                onClicked: SessionData.resetDesktopWidgetInstanceGeometry(root.instanceId, ["width", "height"])
            }
        }
    }
}
