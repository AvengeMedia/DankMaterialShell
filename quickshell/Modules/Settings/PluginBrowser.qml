import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property var allPlugins: []
    property string searchQuery: ""
    property var filteredPlugins: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property bool isLoading: false
    property var parentModal: null
    parentWindow: parentModal
    property bool pendingInstallHandled: false
    property string typeFilter: ""
    property string categoryFilter: "all"
    property var categoryFilterOptions: []
    property var availableLetters: []
    property string detailPluginId: ""

    readonly property string previewApiBase: "https://api.danklinux.com/previews/"
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

    function statusTone(status) {
        switch (status) {
        case "broken":
            return "error";
        case "unmaintained":
            return "warning";
        case "reviewed":
            return "info";
        default:
            return "outline";
        }
    }

    function badgeTone(tone) {
        switch (tone) {
        case "secondary":
            return Theme.secondary;
        case "warning":
            return Theme.warning;
        case "error":
            return Theme.error;
        case "info":
            return Theme.info;
        case "outline":
            return Theme.outline;
        default:
            return Theme.primary;
        }
    }

    function statusLabel(status) {
        switch (status) {
        case "broken":
            return I18n.tr("broken", "plugin status");
        case "unmaintained":
            return I18n.tr("unmaintained", "plugin status");
        case "deprecated":
            return I18n.tr("deprecated", "plugin status");
        case "reviewed":
            return I18n.tr("reviewed", "plugin status");
        default:
            return status;
        }
    }

    function badgeModel(plugin) {
        if (!plugin || (!plugin.id && !plugin.name))
            return [];
        var badges = [];
        if (plugin.featured)
            badges.push({
                label: I18n.tr("featured"),
                icon: "star",
                tone: "secondary"
            });
        if (plugin.firstParty)
            badges.push({
                label: I18n.tr("official"),
                icon: "verified",
                tone: "primary"
            });
        else
            badges.push({
                label: I18n.tr("3rd party"),
                icon: "",
                tone: "warning"
            });
        var status = plugin.status || [];
        for (var i = 0; i < status.length; i++)
            badges.push({
                label: statusLabel(status[i]),
                icon: "",
                tone: statusTone(status[i])
            });
        return badges;
    }

    function previewUrl(plugin) {
        if (!plugin)
            return "";
        if (plugin.previewUrl)
            return plugin.previewUrl;
        if (plugin.id)
            return previewApiBase + plugin.id;
        return plugin.screenshot || "";
    }

    function heroUrl(plugin) {
        if (!plugin)
            return "";
        return plugin.screenshot || previewUrl(plugin);
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

    function installPlugin(pluginName, enableAfterInstall) {
        ToastService.showInfo(I18n.tr("Installing: %1", "installation progress").arg(pluginName));
        DMSService.install(pluginName, response => {
            if (response.error) {
                ToastService.showError(I18n.tr("Install failed: %1", "installation error").arg(response.error));
                return;
            }
            ToastService.showInfo(I18n.tr("Installed: %1", "installation success").arg(pluginName));
            PluginService.scanPlugins();
            refreshPlugins();
            if (enableAfterInstall) {
                Qt.callLater(() => {
                    PluginService.enablePlugin(pluginName);
                    const plugin = PluginService.availablePlugins[pluginName];
                    if (plugin?.type === "desktop") {
                        const defaultConfig = DesktopWidgetRegistry.getDefaultConfig(pluginName);
                        SettingsData.createDesktopWidgetInstance(pluginName, plugin.name || pluginName, defaultConfig);
                    }
                    hide();
                });
            }
        });
    }

    function refreshPlugins() {
        isLoading = true;
        DMSService.listPlugins();
        if (DMSService.apiVersion >= 8)
            DMSService.listInstalled();
    }

    function checkPendingInstall() {
        if (!PopoutService.pendingPluginInstall || pendingInstallHandled)
            return;
        pendingInstallHandled = true;
        var pluginId = PopoutService.pendingPluginInstall;
        PopoutService.pendingPluginInstall = "";
        urlInstallConfirm.showWithOptions({
            "title": I18n.tr("Install Plugin", "plugin installation dialog title"),
            "message": I18n.tr("Install plugin '%1' from the DMS registry?", "plugin installation confirmation").arg(pluginId),
            "confirmText": I18n.tr("Install", "install action button"),
            "cancelText": I18n.tr("Cancel"),
            "onConfirm": () => installPlugin(pluginId, true),
            "onCancel": () => hide()
        });
    }

    function show() {
        if (parentModal)
            parentModal.shouldHaveFocus = false;
        visible = true;
        Qt.callLater(() => browserSearchField.forceActiveFocus());
    }

    function hide() {
        visible = false;
        if (!parentModal)
            return;
        parentModal.shouldHaveFocus = Qt.binding(() => parentModal.shouldBeVisible);
        Qt.callLater(() => {
            if (parentModal.modalFocusScope)
                parentModal.modalFocusScope.forceActiveFocus();
        });
    }

    objectName: "pluginBrowser"
    title: I18n.tr("Browse Plugins", "plugin browser window title")
    minimumSize: Qt.size(520, 460)
    implicitWidth: {
        const maxWidth = screen ? screen.width - 120 : 1500;
        if (parentModal && parentModal.width > 0)
            return Math.round(Math.min(maxWidth, Math.max(640, parentModal.width * 0.8)));
        return Math.min(maxWidth, 900);
    }
    implicitHeight: {
        const maxHeight = screen ? screen.height - 80 : 960;
        if (parentModal && parentModal.height > 0)
            return Math.round(Math.min(maxHeight, Math.max(540, parentModal.height * 0.8)));
        return Math.min(maxHeight, 760);
    }
    color: Theme.surfaceContainer
    visible: false

    onClosed: hide()

    onVisibleChanged: {
        if (visible) {
            pendingInstallHandled = false;
            refreshPlugins();
            Qt.callLater(() => {
                browserSearchField.forceActiveFocus();
                checkPendingInstall();
            });
            return;
        }
        allPlugins = [];
        searchQuery = "";
        filteredPlugins = [];
        selectedIndex = -1;
        keyboardNavigationActive = false;
        isLoading = false;
        detailPluginId = "";
    }

    Connections {
        target: DMSService

        function onPluginsListReceived(plugins) {
            root.isLoading = false;
            root.allPlugins = plugins;
            root.updateFilteredPlugins();
        }

        function onInstalledPluginsReceived(plugins) {
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
        }
    }

    ConfirmModal {
        id: urlInstallConfirm
    }

    FocusScope {
        id: browserKeyHandler

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                if (root.detailPluginId !== "") {
                    root.closePluginDetail();
                    event.accepted = true;
                    return;
                }
                root.hide();
                event.accepted = true;
                return;
            case Qt.Key_Down:
                root.selectNext();
                event.accepted = true;
                return;
            case Qt.Key_Up:
                root.selectPrevious();
                event.accepted = true;
                return;
            case Qt.Key_Left:
                if (!root.keyboardNavigationActive)
                    return;
                root.selectStep(-1);
                event.accepted = true;
                return;
            case Qt.Key_Right:
                if (!root.keyboardNavigationActive)
                    return;
                root.selectStep(1);
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.detailPluginId !== "" || !root.keyboardNavigationActive || root.selectedIndex < 0)
                    return;
                root.openPluginDetail(root.filteredPlugins[root.selectedIndex]);
                event.accepted = true;
                return;
            }
        }

        Item {
            id: browserContent
            anchors.fill: parent
            anchors.margins: Theme.spacingL

            Item {
                id: headerArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 44

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                Rectangle {
                    id: headerIconTile
                    width: 40
                    height: 40
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.primary, 0.12)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: "store"
                        size: Theme.iconSize
                        color: Theme.primary
                    }
                }

                Column {
                    anchors.left: headerIconTile.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: headerActions.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: I18n.tr("Browse Plugins", "plugin browser header")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: parent.width
                    }

                    StyledText {
                        text: {
                            const description = I18n.tr("Install plugins from the DMS plugin registry", "plugin browser description");
                            if (root.isLoading || root.allPlugins.length === 0)
                                return description;
                            return description + "  •  " + root.filteredPlugins.length + "/" + root.allPlugins.length;
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: parent.width
                    }
                }

                Row {
                    id: headerActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankButton {
                        text: SessionData.showThirdPartyPlugins ? I18n.tr("Hide 3rd Party") : I18n.tr("Show 3rd Party")
                        iconName: SessionData.showThirdPartyPlugins ? "visibility_off" : "visibility"
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (SessionData.showThirdPartyPlugins) {
                                SessionData.setShowThirdPartyPlugins(false);
                                root.updateFilteredPlugins();
                                return;
                            }
                            thirdPartyConfirmLoader.active = true;
                            if (thirdPartyConfirmLoader.item)
                                thirdPartyConfirmLoader.item.show();
                        }
                    }

                    DankActionButton {
                        iconName: "refresh"
                        iconSize: 18
                        iconColor: Theme.primary
                        visible: !root.isLoading
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.refreshPlugins()
                    }

                    DankActionButton {
                        visible: windowControls.canMaximize
                        iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.hide()
                    }
                }
            }

            DankTextField {
                id: browserSearchField
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerArea.bottom
                anchors.topMargin: Theme.spacingM
                height: 48
                cornerRadius: Theme.cornerRadius
                backgroundColor: Theme.surfaceContainerHigh
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: Theme.primary
                leftIconName: "search"
                leftIconSize: Theme.iconSize
                leftIconColor: Theme.surfaceVariantText
                leftIconFocusedColor: Theme.primary
                showClearButton: true
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                placeholderText: I18n.tr("Search plugins...", "plugin search placeholder")
                text: root.searchQuery
                focus: true
                ignoreLeftRightKeys: true
                keyForwardTargets: [browserKeyHandler]
                onTextEdited: {
                    root.searchQuery = text;
                    root.updateFilteredPlugins();
                }
            }

            Flow {
                id: sortControlsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: browserSearchField.bottom
                anchors.topMargin: Theme.spacingM
                spacing: Theme.spacingS

                Repeater {
                    model: root.sortChipOptions

                    Rectangle {
                        id: sortChip
                        required property var modelData

                        property bool selected: root.isSortChipSelected(modelData.id, modelData.toggle)
                        property bool hovered: chipMouseArea.containsMouse
                        property bool pressed: chipMouseArea.pressed

                        width: chipContent.implicitWidth + Theme.spacingM * 2
                        height: 32
                        radius: height / 2
                        color: selected ? Theme.primary : Theme.surfaceVariant

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: {
                                if (sortChip.pressed)
                                    return sortChip.selected ? Theme.primaryPressed : Theme.surfaceTextHover;
                                if (sortChip.hovered)
                                    return sortChip.selected ? Theme.primaryHover : Theme.surfaceTextHover;
                                return "transparent";
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shorterDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        DankRipple {
                            id: chipRipple
                            cornerRadius: sortChip.radius
                            rippleColor: sortChip.selected ? Theme.primaryText : Theme.surfaceVariantText
                        }

                        Row {
                            id: chipContent
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: sortChip.modelData.toggle ? "download_done" : "check"
                                size: 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.primaryText
                                visible: sortChip.selected
                            }

                            StyledText {
                                text: sortChip.modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: sortChip.selected ? Font.Medium : Font.Normal
                                color: sortChip.selected ? Theme.primaryText : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: chipMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => chipRipple.trigger(mouse.x, mouse.y)
                            onClicked: {
                                if (sortChip.modelData.toggle) {
                                    if (sortChip.modelData.id === "hideInstalled")
                                        SessionData.setPluginBrowserHideInstalled(!SessionData.pluginBrowserHideInstalled);
                                    else
                                        SessionData.setPluginBrowserInstalledFirst(!SessionData.pluginBrowserInstalledFirst);
                                } else {
                                    if (sortChip.modelData.id !== "category")
                                        root.categoryFilter = "all";
                                    SessionData.setPluginBrowserSortMode(sortChip.modelData.id);
                                }
                                root.updateFilteredPlugins();
                            }
                        }
                    }
                }
            }

            Item {
                id: categoryFiltersRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sortControlsRow.bottom
                anchors.topMargin: root.showCategoryFilters ? Theme.spacingS : 0
                height: root.showCategoryFilters ? 40 : 0
                visible: root.showCategoryFilters
                clip: true

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingS

                    StyledText {
                        id: categoryFilterLabel
                        text: I18n.tr("Filter", "plugin browser category filter label")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        Layout.alignment: Qt.AlignVCenter
                    }

                    DankDropdown {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        compactMode: true
                        dropdownWidth: Math.max(240, categoryFiltersRow.width - categoryFilterLabel.implicitWidth - Theme.spacingS * 3)
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

            Item {
                id: listArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: categoryFiltersRow.bottom
                anchors.topMargin: Theme.spacingM
                anchors.bottom: parent.bottom

                Item {
                    anchors.fill: parent
                    visible: root.isLoading

                    DankSpinner {
                        anchors.centerIn: parent
                        running: root.isLoading
                    }
                }

                DankGridView {
                    id: pluginGrid

                    property int columns: Math.max(1, Math.floor(width / 300))
                    readonly property real cardSpacing: Theme.spacingM
                    readonly property int previewHeight: Math.round((cellWidth - cardSpacing - Theme.spacingS * 2) * 0.52)
                    readonly property int infoHeight: 100

                    anchors.fill: parent
                    anchors.rightMargin: root.showLetterIndex ? 22 : 0
                    cellWidth: Math.floor(width / columns)
                    cellHeight: previewHeight + infoHeight + Math.round(cardSpacing) + Theme.spacingS * 2 + Theme.spacingM
                    model: root.filteredPlugins
                    clip: true
                    visible: !root.isLoading
                    cacheBuffer: cellHeight * 2

                    delegate: Item {
                        id: cardCell

                        required property var modelData
                        required property int index

                        property bool isInstalled: modelData.installed || false
                        property bool isCompatible: PluginService.checkPluginCompatibility(modelData.requires_dms)
                        property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex

                        width: pluginGrid.cellWidth
                        height: pluginGrid.cellHeight

                        Rectangle {
                            id: card
                            anchors.fill: parent
                            anchors.margins: pluginGrid.cardSpacing / 2
                            radius: Theme.cornerRadius
                            color: cardMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.5) : Theme.withAlpha(Theme.surfaceVariant, 0.3)
                            border.color: cardCell.isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
                            border.width: cardCell.isSelected ? 2 : 1
                            scale: cardMouseArea.containsMouse ? 1.012 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            MouseArea {
                                id: cardMouseArea
                                z: 0
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => cardRipple.trigger(mouse.x, mouse.y)
                                onClicked: root.openPluginDetail(cardCell.modelData)
                            }

                            DankRipple {
                                id: cardRipple
                                cornerRadius: card.radius
                                rippleColor: Theme.surfaceVariantText
                            }

                            Item {
                                id: previewArea
                                z: 1
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Theme.spacingS
                                height: pluginGrid.previewHeight

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius - 2
                                    color: Theme.surfaceContainerHigh

                                    CachingImage {
                                        id: cardPreview
                                        anchors.fill: parent
                                        imagePath: root.previewUrl(cardCell.modelData)
                                        maxCacheSize: 640
                                        fillMode: Image.PreserveAspectCrop
                                        animate: false
                                        visible: status === Image.Ready
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: cardCell.modelData.icon || "extension"
                                        size: Theme.iconSize + 12
                                        color: Theme.withAlpha(Theme.outline, 0.6)
                                        visible: cardPreview.status !== Image.Ready
                                    }

                                    DankSpinner {
                                        anchors.centerIn: parent
                                        running: cardPreview.status === Image.Loading
                                        visible: running
                                    }
                                }

                                Row {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: Theme.spacingXS
                                    spacing: Theme.spacingXXS

                                    Repeater {
                                        model: root.badgeModel(cardCell.modelData)

                                        PluginBadge {
                                            required property var modelData
                                            label: modelData.label
                                            iconName: modelData.icon
                                            tone: root.badgeTone(modelData.tone)
                                            onImage: true
                                        }
                                    }
                                }

                                PluginBadge {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: Theme.spacingXS
                                    iconName: "thumb_up"
                                    label: cardCell.modelData.upvotes || 0
                                    tone: Theme.primary
                                    onImage: true
                                    visible: !!cardCell.modelData.issueUrl
                                }
                            }

                            Column {
                                z: 1
                                anchors.top: previewArea.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: Theme.spacingS
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingXXS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        id: cardIcon
                                        name: cardCell.modelData.icon || "extension"
                                        size: Theme.iconSize - 4
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        width: parent.width - cardIcon.width - installAction.width - Theme.spacingS * 2
                                        text: cardCell.modelData.name || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        id: installAction

                                        property string buttonState: {
                                            if (cardCell.isInstalled)
                                                return "installed";
                                            if (!cardCell.isCompatible)
                                                return "incompatible";
                                            return "available";
                                        }

                                        width: 28
                                        height: 28
                                        radius: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: {
                                            switch (buttonState) {
                                            case "installed":
                                                return Theme.surfaceVariant;
                                            case "incompatible":
                                                return Theme.withAlpha(Theme.warning, 0.15);
                                            default:
                                                return Theme.primary;
                                            }
                                        }
                                        opacity: buttonState === "available" && installMouseArea.containsMouse ? 0.85 : 1

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            size: 15
                                            name: {
                                                switch (installAction.buttonState) {
                                                case "installed":
                                                    return "check";
                                                case "incompatible":
                                                    return "warning";
                                                default:
                                                    return "download";
                                                }
                                            }
                                            color: {
                                                switch (installAction.buttonState) {
                                                case "installed":
                                                    return Theme.surfaceText;
                                                case "incompatible":
                                                    return Theme.warning;
                                                default:
                                                    return Theme.surface;
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: installMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: installAction.buttonState === "available" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: installAction.buttonState === "available"
                                            onClicked: root.installPlugin(cardCell.modelData.name, cardCell.modelData.type === "desktop")
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: I18n.tr("by %1", "author attribution").arg(cardCell.modelData.author || I18n.tr("Unknown", "unknown author"))
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.outline
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                StyledText {
                                    width: parent.width
                                    text: cardCell.modelData.description || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }
                        }
                    }
                }

                Column {
                    id: letterIndex
                    anchors.right: parent.right
                    anchors.top: pluginGrid.top
                    anchors.bottom: pluginGrid.bottom
                    width: 16
                    visible: root.showLetterIndex && !root.isLoading
                    spacing: 0

                    Repeater {
                        model: root.availableLetters

                        Item {
                            required property string modelData
                            width: letterIndex.width
                            height: Math.max(12, letterIndex.height / Math.max(1, root.availableLetters.length))

                            StyledText {
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: letterMouseArea.containsMouse ? Theme.primary : Theme.outline
                            }

                            MouseArea {
                                id: letterMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.scrollToLetter(parent.modelData)
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    visible: !root.isLoading && root.filteredPlugins.length === 0

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "search_off"
                        size: Theme.iconSize + 16
                        color: Theme.outline
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("No plugins found", "empty plugin list")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Rectangle {
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
                anchors.top: headerArea.bottom
                anchors.topMargin: Theme.spacingM
                anchors.bottom: parent.bottom
                z: 10
                color: Theme.surfaceContainer
                opacity: root.detailPluginId !== "" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
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
                    height: 40

                    DankActionButton {
                        id: detailBackButton
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "arrow_back"
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
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Rectangle {
                        id: detailInstallButton

                        property string buttonState: {
                            if (detailPane.plugin.installed)
                                return "installed";
                            if (!PluginService.checkPluginCompatibility(detailPane.plugin.requires_dms))
                                return "incompatible";
                            return "available";
                        }

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: Math.max(96, detailInstallRow.implicitWidth + Theme.spacingL * 2)
                        width: implicitWidth
                        height: 36
                        radius: height / 2
                        color: {
                            switch (buttonState) {
                            case "installed":
                                return Theme.surfaceVariant;
                            case "incompatible":
                                return Theme.withAlpha(Theme.warning, 0.15);
                            default:
                                return Theme.primary;
                            }
                        }
                        opacity: buttonState === "available" && detailInstallMouseArea.containsMouse ? 0.9 : 1
                        border.width: buttonState !== "available" ? 1 : 0
                        border.color: buttonState === "incompatible" ? Theme.warning : Theme.outline

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Row {
                            id: detailInstallRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: {
                                    switch (detailInstallButton.buttonState) {
                                    case "installed":
                                        return "check";
                                    case "incompatible":
                                        return "warning";
                                    default:
                                        return "download";
                                    }
                                }
                                size: 16
                                color: {
                                    switch (detailInstallButton.buttonState) {
                                    case "installed":
                                        return Theme.surfaceText;
                                    case "incompatible":
                                        return Theme.warning;
                                    default:
                                        return Theme.surface;
                                    }
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: {
                                    switch (detailInstallButton.buttonState) {
                                    case "installed":
                                        return I18n.tr("Installed", "installed status");
                                    case "incompatible":
                                        return I18n.tr("Requires %1", "version requirement").arg(detailPane.plugin.requires_dms || "");
                                    default:
                                        return I18n.tr("Install", "install action button");
                                    }
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                wrapMode: Text.NoWrap
                                color: {
                                    switch (detailInstallButton.buttonState) {
                                    case "installed":
                                        return Theme.surfaceText;
                                    case "incompatible":
                                        return Theme.warning;
                                    default:
                                        return Theme.surface;
                                    }
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: detailInstallMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: detailInstallButton.buttonState === "available" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: detailInstallButton.buttonState === "available"
                            onClicked: root.installPlugin(detailPane.plugin.name, detailPane.plugin.type === "desktop")
                        }
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
                        width: Math.min(880, parent.width)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingL

                        Rectangle {
                            width: parent.width
                            height: Math.round(width * 0.52)
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            border.color: Theme.withAlpha(Theme.outline, 0.2)
                            border.width: 1

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Theme.cornerRadius - 1
                                color: "transparent"

                                CachingImage {
                                    id: heroImage
                                    anchors.fill: parent
                                    imagePath: detailPane.heroFallback ? root.previewUrl(detailPane.plugin) : root.heroUrl(detailPane.plugin)
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
                                    size: Theme.iconSize + 8
                                    color: Theme.outline
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: heroImage.status === Image.Error ? I18n.tr("Screenshot unavailable", "plugin browser screenshot error") : I18n.tr("No screenshot provided", "plugin browser no screenshot")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.outline
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.badgeModel(detailPane.plugin)

                                PluginBadge {
                                    required property var modelData
                                    label: modelData.label
                                    iconName: modelData.icon
                                    tone: root.badgeTone(modelData.tone)
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
                            color: Theme.outline
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
                                font.weight: Font.Medium
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
                                size: Theme.iconSize - 6
                                color: Theme.surfaceVariantText
                            }

                            Flow {
                                width: parent.width - Theme.iconSize + 6 - Theme.spacingS
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
                                size: Theme.iconSize - 6
                                color: Theme.surfaceVariantText
                            }

                            Flow {
                                width: parent.width - Theme.iconSize + 6 - Theme.spacingS
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
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                            }

                            Flow {
                                width: parent.width
                                spacing: Theme.spacingXS

                                Repeater {
                                    model: root.relatedPlugins(detailPane.plugin)

                                    Rectangle {
                                        id: relatedChip

                                        required property var modelData

                                        height: 26
                                        width: relatedRow.implicitWidth + Theme.spacingM * 2
                                        radius: height / 2
                                        color: relatedMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.primary, 0.1)
                                        border.color: Theme.withAlpha(Theme.primary, 0.3)
                                        border.width: 1
                                        opacity: modelData.key ? 1 : 0.6

                                        Row {
                                            id: relatedRow
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingXXS

                                            DankIcon {
                                                name: "extension"
                                                size: 12
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: relatedChip.modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: relatedMouseArea
                                            anchors.fill: parent
                                            enabled: relatedChip.modelData.key !== ""
                                            hoverEnabled: enabled
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: root.detailPluginId = relatedChip.modelData.key
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    LazyLoader {
        id: thirdPartyConfirmLoader
        active: false

        FloatingWindow {
            id: thirdPartyConfirmModal

            property bool disablePopupTransparency: true
            parentWindow: root

            function show() {
                visible = true;
            }

            function hide() {
                visible = false;
            }

            objectName: "thirdPartyConfirm"
            title: I18n.tr("Third-Party Plugin Warning")
            implicitWidth: 500
            implicitHeight: 350
            color: Theme.surfaceContainer
            visible: false

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        thirdPartyConfirmModal.hide();
                        event.accepted = true;
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "warning"
                            size: Theme.iconSize
                            color: Theme.warning
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Third-Party Plugin Warning")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - parent.spacing * 2 - Theme.iconSize - parent.children[1].implicitWidth - closeConfirmBtn.width
                            height: 1
                        }

                        DankActionButton {
                            id: closeConfirmBtn
                            iconName: "close"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: thirdPartyConfirmModal.hide()
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Third-party plugins are created by the community and are not officially supported by DankMaterialShell.\n\nThese plugins may pose security and privacy risks - install at your own risk.")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("• Plugins may contain bugs or security issues")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: I18n.tr("• Review code before installation when possible")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: I18n.tr("• Install only from trusted sources")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - parent.spacing * 3 - y
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Cancel")
                            iconName: "close"
                            onClicked: thirdPartyConfirmModal.hide()
                        }

                        DankButton {
                            text: I18n.tr("I Understand")
                            iconName: "check"
                            onClicked: {
                                SessionData.setShowThirdPartyPlugins(true);
                                root.updateFilteredPlugins();
                                thirdPartyConfirmModal.hide();
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
