import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: localeTab

    readonly property string _systemDefaultLabel: I18n.tr("System Default")

    function capitalizeNativeLanguageName(localeCode) {
        if (I18n.presentLocales[localeCode] == undefined) {
            return;
        }
        const nativeName = I18n.presentLocales[localeCode].nativeLanguageName;
        return nativeName[0].toUpperCase() + nativeName.slice(1);
    }

    function _displayValue() {
        if (!SessionData.locale) return _systemDefaultLabel;
        return capitalizeNativeLanguageName(SessionData.locale);
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                tab: "locale"
                tags: ["locale", "language", "country"]
                title: I18n.tr("Locale Settings")
                iconName: "language"

                SettingsDropdownRow {
                    id: localeDropdown
                    tab: "locale"
                    tags: ["locale", "language", "country"]
                    settingKey: "locale"
                    text: I18n.tr("Current Locale")
                    description: I18n.tr("Change the locale used by the DMS interface.")
                    options: [localeTab._systemDefaultLabel].concat(Object.keys(I18n.presentLocales).map(localeTab.capitalizeNativeLanguageName))
                    enableFuzzySearch: true

                    Component.onCompleted: {
                        currentValue = localeTab._displayValue();
                    }

                    onValueChanged: value => {
                        if (value === localeTab._systemDefaultLabel) {
                            SessionData.set("locale", "");
                            return;
                        }
                        for (let code of Object.keys(I18n.presentLocales)) {
                            if (localeTab.capitalizeNativeLanguageName(code) === value) {
                                SessionData.set("locale", code);
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
}
