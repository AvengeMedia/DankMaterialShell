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
    readonly property real chromeHeight: header.height + Theme.spacingXS * 2 + DashMetrics.contentPadding
    readonly property real editGutter: editMode ? PopoutMetrics.editOverflow : 0
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
        gutter: root.editGutter
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
                values.panelRows = rows > root.contentRows ? rows : DashMetrics.minimumTabRows;
            DashRegistry.setOptions(root.entryId, values);
            DashMetrics.panelPreview = null;
        }
        onCanceled: DashMetrics.panelPreview = null
    }

    clip: true
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true
    KeyNavigation.tab: root.tab?.focusTarget ?? null

    function focusFace() {
        (root.tab?.focusTarget ?? root).forceActiveFocus();
        return true;
    }

    function focusHeader(backwards) {
        const targets = root.editMode ? editControls.focusTargets : [menuButton];
        targets[backwards ? targets.length - 1 : 0].forceActiveFocus();
    }

    function reportHeight() {
        root.controller.setDashboardContentHeight(root.activityId, root.contentHeight + root.chromeHeight);
    }

    onContentHeightChanged: reportHeight()
    onChromeHeightChanged: reportHeight()
    onLiveChanged: {
        if (live)
            return;
        editMode = false;
        headerMenu.close();
        tabOptions.dismiss();
    }
    onEditModeChanged: {
        root.controller.setEditing(root.activityId, editMode);
        if (!editMode) {
            panelResizer.cancel();
            return;
        }
        Qt.callLater(() => {
            if (root.live && root.editMode)
                root.focusHeader(false);
        });
    }

    Keys.onPressed: event => {
        if (root.tab?.handleKeyEvent?.(event) === true) {
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
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: Theme.spacingXS
            leftMargin: DashMetrics.contentPadding + root.editGutter
            rightMargin: DashMetrics.contentPadding + root.editGutter
        }
        height: root.editMode ? editControls.height : Theme.buttonHeightXS

        DankActionButton {
            id: menuButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            buttonSize: Theme.buttonHeightXS
            iconName: "more_vert"
            Accessible.name: I18n.tr("Options")
            visible: !root.editMode
            KeyNavigation.tab: root.tab?.focusTarget ?? null
            KeyNavigation.backtab: root.tab?.previousFocusTarget ?? root.tab?.focusTarget ?? null
            onClicked: headerMenu.openAt(menuButton)
        }

        DashEditControls {
            id: editControls
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.editMode
            canAdd: (root.tab?.addable?.length ?? 0) > 0
            onAddRequested: anchor => root.tab?.openAddMenu(anchor)
            onMenuRequested: anchor => headerMenu.openAt(anchor)
            onFinished: {
                root.editMode = false;
                root.focusFace();
            }
        }
    }

    DankFlickable {
        id: pages
        anchors {
            top: header.bottom
            topMargin: Theme.spacingXS
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: DashMetrics.contentPadding + root.editGutter
            rightMargin: DashMetrics.contentPadding + root.editGutter
            bottomMargin: DashMetrics.contentPadding + root.editGutter
        }
        contentHeight: tabLoader.height
        clip: contentHeight > height

        Loader {
            id: tabLoader
            width: pages.width
            height: Math.max(pages.height, root.tabHeight)
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
        atDefault: root.panelColumns === DashMetrics.defaultGridColumns && DashMetrics.panelFloorRowsFor(root.entryId) <= root.contentRows
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
        onDismissed: root.focusFace()
    }

    DashPageMenu {
        id: headerMenu
        entryId: root.entryId
        tabItem: root.tab
        editMode: root.editMode
        onEditRequested: root.editMode = true
        onOptionsRequested: tabOptions.presentFor(root.entryId)
        onSettingsRequested: {
            root.controller.requestCollapse();
            PopoutService.openSettingsWithTab("dank_dash");
        }
    }

    Component.onDestruction: root.controller.setEditing(root.activityId, false)

    Component.onCompleted: {
        root.contentStaged = true;
        root.reportHeight();
    }
}
