pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property string query: ""
    property var results: []
    property string targetSection: ""
    property string highlightSection: ""
    property var registeredCards: ({})
    property var settingsIndex: []
    property bool indexLoaded: false
    property var _translatedCache: []

    readonly property var conditionMap: ({
            "isNiri": () => CompositorService.isNiri,
            "isHyprland": () => CompositorService.isHyprland,
            "isDwl": () => CompositorService.isDwl,
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
                console.warn("SettingsSearchService: Failed to parse index:", e);
                root.settingsIndex = [];
                root._translatedCache = [];
            }
        }
        onLoadFailed: error => console.warn("SettingsSearchService: Failed to load index:", error)
    }

    function registerCard(settingKey, item, flickable) {
        if (!settingKey)
            return;
        registeredCards[settingKey] = {
            item: item,
            flickable: flickable
        };
        if (targetSection === settingKey)
            scrollTimer.restart();
    }

    function unregisterCard(settingKey) {
        if (!settingKey)
            return;
        let cards = registeredCards;
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
            cache.push({
                section: t.section,
                label: t.label,
                tabIndex: t.tabIndex,
                category: t.category,
                keywords: t.keywords,
                icon: t.icon,
                description: t.description,
                conditionKey: t.conditionKey,
                labelLower: t.label.toLowerCase(),
                categoryLower: t.category.toLowerCase()
            });
        }
        _translatedCache = cache;
    }

    function search(text) {
        query = text;
        if (!text) {
            results = [];
            return;
        }

        var queryLower = text.toLowerCase().trim();
        var queryWords = queryLower.split(/\s+/).filter(w => w.length > 0);
        var scored = [];
        var cache = _translatedCache;

        for (var i = 0; i < cache.length; i++) {
            var entry = cache[i];
            if (!checkCondition(entry))
                continue;

            var labelLower = entry.labelLower;
            var categoryLower = entry.categoryLower;
            var score = 0;

            if (labelLower === queryLower) {
                score = 10000;
            } else if (labelLower.startsWith(queryLower)) {
                score = 5000;
            } else if (labelLower.includes(queryLower)) {
                score = 1000;
            } else if (categoryLower.includes(queryLower)) {
                score = 500;
            }

            if (score === 0) {
                var keywords = entry.keywords;
                for (var k = 0; k < keywords.length; k++) {
                    if (keywords[k].startsWith(queryLower)) {
                        score = 800;
                        break;
                    }
                    if (keywords[k].includes(queryLower) && score < 400) {
                        score = 400;
                    }
                }
            }

            if (score === 0 && queryWords.length > 1) {
                var allMatch = true;
                for (var w = 0; w < queryWords.length; w++) {
                    var word = queryWords[w];
                    if (labelLower.includes(word))
                        continue;
                    var inKeywords = false;
                    for (var k = 0; k < entry.keywords.length; k++) {
                        if (entry.keywords[k].includes(word)) {
                            inKeywords = true;
                            break;
                        }
                    }
                    if (!inKeywords && !categoryLower.includes(word)) {
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
                    score: score
                });
            }
        }

        scored.sort((a, b) => b.score - a.score);
        results = scored.slice(0, 15).map(s => s.item);
    }

    function clear() {
        query = "";
        results = [];
    }
}
