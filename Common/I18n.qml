import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    readonly property string _rawLocale: Qt.locale().name
    readonly property string _lang: _rawLocale.split(/[_-]/)[0]
    readonly property var    _candidates: {
        const fullUnderscore = _rawLocale;
        const fullHyphen     = _rawLocale.replace("_", "-");
        return [fullUnderscore, fullHyphen, _lang].filter(c => c && c !== "en");
    }

  
    readonly property url translationsFolder: Qt.resolvedUrl("../translations/poexports")

    property string currentLocale: "en"
    property var    translations: ({})
    property bool   translationsLoaded: false

    property url _selectedPath: ""

    FolderListModel {
        id: dir
        folder: root.translationsFolder
        nameFilters: ["*.json"]
        showDirs: false
        showDotAndDotDot: false

        onStatusChanged: if (status === FolderListModel.Ready) root._pickTranslation()
    }

    FileView {
        id: translationLoader
        path: root._selectedPath

        onLoaded: {
            try {
                root.translations = JSON.parse(text())
                root.translationsLoaded = true
                console.log(`I18n: Loaded translations for '${root.currentLocale}' ` +
                            `(${Object.keys(root.translations).length} contexts)`)
            } catch (e) {
                console.warn(`I18n: Error parsing '${root.currentLocale}':`, e,
                             "- falling back to English")
                root._fallbackToEnglish()
            }
        }

        onLoadFailed: (error) => {
            console.warn(`I18n: Failed to load '${root.currentLocale}' (${error}), ` +
                         "falling back to English")
            root._fallbackToEnglish()
        }
    }

    function _pickTranslation() {
        const present = new Set()
        for (let i = 0; i < dir.count; i++) {
            const name = dir.get(i, "fileName") // e.g. "zh_CN.json"
            if (name && name.endsWith(".json")) {
                present.add(name.slice(0, -5))
            }
        }

        for (let i = 0; i < _candidates.length; i++) {
            const cand = _candidates[i]
            if (present.has(cand)) {
                _useLocale(cand, dir.folder + "/" + cand + ".json")
                return
            }
        }

        _fallbackToEnglish()
    }

    function _useLocale(localeTag, fileUrl) {
        currentLocale = localeTag
        _selectedPath = fileUrl
        translationsLoaded = false
        translations = ({})
        console.log(`I18n: Using locale '${localeTag}' from ${fileUrl}`)
    }

    function _fallbackToEnglish() {
        currentLocale = "en"
        _selectedPath = ""
        translationsLoaded = false
        translations = ({})
        console.warn("I18n: Falling back to built-in English strings")
    }

    function tr(term, context) {
        if (!translationsLoaded || !translations) return term
        const ctx = context || term
        if (translations[ctx] && translations[ctx][term]) return translations[ctx][term]
        for (const c in translations) {
            if (translations[c] && translations[c][term]) return translations[c][term]
        }
        return term
    }

    function trContext(context, term) {
        if (!translationsLoaded || !translations) return term
        if (translations[context] && translations[context][term]) return translations[context][term]
        return term
    }
}
