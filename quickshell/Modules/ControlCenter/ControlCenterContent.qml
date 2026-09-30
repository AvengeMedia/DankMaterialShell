pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Models
import qs.Modules.ControlCenter.Details
import qs.Widgets
import "./utils/sections.js" as Sections
import "./utils/widgets.js" as WidgetUtils

FocusScope {
    id: root

    required property var host

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property bool pageOpen: (host.expandedSection ?? "") !== ""
    readonly property real gridHeight: widgetGrid.gridHeight
    readonly property real chromeHeight: footer.occupied ? Theme.spacingS + footer.height : 0
    readonly property bool widgetSheetOpen: widgetSheetLoader.item?.active ?? false
    readonly property real coveredAmount: Math.max(detailPage.opacity, widgetSheetLoader.item?.progress ?? 0)
    property bool widgetSheetRequested: false
    property int toplevelRevision: 0
    readonly property var runningToplevels: {
        toplevelRevision;
        const all = CompositorService.sortedToplevels ?? [];
        const current = CompositorService.filterCurrentWorkspace(all, host.triggerScreen?.name) || [];
        return current.concat(all.filter(toplevel => !current.includes(toplevel)));
    }
    readonly property string placedWidgetIds: WidgetUtils.placedIds(SettingsData.controlCenterWidgets).sort().join(",")
    readonly property bool editPlaced: placedWidgetIds.split(",").includes("edit")
    readonly property real targetImplicitHeight: {
        const total = CcMetrics.sheetPadding * 2 + gridHeight + chromeHeight;
        if (detailPage.shownSection === "")
            return total;
        return Math.max(total, detailPage.topInset + detailPage.minimumHeight + CcMetrics.detailDialogInset);
    }
    property Item detailReturnFocus: null
    property var pageHistory: []
    property var editSnapshot: null
    readonly property bool panelResizing: panelResizer.resizing
    readonly property real sheetContentWidth: host.sheetContentWidth ?? CcMetrics.sheetWidthFor(gridColumns)
    readonly property vector4d surfaceCornerRadii: host.surfaceCornerRadii ?? Qt.vector4d(Theme.windowRadius, Theme.windowRadius, Theme.windowRadius, Theme.windowRadius)
    readonly property int gridColumnCap: host.gridColumnCap ?? CcMetrics.columnCapFor((host.triggerScreen?.width ?? CcMetrics.sheetWidthDefault + Theme.spacingL * 2) - Theme.spacingL * 2)
    readonly property int gridColumns: host.gridColumns ?? Math.min(CcMetrics.gridColumns, gridColumnCap)
    // Always reserve the footer: the row cap stays the same in edit mode and cannot loop through the docked edit button.
    readonly property real availableGridHeight: (host.availableHeight ?? (host.triggerScreen?.height ?? CcMetrics.fallbackScreenHeight) - CcMetrics.maxHeightInset) - CcMetrics.sheetPadding * 2 - Theme.spacingS - CcMetrics.footerHeight
    readonly property vector4d chromeRoom: host.chromeRoom ?? Qt.vector4d(Infinity, Infinity, Infinity, Infinity)
    readonly property DankPanelResizer panelResizer: DankPanelResizer {
        popout: root.host
        stepWidth: CcMetrics.columnWidth + CcMetrics.gridGap
        widthFor: columns => CcMetrics.sheetWidthFor(columns) + root.sheetContentWidth - CcMetrics.sheetWidthFor(root.gridColumns)
        currentStep: () => root.gridColumns
        minStep: Math.min(CcMetrics.minimumColumns, root.gridColumnCap)
        maxStep: root.gridColumnCap
        onPreview: columns => CcMetrics.columnPreview = columns
        onCommitted: columns => {
            SettingsData.set("controlCenterColumns", columns);
            CcMetrics.columnPreview = 0;
        }
        onCanceled: CcMetrics.columnPreview = 0
    }

    implicitHeight: targetImplicitHeight
    focus: true

    function navigateTo(section) {
        if (section === host.expandedSection)
            return;
        if (host.expandedSection)
            pageHistory = pageHistory.concat([host.expandedSection]);
        else if (detailPage.shownSection === "")
            detailReturnFocus = root.Window.window?.activeFocusItem ?? null;
        host.expandedSection = section;
    }

    function goBack() {
        if (detailPage.dismissTransient())
            return;
        if (pageHistory.length > 0) {
            const previous = pageHistory[pageHistory.length - 1];
            pageHistory = pageHistory.slice(0, -1);
            host.expandedSection = previous;
            return;
        }
        host.collapseAll();
    }

    function openWidgetPage(widgetData) {
        const section = Sections.sectionFor(widgetData);
        if (host.expandedSection === section) {
            goBack();
            return;
        }
        navigateTo(section);
    }

    function showCodecSelector(device) {
        presentSheet(codecSelectorLoader, device);
    }

    function showPortSelector(node) {
        presentSheet(portSelectorLoader, node);
    }

    function presentSheet(loader, target) {
        loader.active = true;
        const sheet = loader.item;
        if (!sheet)
            return;
        sheet.show(target);
        if (!sheet.shown)
            loader.active = false;
    }

    function releaseSheet(loader) {
        if (loader.item?.shown)
            return;
        loader.active = false;
    }

    function openConfigOverlay(index, widgetData, anchor) {
        if (widgetData.id === "brightnessSlider") {
            openWidgetPage(widgetData);
            return;
        }
        configOverlayLoader.active = true;
        const overlay = configOverlayLoader.item;
        if (!overlay)
            return;
        overlay.open(index, widgetData, anchor);
    }

    function releaseConfigOverlay() {
        if (configOverlayLoader.item?.visible)
            return;
        configOverlayLoader.active = false;
    }

    function cancelEdit() {
        const snapshot = editSnapshot;
        host.editMode = false;
        if (!snapshot)
            return;
        if (JSON.stringify(SettingsData.controlCenterWidgets) !== snapshot.widgets)
            SettingsData.set("controlCenterWidgets", JSON.parse(snapshot.widgets));
        if (SettingsData.controlCenterColumns !== snapshot.columns)
            SettingsData.set("controlCenterColumns", snapshot.columns);
    }

    function openWidgetSheet() {
        const sheet = widgetSheetLoader.item;
        if (!sheet) {
            widgetSheetRequested = true;
            return;
        }
        sheet.opened = true;
    }

    function closeWidgetSheet() {
        if (!widgetSheetLoader.item)
            return;
        widgetSheetLoader.item.opened = false;
    }

    Keys.onEscapePressed: event => {
        if (footer.pendingAction !== "") {
            footer.cancelConfirmation();
            event.accepted = true;
            return;
        }
        if (widgetSheetLoader.item?.opened) {
            closeWidgetSheet();
            event.accepted = true;
            return;
        }
        if (configOverlayLoader.item?.visible) {
            configOverlayLoader.item.close();
            event.accepted = true;
            return;
        }
        if (pageOpen) {
            goBack();
            event.accepted = true;
            return;
        }
        if (host.editMode) {
            host.editMode = false;
            event.accepted = true;
            return;
        }
        host.close();
        event.accepted = true;
    }

    readonly property string expandedSection: host.expandedSection ?? ""
    readonly property bool editMode: host.editMode

    onExpandedSectionChanged: {
        if (expandedSection !== "")
            return;
        pageHistory = [];
    }

    onEditModeChanged: {
        if (editMode) {
            host.collapseAll();
            editSnapshot = {
                "widgets": JSON.stringify(SettingsData.controlCenterWidgets),
                "columns": SettingsData.controlCenterColumns
            };
        } else {
            panelResizer.cancel();
            editSnapshot = null;
            widgetSheetRequested = false;
        }
        if (!activeFocus)
            forceActiveFocus();
    }

    DankGridEditChrome {
        id: panelChrome

        readonly property real screenWidth: root.host.triggerScreen?.width ?? Infinity
        readonly property real screenHeight: root.host.triggerScreen?.height ?? Infinity

        function ringOffset(room) {
            return Math.min(Theme.spacingS, room - handleThickness / 2 - Theme.outlineWidthFocused);
        }

        anchors.fill: parent
        anchors.leftMargin: -(contentInset + ringOffset(Math.min(root.host.alignedX, root.chromeRoom.x)))
        anchors.rightMargin: -(contentInset + ringOffset(Math.min(screenWidth - root.host.alignedX - root.width, root.chromeRoom.z)))
        anchors.topMargin: -(contentInset + ringOffset(Math.min(root.host.alignedY, root.chromeRoom.y)))
        anchors.bottomMargin: -(contentInset + ringOffset(Math.min(screenHeight - root.host.alignedY - root.height, root.chromeRoom.w)))
        z: 1
        visible: root.host.editMode
        enabled: detailPage.shownSection === "" && !root.widgetSheetOpen
        edgeResize: root.panelResizing || root.panelResizer.sideMovable(-1, root.gridColumns)
        cornerResize: root.panelResizing || root.panelResizer.sideMovable(1, root.gridColumns)
        horizontalResize: true
        removable: false
        cornerRadius: Theme.windowRadius + Theme.spacingS
        buttonSize: Theme.iconSize
        iconSize: PopoutMetrics.chromeIconSize
        resizing: root.panelResizing
        atDefault: root.gridColumns === Math.min(CcMetrics.defaultColumns, root.gridColumnCap)
        sizeText: root.gridColumns + "×" + widgetGrid.slotLayout.rows
        onResizeStarted: (px, py, signX) => root.panelResizer.begin(px, py, signX)
        onResizeMoved: (px, py) => root.panelResizer.move(px, py)
        onResizeEnded: root.panelResizer.end()
        onResizeCanceled: root.panelResizer.cancel()
    }

    WidgetModel {
        id: widgetModel
        columns: root.gridColumns
        maximumRows: widgetGrid.maximumRows
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.surfaceCornerRadii.x
        topRightRadius: root.surfaceCornerRadii.y
        bottomRightRadius: root.surfaceCornerRadii.z
        bottomLeftRadius: root.surfaceCornerRadii.w
        color: Qt.rgba(0, 0, 0, Theme.scrimAlpha)
        opacity: root.host.powerMenuOpen ? 1 : 0
        visible: opacity > 0
        z: CcMetrics.overlayZ

        Behavior on opacity {
            enabled: CcMetrics.animationsEnabled
            NumberAnimation {
                duration: CcMetrics.fadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    DankFlickable {
        id: contentFlickable

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: footer.occupied ? Theme.spacingS : 0
        clip: contentHeight > height
        contentWidth: width
        contentHeight: Math.max(height, mainColumn.implicitHeight + CcMetrics.sheetPadding)
        interactive: contentHeight > height

        Column {
            id: mainColumn

            width: root.sheetContentWidth - CcMetrics.sheetPadding * 2
            x: CcMetrics.sheetPadding
            y: CcMetrics.sheetPadding
            spacing: Theme.spacingS

            Item {
                id: body

                width: parent.width
                height: root.gridHeight
                opacity: CcMetrics.hideCoveredContent ? 1 - root.coveredAmount : 1

                CcTileGrid {
                    id: widgetGrid
                    columns: root.gridColumns
                    availableHeight: root.availableGridHeight

                    width: parent.width
                    anchors.top: parent.top
                    editMode: root.host.editMode
                    model: widgetModel
                    live: root.host.shouldBeVisible && detailPage.shownSection === ""
                    screenName: root.host.triggerScreen?.name || ""
                    tapToClose: root.host.headerTogglesClose ?? false
                    runningToplevels: root.runningToplevels
                    dockEdit: !root.editPlaced && !root.host.editMode
                    onExpandClicked: widgetData => root.openWidgetPage(widgetData)
                    onRemoveWidget: index => widgetModel.removeWidget(index)
                    onConfigRequested: (index, widgetData, anchor) => root.openConfigOverlay(index, widgetData, anchor)
                    onColorPickerRequested: root.host.openColorPicker()
                    onCloseRequested: root.host.close()
                    onSettingsRequested: root.host.openSettings()
                    onAccountsRequested: root.host.openAccounts()
                    onEditRequested: root.host.editMode = true
                    onLockRequested: {
                        root.host.close();
                        root.host.lockRequested();
                    }
                    onPowerRequested: {
                        const loader = root.host.powerMenuModalLoader;
                        if (!loader)
                            return;
                        loader.active = true;
                        if (!loader.item)
                            return;
                        const bounds = Qt.rect(root.host.alignedX, root.host.alignedY, root.host.popupWidth, root.host.popupHeight);
                        loader.item.openFromControlCenter(bounds, root.host.screen);
                    }
                }
            }
        }
    }

    CcFooter {
        id: footer

        x: CcMetrics.sheetPadding
        width: root.sheetContentWidth - CcMetrics.sheetPadding * 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: CcMetrics.sheetPadding
        editMode: root.host.editMode
        showEdit: !root.editPlaced && widgetGrid.editDock === null
        opacity: body.opacity
        onAddWidgetRequested: root.openWidgetSheet()
        onResetRequested: widgetModel.resetToDefault()
        onClearRequested: widgetModel.clearAll()
        onEditToggled: root.host.editMode = !root.host.editMode
        onCancelRequested: root.cancelEdit()
    }

    CcDetailPage {
        id: detailPage

        z: 1
        anchors.fill: parent
        section: root.host.expandedSection ?? ""
        topInset: CcMetrics.sheetPadding
        cornerRadii: root.surfaceCornerRadii
        coverage: Math.max(codecSelectorLoader.item?.presence ?? 0, portSelectorLoader.item?.presence ?? 0)
        model: widgetModel
        screenName: root.host.triggerScreen?.name || ""
        screenModel: root.host.triggerScreen?.model || ""
        transientSurfaceTracker: root.host.transientSurfaceTracker
        onCodecSelectorRequested: device => root.showCodecSelector(device)
        onPortSelectorRequested: node => root.showPortSelector(node)
        runningToplevels: root.runningToplevels
        onBackRequested: root.goBack()
        onCollapseRequested: root.host.collapseAll()
        onCloseRequested: root.host.close()
        onDismissed: {
            const target = root.detailReturnFocus;
            root.detailReturnFocus = null;
            if (target?.visible && target.enabled) {
                target.forceActiveFocus();
                return;
            }
            root.forceActiveFocus();
        }
    }

    Loader {
        id: codecSelectorLoader

        anchors.fill: parent
        z: CcMetrics.overlayZ
        active: false
        sourceComponent: BluetoothCodecSelector {
            cornerRadii: root.surfaceCornerRadii
            onDismissed: Qt.callLater(root.releaseSheet, codecSelectorLoader)
        }
    }

    Loader {
        id: portSelectorLoader

        anchors.fill: parent
        z: CcMetrics.overlayZ
        active: false
        sourceComponent: AudioPortSelector {
            cornerRadii: root.surfaceCornerRadii
            onDismissed: Qt.callLater(root.releaseSheet, portSelectorLoader)
        }
    }

    Connections {
        target: CompositorService

        function onToplevelsChanged() {
            root.toplevelRevision++;
        }
    }

    Loader {
        id: widgetSheetLoader

        anchors.fill: parent
        z: CcMetrics.overlayZ
        active: root.host.editMode
        asynchronous: true
        onLoaded: {
            if (!root.widgetSheetRequested)
                return;
            root.widgetSheetRequested = false;
            item.opened = true;
        }
        sourceComponent: CcWidgetSheet {
            scrimRadii: root.surfaceCornerRadii
            surfaceColor: CcMetrics.dialogColor
            widgets: {
                const existingIds = root.placedWidgetIds.split(",");
                const allWidgets = widgetModel.baseWidgetDefinitions.concat(widgetModel.getPluginWidgets());
                return allWidgets.filter(w => w.allowMultiple || !existingIds.includes(w.id));
            }
            onDismissRequested: opened = false
            onChosen: widgetId => {
                widgetModel.addWidget(widgetId);
                opened = false;
            }
        }
    }

    Loader {
        id: configOverlayLoader

        active: false
        sourceComponent: WidgetConfigOverlay {
            model: widgetModel
            columns: root.gridColumns
            transientSurfaceTracker: root.host.transientSurfaceTracker
            onVisibleChanged: {
                if (visible)
                    return;
                Qt.callLater(root.releaseConfigOverlay);
            }
        }
    }
}
