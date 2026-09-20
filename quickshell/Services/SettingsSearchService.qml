pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.DankDash

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
    property int _scrollPass: 0
    property int _stablePasses: 0
    property real _appliedY: 0
    property string _lastGeometry: ""
    readonly property int settleInterval: 250
    readonly property int stablePassesNeeded: 4
    readonly property int maxScrollPasses: 12

    Connections {
        target: I18n

        function onTranslationsChanged() {
            root._refreshTranslatedCache();
        }

        function onTranslationsLoadedChanged() {
            root._refreshTranslatedCache();
        }
    }

    Connections {
        target: PluginService

        function onPluginListUpdated() {
            root._refreshTranslatedCache();
        }
    }

    readonly property var conditionMap: ({
            "isNiri": () => CompositorService.isNiri,
            "pointerCapable": () => CompositorService.supportsPointerConfig,
            "isHyprland": () => CompositorService.isHyprland,
            "isMango": () => CompositorService.isMango,
            "isAqueous": () => CompositorService.isAqueous,
            "nativeOverviewCapable": () => CompositorService.supportsNativeOverview,
            "smartDockCapable": () => CompositorService.supportsSmartDock,
            "workspaceFollowFocusCapable": () => CompositorService.supportsWorkspaceFollowFocus,
            "isHyprlandOrNiri": () => CompositorService.isHyprland || CompositorService.isNiri,
            "windowRulesCapable": () => CompositorService.supportsWindowRules,
            "layoutCapable": () => CompositorService.supportsLayoutConfig,
            "keybindsAvailable": () => KeybindsService.available,
            "soundsAvailable": () => !MultimediaService.unavailable,
            "cupsAvailable": () => CupsService.cupsAvailable,
            "networkAvailable": () => NetworkService.networkAvailable,
            "dmsConnected": () => DMSService.isConnected && DMSService.apiVersion >= 23,
            "matugenAvailable": () => Theme.matugenAvailable,
            "greeterAvailable": () => GreeterService.available,
            "frameEnabled": () => SettingsData.frameEnabled,
            "islandEnabled": () => SettingsData.islandBarConfigs.length > 0,
            "cellularAvailable": () => (NetworkService.cellularDevices?.length ?? 0) > 0
        })

    property var pluginSettingLabels: ({})

    Component.onCompleted: indexFile.reload()

    Instantiator {
        model: (PluginService.availablePluginsList || []).filter(plugin => !!plugin.settingsPath)

        FileView {
            required property var modelData

            path: "file://" + modelData.settingsPath
            printErrors: false
            onLoaded: root._indexPluginSettings(modelData.id, text())
        }
    }

    property var barWidgetLabels: ({})
    readonly property var presentBarWidgets: {
        const present = {};
        for (const config of SettingsData.barConfigs) {
            for (const sectionId of ["left", "center", "right"]) {
                for (const entry of config[sectionId + "Widgets"] ?? [])
                    present[typeof entry === "string" ? entry : entry.id] = true;
            }
        }
        return present;
    }

    onPresentBarWidgetsChanged: _refreshTranslatedCache()

    function _barWidgetSearchEntries() {
        const entries = [];
        for (const widget of BarWidgetCatalog.widgets) {
            const present = presentBarWidgets[widget.id] === true;
            entries.push({
                section: "",
                label: widget.text,
                tabIndex: 22,
                category: present ? "Bar widgets" : "Add widget",
                keywords: [widget.id, "widget", "bar"],
                icon: widget.icon,
                description: widget.description,
                conditionKey: "",
                runtimeType: present ? "barWidget" : "barWidgetAdd",
                runtimeId: widget.id
            });
            if (!present)
                continue;
            const labels = barWidgetLabels[BarWidgetCatalog.optionsFile(widget.id)] || [];
            for (const label of labels) {
                entries.push({
                    section: "",
                    label: label,
                    tabIndex: 22,
                    category: widget.text,
                    keywords: [widget.id, "widget", "bar"],
                    icon: widget.icon,
                    description: "",
                    conditionKey: "",
                    runtimeType: "barWidget",
                    runtimeId: widget.id
                });
            }
        }
        return entries;
    }

    function _indexPluginSettings(pluginId, source) {
        const labels = [];
        const pattern = /\blabel:\s*(?:I18n\.tr\()?"((?:[^"\\]|\\.)*)"/g;
        let match;
        while ((match = pattern.exec(source)) !== null) {
            if (match[1] && labels.indexOf(match[1]) === -1)
                labels.push(match[1]);
        }
        if (JSON.stringify(pluginSettingLabels[pluginId] ?? []) === JSON.stringify(labels))
            return;
        const next = Object.assign({}, pluginSettingLabels);
        next[pluginId] = labels;
        pluginSettingLabels = next;
        _refreshTranslatedCache();
    }

    FileView {
        id: indexFile
        path: Qt.resolvedUrl("../translations/settings_search_index.json")
        onLoaded: {
            try {
                const labels = {};
                root.settingsIndex = JSON.parse(text()).filter(entry => {
                    if (entry.runtimeType !== "barWidgetOption")
                        return true;
                    labels[entry.optionFile] = (labels[entry.optionFile] ?? []).concat(entry.label);
                    return false;
                });
                root.barWidgetLabels = labels;
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

    function registerCard(settingKey, item, flickable, collapsible) {
        if (!settingKey)
            return;
        var cards = Object.assign({}, registeredCards);
        cards[settingKey] = {
            item: item,
            flickable: flickable,
            collapsible: collapsible ?? null
        };
        registeredCards = cards;
        if (targetSection !== settingKey)
            return;
        _expandFor(cards[settingKey]);
        scrollTimer.restart();
    }

    function unregisterCard(settingKey, item) {
        if (!settingKey)
            return;
        if (item && registeredCards[settingKey] && registeredCards[settingKey].item !== item)
            return;
        var cards = Object.assign({}, registeredCards);
        delete cards[settingKey];
        registeredCards = cards;
    }

    function navigateToSection(section) {
        targetSection = section;
        _scrollPass = 0;
        _stablePasses = 0;
        _lastGeometry = "";
        scrollTimer.interval = 50;
        const entry = registeredCards[section];
        if (!entry)
            return;
        _expandFor(entry);
        scrollTimer.restart();
    }

    function _expandFor(entry) {
        if (!entry)
            return;
        _expand(entry.collapsible);
        _expand(entry.item);
    }

    function _expand(card) {
        if (!card || card.collapsible !== true || card.expanded)
            return;
        card.expanded = true;
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
        const userScrolled = _scrollPass > 0 && Math.abs(flickable.contentY - _appliedY) > 1;
        if (userScrolled) {
            _finishScroll();
            return;
        }
        const mapped = item.mapToItem(contentItem, 0, 0);
        const maxY = Math.max(0, flickable.contentHeight - flickable.height);
        const targetY = Math.min(maxY, Math.max(0, mapped.y - 16));
        flickable.contentY = targetY;
        _appliedY = flickable.contentY;

        highlightSection = targetSection;
        highlightTimer.restart();
        const geometry = mapped.y + ":" + flickable.contentHeight;
        _stablePasses = geometry === _lastGeometry ? _stablePasses + 1 : 0;
        _lastGeometry = geometry;
        _scrollPass++;
        if (_stablePasses < stablePassesNeeded && _scrollPass < maxScrollPasses) {
            scrollTimer.interval = settleInterval;
            scrollTimer.restart();
            return;
        }
        _finishScroll();
    }

    function _finishScroll() {
        targetSection = "";
        scrollTimer.interval = 50;
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
        const isRuntimePlugin = item.runtimeType === "plugin";
        const label = isRuntimePlugin ? item.label : I18n.tr(item.label);
        const description = isRuntimePlugin ? (item.description || "") : I18n.tr(item.description || "");
        const category = I18n.tr(item.category);
        return {
            section: item.section,
            label: label,
            tabIndex: item.tabIndex,
            category: item.parentLabel ? I18n.tr(item.parentLabel) + " › " + category : category,
            keywords: item.keywords || [],
            icon: item.icon || "settings",
            description: description,
            conditionKey: item.conditionKey,
            runtimeType: item.runtimeType || "",
            runtimeId: item.runtimeId || "",
            page: item.page || (isRuntimePlugin ? SettingsTabs.pluginPrefix + item.runtimeId : "")
        };
    }

    function _rebuildTranslationCache() {
        var cache = [];
        var items = settingsIndex.concat(_runtimeSearchEntries());
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var t = translateItem(item);
            var sourceDescription = item.description || "";
            var labelLower = _lowerVariants([item.label, t.label]);
            var categoryLower = _lowerVariants([item.category, item.parentLabel, t.category]);
            var descriptionLower = item.runtimeType === "plugin" ? [] : _lowerVariants([sourceDescription, t.description]);
            cache.push({
                section: t.section,
                label: t.label,
                tabIndex: t.tabIndex,
                category: t.category,
                keywords: t.keywords,
                icon: t.icon,
                description: t.description,
                conditionKey: t.conditionKey,
                runtimeType: t.runtimeType,
                runtimeId: t.runtimeId,
                page: t.page,
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

    function _runtimeSearchEntries() {
        var entries = _barWidgetSearchEntries();
        for (const entry of DashRegistry.entries) {
            for (const spec of entry.options ?? []) {
                entries.push({
                    section: "dashOptions:" + entry.id + ":" + spec.key,
                    label: spec.text,
                    tabIndex: 43,
                    category: entry.text,
                    parentLabel: "Dashboard",
                    keywords: [entry.id, entry.text, "dash", "options"],
                    icon: entry.icon,
                    description: spec.description ?? ""
                });
            }
        }
        var plugins = PluginService.availablePluginsList || [];
        for (var i = 0; i < plugins.length; i++) {
            var plugin = plugins[i];
            entries.push({
                section: "",
                label: plugin.name || plugin.id,
                tabIndex: 12,
                category: "Plugins",
                keywords: [plugin.id || ""],
                icon: plugin.icon || "extension",
                description: plugin.description || "",
                conditionKey: "",
                runtimeType: "plugin",
                runtimeId: plugin.id || ""
            });
            var labels = pluginSettingLabels[plugin.id] || [];
            for (var j = 0; j < labels.length; j++) {
                entries.push({
                    section: "",
                    label: labels[j],
                    tabIndex: 12,
                    category: plugin.name || plugin.id,
                    keywords: [plugin.id || "", plugin.name || ""],
                    icon: plugin.icon || "extension",
                    description: "",
                    conditionKey: "",
                    runtimeType: "plugin",
                    runtimeId: plugin.id || ""
                });
            }
        }
        return entries;
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
            const aRuntime = !!a.item.runtimeType;
            const bRuntime = !!b.item.runtimeType;
            if (aRuntime !== bRuntime)
                return aRuntime ? 1 : -1;
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
