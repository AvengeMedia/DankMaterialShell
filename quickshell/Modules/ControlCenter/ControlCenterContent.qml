pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Models
import qs.Modules.ControlCenter.Details
import qs.Widgets
import "./utils/sections.js" as Sections

FocusScope {
    id: root

    required property var host

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property bool pageOpen: (host.expandedSection ?? "") !== ""
    readonly property real gridHeight: widgetGrid.gridHeight
    readonly property real targetImplicitHeight: {
        let total = CcMetrics.sheetPadding * 2 + gridHeight;
        if (host.editMode)
            total += Theme.spacingS + editControls.height;
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
    readonly property real availableGridHeight: (host.availableHeight ?? (host.triggerScreen?.height ?? CcMetrics.fallbackScreenHeight) - CcMetrics.maxHeightInset) - CcMetrics.sheetPadding * 2 - Theme.spacingS - editControls.height
    readonly property real editGutter: host.editGutter ?? 0
    readonly property DankPanelResizer panelResizer: DankPanelResizer {
        popout: root.host
        gutter: root.editGutter
        stepWidth: CcMetrics.columnWidth + CcMetrics.gridGap
        widthFor: columns => CcMetrics.sheetWidthFor(columns) + root.sheetContentWidth - CcMetrics.sheetWidthFor(root.gridColumns)
        currentStep: () => root.gridColumns
        minStep: Math.min(CcMetrics.minimumColumns, root.gridColumnCap)
        maxStep: root.gridColumnCap
        onPreview: columns => CcMetrics.columnPreview = columns
        onCommitted: columns => {
            const widgets = widgetGrid.displayedItems();
            SettingsData.set("controlCenterColumns", columns);
            CcMetrics.columnPreview = 0;
            widgetModel.setLayout(widgets);
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

    Keys.onEscapePressed: event => {
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
        }
        forceActiveFocus();
    }

    DankGridEditChrome {
        id: panelChrome

        anchors.fill: parent
        anchors.margins: -(contentInset + Theme.spacingS)
        z: 1
        visible: root.host.editMode
        enabled: detailPage.shownSection === ""
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

        anchors.fill: parent
        clip: contentHeight > height
        contentWidth: width
        contentHeight: Math.max(height, mainColumn.implicitHeight + CcMetrics.sheetPadding * 2)
        interactive: contentHeight > height

        Column {
            id: mainColumn

            width: root.sheetContentWidth - CcMetrics.sheetPadding * 2
            x: CcMetrics.sheetPadding + root.editGutter
            y: CcMetrics.sheetPadding
            spacing: Theme.spacingS

            Item {
                id: body

                width: parent.width
                height: root.gridHeight
                opacity: CcMetrics.hideCoveredContent ? 1 - detailPage.opacity : 1

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
                    onExpandClicked: widgetData => root.openWidgetPage(widgetData)
                    onRemoveWidget: index => widgetModel.removeWidget(index)
                    onConfigRequested: (index, widgetData, anchor) => root.openConfigOverlay(index, widgetData, anchor)
                    onColorPickerRequested: root.host.openColorPicker()
                    onHeaderTapped: root.host.close()
                    onEditRequested: root.host.editMode = !root.host.editMode
                    onSettingsRequested: root.host.openSettings()
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

            EditControls {
                id: editControls

                width: parent.width
                visible: root.host.editMode
                popupScreen: root.host.screen
                popoutX: root.host.alignedX
                popoutY: root.host.alignedY
                popoutWidth: root.host.alignedWidth
                popoutHeight: root.host.alignedHeight
                availableWidgets: {
                    if (!root.host.editMode)
                        return [];
                    const existingIds = (SettingsData.controlCenterWidgets || []).map(w => w.id);
                    const allWidgets = widgetModel.baseWidgetDefinitions.concat(widgetModel.getPluginWidgets());
                    return allWidgets.filter(w => w.allowMultiple || !existingIds.includes(w.id));
                }
                onAddWidget: widgetId => widgetModel.addWidget(widgetId)
                onResetToDefault: () => widgetModel.resetToDefault()
                onClearAll: () => widgetModel.clearAll()
                onFinishRequested: root.host.editMode = false
                onCancelRequested: root.cancelEdit()
            }
        }
    }

    CcDetailPage {
        id: detailPage

        z: 1
        anchors.fill: parent
        section: root.host.expandedSection ?? ""
        topInset: CcMetrics.sheetPadding
        minimumContentHeight: Math.max(0, root.gridHeight - CcMetrics.pageHeaderHeight)
        cornerRadii: root.surfaceCornerRadii
        coverage: Math.max(codecSelectorLoader.item?.presence ?? 0, portSelectorLoader.item?.presence ?? 0)
        model: widgetModel
        screenName: root.host.triggerScreen?.name || ""
        screenModel: root.host.triggerScreen?.model || ""
        onCodecSelectorRequested: device => root.showCodecSelector(device)
        onPortSelectorRequested: node => root.showPortSelector(node)
        onBackRequested: root.goBack()
        onCollapseRequested: root.host.collapseAll()
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

    Loader {
        id: configOverlayLoader

        anchors.fill: parent
        z: CcMetrics.overlayZ
        active: false
        sourceComponent: WidgetConfigOverlay {
            backdrop: contentFlickable
            onVisibleChanged: {
                if (visible)
                    return;
                Qt.callLater(root.releaseConfigOverlay);
            }
        }
    }
}
