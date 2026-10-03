pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash
import qs.Modules.DankDash.Overview

FocusScope {
    id: root

    required property var controller
    required property string activityId
    required property Component tabComponent
    property string entryId: activityId
    property QtObject resizeGeometry: null
    property bool editMode: false
    property bool contentStaged: false
    readonly property bool live: root.controller.expanded && root.controller.activeActivity === root.activityId
    readonly property var tab: tabLoader.item
    readonly property real tabHeight: tab?.implicitHeight ?? 0
    readonly property real contentHeight: DashMetrics.panelHeightFor(entryId, tabHeight)
    readonly property bool handleHeader: !root.editMode
    readonly property real pillOverhang: editMode ? DashMetrics.islandPillOverhang : 0
    readonly property int panelColumns: DashMetrics.panelColumnsFor(entryId)
    readonly property int contentRows: DashMetrics.rowsForHeight(tabHeight)
    readonly property int panelRows: Math.max(DashMetrics.panelFloorRowsFor(entryId), contentRows)

    readonly property QtObject resizeHost: QtObject {
        readonly property real renderedAlignedX: root.resizeGeometry?.renderedX ?? 0
        readonly property real renderedAlignedY: root.resizeGeometry?.renderedY ?? 0

        function alignedXFor(width) {
            return root.resizeGeometry?.screenXFor(width) ?? 0;
        }
    }

    readonly property DankPanelResizer panelResizer: DankPanelResizer {
        popout: root.resizeHost
        stepWidth: DashMetrics.preferredColumnWidth + DashMetrics.gridGap
        widthFor: columns => Math.min(root.controller.dashboardAvailableWidth, DashMetrics.widthFor(SettingsData.showWeekNumber, undefined, columns))
        currentStep: () => root.panelColumns
        currentRows: () => root.panelRows
        minStep: DashMetrics.minimumGridColumns
        maxStep: root.controller.dashboardColumnCap
        rowUnit: DashMetrics.gridRowUnit + DashMetrics.gridGap
        minRows: root.contentRows
        maxRows: Math.min(root.controller.dashboardRowBudget, DashMetrics.maximumGridRows)
        onPreview: (columns, rows) => DashMetrics.panelPreview = {
                "id": root.entryId,
                "columns": columns,
                "rows": rows
            }
        onCommitted: (columns, rows, columnsChanged, rowsChanged) => {
            const values = {};
            if (columnsChanged)
                values.panelColumns = columns;
            if (rowsChanged)
                values.panelRows = DashMetrics.panelRowsToStore(root.entryId, rows, root.contentRows);
            DashRegistry.setOptions(root.entryId, values);
            DashMetrics.panelPreview = null;
        }
        onCanceled: DashMetrics.panelPreview = null
    }

    clip: true
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true
    KeyNavigation.tab: !root.editMode && !tabOptions.shown && !pageActions.menuOpen ? root.tab?.focusTarget ?? null : null

    function focusFace() {
        pageActions.clearFocus();
        const target = root.tab?.focusTarget ?? root;
        if (typeof target.requestFocus === "function") {
            target.requestFocus(false, Qt.OtherFocusReason);
            return true;
        }
        target.forceActiveFocus(Qt.OtherFocusReason);
        return true;
    }

    function focusHeader(backwards) {
        const targets = root.editMode ? pageActions.focusTargets : [sheetHandle.focusTarget];
        targets[backwards ? targets.length - 1 : 0]?.forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
    }

    function reportHeight() {
        root.controller.setDashboardContentHeight(root.activityId, root.contentHeight + DashMetrics.islandHandleChromeHeight);
    }

    onContentHeightChanged: reportHeight()
    onLiveChanged: {
        if (live)
            return;
        editMode = false;
        pageActions.closeMenu();
        tabOptions.dismiss();
    }
    onEditModeChanged: {
        root.controller.setEditing(root.activityId, editMode, DashMetrics.islandEditRoom);
        if (!editMode) {
            panelResizer.cancel();
            return;
        }
        Qt.callLater(() => {
            if (!root.live || !root.editMode)
                return;
            pageActions.clearFocus();
            sheetHandle.focusTarget.focus = false;
            tabLoader.focus = false;
            root.forceActiveFocus(Qt.OtherFocusReason);
        });
    }

    Keys.onPressed: event => {
        if (tabOptions.shown || pageActions.menuOpen)
            return;
        if (root.editMode && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            root.focusHeader(event.key === Qt.Key_Backtab || !!(event.modifiers & Qt.ShiftModifier));
            event.accepted = true;
            return;
        }
        if (root.tab?.handleKeyEvent?.(event) === true) {
            event.accepted = true;
            return;
        }
        if (!root.editMode && (event.key === Qt.Key_F2 || (event.key === Qt.Key_E && (event.modifiers & Qt.ControlModifier)))) {
            root.editMode = true;
            event.accepted = true;
            return;
        }
        if (event.key !== Qt.Key_Escape || !root.editMode)
            return;
        root.editMode = false;
        root.focusFace();
        event.accepted = true;
    }

    Item {
        id: header
        enabled: !tabOptions.shown && !pageActions.menuOpen
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.editMode ? DashMetrics.islandEditHeaderInset : 0
            leftMargin: DashMetrics.contentPadding
            rightMargin: DashMetrics.contentPadding
        }
        height: root.handleHeader ? DashMetrics.islandHandleHeight : DashMetrics.editHeaderHeight

        DashSheetHandle {
            id: sheetHandle
            anchors.fill: parent
            visible: root.handleHeader
            editable: root.entryId !== ""
            onEditRequested: root.editMode = true
        }

        DashPageActions {
            id: pageActions
            visible: root.editMode
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.width, implicitWidth)
            height: parent.height
            transientSurfaceTracker: root.controller.transientSurfaces
            entryId: root.entryId
            tabItem: root.tab
            editMode: root.editMode
            panelResizable: true
            onOptionsRequested: tabOptions.presentFor(root.entryId)
            onFinished: {
                root.editMode = false;
                root.focusFace();
            }
        }
    }

    DankFlickable {
        id: pages
        enabled: !tabOptions.shown && !pageActions.menuOpen
        showScrollBar: false
        anchors {
            top: header.bottom
            topMargin: root.editMode ? DashMetrics.contentPadding : 0
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: DashMetrics.contentPadding
            rightMargin: DashMetrics.contentPadding
            bottomMargin: root.editMode ? DashMetrics.islandEditBottomInset : DashMetrics.contentPadding
        }
        contentHeight: tabLoader.y + tabLoader.height
        clip: contentHeight > height

        Loader {
            id: tabLoader
            y: root.pillOverhang
            width: pages.width
            height: Math.max(pages.height - y, root.tabHeight)
            active: root.contentStaged
            asynchronous: true
            visible: status === Loader.Ready
            sourceComponent: root.tabComponent
            onLoaded: {
                root.reportHeight();
                if (root.live)
                    root.focusFace();
            }
        }
    }

    Connections {
        target: root.tab
        ignoreUnknownSignals: true
        function onNavFocusRequested(backwards) {
            root.focusHeader(backwards);
        }
    }

    DankGridEditChrome {
        id: panelChrome

        anchors.fill: parent
        anchors.margins: PopoutMetrics.panelChromeInset - contentInset
        z: 2
        visible: root.editMode
        edgeResize: true
        removable: false
        cornerRadius: Math.max(0, Theme.windowRadius - PopoutMetrics.panelChromeInset)
        buttonSize: PopoutMetrics.chromeButtonSize
        iconSize: PopoutMetrics.chromeIconSize
        resizing: root.panelResizer.resizing
        atDefault: root.panelColumns === DashMetrics.defaultGridColumns && root.panelRows === DashMetrics.defaultPanelRows(root.entryId, root.contentRows)
        sizeText: root.panelColumns + "×" + root.panelRows
        onResizeStarted: (px, py, signX) => root.panelResizer.begin(px, py, signX)
        onResizeMoved: (px, py) => root.panelResizer.move(px, py)
        onResizeEnded: root.panelResizer.end()
        onResizeCanceled: root.panelResizer.cancel()
    }

    DankSpinner {
        anchors.centerIn: pages
        size: DashMetrics.spinnerSize
        visible: !tabLoader.visible
    }

    DashOptionsSheet {
        id: tabOptions
        backdrop: pages
        tabScope: true
        onDismissed: root.focusFace()
    }

    Component.onDestruction: root.controller.setEditing(root.activityId, false)

    Component.onCompleted: {
        root.contentStaged = true;
        root.reportHeight();
    }
}
