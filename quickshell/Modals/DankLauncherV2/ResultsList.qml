pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var controller: null
    property int gridColumns: controller?.gridColumns ?? 4
    property var _visualRows: []
    property var _flatIndexToRowMap: ({})
    property var _cumulativeHeights: []

    signal itemRightClicked(int index, var item, real mouseX, real mouseY)

    function _rebuildVisualModel() {
        var sections = root.controller?.sections ?? [];
        var rows = [];
        var indexMap = {};
        var cumHeights = [];
        var cumY = 0;

        for (var s = 0; s < sections.length; s++) {
            var section = sections[s];
            var sectionId = section.id;

            cumHeights.push(cumY);
            rows.push({
                _rowId: "h_" + sectionId,
                type: "header",
                section: section,
                sectionId: sectionId,
                height: 32
            });
            cumY += 32;

            if (section.collapsed)
                continue;

            var versionTrigger = root.controller?.viewModeVersion ?? 0;
            void (versionTrigger);
            var mode = root.controller?.getSectionViewMode(sectionId) ?? "list";
            var items = section.items ?? [];
            var flatStartIndex = section.flatStartIndex ?? 0;

            if (mode === "list") {
                for (var i = 0; i < items.length; i++) {
                    var flatIdx = flatStartIndex + i;
                    indexMap[flatIdx] = rows.length;
                    cumHeights.push(cumY);
                    rows.push({
                        _rowId: items[i].id,
                        type: "list_item",
                        item: items[i],
                        flatIndex: flatIdx,
                        sectionId: sectionId,
                        height: 52
                    });
                    cumY += 52;
                }
            } else {
                var cols = root.controller?.getGridColumns(sectionId) ?? root.gridColumns;
                var cellWidth = mode === "tile" ? Math.floor(root.width / 3) : Math.floor(root.width / root.gridColumns);
                var cellHeight = mode === "tile" ? cellWidth * 0.75 : cellWidth + 24;
                var numRows = Math.ceil(items.length / cols);

                for (var r = 0; r < numRows; r++) {
                    var rowItems = [];
                    for (var c = 0; c < cols; c++) {
                        var idx = r * cols + c;
                        if (idx >= items.length)
                            break;
                        var fi = flatStartIndex + idx;
                        indexMap[fi] = rows.length;
                        rowItems.push({
                            item: items[idx],
                            flatIndex: fi
                        });
                    }
                    cumHeights.push(cumY);
                    rows.push({
                        _rowId: "gr_" + sectionId + "_" + r,
                        type: "grid_row",
                        items: rowItems,
                        sectionId: sectionId,
                        viewMode: mode,
                        cols: cols,
                        height: cellHeight
                    });
                    cumY += cellHeight;
                }
            }
        }

        root._flatIndexToRowMap = indexMap;
        root._cumulativeHeights = cumHeights;
        root._visualRows = rows;
    }

    onGridColumnsChanged: Qt.callLater(_rebuildVisualModel)
    onWidthChanged: Qt.callLater(_rebuildVisualModel)

    Connections {
        target: root.controller
        function onSectionsChanged() {
            Qt.callLater(root._rebuildVisualModel);
        }
        function onViewModeVersionChanged() {
            Qt.callLater(root._rebuildVisualModel);
        }
        function onSearchModeChanged() {
            root._visualRows = [];
            root._cumulativeHeights = [];
            root._flatIndexToRowMap = {};
        }
    }

    function resetScroll() {
        mainListView.contentY = mainListView.originY;
    }

    function ensureVisible(index) {
        if (index < 0 || !controller?.flatModel || index >= controller.flatModel.length)
            return;
        var entry = controller.flatModel[index];
        if (!entry || entry.isHeader)
            return;
        var rowIndex = _flatIndexToRowMap[index];
        if (rowIndex === undefined)
            return;

        mainListView.positionViewAtIndex(rowIndex, ListView.Contain);

        if (stickyHeader.visible && rowIndex < _cumulativeHeights.length) {
            var rowY = _cumulativeHeights[rowIndex];
            var scrollY = mainListView.contentY - mainListView.originY;
            if (rowY < scrollY + stickyHeader.height) {
                mainListView.contentY = Math.max(mainListView.originY, rowY - stickyHeader.height + mainListView.originY);
            }
        }
    }

    function getSelectedItemPosition() {
        var fallback = mapToItem(null, width / 2, height / 2);
        if (!controller?.flatModel || controller.selectedFlatIndex < 0)
            return fallback;

        var entry = controller.flatModel[controller.selectedFlatIndex];
        if (!entry || entry.isHeader)
            return fallback;

        var rowIndex = _flatIndexToRowMap[controller.selectedFlatIndex];
        if (rowIndex === undefined)
            return fallback;

        var rowY = (rowIndex < _cumulativeHeights.length) ? _cumulativeHeights[rowIndex] : 0;
        var row = _visualRows[rowIndex];
        if (!row)
            return fallback;

        var itemX = width / 2;
        var itemH = row.height;

        if (row.type === "grid_row") {
            var rowItems = row.items;
            for (var i = 0; i < rowItems.length; i++) {
                if (rowItems[i].flatIndex === controller.selectedFlatIndex) {
                    var cellWidth = row.viewMode === "tile" ? Math.floor(width / 3) : Math.floor(width / row.cols);
                    itemX = i * cellWidth + cellWidth / 2;
                    break;
                }
            }
        }

        var visualY = rowY - mainListView.contentY + mainListView.originY + itemH / 2;
        var clampedY = Math.max(40, Math.min(height - 40, visualY));
        return mapToItem(null, itemX, clampedY);
    }

    Connections {
        target: root.controller
        function onSelectedFlatIndexChanged() {
            if (root.controller?.keyboardNavigationActive) {
                Qt.callLater(() => root.ensureVisible(root.controller.selectedFlatIndex));
            }
        }
    }

    DankListView {
        id: mainListView
        anchors.fill: parent
        clip: true
        scrollBarTopMargin: (root.controller?.sections?.length > 0) ? 32 : 0

        model: ScriptModel {
            values: root._visualRows
            objectProp: "_rowId"
        }

        add: null
        remove: null
        displaced: null
        move: null

        delegate: Item {
            id: delegateRoot
            required property var modelData
            required property int index

            width: mainListView.width
            height: modelData?.height ?? 52

            SectionHeader {
                anchors.fill: parent
                visible: delegateRoot.modelData?.type === "header"
                section: delegateRoot.modelData?.section ?? null
                controller: root.controller
                viewMode: {
                    var vt = root.controller?.viewModeVersion ?? 0;
                    void (vt);
                    return root.controller?.getSectionViewMode(delegateRoot.modelData?.sectionId ?? "") ?? "list";
                }
                canChangeViewMode: {
                    var vt = root.controller?.viewModeVersion ?? 0;
                    void (vt);
                    return root.controller?.canChangeSectionViewMode(delegateRoot.modelData?.sectionId ?? "") ?? false;
                }
                canCollapse: root.controller?.canCollapseSection(delegateRoot.modelData?.sectionId ?? "") ?? false
            }

            ResultItem {
                anchors.fill: parent
                visible: delegateRoot.modelData?.type === "list_item"
                item: delegateRoot.modelData?.type === "list_item" ? (delegateRoot.modelData?.item ?? null) : null
                isSelected: delegateRoot.modelData?.type === "list_item" && (delegateRoot.modelData?.flatIndex ?? -1) === root.controller?.selectedFlatIndex
                controller: root.controller
                flatIndex: delegateRoot.modelData?.type === "list_item" ? (delegateRoot.modelData?.flatIndex ?? -1) : -1

                onClicked: {
                    if (root.controller && delegateRoot.modelData?.item) {
                        root.controller.executeItem(delegateRoot.modelData.item);
                    }
                }

                onRightClicked: (mouseX, mouseY) => {
                    root.itemRightClicked(delegateRoot.modelData?.flatIndex ?? -1, delegateRoot.modelData?.item ?? null, mouseX, mouseY);
                }
            }

            Row {
                id: gridRowContent
                anchors.fill: parent
                visible: delegateRoot.modelData?.type === "grid_row"

                Repeater {
                    model: delegateRoot.modelData?.type === "grid_row" ? (delegateRoot.modelData?.items ?? []) : []

                    Item {
                        id: gridCellDelegate
                        required property var modelData
                        required property int index

                        readonly property real cellWidth: delegateRoot.modelData?.viewMode === "tile" ? Math.floor(delegateRoot.width / 3) : Math.floor(delegateRoot.width / (delegateRoot.modelData?.cols ?? root.gridColumns))

                        width: cellWidth
                        height: delegateRoot.height

                        GridItem {
                            width: parent.width - 4
                            height: parent.height - 4
                            anchors.centerIn: parent
                            visible: delegateRoot.modelData?.viewMode === "grid"
                            item: gridCellDelegate.modelData?.item ?? null
                            isSelected: (gridCellDelegate.modelData?.flatIndex ?? -1) === root.controller?.selectedFlatIndex
                            controller: root.controller
                            flatIndex: gridCellDelegate.modelData?.flatIndex ?? -1

                            onClicked: {
                                if (root.controller && gridCellDelegate.modelData?.item) {
                                    root.controller.executeItem(gridCellDelegate.modelData.item);
                                }
                            }

                            onRightClicked: (mouseX, mouseY) => {
                                root.itemRightClicked(gridCellDelegate.modelData?.flatIndex ?? -1, gridCellDelegate.modelData?.item ?? null, mouseX, mouseY);
                            }
                        }

                        TileItem {
                            width: parent.width - 4
                            height: parent.height - 4
                            anchors.centerIn: parent
                            visible: delegateRoot.modelData?.viewMode === "tile"
                            item: gridCellDelegate.modelData?.item ?? null
                            isSelected: (gridCellDelegate.modelData?.flatIndex ?? -1) === root.controller?.selectedFlatIndex
                            controller: root.controller
                            flatIndex: gridCellDelegate.modelData?.flatIndex ?? -1

                            onClicked: {
                                if (root.controller && gridCellDelegate.modelData?.item) {
                                    root.controller.executeItem(gridCellDelegate.modelData.item);
                                }
                            }

                            onRightClicked: (mouseX, mouseY) => {
                                root.itemRightClicked(gridCellDelegate.modelData?.flatIndex ?? -1, gridCellDelegate.modelData?.item ?? null, mouseX, mouseY);
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: bottomShadow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 24
        z: 100
        visible: {
            if (mainListView.contentHeight <= mainListView.height)
                return false;
            var atBottom = mainListView.contentY >= mainListView.contentHeight - mainListView.height + mainListView.originY - 5;
            if (atBottom)
                return false;

            var flatModel = root.controller?.flatModel;
            if (!flatModel || flatModel.length === 0)
                return false;
            var lastItemIdx = -1;
            for (var i = flatModel.length - 1; i >= 0; i--) {
                if (!flatModel[i].isHeader) {
                    lastItemIdx = i;
                    break;
                }
            }
            if (lastItemIdx >= 0 && root.controller?.selectedFlatIndex === lastItemIdx)
                return false;
            return true;
        }
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            }
        }
    }

    Rectangle {
        id: stickyHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 32
        z: 101
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        visible: stickyHeaderSection !== null

        readonly property int versionTrigger: root.controller?.viewModeVersion ?? 0

        readonly property var stickyHeaderSection: {
            var scrollY = mainListView.contentY - mainListView.originY;
            if (scrollY <= 0)
                return null;

            var rows = root._visualRows;
            var heights = root._cumulativeHeights;
            if (rows.length === 0 || heights.length === 0)
                return null;

            var lo = 0;
            var hi = rows.length - 1;
            while (lo < hi) {
                var mid = (lo + hi + 1) >> 1;
                if (mid < heights.length && heights[mid] <= scrollY)
                    lo = mid;
                else
                    hi = mid - 1;
            }

            for (var i = lo; i >= 0; i--) {
                if (rows[i].type === "header")
                    return rows[i].section;
            }
            return null;
        }

        SectionHeader {
            width: parent.width
            section: stickyHeader.stickyHeaderSection
            controller: root.controller
            viewMode: {
                void (stickyHeader.versionTrigger);
                return root.controller?.getSectionViewMode(stickyHeader.stickyHeaderSection?.id) ?? "list";
            }
            canChangeViewMode: {
                void (stickyHeader.versionTrigger);
                return root.controller?.canChangeSectionViewMode(stickyHeader.stickyHeaderSection?.id) ?? false;
            }
            canCollapse: {
                void (stickyHeader.versionTrigger);
                return root.controller?.canCollapseSection(stickyHeader.stickyHeaderSection?.id) ?? false;
            }
            isSticky: true
        }
    }

    Item {
        anchors.centerIn: parent
        visible: (!root.controller?.sections || root.controller.sections.length === 0) && !root.controller?.isFileSearching
        width: emptyColumn.implicitWidth
        height: emptyColumn.implicitHeight

        Column {
            id: emptyColumn
            spacing: Theme.spacingM

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: getEmptyIcon()
                size: 48
                color: Theme.outlineButton

                function getEmptyIcon() {
                    var mode = root.controller?.searchMode ?? "all";
                    switch (mode) {
                    case "files":
                        var fileType = root.controller?.fileSearchType ?? "all";
                        switch (fileType) {
                        case "dir":
                            return "folder_open";
                        case "file":
                            return "insert_drive_file";
                        default:
                            return "folder_open";
                        }
                    case "plugins":
                        return "extension";
                    case "apps":
                        return "apps";
                    default:
                        return root.controller?.searchQuery?.length > 0 ? "search_off" : "search";
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: getEmptyText()
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                horizontalAlignment: Text.AlignHCenter

                function getEmptyText() {
                    var mode = root.controller?.searchMode ?? "all";
                    var hasQuery = root.controller?.searchQuery?.length > 0;

                    switch (mode) {
                    case "files":
                        if (!DSearchService.dsearchAvailable)
                            return I18n.tr("File search requires dsearch\nInstall from github.com/morelazers/dsearch");
                        if (!hasQuery)
                            return I18n.tr("Type to search files");
                        if (root.controller.searchQuery.length < 2)
                            return I18n.tr("Type at least 2 characters");
                        var fileType = root.controller?.fileSearchType ?? "all";
                        switch (fileType) {
                        case "dir":
                            return I18n.tr("No folders found");
                        case "file":
                            return I18n.tr("No files found");
                        default:
                            return I18n.tr("No results found");
                        }
                    case "plugins":
                        return hasQuery ? I18n.tr("No plugin results") : I18n.tr("Browse or search plugins");
                    case "apps":
                        return hasQuery ? I18n.tr("No apps found") : I18n.tr("Type to search apps");
                    default:
                        return hasQuery ? I18n.tr("No results found") : I18n.tr("Type to search");
                    }
                }
            }
        }
    }
}
