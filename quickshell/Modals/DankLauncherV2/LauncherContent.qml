pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.DankLauncherV2.Components

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property string viewModeContext: "spotlight"
    property alias searchField: searchField
    property alias controller: controller
    property alias resultsList: resultsList
    property alias actionPanel: actionPanel
    readonly property alias activeContextMenu: contextMenu
    property var transientSurfaceTracker: null

    property bool editMode: false
    property var editingApp: null
    property string editAppId: ""

    function resetScroll() {
        resultsList.resetScroll();
    }

    function focusSearchField() {
        searchField.forceActiveFocus();
    }

    function closeTransientUi() {
        transientSurfaceTracker?.closeAll?.();
        actionPanel.hide();
        root.enabled = true;
    }

    function openEditMode(app) {
        if (!app)
            return;
        editingApp = app;
        editAppId = app.id || app.execString || app.exec || "";
        editMode = true;
    }

    function closeEditMode() {
        editMode = false;
        editingApp = null;
        editAppId = "";
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function showContextMenu(item, x, y, fromKeyboard) {
        if (!item)
            return;
        if (!contextMenu.hasContextMenuActions(item))
            return;
        contextMenu.show(x, y, item, fromKeyboard);
    }

    anchors.fill: parent
    focus: true

    Controller {
        id: controller
        active: root.parentModal ? (root.parentModal.spotlightOpen || root.parentModal.isClosing) : true
        viewModeContext: root.viewModeContext

        onItemExecuted: {
            if (root.parentModal) {
                root.parentModal.hide();
            }
        }
    }

    LauncherContextMenu {
        id: contextMenu
        parent: root
        controller: root.controller
        searchField: root.searchField
        parentHandler: root
        transientSurfaceTracker: root.transientSurfaceTracker

        onEditAppRequested: app => {
            root.openEditMode(app);
        }
    }

    Connections {
        target: root.parentModal
        ignoreUnknownSignals: true

        function onSpotlightOpenChanged() {
            if (!root.parentModal?.spotlightOpen)
                root.closeTransientUi();
        }

        function onContentVisibleChanged() {
            if (!root.parentModal?.contentVisible)
                root.closeTransientUi();
        }
    }

    Keys.onPressed: event => {
        if (editMode) {
            if (event.key === Qt.Key_Escape) {
                closeEditMode();
                event.accepted = true;
            }
            return;
        }

        var hasCtrl = event.modifiers & Qt.ControlModifier;
        var hasAlt = event.modifiers & Qt.AltModifier;
        event.accepted = true;

        switch (event.key) {
        case Qt.Key_Escape:
            if (actionPanel.expanded) {
                actionPanel.hide();
                return;
            }
            if (controller.clearPluginFilter())
                return;
            if (root.parentModal)
                root.parentModal.hide();
            return;
        case Qt.Key_Backspace:
            if (searchField.text.length === 0) {
                if (controller.clearPluginFilter())
                    return;
                if (controller.autoSwitchedToFiles) {
                    controller.restorePreviousMode();
                    return;
                }
            }
            event.accepted = false;
            return;
        case Qt.Key_Down:
            controller.selectNext();
            return;
        case Qt.Key_Up:
            controller.selectPrevious();
            return;
        case Qt.Key_PageDown:
            controller.selectPageDown(8);
            return;
        case Qt.Key_PageUp:
            controller.selectPageUp(8);
            return;
        case Qt.Key_Right:
            if (controller.getCurrentSectionViewMode() !== "list") {
                I18n.isRtl ? controller.selectLeft() : controller.selectRight();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_Left:
            if (controller.getCurrentSectionViewMode() !== "list") {
                I18n.isRtl ? controller.selectRight() : controller.selectLeft();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_J:
            if (hasCtrl) {
                controller.selectNext();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_K:
            if (hasCtrl) {
                controller.selectPrevious();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_L:
            if (hasCtrl) {
                if (controller.getCurrentSectionViewMode() !== "list") {
                    I18n.isRtl ? controller.selectLeft() : controller.selectRight();
                }
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_H:
            if (hasCtrl) {
                if (controller.getCurrentSectionViewMode() !== "list") {
                    I18n.isRtl ? controller.selectRight() : controller.selectLeft();
                }
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_N:
            if (hasCtrl) {
                controller.selectNextSection();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_P:
            if (hasCtrl) {
                controller.selectPreviousSection();
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_Tab:
            if (hasCtrl) {
                actionPanel.hide();
                controller.cycleMode();
            } else if (actionPanel.hasActions) {
                actionPanel.expanded ? actionPanel.cycleAction() : actionPanel.show();
            }
            return;
        case Qt.Key_Backtab:
            if (hasCtrl) {
                actionPanel.hide();
                controller.cycleMode(true);
            } else if (actionPanel.hasActions) {
                actionPanel.expanded ? actionPanel.cycleAction(true) : actionPanel.show();
            }
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.modifiers & Qt.ShiftModifier) {
                controller.pasteSelected();
                return;
            }
            if (actionPanel.expanded && actionPanel.selectedActionIndex > 0) {
                actionPanel.executeSelectedAction();
            } else {
                controller.executeSelected();
            }
            return;
        case Qt.Key_Menu:
        case Qt.Key_F10:
            if (contextMenu.hasContextMenuActions(controller.selectedItem)) {
                var scenePos = resultsList.getSelectedItemPosition();
                var localPos = root.mapFromItem(null, scenePos.x, scenePos.y);
                showContextMenu(controller.selectedItem, localPos.x, localPos.y, true);
            }
            return;
        case Qt.Key_1:
            if (hasCtrl || hasAlt) {
                controller.setMode("all");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_2:
            if (hasCtrl || hasAlt) {
                controller.setMode("apps");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_3:
            if (hasCtrl || hasAlt) {
                controller.setMode("files");
                return;
            }
            event.accepted = false;
            return;
        case Qt.Key_4:
            if (hasCtrl || hasAlt) {
                controller.setMode("plugins");
                return;
            }
            event.accepted = false;
            return;
        default:
            event.accepted = false;
        }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
        visible: !editMode

        readonly property bool inverted: (root.parentModal?.frameOwnsConnectedChrome ?? false) && (root.parentModal?.resolvedConnectedBarSide === "top")
        readonly property bool _connectedArcAtHeader: inverted && !(root.parentModal?.launcherArcExtenderActive ?? false)

        Item {
            id: footerBar
            readonly property bool _connectedBottomEmerge: (root.parentModal?.frameOwnsConnectedChrome ?? false) && (root.parentModal?.resolvedConnectedBarSide === "bottom")
            readonly property bool _connectedArcAtFooter: _connectedBottomEmerge && !(root.parentModal?.launcherArcExtenderActive ?? false)
            readonly property bool showFooter: SettingsData.dankLauncherV2Size !== "micro" && SettingsData.dankLauncherV2ShowFooter
            readonly property int edgeInset: root.parentModal?.paintedBorderWidth ?? Theme.outlineWidth
            readonly property var modes: [
                {
                    label: I18n.tr("All"),
                    mode: "all"
                },
                {
                    label: I18n.tr("Apps", "launcher mode tab, short for applications"),
                    mode: "apps"
                },
                {
                    label: I18n.tr("Files"),
                    mode: "files"
                },
                {
                    label: I18n.tr("Plugins"),
                    mode: "plugins"
                }
            ]

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: footerBar.edgeInset
            anchors.rightMargin: footerBar.edgeInset
            y: contentHolder.inverted ? 0 : (parent.height - height - (_connectedBottomEmerge ? 0 : footerBar.edgeInset))
            height: showFooter ? ((_connectedArcAtFooter || contentHolder._connectedArcAtHeader) ? LauncherMetrics.footerHeight + Theme.avatarSize : LauncherMetrics.footerHeight) : 0
            visible: showFooter
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: -Theme.windowRadius

                visible: !(root.parentModal?.frameOwnsConnectedChrome ?? false) && !Theme.blurLayersActive
                color: Theme.foregroundColor(Theme.cardSurface, Theme.isFloatingWindow(root))
                radius: Theme.windowRadius
            }
            DankFilterChips {
                id: modeChips
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: chipHeight
                flow: Flow.TopToBottom
                chipHeight: LauncherMetrics.footerChipHeight
                chipPadding: Theme.spacingS
                showCheck: false
                activeFocusOnTab: false
                model: footerBar.modes
                Binding on currentIndex {
                    value: footerBar.modes.findIndex(entry => entry.mode === controller.searchMode)
                    restoreMode: Binding.RestoreNone
                }
                onSelectionChanged: index => {
                    controller.setMode(footerBar.modes[index].mode);
                    searchField.forceActiveFocus();
                }
            }

            Row {
                id: hintsRow
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight
                spacing: Theme.spacingM

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑↓ " + I18n.tr("nav", "launcher footer hint after arrow keys, short for navigate")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵ " + I18n.tr("Open")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Tab", "keyboard tab key name", true) + " " + I18n.tr("Actions", "noun, launcher footer hint after the tab key, also section label")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                    visible: actionPanel.hasActions
                }
            }
        }

        Item {
            id: searchRow
            height: searchField.height
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            y: contentHolder.inverted ? (parent.height - height - Theme.spacingM) : Theme.spacingM

            LauncherSearchField {
                id: searchField
                pluginName: controller.activePluginName
                width: parent.width
                textColor: Theme.onSurface
                font.pixelSize: Theme.fontSizeLarge
                enabled: root.parentModal ? (root.parentModal.spotlightOpen || root.parentModal.isClosing) : true
                placeholderText: I18n.tr("Search", "search field placeholder") + "…"
                ignoreUpDownKeys: true
                ignoreTabKeys: true
                keyForwardTargets: [root]

                onTextChanged: {
                    controller.setSearchQuery(text);
                    if (actionPanel.expanded) {
                        actionPanel.hide();
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (root.parentModal) {
                            root.parentModal.hide();
                        }
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        if (actionPanel.expanded && actionPanel.selectedActionIndex > 0) {
                            actionPanel.executeSelectedAction();
                        } else {
                            controller.executeSelected();
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        Item {
            id: contentStack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: contentHolder.inverted ? footerBar.bottom : searchRow.bottom
            anchors.bottom: contentHolder.inverted ? searchRow.top : footerBar.top
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.topMargin: contentHolder.inverted && !footerBar.showFooter ? Theme.spacingM : (contentHolder.inverted || categoryRow.visible || fileFilterRow.visible ? contentStack.gap : 0)
            anchors.bottomMargin: 0
            readonly property real gap: controller.searchMode === "files" ? Theme.spacingS : Theme.spacingXS
            clip: false

            Row {
                id: categoryRow
                width: parent.width
                readonly property bool showPluginCategories: controller.activePluginCategories.length > 0
                height: showPluginCategories ? Theme.buttonHeightS : 0
                visible: showPluginCategories
                spacing: Theme.spacingS
                anchors.top: parent.top
                anchors.topMargin: 0

                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                DankDropdown {
                    id: categoryDropdown
                    transientSurfaceTracker: root.transientSurfaceTracker
                    focusPolicy: Qt.NoFocus
                    focusReturnTarget: searchField
                    visible: categoryRow.showPluginCategories
                    width: Math.min(Theme.fieldDefaultWidth, parent.width)
                    compactMode: true
                    dropdownWidth: Theme.fieldDefaultWidth
                    popupWidth: Theme.fieldDefaultWidth + Theme.spacingXL * 2
                    maxPopupHeight: Theme.menuMaxHeight
                    enableFuzzySearch: controller.activePluginCategories.length > 8
                    currentValue: {
                        const cats = controller.activePluginCategories;
                        const current = controller.activePluginCategory;
                        if (!current)
                            return cats.length > 0 ? cats[0].name : "";
                        for (let i = 0; i < cats.length; i++) {
                            if (cats[i].id === current)
                                return cats[i].name;
                        }
                        return cats.length > 0 ? cats[0].name : "";
                    }
                    options: {
                        const cats = controller.activePluginCategories;
                        const names = [];
                        for (let i = 0; i < cats.length; i++)
                            names.push(cats[i].name);
                        return names;
                    }

                    onValueChanged: value => {
                        const cats = controller.activePluginCategories;
                        for (let i = 0; i < cats.length; i++) {
                            if (cats[i].name === value) {
                                controller.setActivePluginCategory(cats[i].id);
                                return;
                            }
                        }
                    }
                }
            }

            Item {
                id: fileFilterRow
                width: parent.width
                height: showFileFilters ? fileFilterContent.height : 0
                visible: showFileFilters
                anchors.top: parent.top
                anchors.topMargin: 0

                readonly property bool showFileFilters: controller.searchMode === "files"

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                RowLayout {
                    id: fileFilterContent
                    width: parent.width
                    height: Theme.buttonHeightS
                    spacing: Theme.spacingS

                    DankDropdown {
                        id: typeDropdown
                        focusPolicy: Qt.NoFocus
                        focusReturnTarget: searchField
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        visible: DSearchService.supportsTypeFilter
                        triggerHeight: fileFilterContent.height
                        compactMode: true
                        dropdownWidth: width
                        maxPopupHeight: Theme.menuMaxHeight
                        transientSurfaceTracker: root.transientSurfaceTracker
                        currentValue: {
                            switch (controller.fileSearchType) {
                            case "file":
                                return I18n.tr("Files");
                            case "dir":
                                return I18n.tr("Folders");
                            default:
                                return I18n.tr("All");
                            }
                        }
                        options: [I18n.tr("All"), I18n.tr("Files"), I18n.tr("Folders")]

                        onValueChanged: value => {
                            switch (value) {
                            case I18n.tr("Files"):
                                controller.setFileSearchType("file");
                                return;
                            case I18n.tr("Folders"):
                                controller.setFileSearchType("dir");
                                return;
                            default:
                                controller.setFileSearchType("all");
                            }
                        }
                    }

                    DankDropdown {
                        id: sortDropdown
                        focusPolicy: Qt.NoFocus
                        focusReturnTarget: searchField
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        triggerHeight: fileFilterContent.height
                        compactMode: true
                        dropdownWidth: width
                        maxPopupHeight: Theme.menuMaxHeight
                        transientSurfaceTracker: root.transientSurfaceTracker
                        currentValue: {
                            switch (controller.fileSearchSort) {
                            case "score":
                                return I18n.tr("Score");
                            case "name":
                                return I18n.tr("Name");
                            case "modified":
                                return I18n.tr("Modified");
                            case "size":
                                return I18n.tr("Size");
                            default:
                                return I18n.tr("Score");
                            }
                        }
                        options: [I18n.tr("Score", "noun, launcher file search sort option, match relevance"), I18n.tr("Name"), I18n.tr("Modified"), I18n.tr("Size")]

                        onValueChanged: value => {
                            var sortMap = {};
                            sortMap[I18n.tr("Score")] = "score";
                            sortMap[I18n.tr("Name")] = "name";
                            sortMap[I18n.tr("Modified")] = "modified";
                            sortMap[I18n.tr("Size")] = "size";
                            controller.setFileSearchSort(sortMap[value] || "score");
                        }
                    }

                    DankTextField {
                        id: extFilterField
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: fileFilterContent.height
                        backgroundColor: Theme.floatingWindowFieldColor
                        placeholderText: I18n.tr("ext", "launcher file search placeholder, short for file extension")
                        font.pixelSize: Theme.fontSizeMedium
                        showClearButton: text.length > 0

                        onTextChanged: {
                            controller.setFileSearchExt(text.trim());
                        }
                    }
                }
            }

            Item {
                id: resultsSlot
                width: parent.width
                anchors.top: fileFilterRow.visible ? fileFilterRow.bottom : (categoryRow.visible ? categoryRow.bottom : parent.top)
                anchors.topMargin: (fileFilterRow.visible || categoryRow.visible) ? contentStack.gap : 0
                anchors.bottom: actionPanel.top
                anchors.bottomMargin: actionPanel.height > 0 ? contentStack.gap : (footerBar.showFooter || contentHolder.inverted ? 0 : Theme.spacingM)
                opacity: {
                    if (!root.parentModal)
                        return 1;
                    if (Theme.isDirectionalEffect && root.parentModal.isClosing)
                        return 1;
                    return root.parentModal.isClosing ? 0 : 1;
                }

                ResultsList {
                    id: resultsList
                    focusReturnTarget: searchField
                    keyForwardTargets: [root]
                    anchors.fill: parent
                    controller: root.controller
                    leadingSectionHeaderAtBottom: contentHolder.inverted
                    transientSurfaceTracker: root.transientSurfaceTracker

                    onItemRightClicked: (index, item, sceneX, sceneY) => {
                        if (item && contextMenu.hasContextMenuActions(item)) {
                            var localPos = root.mapFromItem(null, sceneX, sceneY);
                            root.showContextMenu(item, localPos.x, localPos.y, false);
                        }
                    }
                }
            }

            ActionPanel {
                id: actionPanel
                width: parent.width
                anchors.bottom: parent.bottom
                selectedItem: controller.selectedItem
                controller: controller
            }
        }
    }

    Connections {
        target: controller
        function onSelectedItemChanged() {
            if (actionPanel.expanded && !actionPanel.hasActions) {
                actionPanel.hide();
            }
        }
        function onSearchQueryRequested(query) {
            searchField.text = query;
        }
        function onModeChanged() {
            extFilterField.text = "";
        }
    }

    Loader {
        id: editLoader
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        active: root.editMode
        visible: active
        focus: root.editMode

        sourceComponent: AppEditView {
            focus: true
            editingApp: root.editingApp
            editAppId: root.editAppId
            onCloseRequested: root.closeEditMode()
        }

        onLoaded: item.loadOverride()
    }
}
