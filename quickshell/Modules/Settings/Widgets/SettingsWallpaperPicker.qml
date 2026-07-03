pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets

Column {
    id: root

    property string path: ""
    property string fillMode: ""
    property string fallbackFillMode: "Fill"
    property string browserTitle: I18n.tr("Select background image")
    property string placeholderText: I18n.tr("Use desktop wallpaper")
    property string fillModeSettingKey: ""
    property var fillModeTags: []

    signal pathSelected(string path)
    signal fillModeSelected(string mode)

    readonly property var _fillModes: ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]

    spacing: Theme.spacingS

    FileBrowserModal {
        id: wallpaperBrowserModal
        browserTitle: root.browserTitle
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif"]
        onFileSelected: path => {
            root.pathSelected(path);
            close();
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        DankTextField {
            id: wallpaperPathField
            width: parent.width - browseWallpaperButton.width - Theme.spacingS
            placeholderText: root.placeholderText
            text: root.path
            backgroundColor: Theme.surfaceContainerHighest
            onTextChanged: {
                if (text !== root.path)
                    root.pathSelected(text);
            }
        }

        DankButton {
            id: browseWallpaperButton
            text: I18n.tr("Browse")
            horizontalPadding: Theme.spacingL
            onClicked: wallpaperBrowserModal.open()
        }
    }

    SettingsDropdownRow {
        settingKey: root.fillModeSettingKey
        tags: root.fillModeTags
        text: I18n.tr("Wallpaper fill mode")
        description: I18n.tr("How the background image is scaled")
        options: root._fillModes.map(m => I18n.tr(m, "wallpaper fill mode"))
        currentValue: {
            var mode = (root.fillMode && root.fillMode !== "") ? root.fillMode : root.fallbackFillMode;
            var idx = root._fillModes.indexOf(mode);
            return idx >= 0 ? I18n.tr(root._fillModes[idx], "wallpaper fill mode") : I18n.tr("Fill", "wallpaper fill mode");
        }
        onValueChanged: value => {
            var idx = root._fillModes.map(m => I18n.tr(m, "wallpaper fill mode")).indexOf(value);
            if (idx >= 0)
                root.fillModeSelected(root._fillModes[idx]);
        }
    }
}
