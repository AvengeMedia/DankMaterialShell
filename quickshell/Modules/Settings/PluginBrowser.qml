import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
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

    readonly property bool activeCategorySort: normalizedSortMode(SessionData.pluginBrowserSortMode) === "category"
    readonly property bool showCategoryFilters: activeCategorySort && categoryFilterOptions.length > 1
    readonly property bool showLetterIndex: {
        var mode = normalizedSortMode(SessionData.pluginBrowserSortMode);
        return (mode === "name" || mode === "author") && availableLetters.length > 1;
    }

    readonly property var sortChipOptions: [
        { id: "installed", label: I18n.tr("Installed", "plugin browser filter chip"), toggle: true },
        { id: "default", label: I18n.tr("Default", "plugin browser sort option"), toggle: false },
        { id: "name", label: I18n.tr("Name", "plugin browser sort option"), toggle: false },
        { id: "author", label: I18n.tr("Contributor", "plugin browser sort option"), toggle: false },
        { id: "category", label: I18n.tr("Category", "plugin browser sort option"), toggle: false }
    ]

    function normalizedSortMode(mode) {
        if (mode === "type" || mode === "contributor")
            return "author";
        if (mode === "name" || mode === "author" || mode === "category")
            return mode;
        return "default";
    }

    function isSortChipSelected(chipId, toggle) {
        if (toggle)
            return SessionData.pluginBrowserInstalledFirst;
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
        var options = [{
            key: "all",
            label: I18n.tr("All", "plugin browser category filter"),
            count: plugins.length
        }];
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
        if (!pluginBrowserList)
            return;
        pluginBrowserList.savedY = 0;
        pluginBrowserList.cancelFlick();
        pluginBrowserList.contentY = 0;
        Qt.callLater(() => {
            if (pluginBrowserList)
                pluginBrowserList.forceLayout();
        });
    }

    function scrollToLetter(letter) {
        var mode = normalizedSortMode(SessionData.pluginBrowserSortMode);
        for (var i = 0; i < filteredPlugins.length; i++) {
            var key = sortKeyForPlugin(filteredPlugins[i], mode);
            if (key && key.charAt(0).toUpperCase() === letter) {
                pluginBrowserList.positionViewAtIndex(i, ListView.Beginning);
                pluginBrowserList.savedY = pluginBrowserList.contentY;
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
            if (a.featured !== b.featured)
                return a.featured ? -1 : 1;
            if (a.firstParty !== b.firstParty)
                return a.firstParty ? -1 : 1;
            return comparePluginName(a, b);
        });

        filteredPlugins = filtered;
        updateAvailableLetters(filtered);
        selectedIndex = -1;
        keyboardNavigationActive = false;
        refreshListLayout();
    }

    function selectNext() {
        if (filteredPlugins.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, filteredPlugins.length - 1);
    }

    function selectPrevious() {
        if (filteredPlugins.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.max(selectedIndex - 1, -1);
        if (selectedIndex === -1)
            keyboardNavigationActive = false;
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
    minimumSize: Qt.size(450, 400)
    implicitWidth: 600
    implicitHeight: 650
    color: Theme.surfaceContainer
    visible: false

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
                height: Math.max(headerIcon.height, headerText.height, refreshButton.height, closeButton.height)

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                DankIcon {
                    id: headerIcon
                    name: "store"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: headerText
                    text: I18n.tr("Browse Plugins", "plugin browser header")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.left: headerIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankButton {
                        id: thirdPartyButton
                        text: SessionData.showThirdPartyPlugins ? I18n.tr("Hide 3rd Party") : I18n.tr("Show 3rd Party")
                        iconName: SessionData.showThirdPartyPlugins ? "visibility_off" : "visibility"
                        height: 28
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
                        id: refreshButton
                        iconName: "refresh"
                        iconSize: 18
                        iconColor: Theme.primary
                        visible: !root.isLoading
                        onClicked: root.refreshPlugins()
                    }

                    DankActionButton {
                        visible: windowControls.canMaximize
                        iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.outline
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        id: closeButton
                        iconName: "close"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.outline
                        onClicked: root.hide()
                    }
                }
            }

            StyledText {
                id: descriptionText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerArea.bottom
                anchors.topMargin: Theme.spacingM
                text: I18n.tr("Install plugins from the DMS plugin registry", "plugin browser description")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.outline
                wrapMode: Text.WordWrap
            }

            DankTextField {
                id: browserSearchField
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: descriptionText.bottom
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

            Item {
                id: sortControlsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: browserSearchField.bottom
                anchors.topMargin: Theme.spacingM
                height: sortControlsLayout.implicitHeight

                RowLayout {
                    id: sortControlsLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.spacingS

                    Repeater {
                        model: root.sortChipOptions

                        Rectangle {
                            id: sortChip
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.maximumHeight: 32
                            property bool selected: root.isSortChipSelected(modelData.id, modelData.toggle)
                            property bool hovered: chipMouseArea.containsMouse
                            property bool pressed: chipMouseArea.pressed

                            implicitWidth: chipContent.implicitWidth + Theme.spacingM * 2
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
                                    if (pressed)
                                        return sortChip.selected ? Theme.primaryPressed : Theme.surfaceTextHover;
                                    if (hovered)
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
                                    name: modelData.toggle ? "download_done" : "check"
                                    size: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.primaryText
                                    visible: sortChip.selected
                                }

                                StyledText {
                                    text: modelData.label
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
                                    if (modelData.toggle) {
                                        SessionData.setPluginBrowserInstalledFirst(!SessionData.pluginBrowserInstalledFirst);
                                    } else {
                                        if (modelData.id !== "category")
                                            root.categoryFilter = "all";
                                        SessionData.setPluginBrowserSortMode(modelData.id);
                                    }
                                    root.updateFilteredPlugins();
                                }
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
                        id: categoryFilterDropdown
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
                anchors.bottomMargin: Theme.spacingM

                Item {
                    anchors.fill: parent
                    visible: root.isLoading

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "sync"
                            size: 48
                            color: Theme.primary
                            anchors.horizontalCenter: parent.horizontalCenter
                            smoothTransform: root.isLoading

                            RotationAnimator on rotation {
                                from: 0
                                to: -360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.isLoading
                            }
                        }

                        StyledText {
                            text: I18n.tr("Loading...", "loading indicator")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                DankListView {
                    id: pluginBrowserList

                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: root.showLetterIndex ? Theme.spacingM + 18 : Theme.spacingM
                    anchors.topMargin: Theme.spacingS
                    anchors.bottomMargin: Theme.spacingS
                    spacing: Theme.spacingS
                    model: ScriptModel {
                        values: root.filteredPlugins
                        objectProp: "id"
                    }
                    clip: true
                    visible: !root.isLoading
                    add: null
                    remove: null
                    displaced: null
                    move: null

                    ScrollBar.vertical: DankScrollbar {
                        id: browserScrollbar
                    }

                    delegate: Rectangle {
                        width: pluginBrowserList.width
                        height: pluginDelegateColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
                        property bool isInstalled: modelData.installed || false
                        property bool isFirstParty: modelData.firstParty || false
                        property bool isFeatured: modelData.featured || false
                        property bool isCompatible: PluginService.checkPluginCompatibility(modelData.requires_dms)
                        color: isSelected ? Theme.primarySelected : Theme.withAlpha(Theme.surfaceVariant, 0.3)
                        border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.2)
                        border.width: isSelected ? 2 : 1

                        Column {
                            id: pluginDelegateColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: modelData.icon || "extension"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - Theme.iconSize - Theme.spacingM - installButton.width - Theme.spacingM
                                    spacing: 2

                                    Row {
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            height: 16
                                            width: featuredRow.implicitWidth + Theme.spacingXS * 2
                                            radius: 8
                                            color: Theme.withAlpha(Theme.secondary, 0.15)
                                            border.color: Theme.withAlpha(Theme.secondary, 0.4)
                                            border.width: 1
                                            visible: isFeatured
                                            anchors.verticalCenter: parent.verticalCenter

                                            Row {
                                                id: featuredRow
                                                anchors.centerIn: parent
                                                spacing: 2

                                                DankIcon {
                                                    name: "star"
                                                    size: 10
                                                    color: Theme.secondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: I18n.tr("featured")
                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                    color: Theme.secondary
                                                    font.weight: Font.Medium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }

                                        Rectangle {
                                            height: 16
                                            width: firstPartyText.implicitWidth + Theme.spacingXS * 2
                                            radius: 8
                                            color: Theme.withAlpha(Theme.primary, 0.15)
                                            border.color: Theme.withAlpha(Theme.primary, 0.4)
                                            border.width: 1
                                            visible: isFirstParty
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                id: firstPartyText
                                                anchors.centerIn: parent
                                                text: I18n.tr("official")
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                color: Theme.primary
                                                font.weight: Font.Medium
                                            }
                                        }

                                        Rectangle {
                                            height: 16
                                            width: thirdPartyText.implicitWidth + Theme.spacingXS * 2
                                            radius: 8
                                            color: Theme.withAlpha(Theme.warning, 0.15)
                                            border.color: Theme.withAlpha(Theme.warning, 0.4)
                                            border.width: 1
                                            visible: !isFirstParty
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                id: thirdPartyText
                                                anchors.centerIn: parent
                                                text: I18n.tr("3rd party")
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                color: Theme.warning
                                                font.weight: Font.Medium
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: {
                                            const author = I18n.tr("by %1", "author attribution").arg(modelData.author || I18n.tr("Unknown", "unknown author"));
                                            const source = modelData.repo ? ` • <a href="${modelData.repo}" style="text-decoration:none; color:${Theme.primary};">${I18n.tr("source", "source code link")}</a>` : "";
                                            return author + source;
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.outline
                                        linkColor: Theme.primary
                                        textFormat: Text.RichText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        onLinkActivated: url => Qt.openUrlExternally(url)

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            acceptedButtons: Qt.NoButton
                                            propagateComposedEvents: true
                                        }
                                    }
                                }

                                Rectangle {
                                    id: installButton

                                    property string buttonState: {
                                        if (isInstalled)
                                            return "installed";
                                        if (!isCompatible)
                                            return "incompatible";
                                        return "available";
                                    }

                                    implicitWidth: Math.max(80, incompatRow.implicitWidth + Theme.spacingM * 2)
                                    width: implicitWidth
                                    height: 32
                                    radius: Theme.cornerRadius
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
                                    opacity: buttonState === "available" && installMouseArea.containsMouse ? 0.9 : 1
                                    border.width: buttonState !== "available" ? 1 : 0
                                    border.color: buttonState === "incompatible" ? Theme.warning : Theme.outline

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.standardEasing
                                        }
                                    }

                                    Row {
                                        id: incompatRow
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS

                                        DankIcon {
                                            name: {
                                                switch (installButton.buttonState) {
                                                case "installed":
                                                    return "check";
                                                case "incompatible":
                                                    return "warning";
                                                default:
                                                    return "download";
                                                }
                                            }
                                            size: 14
                                            color: {
                                                switch (installButton.buttonState) {
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
                                                switch (installButton.buttonState) {
                                                case "installed":
                                                    return I18n.tr("Installed", "installed status");
                                                case "incompatible":
                                                    return I18n.tr("Requires %1", "version requirement").arg(modelData.requires_dms);
                                                default:
                                                    return I18n.tr("Install", "install action button");
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            elide: Text.ElideNone
                                            wrapMode: Text.NoWrap
                                            color: {
                                                switch (installButton.buttonState) {
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
                                        id: installMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: installButton.buttonState === "available" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: installButton.buttonState === "available"
                                        onClicked: {
                                            const isDesktop = modelData.type === "desktop";
                                            root.installPlugin(modelData.name, isDesktop);
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: modelData.description || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.outline
                                width: parent.width
                                wrapMode: Text.WordWrap
                                visible: (modelData.description || "").length > 0
                            }

                            Flow {
                                width: parent.width
                                spacing: Theme.spacingXS
                                visible: (modelData.capabilities || []).length > 0

                                Repeater {
                                    model: modelData.capabilities || []

                                    Rectangle {
                                        height: 18
                                        width: capabilityText.implicitWidth + Theme.spacingXS * 2
                                        radius: 9
                                        color: Theme.withAlpha(Theme.primary, 0.1)
                                        border.color: Theme.withAlpha(Theme.primary, 0.3)
                                        border.width: 1

                                        StyledText {
                                            id: capabilityText
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Theme.primary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: letterIndex
                    anchors.right: parent.right
                    anchors.top: pluginBrowserList.top
                    anchors.bottom: pluginBrowserList.bottom
                    anchors.rightMargin: Theme.spacingXS
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
                                text: modelData
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: letterMouseArea.containsMouse ? Theme.primary : Theme.outline
                            }

                            MouseArea {
                                id: letterMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.scrollToLetter(modelData)
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: listArea
                    text: I18n.tr("No plugins found", "empty plugin list")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    visible: !root.isLoading && root.filteredPlugins.length === 0
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
