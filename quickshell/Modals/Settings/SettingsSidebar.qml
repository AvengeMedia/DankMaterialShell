pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Settings
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string currentPage: ""
    property string activeCategoryId: ""
    property var parentModal: null

    signal pageRequested(string pageId)

    property bool searchActive: searchField.text.length > 0
    property int searchSelectedIndex: 0
    property string keyboardHighlightId: ""
    readonly property var categoryStructure: SettingsTabs.structure
    readonly property var navGroups: {
        const groups = [];
        let current = [];
        for (const entry of categoryStructure) {
            if (entry.separator) {
                if (current.length)
                    groups.push(current);
                current = [];
                continue;
            }
            current.push(entry);
        }
        if (current.length)
            groups.push(current);
        return groups;
    }

    function focusSearch() {
        searchField.forceActiveFocus();
    }

    function focusAfterNavigation() {
        if (parentModal?.isCompactMode && !parentModal.menuVisible) {
            parentModal.focusCurrentPage();
            return;
        }
        focusSearch();
    }

    function navigableIds() {
        const ids = [];
        for (const entry of categoryStructure) {
            if (entry.separator || !SettingsTabs.isVisible(SettingsTabs.page(entry.id)))
                continue;
            ids.push(entry.id);
        }
        return ids;
    }

    function moveHighlight(delta) {
        const ids = navigableIds();
        if (ids.length === 0)
            return;
        let position = ids.indexOf(keyboardHighlightId);
        if (position === -1)
            position = ids.indexOf(SettingsTabs.isPluginPage(currentPage) ? currentPage : activeCategoryId);
        keyboardHighlightId = ids[(position + delta + ids.length) % ids.length];
    }

    function selectHighlighted() {
        if (!keyboardHighlightId)
            return;
        pageRequested(keyboardHighlightId);
        keyboardHighlightId = "";
        Qt.callLater(root.focusAfterNavigation);
    }

    function ensureRowVisible(item) {
        if (!item || sidebarFlickable.height <= 0)
            return;
        const itemY = item.mapToItem(sidebarFlickable.contentItem, 0, 0).y;
        const viewH = sidebarFlickable.height;
        if (itemY >= sidebarFlickable.contentY && itemY + item.height <= sidebarFlickable.contentY + viewH)
            return;
        sidebarFlickable.contentY = Math.max(0, Math.min(itemY - viewH / 4, sidebarFlickable.contentHeight - viewH));
    }

    function openBarWidget(widgetId, addIfMissing) {
        const widget = BarWidgetCatalog.get(widgetId);
        let where = SettingsData.locateBarWidget(widgetId, SettingsUiState.selectedBarId);
        if (!where && addIfMissing) {
            const barId = SettingsData.getBarConfig(SettingsUiState.selectedBarId) ? SettingsUiState.selectedBarId : (SettingsData.barConfigs[0]?.id ?? "default");
            const section = widget?.section ?? "right";
            const index = SettingsData.addBarWidget(barId, section, widgetId);
            if (index >= 0)
                where = {
                    "barId": barId,
                    "section": section,
                    "index": index
                };
        }
        if (!where)
            return;
        SettingsUiState.selectedBarId = where.barId;
        SettingsUiState.selectedWidgetSection = where.section;
        SettingsUiState.selectedWidgetIndex = where.index;
        SettingsUiState.selectedDockId = "";
        SettingsUiState.selectedWidgetTitle = widget?.text ?? widgetId;
        SettingsUiState.selectedWidgetDescription = widget?.description ?? "";
        SettingsUiState.selectedWidgetIcon = widget?.icon ?? "widgets";
        pageRequested("dankbar_widgets");
        if (BarWidgetCatalog.hasOptions(widgetId))
            parentModal?.navigateTo("bar_widget");
    }

    function selectSearchResult(result) {
        if (!result)
            return;
        if (result.runtimeType === "barWidget" || result.runtimeType === "barWidgetAdd") {
            openBarWidget(result.runtimeId, result.runtimeType === "barWidgetAdd");
            keyboardHighlightId = "";
            Qt.callLater(root.focusAfterNavigation);
            return;
        }
        if (result.section)
            SettingsSearchService.navigateToSection(result.section);
        const page = result.page || SettingsTabs.pageForTabIndex(result.tabIndex);
        if (page)
            pageRequested(page);
        keyboardHighlightId = "";
        Qt.callLater(root.focusAfterNavigation);
    }

    function navigateSearchResults(delta) {
        if (SettingsSearchService.results.length === 0)
            return;
        searchSelectedIndex = Math.max(0, Math.min(searchSelectedIndex + delta, SettingsSearchService.results.length - 1));
        Qt.callLater(ensureSearchResultVisible);
    }

    function ensureSearchResultVisible() {
        const result = searchResultsRepeater.itemAt(searchSelectedIndex);
        const contentItem = sidebarFlickable.contentItem;
        if (!result || !contentItem)
            return;

        const mapped = result.mapToItem(contentItem, 0, 0);
        const margin = Theme.spacingS;
        const top = mapped.y;
        const bottom = top + result.height;
        const maxContentY = Math.max(0, sidebarFlickable.contentHeight - sidebarFlickable.height);
        if (top < sidebarFlickable.contentY + margin) {
            sidebarFlickable.contentY = Math.max(0, top - margin);
        } else if (bottom > sidebarFlickable.contentY + sidebarFlickable.height - margin) {
            sidebarFlickable.contentY = Math.min(maxContentY, bottom - sidebarFlickable.height + margin);
        }
    }

    implicitWidth: SettingsMetrics.sidebarWidth
    width: implicitWidth
    height: parent.height

    Component.onCompleted: GreeterService.refresh()

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.dividerWidth
        color: Theme.outlineVariant
        visible: !(root.parentModal?.isCompactMode ?? false)
    }

    DankSearchField {
        id: searchField
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        anchors.topMargin: Theme.spacingM
        height: Theme.iconButtonSize + Theme.spacingM
        placeholderText: I18n.tr("Search settings", "settings search field placeholder")
        onTextChanged: {
            SettingsSearchService.search(text);
            root.searchSelectedIndex = 0;
            sidebarFlickable.contentY = 0;
            Qt.callLater(root.ensureSearchResultVisible);
        }
        keyForwardTargets: [keyHandler]

        Item {
            id: keyHandler
            function navNext() {
                if (root.searchActive) {
                    root.navigateSearchResults(1);
                    return;
                }
                root.moveHighlight(1);
            }
            function navPrev() {
                if (root.searchActive) {
                    root.navigateSearchResults(-1);
                    return;
                }
                root.moveHighlight(-1);
            }
            function navSelect() {
                if (root.searchActive && SettingsSearchService.results.length > 0) {
                    root.selectSearchResult(SettingsSearchService.results[root.searchSelectedIndex]);
                    return;
                }
                root.selectHighlighted();
            }
            Keys.onDownPressed: event => {
                navNext();
                event.accepted = true;
            }
            Keys.onUpPressed: event => {
                navPrev();
                event.accepted = true;
            }
            Keys.onTabPressed: event => {
                if (!root.searchActive && root.keyboardHighlightId === "")
                    return;
                navNext();
                event.accepted = true;
            }
            Keys.onBacktabPressed: event => {
                if (!root.searchActive && root.keyboardHighlightId === "")
                    return;
                navPrev();
                event.accepted = true;
            }
            Keys.onReturnPressed: event => {
                navSelect();
                event.accepted = true;
            }
            Keys.onEscapePressed: event => {
                if (root.searchActive) {
                    searchField.text = "";
                    SettingsSearchService.clear();
                } else {
                    root.keyboardHighlightId = "";
                }
                event.accepted = true;
            }
        }
    }

    DankFlickable {
        id: sidebarFlickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchField.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: SettingsMetrics.sidebarGroupGap
        clip: true
        contentHeight: sidebarColumn.height

        Column {
            id: sidebarColumn
            width: parent.width
            leftPadding: Theme.spacingL
            rightPadding: Theme.spacingL
            bottomPadding: Theme.spacingL
            spacing: SettingsMetrics.sidebarGroupGap

            ProfileSection {
                width: parent.width - parent.leftPadding - parent.rightPadding
                visible: !root.searchActive
                onClicked: {
                    root.pageRequested("user_accounts");
                    Qt.callLater(root.focusAfterNavigation);
                }
            }

            Column {
                id: searchResultsColumn
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: Theme.groupedListGap
                visible: root.searchActive

                Repeater {
                    id: searchResultsRepeater
                    model: ScriptModel {
                        values: SettingsSearchService.results
                    }

                    SettingsSidebarItem {
                        id: resultDelegate
                        required property int index
                        required property var modelData

                        isFirstInGroup: index === 0
                        isLastInGroup: index === SettingsSearchService.results.length - 1
                        iconName: modelData.icon || "settings"
                        title: modelData.label
                        hint: modelData.category
                        accent: SettingsTabs.accentFor(modelData.page || SettingsTabs.pageForTabIndex(modelData.tabIndex))
                        active: root.searchSelectedIndex === index
                        onClicked: root.selectSearchResult(modelData)
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("No matches")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    visible: searchField.text.length > 0 && SettingsSearchService.results.length === 0
                    topPadding: Theme.spacingM
                }
            }

            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: SettingsMetrics.sidebarGroupGap
                visible: !root.searchActive

                Repeater {
                    model: root.navGroups

                    Column {
                        id: groupColumn
                        required property var modelData

                        width: parent.width
                        spacing: Theme.groupedListGap

                        readonly property var visibleIds: {
                            const ids = [];
                            for (const entry of modelData) {
                                if (SettingsTabs.isVisible(SettingsTabs.page(entry.id)))
                                    ids.push(entry.id);
                            }
                            return ids;
                        }

                        Repeater {
                            model: groupColumn.modelData

                            SettingsSidebarItem {
                                id: categoryRow
                                required property var modelData

                                readonly property bool isHighlighted: root.keyboardHighlightId === modelData.id
                                onIsHighlightedChanged: {
                                    if (isHighlighted)
                                        Qt.callLater(root.ensureRowVisible, categoryRow);
                                }

                                width: groupColumn.width
                                visible: SettingsTabs.isVisible(SettingsTabs.page(modelData.id))
                                isFirstInGroup: groupColumn.visibleIds[0] === modelData.id
                                isLastInGroup: groupColumn.visibleIds[groupColumn.visibleIds.length - 1] === modelData.id
                                iconName: modelData.icon || ""
                                title: modelData.text || ""
                                hint: SettingsTabs.hubHint(modelData)
                                accent: SettingsTabs.accentFor(modelData.id)
                                active: root.activeCategoryId === modelData.id && !SettingsTabs.isPluginPage(root.currentPage)
                                highlighted: isHighlighted
                                onClicked: {
                                    root.keyboardHighlightId = "";
                                    root.pageRequested(modelData.id);
                                    Qt.callLater(root.focusAfterNavigation);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
