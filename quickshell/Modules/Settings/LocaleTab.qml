import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    function capitalizeNativeLanguageName(localeCode) {
        if (I18n.presentLocales[localeCode] == undefined) {
            return;
        }
        const nativeName = I18n.presentLocales[localeCode].nativeLanguageName;
        return nativeName[0].toUpperCase() + nativeName.slice(1);
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
                    options: Object.keys(I18n.presentLocales).map(root.capitalizeNativeLanguageName)

                    Component.onCompleted: {
                        currentValue = root.capitalizeNativeLanguageName(I18n.currentLocale);
                    }

                    onValueChanged: value => {
                        for (let code of Object.keys(I18n.presentLocales)) {
                            if (root.capitalizeNativeLanguageName(code) === value) {
                                I18n._useLocale(code, I18n.folder + "/" + code + ".json");
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
}
