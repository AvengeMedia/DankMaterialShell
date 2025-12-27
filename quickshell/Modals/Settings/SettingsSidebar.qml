pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Settings
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int currentIndex: 0
    property var parentModal: null
    property var expandedCategories: ({})
    property var autoExpandedCategories: ({})
    property bool searchActive: searchField.text.length > 0
    property int searchSelectedIndex: 0
    property int keyboardHighlightIndex: -1

    function focusSearch() {
        searchField.forceActiveFocus();
    }

    function highlightNext() {
        var flatItems = getFlatNavigableItems();
        if (flatItems.length === 0)
            return;
        var currentPos = flatItems.findIndex(item => item.tabIndex === keyboardHighlightIndex);
        if (currentPos === -1) {
            currentPos = flatItems.findIndex(item => item.tabIndex === currentIndex);
        }
        var nextPos = (currentPos + 1) % flatItems.length;
        keyboardHighlightIndex = flatItems[nextPos].tabIndex;
        autoExpandForTab(keyboardHighlightIndex);
    }

    function highlightPrevious() {
        var flatItems = getFlatNavigableItems();
        if (flatItems.length === 0)
            return;
        var currentPos = flatItems.findIndex(item => item.tabIndex === keyboardHighlightIndex);
        if (currentPos === -1) {
            currentPos = flatItems.findIndex(item => item.tabIndex === currentIndex);
        }
        var prevPos = (currentPos - 1 + flatItems.length) % flatItems.length;
        keyboardHighlightIndex = flatItems[prevPos].tabIndex;
        autoExpandForTab(keyboardHighlightIndex);
    }

    function selectHighlighted() {
        if (keyboardHighlightIndex < 0)
            return;
        var oldIndex = currentIndex;
        currentIndex = keyboardHighlightIndex;
        autoCollapseIfNeeded(oldIndex, currentIndex);
        keyboardHighlightIndex = -1;
        Qt.callLater(searchField.forceActiveFocus);
    }

    readonly property var categoryStructure: [
        {
            "id": "personalization",
            "text": I18n.tr("Personalization"),
            "icon": "palette",
            "children": [
                {
                    "id": "wallpaper",
                    "text": I18n.tr("Wallpaper"),
                    "icon": "wallpaper",
                    "tabIndex": 0
                },
                {
                    "id": "theme",
                    "text": I18n.tr("Theme & Colors"),
                    "icon": "format_paint",
                    "tabIndex": 10
                },
                {
                    "id": "typography",
                    "text": I18n.tr("Typography & Motion"),
                    "icon": "text_fields",
                    "tabIndex": 14
                },
                {
                    "id": "time_weather",
                    "text": I18n.tr("Time & Weather"),
                    "icon": "schedule",
                    "tabIndex": 1
                },
                {
                    "id": "sounds",
                    "text": I18n.tr("Sounds"),
                    "icon": "volume_up",
                    "tabIndex": 15,
                    "soundsOnly": true
                }
            ]
        },
        {
            "id": "dankbar",
            "text": I18n.tr("Dank Bar"),
            "icon": "toolbar",
            "children": [
                {
                    "id": "dankbar_settings",
                    "text": I18n.tr("Settings"),
                    "icon": "tune",
                    "tabIndex": 3
                },
                {
                    "id": "dankbar_widgets",
                    "text": I18n.tr("Widgets"),
                    "icon": "widgets",
                    "tabIndex": 22
                }
            ]
        },
        {
            "id": "workspaces_widgets",
            "text": I18n.tr("Workspaces & Widgets"),
            "icon": "dashboard",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "workspaces",
                    "text": I18n.tr("Workspaces"),
                    "icon": "view_module",
                    "tabIndex": 4
                },
                {
                    "id": "media_player",
                    "text": I18n.tr("Media Player"),
                    "icon": "music_note",
                    "tabIndex": 16
                },
                {
                    "id": "notifications",
                    "text": I18n.tr("Notifications"),
                    "icon": "notifications",
                    "tabIndex": 17
                },
                {
                    "id": "osd",
                    "text": I18n.tr("On-screen Displays"),
                    "icon": "tune",
                    "tabIndex": 18
                },
                {
                    "id": "running_apps",
                    "text": I18n.tr("Running Apps"),
                    "icon": "apps",
                    "tabIndex": 19,
                    "hyprlandNiriOnly": true
                },
                {
                    "id": "updater",
                    "text": I18n.tr("System Updater"),
                    "icon": "refresh",
                    "tabIndex": 20
                },
                {
                    "id": "desktop_widgets",
                    "text": I18n.tr("Desktop Widgets"),
                    "icon": "widgets",
                    "tabIndex": 27
                }
            ]
        },
        {
            "id": "dock_launcher",
            "text": I18n.tr("Dock & Launcher"),
            "icon": "apps",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "dock",
                    "text": I18n.tr("Dock"),
                    "icon": "dock_to_bottom",
                    "tabIndex": 5
                },
                {
                    "id": "launcher",
                    "text": I18n.tr("Launcher"),
                    "icon": "grid_view",
                    "tabIndex": 9
                }
            ]
        },
        {
            "id": "keybinds",
            "text": I18n.tr("Keyboard Shortcuts"),
            "icon": "keyboard",
            "tabIndex": 2,
            "shortcutsOnly": true
        },
        {
            "id": "displays",
            "text": I18n.tr("Displays"),
            "icon": "monitor",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "display_config",
                    "text": I18n.tr("Configuration") + " (Beta)",
                    "icon": "display_settings",
                    "tabIndex": 24
                },
                {
                    "id": "display_gamma",
                    "text": I18n.tr("Gamma Control"),
                    "icon": "brightness_6",
                    "tabIndex": 25
                },
                {
                    "id": "display_widgets",
                    "text": I18n.tr("Widgets", "settings_displays"),
                    "icon": "widgets",
                    "tabIndex": 26
                }
            ]
        },
        {
            "id": "network",
            "text": I18n.tr("Network"),
            "icon": "wifi",
            "tabIndex": 7,
            "dmsOnly": true
        },
        {
            "id": "system",
            "text": I18n.tr("System"),
            "icon": "computer",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "printers",
                    "text": I18n.tr("Printers"),
                    "icon": "print",
                    "tabIndex": 8,
                    "cupsOnly": true
                },
                {
                    "id": "clipboard",
                    "text": I18n.tr("Clipboard"),
                    "icon": "content_paste",
                    "tabIndex": 23,
                    "clipboardOnly": true
                }
            ]
        },
        {
            "id": "power_security",
            "text": I18n.tr("Power & Security"),
            "icon": "security",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "lock_screen",
                    "text": I18n.tr("Lock Screen"),
                    "icon": "lock",
                    "tabIndex": 11
                },
                {
                    "id": "power_sleep",
                    "text": I18n.tr("Power & Sleep"),
                    "icon": "power_settings_new",
                    "tabIndex": 21
                }
            ]
        },
        {
            "id": "plugins",
            "text": I18n.tr("Plugins"),
            "icon": "extension",
            "tabIndex": 12
        },
        {
            "id": "separator",
            "separator": true
        },
        {
            "id": "about",
            "text": I18n.tr("About"),
            "icon": "info",
            "tabIndex": 13
        }
    ]

    function isItemVisible(item) {
        if (item.dmsOnly && NetworkService.usingLegacy)
            return false;
        if (item.cupsOnly && !CupsService.cupsAvailable)
            return false;
        if (item.shortcutsOnly && !KeybindsService.available)
            return false;
        if (item.soundsOnly && !AudioService.soundsAvailable)
            return false;
        if (item.hyprlandNiriOnly && !CompositorService.isNiri && !CompositorService.isHyprland)
            return false;
        if (item.clipboardOnly && (!DMSService.isConnected || DMSService.apiVersion < 23))
            return false;
        return true;
    }

    function hasVisibleChildren(category) {
        if (!category.children)
            return false;
        return category.children.some(child => isItemVisible(child));
    }

    function isCategoryVisible(category) {
        if (category.separator)
            return true;
        if (!isItemVisible(category))
            return false;
        if (category.children && !hasVisibleChildren(category))
            return false;
        return true;
    }

    function toggleCategory(categoryId) {
        var newExpanded = Object.assign({}, expandedCategories);
        newExpanded[categoryId] = !isCategoryExpanded(categoryId);
        expandedCategories = newExpanded;

        var newAutoExpanded = Object.assign({}, autoExpandedCategories);
        delete newAutoExpanded[categoryId];
        autoExpandedCategories = newAutoExpanded;
    }

    function isCategoryExpanded(categoryId) {
        if (expandedCategories[categoryId] !== undefined) {
            return expandedCategories[categoryId];
        }
        var category = categoryStructure.find(cat => cat.id === categoryId);
        if (category && category.collapsedByDefault) {
            return false;
        }
        return true;
    }

    function isChildActive(category) {
        if (!category.children)
            return false;
        return category.children.some(child => child.tabIndex === currentIndex);
    }

    function findParentCategory(tabIndex) {
        for (var i = 0; i < categoryStructure.length; i++) {
            var cat = categoryStructure[i];
            if (cat.children) {
                for (var j = 0; j < cat.children.length; j++) {
                    if (cat.children[j].tabIndex === tabIndex) {
                        return cat;
                    }
                }
            }
        }
        return null;
    }

    function autoExpandForTab(tabIndex) {
        var parent = findParentCategory(tabIndex);
        if (!parent)
            return;

        if (!isCategoryExpanded(parent.id)) {
            var newExpanded = Object.assign({}, expandedCategories);
            newExpanded[parent.id] = true;
            expandedCategories = newExpanded;

            var newAutoExpanded = Object.assign({}, autoExpandedCategories);
            newAutoExpanded[parent.id] = true;
            autoExpandedCategories = newAutoExpanded;
        }
    }

    function autoCollapseIfNeeded(oldTabIndex, newTabIndex) {
        var oldParent = findParentCategory(oldTabIndex);
        var newParent = findParentCategory(newTabIndex);

        if (oldParent && oldParent !== newParent && autoExpandedCategories[oldParent.id]) {
            var newExpanded = Object.assign({}, expandedCategories);
            newExpanded[oldParent.id] = false;
            expandedCategories = newExpanded;

            var newAutoExpanded = Object.assign({}, autoExpandedCategories);
            delete newAutoExpanded[oldParent.id];
            autoExpandedCategories = newAutoExpanded;
        }
    }

    function navigateNext() {
        var flatItems = getFlatNavigableItems();
        var currentPos = flatItems.findIndex(item => item.tabIndex === currentIndex);
        var oldIndex = currentIndex;
        if (currentPos === -1) {
            currentIndex = flatItems[0]?.tabIndex ?? 0;
        } else {
            var nextPos = (currentPos + 1) % flatItems.length;
            currentIndex = flatItems[nextPos].tabIndex;
        }
        autoCollapseIfNeeded(oldIndex, currentIndex);
        autoExpandForTab(currentIndex);
    }

    function navigatePrevious() {
        var flatItems = getFlatNavigableItems();
        var currentPos = flatItems.findIndex(item => item.tabIndex === currentIndex);
        var oldIndex = currentIndex;
        if (currentPos === -1) {
            currentIndex = flatItems[0]?.tabIndex ?? 0;
        } else {
            var prevPos = (currentPos - 1 + flatItems.length) % flatItems.length;
            currentIndex = flatItems[prevPos].tabIndex;
        }
        autoCollapseIfNeeded(oldIndex, currentIndex);
        autoExpandForTab(currentIndex);
    }

    function getFlatNavigableItems() {
        var items = [];
        for (var i = 0; i < categoryStructure.length; i++) {
            var cat = categoryStructure[i];
            if (cat.separator || !isCategoryVisible(cat))
                continue;

            if (cat.tabIndex !== undefined && !cat.children) {
                items.push(cat);
            }

            if (cat.children) {
                for (var j = 0; j < cat.children.length; j++) {
                    var child = cat.children[j];
                    if (isItemVisible(child)) {
                        items.push(child);
                    }
                }
            }
        }
        return items;
    }

    function resolveTabIndex(name: string): int {
        if (!name)
            return -1;

        var normalized = name.toLowerCase().replace(/[_\-\s]/g, "");

        for (var i = 0; i < categoryStructure.length; i++) {
            var cat = categoryStructure[i];
            if (cat.separator)
                continue;

            var catId = (cat.id || "").toLowerCase().replace(/[_\-\s]/g, "");
            if (catId === normalized) {
                if (cat.tabIndex !== undefined)
                    return cat.tabIndex;
                if (cat.children && cat.children.length > 0)
                    return cat.children[0].tabIndex;
            }

            if (cat.children) {
                for (var j = 0; j < cat.children.length; j++) {
                    var child = cat.children[j];
                    var childId = (child.id || "").toLowerCase().replace(/[_\-\s]/g, "");
                    if (childId === normalized)
                        return child.tabIndex;
                }
            }
        }
        return -1;
    }

    width: 270
    height: parent.height
    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    radius: Theme.cornerRadius

    function selectSearchResult(result) {
        if (!result)
            return;
        if (result.section) {
            SettingsSearchService.navigateToSection(result.section);
        }
        var oldIndex = root.currentIndex;
        root.currentIndex = result.tabIndex;
        autoCollapseIfNeeded(oldIndex, result.tabIndex);
        autoExpandForTab(result.tabIndex);
        searchField.text = "";
        SettingsSearchService.clear();
        searchSelectedIndex = 0;
        keyboardHighlightIndex = -1;
        Qt.callLater(searchField.forceActiveFocus);
    }

    function navigateSearchResults(delta) {
        if (SettingsSearchService.results.length === 0)
            return;
        searchSelectedIndex = Math.max(0, Math.min(searchSelectedIndex + delta, SettingsSearchService.results.length - 1));
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: sidebarColumn.height

        Column {
            id: sidebarColumn
            width: parent.width
            leftPadding: Theme.spacingS
            rightPadding: Theme.spacingS
            bottomPadding: Theme.spacingL
            topPadding: Theme.spacingM + 2
            spacing: 2

            ProfileSection {
                width: parent.width - parent.leftPadding - parent.rightPadding
                parentModal: root.parentModal
            }

            Rectangle {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: 1
                color: Theme.outline
                opacity: 0.2
            }

            Item {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: Theme.spacingS
            }

            DankTextField {
                id: searchField
                width: parent.width - parent.leftPadding - parent.rightPadding
                placeholderText: I18n.tr("Search...")
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: Theme.primary
                leftIconName: "search"
                leftIconSize: Theme.iconSize - 4
                showClearButton: text.length > 0
                onTextChanged: {
                    SettingsSearchService.search(text);
                    root.searchSelectedIndex = 0;
                }
                keyForwardTargets: [keyHandler]

                Item {
                    id: keyHandler
                    function navNext() {
                        if (root.searchActive) {
                            root.navigateSearchResults(1);
                        } else {
                            root.highlightNext();
                        }
                    }
                    function navPrev() {
                        if (root.searchActive) {
                            root.navigateSearchResults(-1);
                        } else {
                            root.highlightPrevious();
                        }
                    }
                    function navSelect() {
                        if (root.searchActive && SettingsSearchService.results.length > 0) {
                            root.selectSearchResult(SettingsSearchService.results[root.searchSelectedIndex]);
                        } else if (root.keyboardHighlightIndex >= 0) {
                            root.selectHighlighted();
                        }
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
                        navNext();
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: event => {
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
                            root.keyboardHighlightIndex = -1;
                        }
                        event.accepted = true;
                    }
                }
            }

            Column {
                id: searchResultsColumn
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 2
                visible: root.searchActive

                Item {
                    width: parent.width
                    height: Theme.spacingS
                }

                Repeater {
                    model: ScriptModel {
                        values: SettingsSearchService.results
                    }

                    Rectangle {
                        id: resultDelegate
                        required property int index
                        required property var modelData

                        width: searchResultsColumn.width
                        height: resultContent.height + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: {
                            if (root.searchSelectedIndex === index)
                                return Theme.primary;
                            if (resultMouseArea.containsMouse)
                                return Theme.surfaceHover;
                            return "transparent";
                        }

                        Row {
                            id: resultContent
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: resultDelegate.modelData.icon || "settings"
                                size: Theme.iconSize - 2
                                color: root.searchSelectedIndex === resultDelegate.index ? Theme.primaryText : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSize - Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: resultDelegate.modelData.label
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: root.searchSelectedIndex === resultDelegate.index ? Theme.primaryText : Theme.surfaceText
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignLeft
                                }

                                StyledText {
                                    text: resultDelegate.modelData.category
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: root.searchSelectedIndex === resultDelegate.index ? Theme.withAlpha(Theme.primaryText, 0.7) : Theme.surfaceVariantText
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }

                        MouseArea {
                            id: resultMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectSearchResult(resultDelegate.modelData)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
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

            Item {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: Theme.spacingS
                visible: !root.searchActive
            }

            Repeater {
                model: root.categoryStructure

                delegate: Column {
                    id: categoryDelegate
                    required property int index
                    required property var modelData

                    width: parent.width - parent.leftPadding - parent.rightPadding
                    visible: !root.searchActive && root.isCategoryVisible(modelData)
                    spacing: 2

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                        visible: categoryDelegate.modelData.separator === true
                    }

                    Item {
                        width: parent.width
                        height: Theme.spacingS
                        visible: categoryDelegate.modelData.separator === true
                    }

                    Rectangle {
                        id: categoryRow
                        width: parent.width
                        height: 40
                        radius: Theme.cornerRadius
                        visible: categoryDelegate.modelData.separator !== true

                        readonly property bool hasTab: categoryDelegate.modelData.tabIndex !== undefined && !categoryDelegate.modelData.children
                        readonly property bool isActive: hasTab && root.currentIndex === categoryDelegate.modelData.tabIndex
                        readonly property bool isHighlighted: hasTab && root.keyboardHighlightIndex === categoryDelegate.modelData.tabIndex

                        color: {
                            if (isActive)
                                return Theme.primary;
                            if (isHighlighted)
                                return Theme.primaryHover;
                            if (categoryMouseArea.containsMouse)
                                return Theme.surfaceHover;
                            return "transparent";
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: categoryDelegate.modelData.icon || ""
                                size: Theme.iconSize - 2
                                color: categoryRow.isActive ? Theme.primaryText : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: categoryDelegate.modelData.text || ""
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: (categoryRow.isActive || root.isChildActive(categoryDelegate.modelData)) ? Font.Medium : Font.Normal
                                color: categoryRow.isActive ? Theme.primaryText : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.iconSize - Theme.spacingM - (categoryDelegate.modelData.children ? expandIcon.width + Theme.spacingS : 0)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                            }

                            DankIcon {
                                id: expandIcon
                                name: root.isCategoryExpanded(categoryDelegate.modelData.id) ? "expand_less" : "expand_more"
                                size: Theme.iconSize - 4
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                                visible: categoryDelegate.modelData.children !== undefined && categoryDelegate.modelData.children.length > 0
                            }
                        }

                        MouseArea {
                            id: categoryMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.keyboardHighlightIndex = -1;
                                if (categoryDelegate.modelData.children) {
                                    root.toggleCategory(categoryDelegate.modelData.id);
                                } else if (categoryDelegate.modelData.tabIndex !== undefined) {
                                    root.currentIndex = categoryDelegate.modelData.tabIndex;
                                }
                                Qt.callLater(searchField.forceActiveFocus);
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Column {
                        id: childrenColumn
                        width: parent.width
                        spacing: 2
                        visible: categoryDelegate.modelData.children !== undefined && root.isCategoryExpanded(categoryDelegate.modelData.id)
                        clip: true

                        Repeater {
                            model: categoryDelegate.modelData.children || []

                            delegate: Rectangle {
                                id: childDelegate
                                required property int index
                                required property var modelData

                                readonly property bool isActive: root.currentIndex === modelData.tabIndex
                                readonly property bool isHighlighted: root.keyboardHighlightIndex === modelData.tabIndex

                                width: childrenColumn.width
                                height: 36
                                radius: Theme.cornerRadius
                                visible: root.isItemVisible(modelData)
                                color: {
                                    if (isActive)
                                        return Theme.primary;
                                    if (isHighlighted)
                                        return Theme.primaryHover;
                                    if (childMouseArea.containsMouse)
                                        return Theme.surfaceHover;
                                    return "transparent";
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingL + Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: childDelegate.modelData.icon || ""
                                        size: Theme.iconSize - 4
                                        color: childDelegate.isActive ? Theme.primaryText : Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: childDelegate.modelData.text || ""
                                        font.pixelSize: Theme.fontSizeSmall + 1
                                        font.weight: childDelegate.isActive ? Font.Medium : Font.Normal
                                        color: childDelegate.isActive ? Theme.primaryText : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: childMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.keyboardHighlightIndex = -1;
                                        root.currentIndex = childDelegate.modelData.tabIndex;
                                        Qt.callLater(searchField.forceActiveFocus);
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
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
