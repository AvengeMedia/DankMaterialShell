pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.DankLauncherV2.Components

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property alias searchField: searchInput
    property var controllerOverride: null
    readonly property var controller: controllerOverride ?? searchController
    readonly property alias activeContextMenu: contextMenu
    property var transientSurfaceTracker: null
    property bool showResultsWithoutQuery: false
    property bool suspendSearchUpdates: false
    property real maxResultsHeight: 0
    property real resultsInset: LauncherMetrics.spotlightInset

    readonly property bool _hasQuery: root.showResultsWithoutQuery || searchInput.text.length > 0
    readonly property real _searchBarH: LauncherMetrics.pillHeight
    readonly property real _searchAreaH: _searchBarH
    readonly property alias searchAreaHeight: root._searchAreaH
    readonly property real actionPanelHeight: actionPanel.height
    readonly property real _statusH: Theme.listItemTwoLineHeight + Theme.spacingXL
    readonly property real _maxResultsH: root.maxResultsHeight > 0 ? root.maxResultsHeight : Math.max(0, Math.min(LauncherMetrics.maxResultsHeight, (parentModal?.screenHeight ?? Theme.mediumBreakpoint) - (parentModal?.modalY ?? 0) - LauncherMetrics.pillHeight - actionPanel.height - Theme.spacingL))
    readonly property real _resultsContentH: resultsList.contentHeight > 0 ? resultsInset + resultsList.contentHeight + resultsList.bottomInset : _statusH
    readonly property real _resultsH: _hasQuery ? Math.min(_resultsContentH, _maxResultsH) : 0
    readonly property int _resizeDuration: Theme.expressiveDurations.expressiveFastSpatial
    readonly property real _frameClipRadius: Math.max(0, (parentModal?.frameBottomRadius ?? 0) - resultsInset)

    implicitHeight: _searchAreaH + resultsContainer.height + actionPanel.height

    property bool _animateResize: false

    Component.onCompleted: resizeAnimEnableTimer.restart()

    Timer {
        id: resizeAnimEnableTimer
        interval: Theme.expressiveDurations.expressiveEffects
        onTriggered: root._animateResize = true
    }

    function resetScroll() {
        resultsList.resetScroll();
    }

    function resetSearch() {
        root.controller.reset();
        if (root.showResultsWithoutQuery)
            root.controller.performSearch();
    }

    function closeTransientUi() {
        transientSurfaceTracker?.closeAll?.();
        actionPanel.hide();
        root.enabled = true;
    }

    function _focusSearch() {
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
    }

    function _showContextMenu(item, sceneX, sceneY, fromKeyboard) {
        if (!item || !contextMenu.hasContextMenuActions(item))
            return;
        const localPos = root.mapFromItem(null, sceneX, sceneY);
        contextMenu.show(localPos.x, localPos.y, item, fromKeyboard);
    }

    function _handleKey(event) {
        const hasCtrl = event.modifiers & Qt.ControlModifier;
        const hasAlt = event.modifiers & Qt.AltModifier;

        switch (event.key) {
        case Qt.Key_Escape:
            if (actionPanel.expanded) {
                actionPanel.hide();
                event.accepted = true;
                return;
            }
            if (root.controller.clearPluginFilter()) {
                event.accepted = true;
                return;
            }
            root.parentModal?.hide();
            event.accepted = true;
            return;
        case Qt.Key_Backspace:
            if (searchInput.text.length === 0) {
                if (root.controller.clearPluginFilter()) {
                    event.accepted = true;
                    return;
                }
                if (root.controller.autoSwitchedToFiles) {
                    root.controller.restorePreviousMode();
                    event.accepted = true;
                    return;
                }
            }
            event.accepted = false;
            return;
        case Qt.Key_Down:
            root.controller.selectNext();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            root.controller.selectPrevious();
            event.accepted = true;
            return;
        case Qt.Key_Right:
        case Qt.Key_Left:
            if (root.controller.getCurrentSectionViewMode() === "list")
                break;
            if ((event.key === Qt.Key_Right) !== I18n.isRtl)
                root.controller.selectRight();
            else
                root.controller.selectLeft();
            event.accepted = true;
            return;
        case Qt.Key_H:
        case Qt.Key_L:
            if (!hasCtrl || root.controller.getCurrentSectionViewMode() === "list")
                break;
            if ((event.key === Qt.Key_L) !== I18n.isRtl)
                root.controller.selectRight();
            else
                root.controller.selectLeft();
            event.accepted = true;
            return;
        case Qt.Key_PageDown:
            root.controller.selectPageDown(7);
            event.accepted = true;
            return;
        case Qt.Key_PageUp:
            root.controller.selectPageUp(7);
            event.accepted = true;
            return;
        case Qt.Key_J:
            if (hasCtrl) {
                root.controller.selectNext();
                event.accepted = true;
                return;
            }
            break;
        case Qt.Key_K:
            if (hasCtrl) {
                root.controller.selectPrevious();
                event.accepted = true;
                return;
            }
            break;
        case Qt.Key_N:
        case Qt.Key_P:
            if (!hasCtrl)
                break;
            if (event.key === Qt.Key_N)
                root.controller.selectNextSection();
            else
                root.controller.selectPreviousSection();
            event.accepted = true;
            return;
        case Qt.Key_Tab:
            if (hasCtrl) {
                actionPanel.hide();
                _cycleCategory(false);
            } else if (actionPanel.hasActions) {
                actionPanel.expanded ? actionPanel.cycleAction() : actionPanel.show();
            }
            event.accepted = true;
            return;
        case Qt.Key_Backtab:
            if (hasCtrl) {
                actionPanel.hide();
                _cycleCategory(true);
            } else if (actionPanel.hasActions) {
                actionPanel.expanded ? actionPanel.cycleAction(true) : actionPanel.show();
            }
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.modifiers & Qt.ShiftModifier) {
                root.controller.pasteSelected();
            } else if (actionPanel.expanded && actionPanel.selectedActionIndex > 0) {
                actionPanel.executeSelectedAction();
            } else {
                root.controller.executeSelected();
            }
            event.accepted = true;
            return;
        case Qt.Key_Menu:
        case Qt.Key_F10:
            if (contextMenu.hasContextMenuActions(root.controller.selectedItem)) {
                const scenePos = resultsList.getSelectedItemPosition();
                _showContextMenu(root.controller.selectedItem, scenePos.x, scenePos.y, true);
                event.accepted = true;
                return;
            }
            break;
        case Qt.Key_1:
            if (hasCtrl || hasAlt) {
                root.controller.setMode("all");
                event.accepted = true;
                return;
            }
            break;
        case Qt.Key_2:
            if (hasCtrl || hasAlt) {
                root.controller.setMode("apps");
                event.accepted = true;
                return;
            }
            break;
        case Qt.Key_3:
            if (hasCtrl || hasAlt) {
                root.controller.setMode("files");
                event.accepted = true;
                return;
            }
            break;
        case Qt.Key_4:
            if (hasCtrl || hasAlt) {
                root.controller.setMode("plugins");
                event.accepted = true;
                return;
            }
            break;
        }

        event.accepted = false;
    }

    Controller {
        id: searchController
        active: !root.controllerOverride && (root.parentModal ? (root.parentModal.spotlightOpen || root.parentModal.isClosing) : true)
        viewModeContext: "spotlight"
        forceLinearNavigation: false
    }

    LauncherContextMenu {
        id: contextMenu
        parent: root
        controller: root.controller
        searchField: searchInput
        parentHandler: root
        allowEditActions: false
        transientSurfaceTracker: root.transientSurfaceTracker
    }

    Connections {
        target: root.parentModal
        ignoreUnknownSignals: true

        function onSpotlightOpenChanged() {
            if (!root.parentModal?.spotlightOpen)
                root.closeTransientUi();
        }

        function onContentVisibleChanged() {
            if (!root.parentModal?.contentVisible) {
                root.closeTransientUi();
                return;
            }
            root._animateResize = false;
            resizeAnimEnableTimer.restart();
        }
    }

    Connections {
        target: root.controller

        function onSelectedItemChanged() {
            if (actionPanel.expanded)
                actionPanel.hide();
        }

        function onItemExecuted() {
            root.parentModal?.hide();
            CompositorService.closeNiriOverviewOnWindowFocus();
        }
        function onModeChanged(mode, userInitiated) {
            if (!userInitiated || !SettingsData.rememberLastMode)
                return;
            SessionData.setLauncherLastMode(mode);
        }
        function onSearchQueryRequested(query) {
            searchInput.text = query;
            root._focusSearch();
        }
    }

    Item {
        id: searchBarItem
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root._searchAreaH

        LauncherSearchField {
            id: searchInput
            pluginName: root.controller.activePluginName
            anchors.fill: parent
            categories: root._categoryModel
            categoryIndex: categories.findIndex(category => root._isCategorySelected(category))
            showCategories: SettingsData.spotlightBarShowModeChips || root._hasQuery
            onCategorySelected: index => root._selectCategory(index)
            placeholderText: I18n.tr("Spotlight Search")
            hidePlaceholderOnFocus: false
            ignoreUpDownKeys: true
            ignoreTabKeys: true
            keyForwardTargets: [searchKeyHandler]

            onTextChanged: {
                if (root.suspendSearchUpdates)
                    return;
                actionPanel.hide();
                if (text.length > 0) {
                    root.controller.setSearchQuery(text);
                    return;
                }
                root.resetSearch();
            }

            Item {
                id: searchKeyHandler
                Keys.onPressed: event => root._handleKey(event)
            }
        }
    }

    ClippingRectangle {
        id: resultsContainer
        anchors.top: searchBarItem.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.resultsInset
        anchors.rightMargin: root.resultsInset
        color: "transparent"
        bottomLeftRadius: actionPanel.height > 0 ? 0 : root._frameClipRadius
        bottomRightRadius: bottomLeftRadius
        height: root._resultsH

        Behavior on height {
            enabled: root._animateResize
            NumberAnimation {
                duration: root._resizeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.standard
            }
        }

        ResultsList {
            id: resultsList
            focusReturnTarget: searchInput
            keyForwardTargets: [searchKeyHandler]
            readonly property real bottomInset: Theme.spacingS
            anchors.fill: parent
            anchors.topMargin: root.resultsInset
            controller: root.controller

            onItemRightClicked: (index, item, sceneX, sceneY) => {
                root._showContextMenu(item, sceneX, sceneY, false);
            }
        }
    }

    ActionPanel {
        id: actionPanel
        anchors.top: resultsContainer.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        selectedItem: root.controller.selectedItem
        controller: root.controller
    }

    readonly property var _categoryModel: [
        {
            "label": I18n.tr("All"),
            "mode": "all"
        },
        {
            "label": I18n.tr("Apps"),
            "mode": "apps"
        },
        {
            "label": I18n.tr("Files"),
            "mode": "files"
        },
        {
            "label": I18n.tr("Plugins"),
            "mode": "plugins"
        }
    ]

    function _isCategorySelected(cat) {
        return root.controller.searchMode === cat.mode;
    }

    function _cycleCategory(reverse) {
        let idx = 0;
        for (let i = 0; i < _categoryModel.length; i++) {
            if (_isCategorySelected(_categoryModel[i])) {
                idx = i;
                break;
            }
        }
        idx = reverse ? (idx - 1 + _categoryModel.length) % _categoryModel.length : (idx + 1) % _categoryModel.length;
        _selectCategory(idx);
    }

    function _selectCategory(index) {
        const cat = _categoryModel[index];
        if (!cat)
            return;
        root.controller.setMode(cat.mode, false);
        if (root._hasQuery)
            root.controller.setSearchQuery(searchInput.text);
        root._focusSearch();
    }
}
