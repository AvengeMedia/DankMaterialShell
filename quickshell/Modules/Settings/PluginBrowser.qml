import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

RegistryBrowserWindow {
    id: root

    property var allPlugins: []
    property var filteredPlugins: []
    property string typeFilter: ""
    property string categoryFilter: "all"
    property var categoryFilterOptions: []
    property var availableLetters: []
    property string detailPluginId: ""
    property string pendingRevealPluginId: ""
    property string loadError: ""
    property string operationMessage: ""
    property bool operationFailed: false
    property bool operationPending: false

    readonly property var detailPlugin: resolveDetailPlugin(detailPluginId, allPlugins)
    readonly property bool activeCategorySort: normalizedSortMode(SessionData.pluginBrowserSortMode) === "category"
    readonly property bool showCategoryFilters: activeCategorySort && categoryFilterOptions.length > 1
    readonly property bool showLetterIndex: {
        var mode = normalizedSortMode(SessionData.pluginBrowserSortMode);
        return (mode === "name" || mode === "author") && availableLetters.length > 1;
    }

    readonly property var sortChipOptions: [
        {
            id: "hideInstalled",
            label: I18n.tr("Hide installed", "plugin browser filter chip"),
            toggle: true
        },
        {
            id: "installed",
            label: I18n.tr("Installed first", "plugin browser filter chip"),
            toggle: true
        },
        {
            id: "default",
            label: I18n.tr("Votes", "plugin browser sort option"),
            toggle: false
        },
        {
            id: "name",
            label: I18n.tr("Name", "plugin browser sort option"),
            toggle: false
        },
        {
            id: "author",
            label: I18n.tr("Contributor", "plugin browser sort option"),
            toggle: false
        },
        {
            id: "category",
            label: I18n.tr("Category", "plugin browser sort option"),
            toggle: false
        }
    ]

    function normalizedSortMode(mode) {
        if (mode === "type" || mode === "contributor")
            return "author";
        if (mode === "name" || mode === "author" || mode === "category")
            return mode;
        return "default";
    }

    function isSortChipSelected(chipId, toggle) {
        if (toggle) {
            if (chipId === "hideInstalled")
                return SessionData.pluginBrowserHideInstalled;
            return SessionData.pluginBrowserInstalledFirst;
        }
        return normalizedSortMode(SessionData.pluginBrowserSortMode) === chipId;
    }

    function comparePluginName(a, b) {
        var nameA = (a.name || "").toLowerCase();
        var nameB = (b.name || "").toLowerCase();
        if (nameA < nameB)
            return -1;
        if (nameA > nameB)
            return 1;
        return 0;
    }

    function pluginReviewed(plugin) {
        return (plugin.status || []).indexOf("reviewed") !== -1;
    }

    function relatedPlugins(plugin) {
        if (!plugin || !plugin.similar || plugin.similar.length === 0)
            return [];

        var related = [];
        for (var i = 0; i < plugin.similar.length; i++) {
            var id = plugin.similar[i];
            var key = "";
            var name = id;
            for (var j = 0; j < allPlugins.length; j++) {
                if (allPlugins[j].id !== id)
                    continue;
                key = detailKeyFor(allPlugins[j]);
                name = allPlugins[j].name || id;
                break;
            }
            related.push({
                key: key,
                name: name
            });
        }
        return related;
    }

    function comparePluginAuthor(a, b) {
        var authorA = (a.author || "").toLowerCase() || "zzz";
        var authorB = (b.author || "").toLowerCase() || "zzz";
        if (authorA < authorB)
            return -1;
        if (authorA > authorB)
            return 1;
        return comparePluginName(a, b);
    }

    function comparePluginCategory(a, b) {
        var catA = (a.category || "").toLowerCase() || "zzz";
        var catB = (b.category || "").toLowerCase() || "zzz";
        if (catA < catB)
            return -1;
        if (catA > catB)
            return 1;
        return comparePluginName(a, b);
    }

    function formatCategoryLabel(categoryKey) {
        if (!categoryKey || categoryKey === "_uncategorized")
            return I18n.tr("Uncategorized", "plugin browser category filter");
        return categoryKey.charAt(0).toUpperCase() + categoryKey.slice(1);
    }

    function sortKeyForPlugin(plugin, mode) {
        if (mode === "author")
            return (plugin.author || "").trim();
        if (mode === "category")
            return formatCategoryLabel((plugin.category || "").toLowerCase() || "_uncategorized");
        return (plugin.name || "").trim();
    }

    function buildCategoryFilterOptions(plugins) {
        var counts = {};
        for (var i = 0; i < plugins.length; i++) {
            var cat = (plugins[i].category || "").toLowerCase();
            if (!cat)
                cat = "_uncategorized";
            counts[cat] = (counts[cat] || 0) + 1;
        }
        var keys = Object.keys(counts).sort();
        var options = [
            {
                key: "all",
                label: I18n.tr("All", "plugin browser category filter"),
                count: plugins.length
            }
        ];
        for (var j = 0; j < keys.length; j++) {
            var key = keys[j];
            options.push({
                key: key,
                label: formatCategoryLabel(key),
                count: counts[key]
            });
        }
        return options;
    }

    function categoryFilterDisplayLabel(option) {
        return option.label + " (" + option.count + ")";
    }

    function categoryFilterLabelForKey(key) {
        for (var i = 0; i < categoryFilterOptions.length; i++) {
            if (categoryFilterOptions[i].key === key)
                return categoryFilterDisplayLabel(categoryFilterOptions[i]);
        }
        return "";
    }

    function categoryFilterKeyForLabel(label) {
        for (var i = 0; i < categoryFilterOptions.length; i++) {
            if (categoryFilterDisplayLabel(categoryFilterOptions[i]) === label)
                return categoryFilterOptions[i].key;
        }
        return "all";
    }

    function categoryFilterDropdownLabels() {
        var labels = [];
        for (var i = 0; i < categoryFilterOptions.length; i++)
            labels.push(categoryFilterDisplayLabel(categoryFilterOptions[i]));
        return labels;
    }

    function updateAvailableLetters(plugins) {
        var mode = normalizedSortMode(SessionData.pluginBrowserSortMode);
        if (mode !== "name" && mode !== "author") {
            availableLetters = [];
            return;
        }
        var letters = {};
        for (var i = 0; i < plugins.length; i++) {
            var key = sortKeyForPlugin(plugins[i], mode);
            if (!key)
                continue;
            var letter = key.charAt(0).toUpperCase();
            if (letter >= "A" && letter <= "Z")
                letters[letter] = true;
        }
        availableLetters = Object.keys(letters).sort();
    }

    function refreshListLayout() {
        if (!pluginGrid)
            return;
        pluginGrid.cancelFlick();
        pluginGrid.contentY = 0;
        Qt.callLater(() => {
            if (pluginGrid)
                pluginGrid.forceLayout();
        });
    }

    function scrollToLetter(letter) {
        var mode = normalizedSortMode(SessionData.pluginBrowserSortMode);
        for (var i = 0; i < filteredPlugins.length; i++) {
            var key = sortKeyForPlugin(filteredPlugins[i], mode);
            if (key && key.charAt(0).toUpperCase() === letter) {
                pluginGrid.positionViewAtIndex(i, GridView.Beginning);
                return;
            }
        }
    }

    function updateFilteredPlugins() {
        var baseFiltered = [];
        var query = searchQuery ? searchQuery.toLowerCase() : "";

        for (var i = 0; i < allPlugins.length; i++) {
            var plugin = allPlugins[i];
            var isFirstParty = plugin.firstParty || false;

            if (!SessionData.showThirdPartyPlugins && !isFirstParty)
                continue;
            if (typeFilter !== "") {
                var hasCapability = plugin.capabilities && plugin.capabilities.includes(typeFilter);
                if (!hasCapability)
                    continue;
            }

            if (query.length === 0) {
                baseFiltered.push(plugin);
                continue;
            }

            var name = plugin.name ? plugin.name.toLowerCase() : "";
            var description = plugin.description ? plugin.description.toLowerCase() : "";
            var author = plugin.author ? plugin.author.toLowerCase() : "";

            if (name.indexOf(query) !== -1 || description.indexOf(query) !== -1 || author.indexOf(query) !== -1)
                baseFiltered.push(plugin);
        }

        categoryFilterOptions = buildCategoryFilterOptions(baseFiltered);
        if (categoryFilter !== "all") {
            var filterStillValid = false;
            for (var c = 0; c < categoryFilterOptions.length; c++) {
                if (categoryFilterOptions[c].key === categoryFilter) {
                    filterStillValid = true;
                    break;
                }
            }
            if (!filterStillValid)
                categoryFilter = "all";
        }

        var filtered = baseFiltered.slice();
        if (SessionData.pluginBrowserHideInstalled)
            filtered = filtered.filter(p => !(p.installed || false));
        if (activeCategorySort && categoryFilter !== "all") {
            filtered = filtered.filter(p => {
                var cat = (p.category || "").toLowerCase();
                if (!cat)
                    cat = "_uncategorized";
                return cat === categoryFilter;
            });
        }

        filtered.sort((a, b) => {
            if (SessionData.pluginBrowserInstalledFirst) {
                var instA = a.installed || false;
                var instB = b.installed || false;
                if (instA !== instB)
                    return instA ? -1 : 1;
            }
            var sortMode = normalizedSortMode(SessionData.pluginBrowserSortMode);
            if (sortMode === "name")
                return comparePluginName(a, b);
            if (sortMode === "author")
                return comparePluginAuthor(a, b);
            if (sortMode === "category")
                return comparePluginCategory(a, b);
            var votesA = a.upvotes || 0;
            var votesB = b.upvotes || 0;
            if (votesA !== votesB)
                return votesB - votesA;
            var verA = root.pluginReviewed(a);
            var verB = root.pluginReviewed(b);
            if (verA !== verB)
                return verA ? -1 : 1;
            return comparePluginName(a, b);
        });

        filteredPlugins = filtered;
        updateAvailableLetters(filtered);
        selectedIndex = -1;
        keyboardNavigationActive = false;
        refreshListLayout();
        revealTimer.restart();
    }

    Timer {
        id: revealTimer
        interval: 0
        onTriggered: {
            if (!root.visible || !root.pendingRevealPluginId || root.isLoading)
                return;
            const index = root.filteredPlugins.findIndex(plugin => plugin.id === root.pendingRevealPluginId);
            if (index < 0)
                return;
            root.selectedIndex = index;
            root.keyboardNavigationActive = true;
            pluginGrid.currentIndex = index;
            pluginGrid.positionViewAtIndex(index, GridView.Contain);
            pluginGrid.forceLayout();
            pluginGrid.currentItem?.focusTarget?.forceActiveFocus(Qt.TabFocusReason);
            root.pendingRevealPluginId = "";
        }
    }

    function detailKeyFor(plugin) {
        if (!plugin)
            return "";
        return plugin.id || plugin.name || "";
    }

    function resolveDetailPlugin(key, plugins) {
        if (!key)
            return null;
        for (var i = 0; i < plugins.length; i++) {
            if (detailKeyFor(plugins[i]) === key)
                return plugins[i];
        }
        return null;
    }

    function openPluginDetail(plugin) {
        var key = detailKeyFor(plugin);
        if (!key)
            return;
        detailPluginId = key;
    }

    function closePluginDetail() {
        detailPluginId = "";
    }

    function formatUpdatedDate(iso) {
        if (!iso)
            return "";
        var date = new Date(iso);
        if (isNaN(date.getTime()))
            return "";
        return date.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    function detailMetaBadges(plugin) {
        if (!plugin)
            return [];
        var items = [];
        if (plugin.version)
            items.push({
                label: "v" + plugin.version,
                icon: "sell"
            });
        if (plugin.category)
            items.push({
                label: formatCategoryLabel((plugin.category || "").toLowerCase()),
                icon: "category"
            });
        var updated = formatUpdatedDate(plugin.updated_at);
        if (updated)
            items.push({
                label: updated,
                icon: "history"
            });
        return items;
    }

    function ensureSelectedVisible() {
        if (selectedIndex < 0 || !pluginGrid)
            return;
        pluginGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function selectNext() {
        if (detailPluginId !== "" || filteredPlugins.length === 0)
            return;
        if (!keyboardNavigationActive) {
            keyboardNavigationActive = true;
            selectedIndex = 0;
            ensureSelectedVisible();
            return;
        }
        selectedIndex = Math.min(selectedIndex + pluginGrid.columns, filteredPlugins.length - 1);
        ensureSelectedVisible();
    }

    function selectPrevious() {
        if (detailPluginId !== "" || filteredPlugins.length === 0 || !keyboardNavigationActive)
            return;
        var next = selectedIndex - pluginGrid.columns;
        if (next < 0) {
            selectedIndex = -1;
            keyboardNavigationActive = false;
            return;
        }
        selectedIndex = next;
        ensureSelectedVisible();
    }

    function selectStep(delta) {
        if (detailPluginId !== "" || filteredPlugins.length === 0 || !keyboardNavigationActive)
            return;
        selectedIndex = Math.max(0, Math.min(selectedIndex + delta, filteredPlugins.length - 1));
        ensureSelectedVisible();
    }

    function setThirdPartyVisible(show) {
        if (!show) {
            SessionData.setShowThirdPartyPlugins(false);
            updateFilteredPlugins();
            return;
        }
        thirdPartyConfirm.showWithOptions({
            title: I18n.tr("Third-Party Plugin Warning"),
            message: I18n.tr("Third-party plugins are created by the community and are not officially supported by DankMaterialShell.\n\nThese plugins may pose security and privacy risks - install at your own risk."),
            confirmText: I18n.tr("I Understand"),
            cancelText: I18n.tr("Cancel"),
            onConfirm: () => {
                SessionData.setShowThirdPartyPlugins(true);
                root.updateFilteredPlugins();
            }
        });
    }

    function installPlugin(pluginId, pluginName, enableAfterInstall) {
        if (PluginService.installingPlugins[pluginId])
            return;
        operationFailed = false;
        operationPending = true;
        operationMessage = I18n.tr("Installing: %1", "installation progress").arg(pluginName);
        PluginService.installFromRegistry(pluginId, pluginName, enableAfterInstall, (success, error) => {
            operationPending = false;
            operationFailed = !success;
            operationMessage = success ? I18n.tr("Installed: %1", "installation success").arg(pluginName) : error;
            if (!success)
                return;
            pendingRevealPluginId = pluginId;
            searchQuery = "";
            typeFilter = "";
            categoryFilter = "all";
            detailPluginId = "";
            SessionData.setPluginBrowserHideInstalled(false);
            refreshPlugins();
        });
    }

    function refreshPlugins() {
        isLoading = true;
        loadError = "";
        DMSService.listPlugins(response => {
            isLoading = false;
            if (!visible)
                return;
            if (response.error) {
                loadError = response.error;
                return;
            }
            allPlugins = response.result || [];
            updateFilteredPlugins();
        });
        if (DMSService.apiVersion >= 8)
            DMSService.listInstalled();
    }

    function checkPendingInstall() {
        if (!PopoutService.pendingPluginInstall || pendingInstallHandled)
            return;
        pendingInstallHandled = true;
        var pluginId = PopoutService.pendingPluginInstall;
        PopoutService.pendingPluginInstall = "";
        installConfirm.showWithOptions({
            "title": I18n.tr("Install Plugin", "plugin installation dialog title"),
            "message": I18n.tr("Install plugin '%1' from the DMS registry?", "plugin installation confirmation").arg(pluginId),
            "confirmText": I18n.tr("Install", "install action button"),
            "cancelText": I18n.tr("Cancel"),
            "onConfirm": () => installPlugin(pluginId, pluginId, true),
            "onCancel": () => hide()
        });
    }

    objectName: "pluginBrowser"
    title: I18n.tr("Browse plugins", "plugin browser window title")
    headerTitle: I18n.tr("Browse plugins")
    searchPlaceholder: I18n.tr("Search plugins...", "plugin search placeholder")

    function pendingInstallId() {
        return PopoutService.pendingPluginInstall || "";
    }

    function refresh() {
        refreshPlugins();
    }

    function applySearch() {
        updateFilteredPlugins();
    }

    function resetContent() {
        allPlugins = [];
        filteredPlugins = [];
        loadError = "";
        detailPluginId = "";
    }

    function handleEscape() {
        if (detailPluginId !== "") {
            closePluginDetail();
            return;
        }
        hide();
    }

    function activateSelected() {
        if (detailPluginId !== "" || !keyboardNavigationActive || selectedIndex < 0)
            return false;
        openPluginDetail(filteredPlugins[selectedIndex]);
        return true;
    }

    Connections {
        target: DMSService

        function onInstalledPluginsReceived(plugins) {
            if (!root.visible)
                return;
            const selectedPluginId = root.pendingRevealPluginId || root.filteredPlugins[root.selectedIndex]?.id;
            var pluginMap = {};
            for (var i = 0; i < plugins.length; i++) {
                var plugin = plugins[i];
                if (plugin.id)
                    pluginMap[plugin.id] = true;
                if (plugin.name)
                    pluginMap[plugin.name] = true;
            }
            var updated = root.allPlugins.map(p => {
                var isInstalled = pluginMap[p.name] || pluginMap[p.id] || false;
                return Object.assign({}, p, {
                    "installed": isInstalled
                });
            });
            root.allPlugins = updated;
            root.updateFilteredPlugins();
            if (!selectedPluginId)
                return;
            root.pendingRevealPluginId = selectedPluginId;
            revealTimer.restart();
        }
    }

    aboveSearch: [
        SettingsToggleRow {
            id: thirdPartyControl
            anchors.left: parent.left
            anchors.right: parent.right
            text: I18n.tr("Third-party plugins", "community plugin discovery control")
            description: I18n.tr("Discover community plugins. Review their code before installing, and audit changes before updating.", "community plugin safety guidance")
            checked: SessionData.showThirdPartyPlugins
            iconName: "extension"
            onToggled: show => root.setThirdPartyVisible(show)
        },
        DankCard {
            id: operationStatus
            readonly property color statusColor: root.operationFailed ? Theme.onErrorContainer : contentColor
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? implicitHeight : 0
            implicitHeight: statusContent.implicitHeight + pad * 2
            visible: root.operationMessage !== ""
            tone: "primary"
            pad: Theme.spacingM
            color: root.operationFailed ? Theme.errorContainer : surfaceColor
            Accessible.name: root.operationMessage

            RowLayout {
                id: statusContent
                anchors.fill: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: root.operationFailed ? "error" : root.operationPending ? "downloading" : "check_circle"
                    size: Theme.iconSize
                    color: operationStatus.statusColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.operationMessage
                    color: operationStatus.statusColor
                    wrapMode: Text.Wrap
                }
            }
        }
    ]

    belowSearch: [
        Column {
            id: sortControlsRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.spacingS

            DankFilterChips {
                width: parent.width
                model: root.sortChipOptions.slice(2)
                currentIndex: Math.max(0, model.findIndex(option => option.id === root.normalizedSortMode(SessionData.pluginBrowserSortMode)))
                onSelectionChanged: index => {
                    const mode = model[index].id;
                    if (mode !== "category")
                        root.categoryFilter = "all";
                    SessionData.setPluginBrowserSortMode(mode);
                    root.updateFilteredPlugins();
                }
            }
            DankFilterChips {
                width: parent.width
                model: root.sortChipOptions.slice(0, 2).map(option => ({
                            label: option.label,
                            value: option.id
                        }))
                multiSelect: true
                selectedValues: [SessionData.pluginBrowserHideInstalled ? "hideInstalled" : "", SessionData.pluginBrowserInstalledFirst ? "installed" : ""]
                onSelectionToggled: (index, selected) => {
                    if (index === 0)
                        SessionData.setPluginBrowserHideInstalled(selected);
                    else
                        SessionData.setPluginBrowserInstalledFirst(selected);
                    root.updateFilteredPlugins();
                }
            }
        },
        Item {
            id: categoryFiltersRow
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.showCategoryFilters ? Theme.buttonHeightS : 0
            visible: root.showCategoryFilters
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacingS

                StyledText {
                    id: categoryFilterLabel
                    text: I18n.tr("Filter", "plugin browser category filter label")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                DankDropdown {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.buttonHeightS
                    compactMode: true
                    dropdownWidth: Math.max(Theme.smallBreakpoint / 2, categoryFiltersRow.width - categoryFilterLabel.implicitWidth - Theme.spacingS * 3)
                    currentValue: root.categoryFilterLabelForKey(root.categoryFilter)
                    options: root.categoryFilterDropdownLabels()
                    onValueChanged: value => {
                        var nextKey = root.categoryFilterKeyForLabel(value);
                        if (nextKey === root.categoryFilter)
                            return;
                        root.categoryFilter = nextKey;
                        root.updateFilteredPlugins();
                    }
                }
            }
        }
    ]

    listContent: [
        DankGridView {
            id: pluginGrid

            property int columns: Math.max(1, Math.floor(width / (Theme.smallBreakpoint / 2 + Theme.spacingXL * 2)))
            readonly property real cardSpacing: Theme.spacingM
            readonly property int previewHeight: Math.round((cellWidth - cardSpacing - Theme.spacingS * 2) * SettingsMetrics.choiceCardPreviewRatio)
            readonly property int infoHeight: Theme.iconButtonSize + Theme.fontSizeSmall * 4 + Theme.spacingS

            anchors.fill: parent
            anchors.rightMargin: root.showLetterIndex ? Theme.iconButtonSize : 0
            cellWidth: Math.floor(width / columns)
            cellHeight: previewHeight + infoHeight + Math.round(cardSpacing) + Theme.spacingS * 2 + Theme.spacingM
            model: root.filteredPlugins
            clip: true
            visible: !root.isLoading && root.loadError === ""
            cacheBuffer: cellHeight * 2

            delegate: Item {
                id: cardCell

                required property var modelData
                required property int index
                readonly property Item focusTarget: pluginCard.focusTarget

                width: pluginGrid.cellWidth
                height: pluginGrid.cellHeight

                PluginCard {
                    id: pluginCard
                    anchors.fill: parent
                    anchors.margins: pluginGrid.cardSpacing / 2
                    plugin: cardCell.modelData
                    busy: !!PluginService.installingPlugins[cardCell.modelData.id]
                    previewHeight: pluginGrid.previewHeight
                    installed: cardCell.modelData.installed || false
                    selected: root.keyboardNavigationActive && cardCell.index === root.selectedIndex
                    onClicked: root.openPluginDetail(cardCell.modelData)
                    onInstallRequested: root.installPlugin(cardCell.modelData.id, cardCell.modelData.name, cardCell.modelData.type === "desktop")
                }
            }
        },
        DankFlickable {
            id: letterIndex
            anchors.right: parent.right
            anchors.top: pluginGrid.top
            anchors.bottom: pluginGrid.bottom
            width: Theme.iconButtonSize
            visible: root.showLetterIndex && !root.isLoading && root.loadError === ""
            contentHeight: letterColumn.implicitHeight
            clip: true

            Column {
                id: letterColumn
                width: parent.width
                Repeater {
                    model: root.availableLetters

                    DankButton {
                        required property string modelData
                        width: letterIndex.width
                        minimumWidth: 0
                        horizontalPadding: 0
                        buttonHeight: Theme.buttonHeightXS
                        text: modelData
                        backgroundColor: Theme.chipSurface
                        textColor: Theme.onSurfaceVariant
                        onClicked: root.scrollToLetter(modelData)
                    }
                }
            }
        },
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: !root.isLoading && root.loadError === "" && root.filteredPlugins.length === 0

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "search_off"
                size: Theme.iconButtonSize
                color: Theme.onSurfaceVariant
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("No plugins found", "empty plugin list")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        },
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: !root.isLoading && root.loadError !== ""
            width: parent.width

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "cloud_off"
                size: Theme.iconButtonSize
                color: Theme.onSurfaceVariant
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Couldn't load plugins", "plugin registry fetch error")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.loadError
                width: parent.width
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }

            DankButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Retry", "retry failed action button")
                iconName: "refresh"
                backgroundColor: Theme.chipSurface
                textColor: Theme.surfaceText
                onClicked: root.refreshPlugins()
            }
        }
    ]

    overlay: Rectangle {
        id: detailPane

        property var plugin: ({})
        property bool heroFallback: false
        readonly property var livePlugin: root.detailPlugin

        onLivePluginChanged: {
            if (!livePlugin)
                return;
            plugin = livePlugin;
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.bottom: parent.bottom
        z: 10
        color: Theme.floatingWindowSurface
        opacity: root.detailPluginId !== "" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        Connections {
            target: root
            function onDetailPluginIdChanged() {
                detailPane.heroFallback = false;
                detailFlickable.contentY = 0;
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Item {
            id: detailHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.buttonHeightS

            DankActionButton {
                id: detailBackButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconName: "arrow_back"
                Accessible.name: I18n.tr("Back")
                iconSize: Theme.iconSize
                iconColor: Theme.surfaceText
                onClicked: root.closePluginDetail()
            }

            DankIcon {
                id: detailIcon
                anchors.left: detailBackButton.right
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: detailPane.plugin.icon || "extension"
                size: Theme.iconSize
                color: Theme.primary
            }

            StyledText {
                anchors.left: detailIcon.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: detailInstallButton.left
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: detailPane.plugin.name || ""
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            DankButton {
                id: detailInstallButton
                readonly property bool compatible: PluginService.checkPluginCompatibility(detailPane.plugin.requires_dms)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: detailPane.plugin.installed ? I18n.tr("Installed", "adjective, plugin or theme is already installed, button state and filter chip") : compatible ? I18n.tr("Install") : I18n.tr("Requires %1", "version requirement").arg(detailPane.plugin.requires_dms || "")
                iconName: detailPane.plugin.installed ? "check" : "download"
                enabled: !detailPane.plugin.installed && compatible && !PluginService.installingPlugins[detailPane.plugin.id]
                onClicked: root.installPlugin(detailPane.plugin.id, detailPane.plugin.name, detailPane.plugin.type === "desktop")
            }
        }

        DankFlickable {
            id: detailFlickable
            anchors.top: detailHeader.bottom
            anchors.topMargin: Theme.spacingM
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            contentHeight: detailColumn.height + Theme.spacingL
            contentWidth: width

            Column {
                id: detailColumn
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingL

                Rectangle {
                    width: Math.min(SettingsMetrics.contentMaxWidth, parent.width)
                    height: Math.round(width * SettingsMetrics.choiceCardPreviewRatio)
                    radius: Theme.cornerRadiusM
                    color: Theme.floatingWindowNestedSurface
                    border.color: Theme.outlineVariant
                    border.width: Theme.outlineWidth

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.outlineWidth
                        radius: Theme.cornerRadiusM - Theme.outlineWidth
                        color: "transparent"

                        CachingImage {
                            id: heroImage
                            anchors.fill: parent
                            imagePath: detailPane.heroFallback ? PluginService.previewUrl(detailPane.plugin) : PluginService.heroUrl(detailPane.plugin)
                            maxCacheSize: 1600
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                            onStatusChanged: {
                                if (status !== Image.Error || detailPane.heroFallback)
                                    return;
                                detailPane.heroFallback = true;
                            }
                        }
                    }

                    DankSpinner {
                        anchors.centerIn: parent
                        running: heroImage.status === Image.Loading
                        visible: running
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        visible: heroImage.imagePath.length === 0 || heroImage.status === Image.Error

                        DankIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "image_not_supported"
                            size: Theme.iconSizeLarge
                            color: Theme.onSurfaceVariant
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: heroImage.status === Image.Error ? I18n.tr("Screenshot unavailable", "plugin browser screenshot error") : I18n.tr("No screenshot provided", "plugin browser no screenshot")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.onSurfaceVariant
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: PluginService.badgeModel(detailPane.plugin)

                        PluginBadge {
                            required property var modelData
                            label: modelData.label
                            iconName: modelData.icon
                            tone: PluginService.badgeTone(modelData.tone)
                        }
                    }

                    PluginBadge {
                        iconName: "thumb_up"
                        label: detailPane.plugin.upvotes || 0
                        tone: Theme.primary
                        visible: !!detailPane.plugin.issueUrl
                    }

                    Repeater {
                        model: root.detailMetaBadges(detailPane.plugin)

                        PluginBadge {
                            required property var modelData
                            label: modelData.label
                            iconName: modelData.icon
                            tone: Theme.outline
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: {
                        const plugin = detailPane.plugin;
                        const author = I18n.tr("by %1", "author attribution").arg(plugin.author || I18n.tr("Unknown", "unknown author"));
                        const source = plugin.repo ? ` • <a href="${plugin.repo}" style="text-decoration:none; color:${Theme.primary};">${I18n.tr("source", "source code link")}</a>` : "";
                        const discuss = plugin.issueUrl ? ` • <a href="${plugin.issueUrl}" style="text-decoration:none; color:${Theme.primary};">${I18n.tr("discuss", "plugin discussion link")}</a>` : "";
                        return author + source + discuss;
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                    linkColor: Theme.primary
                    textFormat: Text.RichText
                    onLinkActivated: url => Qt.openUrlExternally(url)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                    }
                }

                StyledText {
                    width: parent.width
                    text: detailPane.plugin.description || ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                    visible: (detailPane.plugin.description || "").length > 0
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: (detailPane.plugin.capabilities || []).length > 0

                    StyledText {
                        text: I18n.tr("Capabilities", "plugin detail section")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: detailPane.plugin.capabilities || []

                            PluginBadge {
                                required property string modelData
                                label: modelData
                                tone: Theme.primary
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: (detailPane.plugin.permissions || []).length > 0

                    DankIcon {
                        name: "security"
                        size: Theme.iconSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width - Theme.iconSize - Theme.spacingS
                        spacing: Theme.spacingXS

                        Repeater {
                            model: detailPane.plugin.permissions || []

                            PluginBadge {
                                required property string modelData
                                label: modelData
                                tone: Theme.secondary
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: (detailPane.plugin.dependencies || []).length > 0

                    DankIcon {
                        name: "package_2"
                        size: Theme.iconSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width - Theme.iconSize - Theme.spacingS
                        spacing: Theme.spacingXS

                        Repeater {
                            model: detailPane.plugin.dependencies || []

                            PluginBadge {
                                required property string modelData
                                label: modelData
                                tone: Theme.outline
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.relatedPlugins(detailPane.plugin).length > 0

                    StyledText {
                        text: I18n.tr("Related: %1", "related plugins").arg("").trim()
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.relatedPlugins(detailPane.plugin)

                            DankButton {
                                required property var modelData
                                text: modelData.name
                                iconName: "extension"
                                backgroundColor: Theme.secondaryContainer
                                textColor: Theme.onSecondaryContainer
                                enabled: modelData.key !== ""
                                onClicked: root.detailPluginId = modelData.key
                            }
                        }
                    }
                }
            }
        }
    }

    ConfirmDialogOverlay {
        id: thirdPartyConfirm
        onDialogClosed: root.focusSearch()
    }
}
