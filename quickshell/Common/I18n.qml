pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _rawLocale: SettingsData.locale === "" ? Qt.locale().name : SettingsData.locale
    readonly property string _lang: _rawLocale.split(/[_-]/)[0]
    readonly property var _candidates: {
        const fullUnderscore = _rawLocale;
        const fullHyphen = _rawLocale.replace("_", "-");
        return [fullUnderscore, fullHyphen, _lang].filter(c => c && c !== "en");
    }

    readonly property var _rtlLanguages: ["ar", "he", "iw", "fa", "ur", "ps", "sd", "dv", "yi", "ku"]
    readonly property bool isRtl: _rtlLanguages.includes(_lang)

    readonly property url translationsFolder: Qt.resolvedUrl("../translations/poexports")

    readonly property alias folder: dir.folder
    property var presentLocales: ({ "en": Qt.locale("en") })
    property var translations: ({})
    property bool translationsLoaded: false

    property url _selectedPath: ""

    FolderListModel {
        id: dir
        folder: root.translationsFolder
        nameFilters: ["*.json"]
        showDirs: false
        showDotAndDotDot: false

        onStatusChanged: if (status === FolderListModel.Ready) {
            root._loadPresentLocales();
            root._pickTranslation();
        }
    }

    FileView {
        id: translationLoader
        path: root._selectedPath

        onLoaded: {
            try {
                root.translations = JSON.parse(text());
                root.translationsLoaded = true;
                console.info(`I18n: Loaded translations for '${SettingsData.locale}' (${Object.keys(root.translations).length} contexts)`);
            } catch (e) {
                console.warn(`I18n: Error parsing '${SettingsData.locale}':`, e, "- falling back to English");
                root._fallbackToEnglish();
            }
        }

        onLoadFailed: error => {
            console.warn(`I18n: Failed to load '${SettingsData.locale}' (${error}), ` + "falling back to English");
            root._fallbackToEnglish();
        }
    }

    // for replacing Qt.locale()
    function locale() {
        return presentLocales[SettingsData.locale] ?? presentLocales["en"];
    }

    function _loadPresentLocales() {
        if (Object.keys(presentLocales).length > 1) {
            return; // already loaded
        }
        for (let i = 0; i < dir.count; i++) {
            const name = dir.get(i, "fileName"); // e.g. "zh_CN.json"
            if (name && name.endsWith(".json")) {
                const shortName = name.slice(0, -5);
                presentLocales[shortName] = Qt.locale(shortName);
            }
        }
    }

    function _pickTranslation() {
        for (let i = 0; i < _candidates.length; i++) {
            const cand = _candidates[i];
            if (presentLocales[cand] !== undefined) {
                SettingsData.set("locale", cand);
                return;
            }
        }

        _fallbackToEnglish();
    }

    function useLocale(localeTag, fileUrl) {
        _selectedPath = fileUrl;
        translationsLoaded = false;
        translations = ({});
        console.info(`I18n: Using locale '${localeTag}' from ${fileUrl}`);
    }

    function _fallbackToEnglish() {
        _selectedPath = "";
        translationsLoaded = false;
        translations = ({});
        console.warn("I18n: Falling back to built-in English strings");
    }

    function tr(term, context) {
        if (!translationsLoaded || !translations)
            return term;
        const ctx = context || term;
        if (translations[ctx] && translations[ctx][term])
            return translations[ctx][term];
        for (const c in translations) {
            if (translations[c] && translations[c][term])
                return translations[c][term];
        }
        return term;
    }

    function trContext(context, term) {
        if (!translationsLoaded || !translations)
            return term;
        if (translations[context] && translations[context][term])
            return translations[context][term];
        return term;
    }
}
