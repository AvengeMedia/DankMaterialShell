pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    property var parentModal: null
    property alias searchField: searchInput
    property var controllerOverride: null
    readonly property var controller: controllerOverride ?? searchController
    readonly property alias activeContextMenu: contextMenu
    property var transientSurfaceTracker: null
    property bool showResultsWithoutQuery: false
    property bool suspendSearchUpdates: false
    property real maxResultsHeight: 0

    readonly property bool _hasQuery: root.showResultsWithoutQuery || searchInput.text.length > 0
    readonly property real _searchBarH: 56
    readonly property real _searchAreaH: _searchBarH
    readonly property alias searchAreaHeight: root._searchAreaH
    readonly property real actionPanelHeight: actionPanel.height
    readonly property real _statusH: 92
    readonly property real _rowH: 64
    readonly property real _maxResultsH: root.maxResultsHeight > 0 ? root.maxResultsHeight : Math.min(430, (parentModal?.screenHeight ?? 900) * 0.55)
    readonly property var _resultRows: _buildRows()
    readonly property real _resultsContentH: _resultRows.length > 0 ? _resultRows.length * _rowH + resultsList.bottomInset : _statusH
    readonly property real _resultsH: _hasQuery ? Math.min(_resultsContentH, _maxResultsH) : 0
    readonly property int _fastDuration: 90
    readonly property int _resizeDuration: Theme.expressiveDurations.fast
    readonly property bool _blurActive: Theme.blurForegroundLayers || Theme.transparentBlurLayers
    readonly property real _searchSurfaceAlpha: {
        if (Theme.transparentBlurLayers)
            return _hasQuery ? 0.34 : 0.28;
        if (Theme.blurForegroundLayers)
            return Math.max(Theme.popupTransparency, _hasQuery ? 0.68 : 0.74);
        return _hasQuery ? Theme.popupTransparency : Math.max(0.68, Theme.popupTransparency * 0.9);
    }
    readonly property color _searchSurfaceColor: Theme.withAlpha(_hasQuery ? Theme.surfaceContainerHigh : Theme.surfaceContainer, _searchSurfaceAlpha)
    readonly property color _searchWellColor: {
        if (searchInput.getActiveFocus())
            return Theme.withAlpha(Theme.primaryContainer, Theme.transparentBlurLayers ? 0.42 : 1.0);
        if (Theme.transparentBlurLayers)
            return Theme.ccPillInactiveBg;
        return Theme.surfaceContainer;
    }

    implicitHeight: _searchAreaH + resultsContainer.height + actionPanel.height

    property bool _animateResize: false

    Component.onCompleted: resizeAnimEnableTimer.restart()

    Timer {
        id: resizeAnimEnableTimer
        interval: 100
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

    function _buildRows() {
        const flat = root.controller.flatModel || [];
        const sections = root.controller.sections || [];
        const rows = [];
        const seen = {};
        for (let i = 0; i < flat.length; i++) {
            const entry = flat[i];
            if (!entry || entry.isHeader || !entry.item)
                continue;
            const section = sections[entry.sectionIndex] || null;
            // Plugin item ids embed result content, so key them by slot position instead
            const base = entry.item.pluginId ? (entry.sectionId + ":" + entry.indexInSection) : (entry.item.id || (entry.sectionId + ":" + (entry.item.name || entry.indexInSection)));
            const bump = seen[base] || 0;
            seen[base] = bump + 1;
            rows.push({
                "_rowId": bump ? base + "#" + bump : base,
                "item": entry.item,
                "flatIndex": i,
                "sectionTitle": section?.title || "",
                "sectionIcon": section?.icon || ""
            });
        }
        return rows;
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
        forceLinearNavigation: true
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
            if (SettingsData.spotlightCloseNiriOverview && NiriService.inOverview)
                NiriService.toggleOverview();
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

        Rectangle {
            id: searchBarSurface
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: root._searchSurfaceColor

            Behavior on color {
                ColorAnimation {
                    duration: root._fastDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                id: leadingWell
                width: 36
                height: 36
                radius: height / 2
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                color: root._searchWellColor

                DankIcon {
                    anchors.centerIn: parent
                    name: root.controller.activePluginId ? "extension" : root.controller.searchMode === "files" ? "folder" : "search"
                    size: 20
                    color: searchInput.getActiveFocus() ? Theme.primary : Theme.surfaceVariantText
                }
            }

            Row {
                id: rightControls
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                Row {
                    id: categoryRow
                    visible: SettingsData.spotlightBarShowModeChips || root._hasQuery
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: root._categoryModel

                        delegate: Item {
                            id: categoryChip
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: root._isCategorySelected(modelData)

                            width: chipLabel.implicitWidth + Theme.spacingM * 2
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: chipColor.value

                                DankColorAnimation {
                                    id: chipColor
                                    to: categoryChip.isSelected ? Theme.primary : chipArea.containsMouse ? Theme.surfaceHover : Theme.surfaceVariantAlpha
                                    duration: root._fastDuration
                                    easingType: Theme.standardEasing
                                }

                                StyledText {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: categoryChip.modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: categoryChip.isSelected ? Font.Medium : Font.Normal
                                    color: categoryChip.isSelected ? Theme.primaryText : Theme.surfaceVariantText
                                }
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._selectCategory(categoryChip.index)
                            }
                        }
                    }
                }

                DankActionButton {
                    id: clearButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    iconSize: 16
                    visible: searchInput.text.length > 0
                    onClicked: {
                        searchInput.text = "";
                        root._focusSearch();
                    }
                }
            }

            DankTextField {
                id: searchInput
                anchors.left: leadingWell.right
                anchors.right: rightControls.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                font.pixelSize: 18
                font.weight: Font.Medium
                placeholderText: I18n.tr("Spotlight Search")
                hidePlaceholderOnFocus: false
                backgroundColor: "transparent"
                borderWidth: 0
                focusedBorderWidth: 0
                keyForwardTargets: [searchKeyHandler]

                onTextChanged: {
                    if (root.suspendSearchUpdates)
                        return;
                    actionPanel.hide();
                    if (text.length > 0) {
                        root.controller.setSearchQuery(text);
                    } else {
                        root.resetSearch();
                    }
                }

                Item {
                    id: searchKeyHandler

                    Keys.onPressed: event => root._handleKey(event)
                }
            }
        }
    }

    Item {
        id: resultsContainer
        anchors.top: searchBarItem.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        height: root._resultsH

        Behavior on height {
            enabled: root._animateResize
            NumberAnimation {
                duration: root._resizeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
            }
        }

        SpotlightResultsList {
            id: resultsList
            anchors.fill: parent
            controller: root.controller
            hasQuery: root._hasQuery
            rows: root._resultRows

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
