pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property var displayPreferences: []

    signal preferencesChanged(var preferences)

    property bool emptyMeansAll: true

    function coversAllDisplays(prefs) {
        return !Array.isArray(prefs) || prefs.includes("all") || (emptyMeansAll && prefs.length === 0);
    }

    function screenPref(screen) {
        const pref = {
            name: screen.name,
            model: screen.model || ""
        };
        const modelIndex = SettingsData.getScreenModelIndex(screen);
        if (modelIndex >= 0)
            pref.modelIndex = modelIndex;
        return pref;
    }

    property bool localAllDisplays: coversAllDisplays(displayPreferences)

    onDisplayPreferencesChanged: localAllDisplays = coversAllDisplays(displayPreferences)

    width: parent?.width ?? 0
    height: displayColumn.height + Theme.spacingM * 2

    Column {
        id: displayColumn
        width: parent.width - Theme.spacingM * 2
        x: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        StyledText {
            text: I18n.tr("Displays")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("All displays")
            checked: root.localAllDisplays
            onToggled: isChecked => {
                root.localAllDisplays = isChecked;
                if (isChecked) {
                    root.preferencesChanged(["all"]);
                    return;
                }
                root.preferencesChanged(Quickshell.screens.map(s => root.screenPref(s)));
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: !root.localAllDisplays

            Repeater {
                model: Quickshell.screens

                DankToggle {
                    required property var modelData

                    property bool localChecked: {
                        const prefs = root.displayPreferences;
                        if (!Array.isArray(prefs) || prefs.includes("all"))
                            return true;
                        return prefs.some(p => p.name === modelData.name);
                    }

                    width: parent.width
                    text: SettingsData.getScreenDisplayName(modelData)
                    description: modelData.width + "×" + modelData.height + " • " + (SettingsData.displayNameMode === "system" ? (modelData.model || I18n.tr("Unknown Model")) : modelData.name)
                    checked: localChecked
                    onToggled: isChecked => {
                        var prefs = JSON.parse(JSON.stringify(root.displayPreferences));
                        if (!Array.isArray(prefs) || prefs.includes("all"))
                            prefs = [];
                        prefs = prefs.filter(p => p.name !== modelData.name);
                        if (isChecked)
                            prefs.push(root.screenPref(modelData));
                        if (prefs.length === 0) {
                            localChecked = true;
                            return;
                        }
                        localChecked = isChecked;
                        root.preferencesChanged(prefs);
                    }
                }
            }
        }
    }
}
