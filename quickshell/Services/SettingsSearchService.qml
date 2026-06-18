pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("SettingsSearchService")

    property string query: ""
    property var results: []
    property string targetSection: ""
    property string highlightSection: ""
    property var registeredCards: ({})
    property var settingsIndex: []
    property bool indexLoaded: false
    property var _translatedCache: []

    Connections {
        target: I18n

        function onTranslationsChanged() {
            root._refreshTranslatedCache();
        }

        function onTranslationsLoadedChanged() {
            root._refreshTranslatedCache();
        }
    }

    readonly property var conditionMap: ({
            "isNiri": () => CompositorService.isNiri,
            "isHyprland": () => CompositorService.isHyprland,
            "isMango": () => CompositorService.isMango,
            "isHyprlandOrNiri": () => CompositorService.isHyprland || CompositorService.isNiri,
            "windowRulesCapable": () => CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango,
            "layoutCapable": () => CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango,
            "keybindsAvailable": () => KeybindsService.available,
            "soundsAvailable": () => AudioService.soundsAvailable,
            "cupsAvailable": () => CupsService.cupsAvailable,
            "networkNotLegacy": () => !NetworkService.usingLegacy,
            "dmsConnected": () => DMSService.isConnected && DMSService.apiVersion >= 23,
            "matugenAvailable": () => Theme.matugenAvailable
        })

    Component.onCompleted: indexFile.reload()

    FileView {
        id: indexFile
        path: Qt.resolvedUrl("../translations/settings_search_index.json")
        onLoaded: {
            try {
                root.settingsIndex = JSON.parse(text());
                root.indexLoaded = true;
                root._rebuildTranslationCache();
            } catch (e) {
                log.warn("Failed to parse index:", e);
                root.settingsIndex = [];
                root._translatedCache = [];
            }
        }
        onLoadFailed: error => log.warn("Failed to load index:", error)
    }

    function registerCard(settingKey, item, flickable) {
        if (!settingKey)
            return;
        var cards = Object.assign({}, registeredCards);
        cards[settingKey] = {
            item: item,
            flickable: flickable
        };
        registeredCards = cards;
        if (targetSection === settingKey)
            scrollTimer.restart();
    }

    function unregisterCard(settingKey) {
        if (!settingKey)
            return;
        var cards = Object.assign({}, registeredCards);
        delete cards[settingKey];
        registeredCards = cards;
    }

    function navigateToSection(section) {
        targetSection = section;
        if (registeredCards[section])
            scrollTimer.restart();
    }

    function scrollToTarget() {
        if (!targetSection)
            return;
        const entry = registeredCards[targetSection];
        if (!entry || !entry.item || !entry.flickable)
            return;
        const flickable = entry.flickable;
        const item = entry.item;
        const contentItem = flickable.contentItem;

        if (!contentItem)
            return;
        const mapped = item.mapToItem(contentItem, 0, 0);
        const maxY = Math.max(0, flickable.contentHeight - flickable.height);
        const targetY = Math.min(maxY, Math.max(0, mapped.y - 16));
        flickable.contentY = targetY;

        highlightSection = targetSection;
        targetSection = "";
        highlightTimer.restart();
    }

    function clearHighlight() {
        highlightSection = "";
    }

    Timer {
        id: scrollTimer
        interval: 50
        onTriggered: root.scrollToTarget()
    }

    Timer {
        id: highlightTimer
        interval: 2500
        onTriggered: root.highlightSection = ""
    }

    function checkCondition(item) {
        if (!item.conditionKey)
            return true;
        const condFn = conditionMap[item.conditionKey];
        if (!condFn)
            return true;
        return condFn();
    }

    function translateItem(item) {
        return {
            section: item.section,
            label: I18n.tr(item.label),
            tabIndex: item.tabIndex,
            category: I18n.tr(item.category),
            keywords: item.keywords || [],
            icon: item.icon || "settings",
            description: item.description ? I18n.tr(item.description) : "",
            conditionKey: item.conditionKey
        };
    }

    function _rebuildTranslationCache() {
        var cache = [];
        for (var i = 0; i < settingsIndex.length; i++) {
            var item = settingsIndex[i];
            var t = translateItem(item);
            var sourceDescription = item.description || "";
            var labelLower = _lowerVariants([item.label, t.label]);
            var categoryLower = _lowerVariants([item.category, t.category]);
            var descriptionLower = _lowerVariants([sourceDescription, t.description]);
            cache.push({
                section: t.section,
                label: t.label,
                tabIndex: t.tabIndex,
                category: t.category,
                keywords: t.keywords,
                icon: t.icon,
                description: t.description,
                conditionKey: t.conditionKey,
                isTab: String(t.section).startsWith("_tab_"),
                labelSearch: labelLower,
                categorySearch: categoryLower,
                descriptionSearch: descriptionLower,
                labelSquash: _squashVariants(labelLower),
                categorySquash: _squashVariants(categoryLower),
                descriptionSquash: _squashVariants(descriptionLower),
                keywordsSquash: _squashVariants(t.keywords)
            });
        }
        _translatedCache = cache;
    }

    function _lowerVariants(values) {
        var out = [];
        for (var i = 0; i < values.length; i++) {
            var value = values[i];
            if (!value)
                continue;
            var lower = String(value).toLowerCase();
            if (out.indexOf(lower) === -1)
                out.push(lower);
        }
        return out;
    }

    function _squash(value) {
        return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "");
    }

    function _squashVariants(values) {
        var out = [];
        for (var i = 0; i < values.length; i++) {
            if (!values[i])
                continue;
            var squashed = _squash(values[i]);
            if (squashed && out.indexOf(squashed) === -1)
                out.push(squashed);
        }
        return out;
    }

    function _bestFieldScore(fields, queryLower, exactScore, prefixScore, includesScore) {
        var score = 0;
        for (var i = 0; i < fields.length; i++) {
            var field = fields[i];
            if (field === queryLower) {
                score = Math.max(score, exactScore);
            } else if (field.startsWith(queryLower)) {
                score = Math.max(score, prefixScore);
            } else if (field.includes(queryLower)) {
                score = Math.max(score, includesScore);
            }
        }
        return score;
    }

    function _fieldsContainWord(fields, word) {
        for (var i = 0; i < fields.length; i++) {
            if (fields[i].includes(word))
                return true;
        }
        return false;
    }

    function _refreshTranslatedCache() {
        if (!indexLoaded)
            return;
        _rebuildTranslationCache();
        if (query)
            results = _searchEntries(query, 15);
    }

    function _searchEntries(text, maxResults) {
        if (!text)
            return [];

        var queryLower = text.toLowerCase().trim();
        var querySquash = _squash(queryLower);
        var queryWords = queryLower.split(/\s+/).filter(w => w.length > 0);
        var scored = [];
        var cache = _translatedCache;
        var limit = maxResults > 0 ? maxResults : 15;

        for (var i = 0; i < cache.length; i++) {
            var entry = cache[i];
            if (!checkCondition(entry))
                continue;

            var labelScore = _bestFieldScore(entry.labelSearch, queryLower, 10000, 5000, 1000);
            if (querySquash)
                labelScore = Math.max(labelScore, _bestFieldScore(entry.labelSquash, querySquash, 9000, 4500, 900));

            var score = labelScore;
            score = Math.max(score, _bestFieldScore(entry.categorySearch, queryLower, 500, 500, 500));
            score = Math.max(score, _bestFieldScore(entry.descriptionSearch, queryLower, 250, 250, 250));
            if (querySquash) {
                score = Math.max(score, _bestFieldScore(entry.categorySquash, querySquash, 500, 500, 500));
                score = Math.max(score, _bestFieldScore(entry.descriptionSquash, querySquash, 250, 250, 250));
            }

            if (score === 0) {
                var keywords = entry.keywords;
                for (var k = 0; k < keywords.length; k++) {
                    var keyword = keywords[k];
                    if (keyword === queryLower) {
                        score = 900;
                        break;
                    }
                    if (keyword.startsWith(queryLower)) {
                        score = Math.max(score, 800);
                    } else if (keyword.includes(queryLower) && score < 400) {
                        score = 400;
                    }
                }
            }

            if (score === 0 && querySquash) {
                var keywordsSquash = entry.keywordsSquash;
                for (var ks = 0; ks < keywordsSquash.length; ks++) {
                    if (keywordsSquash[ks] === querySquash) {
                        score = Math.max(score, 850);
                        break;
                    }
                    if (keywordsSquash[ks].startsWith(querySquash)) {
                        score = Math.max(score, 750);
                    }
                }
            }

            if (score === 0 && queryWords.length > 1) {
                var allMatch = true;
                for (var w = 0; w < queryWords.length; w++) {
                    var word = queryWords[w];
                    if (_fieldsContainWord(entry.labelSearch, word))
                        continue;
                    if (_fieldsContainWord(entry.descriptionSearch, word))
                        continue;
                    if (_fieldsContainWord(entry.categorySearch, word))
                        continue;
                    var inKeywords = false;
                    for (var k = 0; k < entry.keywords.length; k++) {
                        if (entry.keywords[k].includes(word)) {
                            inKeywords = true;
                            break;
                        }
                    }
                    if (!inKeywords) {
                        allMatch = false;
                        break;
                    }
                }
                if (allMatch)
                    score = 300;
            }

            if (score > 0) {
                scored.push({
                    item: entry,
                    score: score,
                    labelScore: labelScore
                });
            }
        }

        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            if (b.labelScore !== a.labelScore)
                return b.labelScore - a.labelScore;
            if (a.item.isTab !== b.item.isTab)
                return a.item.isTab ? 1 : -1;
            return a.item.label.length - b.item.label.length;
        });
        return scored.slice(0, limit).map(s => s.item);
    }

    function searchForLauncher(text) {
        return _searchEntries(text, 15);
    }

    function search(text) {
        query = text;
        if (!text) {
            results = [];
            return;
        }
        results = _searchEntries(text, 15);
    }

    function clear() {
        query = "";
        results = [];
    }
}
