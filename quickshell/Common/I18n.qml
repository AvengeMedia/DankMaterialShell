pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("I18n")

    property string _resolvedLocale: "en"

    readonly property string _rawLocale: SessionData.locale === "" ? Qt.locale().name : SessionData.locale
    readonly property string _lang: _rawLocale.split(/[_-]/)[0]
    readonly property var _candidates: {
        const fullUnderscore = _rawLocale;
        const fullHyphen = _rawLocale.replace("_", "-");
        return [fullUnderscore, fullHyphen, _lang].filter(c => c && c !== "en");
    }

    readonly property var _rtlLanguages: ["ar", "he", "iw", "fa", "ur", "ps", "sd", "dv", "yi", "ku"]
    readonly property bool isRtl: _rtlLanguages.includes(_lang)

    readonly property url translationsFolder: Qt.resolvedUrl("../translations/poexports")
    readonly property url commonTranslationsFolder: Qt.resolvedUrl("../DankCommon/translations/poexports")

    readonly property alias folder: dir.folder
    property var presentLocales: ({
            "en": Qt.locale("en")
        })
    property var translations: ({})
    property bool translationsLoaded: false
    property var commonTranslations: ({})
    property bool commonTranslationsLoaded: false

    property url _selectedPath: ""
    property url _commonSelectedPath: ""

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

    FolderListModel {
        id: commonDir
        folder: root.commonTranslationsFolder
        nameFilters: ["*.json"]
        showDirs: false
        showDotAndDotDot: false

        onStatusChanged: if (status === FolderListModel.Ready) {
            root._pickCommonTranslation();
        }
    }

    FileView {
        id: translationLoader
        path: root._selectedPath

        onLoaded: {
            try {
                root.translations = JSON.parse(text());
                root.translationsLoaded = true;
                log.info(`I18n: Loaded translations for '${root._resolvedLocale}' (${Object.keys(root.translations).length} contexts)`);
            } catch (e) {
                log.warn(`I18n: Error parsing '${root._resolvedLocale}':`, e, "- falling back to English");
                root._fallbackToEnglish();
            }
        }

        onLoadFailed: error => {
            log.warn(`I18n: Failed to load '${root._resolvedLocale}' (${error}), ` + "falling back to English");
            root._fallbackToEnglish();
        }
    }

    FileView {
        id: commonTranslationLoader
        path: root._commonSelectedPath
        printErrors: false

        onLoaded: {
            try {
                root.commonTranslations = JSON.parse(text());
                root.commonTranslationsLoaded = true;
                log.info(`I18n: Loaded DankCommon translations (${Object.keys(root.commonTranslations).length} contexts)`);
            } catch (e) {
                log.warn("I18n: Error parsing DankCommon translations:", e);
            }
        }
    }

    function locale() {
        if (SessionData.timeLocale)
            return Qt.locale(SessionData.timeLocale);
        return Qt.locale();
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
            if (presentLocales[cand] === undefined)
                continue;
            _resolvedLocale = cand;
            useLocale(cand, cand.startsWith("en") ? "" : translationsFolder + "/" + cand + ".json");
            return;
        }

        _resolvedLocale = "en";
        _fallbackToEnglish();
    }

    function useLocale(localeTag, fileUrl) {
        _resolvedLocale = localeTag || "en";
        _selectedPath = fileUrl;
        translationsLoaded = false;
        translations = ({});
        log.info(`I18n: Using locale '${localeTag}' from ${fileUrl}`);
    }

    function _fallbackToEnglish() {
        _selectedPath = "";
        translationsLoaded = false;
        translations = ({});
        log.warn("Falling back to built-in English strings");
    }

    function _pickCommonTranslation() {
        const present = {};
        for (let i = 0; i < commonDir.count; i++) {
            const name = commonDir.get(i, "fileName");
            if (name && name.endsWith(".json"))
                present[name.slice(0, -5)] = true;
        }
        for (let i = 0; i < _candidates.length; i++) {
            if (!present[_candidates[i]])
                continue;
            _commonSelectedPath = commonTranslationsFolder + "/" + _candidates[i] + ".json";
            return;
        }
    }

    function _lookup(table, term, context) {
        if (!table)
            return "";
        if (context && table[context] && table[context][term])
            return table[context][term];
        if (table[term] && table[term][term])
            return table[term][term];
        for (const c in table) {
            if (table[c] && table[c][term])
                return table[c][term];
        }
        return "";
    }

    // isRealContext is consumed by translations/extract_translations.py only:
    // pass a literal `true` (same line) to give (term, context) its own POEditor
    // translation slot. Lookup ignores it -- a real context exists as a bucket
    // in the export, a comment-only context does not.
    function tr(term, context, isRealContext) {
        if (translationsLoaded) {
            const hit = _lookup(translations, term, context);
            if (hit)
                return hit;
        }
        if (commonTranslationsLoaded) {
            const hit = _lookup(commonTranslations, term, context);
            if (hit)
                return hit;
        }
        return term;
    }

    function trContext(context, term) {
        if (translationsLoaded && translations[context] && translations[context][term])
            return translations[context][term];
        if (commonTranslationsLoaded && commonTranslations[context] && commonTranslations[context][term])
            return commonTranslations[context][term];
        return term;
    }
}
