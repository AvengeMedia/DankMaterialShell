import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankDash
import qs.Modules.ControlCenter
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var popout: null
    property var cc: null
    property bool failed: false
    property int step: 0
    property real baseHeight: 0
    property real closingHeight: 0
    property int baseRows: 0
    property int requestedRows: 0
    property real wallHeight: 0
    property real wallHeightOut: 0
    readonly property var screen: Quickshell.screens[0]
    readonly property real rowStep: DashMetrics.gridRowUnit + DashMetrics.gridGap

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function widthFor(columns) {
        return DashMetrics.widthFor(SettingsData.showWeekNumber, root.screen.width, columns);
    }

    function content() {
        return root.popout?.contentLoader?.item ?? null;
    }

    function findGrid(item) {
        if (!item)
            return null;
        if (typeof item.previewPanelColumns === "function")
            return item;
        for (const child of item.children) {
            const found = findGrid(child);
            if (found)
                return found;
        }
        return null;
    }

    function edgeGain(host, w0, w1) {
        return host.alignedXFor(w1) + w1 - host.alignedXFor(w0) - w0;
    }

    function columnGain() {
        return edgeGain(root.popout, widthFor(DashMetrics.defaultGridColumns), widthFor(DashMetrics.defaultGridColumns + 1));
    }

    function ccGain() {
        return edgeGain(root.cc, CcMetrics.sheetWidthFor(CcMetrics.defaultColumns), CcMetrics.sheetWidthFor(CcMetrics.defaultColumns + 1));
    }

    property real dragOriginX: 0
    property real dragOriginY: 0

    function beginDrag(host, target, signX) {
        root.dragOriginX = host.renderedAlignedX;
        root.dragOriginY = host.renderedAlignedY;
        target.panelResizer.begin(0, 0, signX ?? 1);
    }

    function dragTo(host, target, dx, dy) {
        target.panelResizer.move(root.dragOriginX + dx - host.renderedAlignedX, root.dragOriginY + dy - host.renderedAlignedY);
    }

    function snapped(host) {
        return host.resizing && host.renderedAlignedX === host.alignedX;
    }

    Component {
        id: dashComponent
        DankDashPopout {}
    }

    Component {
        id: ccComponent
        ControlCenterPopout {}
    }

    function openDash(tab) {
        root.popout = dashComponent.createObject(root);
        root.popout.setBarContext(0, 0);
        root.popout.triggerScreen = root.screen;
        root.popout.setTriggerPosition(640, 0, 40, "center", root.screen);
        root.popout.requestTab(tab);
        PopoutManager.requestPopout(root.popout, undefined, "main-center-overview");
        root.popout.dashVisible = true;
    }

    function openControlCenter() {
        root.cc = ccComponent.createObject(root);
        root.cc.setBarContext(0, 0);
        root.cc.triggerScreen = root.screen;
        root.cc.setTriggerPosition(640, 0, 40, "center", root.screen);
        PopoutManager.requestPopout(root.cc, undefined, "main-center-cc");
        root.cc.open();
    }

    Timer {
        id: sequencer
        interval: 1500
        onTriggered: {
            const c = content();
            switch (root.step++) {
            case 0:
                check(root.popout.shouldBeVisible && c, "dash open");
                check(root.popout.popupWidth === widthFor(DashMetrics.defaultGridColumns), "default width uses the default columns");
                root.baseHeight = root.popout.popupHeight;
                root.baseRows = c.panelRows;
                check(root.baseRows >= DashMetrics.minimumTabRows && DashMetrics.storedPanelRows("overview") === 0, "unset rows fit the cards: " + root.baseRows);
                check(!root.popout.contentWindow.anchors.right, "surface hugs the body outside edit mode");
                root.popout.editMode = true;
                check(root.popout.popupWidth === widthFor(DashMetrics.defaultGridColumns), "edit mode keeps the panel width");
                check(!root.popout.contentWindow.anchors.right && root.popout.contentWindow.implicitWidth >= widthFor(root.popout.columnCap) + PopoutMetrics.editOverflow * 4, "edit mode holds a bounded surface wide enough for the column cap plus handle padding");
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 2 * columnGain(), 0);
                check(DashMetrics.panelPreview?.columns === 8, "preview snaps two columns wider: " + JSON.stringify(DashMetrics.panelPreview));
                check(snapped(root.popout), "drag snaps the body");
                check(c.panelColumns === 8 && DashMetrics.gridColumns === 8, "overview grid follows the preview");
                check(root.popout.popupWidth === widthFor(8), "popout width follows the preview");
                dragTo(root.popout, c, 2 * columnGain(), root.rowStep);
                root.requestedRows = DashMetrics.panelPreview.rows;
                check(root.requestedRows === root.baseRows + 1 && c.panelRows === root.requestedRows, "pill shows the requested rows: " + JSON.stringify([c.panelRows, root.requestedRows]));
                dragTo(root.popout, c, 2 * columnGain(), -4 * root.rowStep);
                check(DashMetrics.panelPreview.rows === c.contentRows && c.panelRows === c.contentRows, "dragging below the content clamps to the content rows: " + JSON.stringify([DashMetrics.panelPreview.rows, c.contentRows]));
                dragTo(root.popout, c, 2 * columnGain(), root.rowStep);
                c.panelResizer.end();
                check(!DashMetrics.panelPreview && !root.popout.resizing, "preview cleared on release");
                check(SettingsData.dashOptions?.overview?.panelColumns === 8, "columns stored: " + JSON.stringify(SettingsData.dashOptions));
                check(SettingsData.dashOptions?.overview?.panelRows === root.requestedRows, "requested rows stored: " + JSON.stringify(SettingsData.dashOptions));
                check(c.panelRows === root.requestedRows, "panel keeps the dragged rows after commit");
                root.popout.editMode = false;
                check(root.popout.popupWidth === widthFor(8), "width holds when edit mode ends");
                check(!root.popout.contentWindow.anchors.right, "leaving edit mode releases the surface");
                root.popout.requestTab("media");
                check(root.popout.animationDuration <= 0 || root.popout.renderedAlignedX !== root.popout.alignedX, "tab switch glides the body");
                break;
            case 1:
                check(root.popout.activeTabId === "media", "media tab active");
                check(root.popout.popupWidth === widthFor(DashMetrics.defaultGridColumns), "media keeps its own default width");
                root.popout.editMode = true;
                beginDrag(root.popout, c);
                dragTo(root.popout, c, -columnGain(), 0);
                check(DashMetrics.panelPreview?.id === "media" && DashMetrics.panelPreview.columns === 5, "media preview: " + JSON.stringify(DashMetrics.panelPreview));
                check(DashMetrics.gridColumns === 8, "overview columns untouched by media preview");
                c.panelResizer.end();
                check(SettingsData.dashOptions?.media?.panelColumns === 5 && SettingsData.dashOptions?.media?.panelRows === undefined, "media columns stored without rows: " + JSON.stringify(SettingsData.dashOptions?.media));
                check(root.popout.popupWidth === widthFor(5), "media width committed");
                beginDrag(root.popout, c);
                dragTo(root.popout, c, columnGain(), 0);
                root.popout.editMode = false;
                check(!DashMetrics.panelPreview && SettingsData.dashOptions?.media?.panelColumns === 5, "leaving edit mode cancels the drag");
                DashRegistry.resetPanelSize("media");
                check(SettingsData.dashOptions?.media?.panelColumns === undefined, "reset clears the media size");
                root.popout.editMode = true;
                beginDrag(root.popout, c, -1);
                dragTo(root.popout, c, -columnGain(), 0);
                check(DashMetrics.panelPreview?.columns === DashMetrics.defaultGridColumns + 1, "left handle grows when dragged outward: " + JSON.stringify(DashMetrics.panelPreview));
                c.panelResizer.cancel();
                beginDrag(root.popout, c);
                c.panelResizer.end();
                check(!DashMetrics.panelPreview && SettingsData.dashOptions?.media === undefined, "release without movement stores nothing");
                check(c.panelRows === DashMetrics.minimumTabRows && c.contentRows === DashMetrics.minimumTabRows && c.panelAtDefault, "media sizes to its content: " + JSON.stringify([c.panelRows, c.contentRows]));
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 0, root.rowStep);
                c.panelResizer.end();
                check(SettingsData.dashOptions?.media?.panelRows === DashMetrics.minimumTabRows + 1 && c.panelRows === DashMetrics.minimumTabRows + 1 && !c.panelAtDefault, "one row above the content is stored for a content-sized tab: " + JSON.stringify([SettingsData.dashOptions?.media, c.panelRows]));
                DashRegistry.resetPanelSize("media");
                check(SettingsData.dashOptions?.media === undefined && c.panelRows === DashMetrics.minimumTabRows, "reset returns media to its content rows: " + c.panelRows);
                root.popout.editMode = false;
                DashRegistry.setPanelSize("overview", DashMetrics.defaultGridColumns, root.baseRows + 1);
                root.popout.requestTab("overview");
                break;
            case 2:
                check(root.popout.activeTabId === "overview" && c.panelRows === root.baseRows + 1, "stored rows above the content raise the floor: " + c.panelRows);
                check(root.popout.popupHeight === root.baseHeight + root.rowStep, "panel height follows the floor: " + JSON.stringify([root.popout.popupHeight, root.baseHeight]));
                DashRegistry.setPanelSize("overview", DashMetrics.defaultGridColumns, DashMetrics.minimumTabRows + 1);
                check(root.baseRows <= DashMetrics.minimumTabRows + 1 || c.panelRows === root.baseRows, "stored rows below the content are ignored: " + JSON.stringify([c.panelRows, root.baseRows]));
                DashRegistry.resetPanelSize("overview");
                check(SettingsData.dashOptions?.overview === undefined, "reset clears the overview size: " + JSON.stringify(SettingsData.dashOptions));
                break;
            case 3:
                check(c.panelRows === root.baseRows && root.popout.popupHeight === root.baseHeight, "unset rows fit the cards again: " + JSON.stringify([c.panelRows, root.popout.popupHeight, root.baseHeight]));
                DashRegistry.setPanelSize("overview", DashMetrics.defaultGridColumns, root.baseRows + 1);
                root.popout.editMode = true;
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 0, -root.rowStep);
                c.panelResizer.end();
                check(SettingsData.dashOptions?.overview === undefined, "dragging the floor down to the content clears the stored rows: " + JSON.stringify(SettingsData.dashOptions));
                {
                    const grid = findGrid(c);
                    const index = grid.sourceItems.findIndex(card => DashRegistry.entry(card.id)?.card?.maxW === DashMetrics.gridColumns);
                    const cell = grid.slotLayout.slots[index];
                    const slot = grid.slotFor(grid.sourceItems[index].id);
                    const base = DashMetrics.gridColumns;
                    const savedCards = JSON.parse(JSON.stringify(DashRegistry.placed));
                    const targetW = base - cell.col + 1;
                    const step = grid.columnWidth + DashMetrics.gridGap;
                    slot.startResize(0, 0);
                    slot.resizeTo((targetW - cell.cols) * step, 0);
                    check(DashMetrics.panelPreview?.columns === base + 1 && DashMetrics.gridColumns === base + 1, "card dragged past the edge widens the panel: " + JSON.stringify([DashMetrics.panelPreview, cell, targetW]));
                    check(grid.sizePreview?.changes.w === targetW && grid.slotLayout.slots[index].col === cell.col, "card grows in place: " + JSON.stringify([grid.sizePreview, grid.slotLayout.slots[index], cell]));
                    check(root.popout.popupWidth === widthFor(base + 1), "popout follows the card-driven preview: " + root.popout.popupWidth);
                    check(c.panelShifted && c.cardResizeColumns === base, "panel pill shows the card-driven column shift: " + JSON.stringify([c.panelShifted, c.panelColumns, c.cardResizeColumns]));
                    slot.finishResize();
                    check(!c.panelShifted, "panel pill hides after release");
                    check(!DashMetrics.panelPreview && SettingsData.dashOptions?.overview?.panelColumns === base + 1 && DashRegistry.placed[index].w === targetW, "release stores the wider panel and card: " + JSON.stringify([SettingsData.dashOptions?.overview, DashRegistry.placed[index]]));
                    slot.startResize(0, 0);
                    slot.resizeTo(-step, 0);
                    check(!DashMetrics.panelPreview && grid.sizePreview?.changes.w === targetW - 1, "narrowing the card keeps the stored panel width: " + JSON.stringify(grid.sizePreview));
                    slot.cancelResize();
                    check(!grid.sizePreview && !DashMetrics.panelPreview && SettingsData.dashOptions?.overview?.panelColumns === base + 1, "cancel keeps the stored width");
                    SettingsData.set("dashCards", savedCards);
                    DashRegistry.resetPanelSize("overview");
                }
                {
                    const grid = findGrid(c);
                    const savedCards = JSON.parse(JSON.stringify(DashRegistry.placed));
                    SettingsData.set("dashCards", [
                        {
                            id: "clock",
                            w: 2,
                            h: 1,
                            col: 0,
                            row: 0
                        },
                        {
                            id: "user",
                            w: 2,
                            h: 1,
                            col: 2,
                            row: 0
                        },
                        {
                            id: "media",
                            w: 3,
                            h: 1,
                            col: 0,
                            row: 1
                        }
                    ]);
                    const slots = grid.slotLayout.slots;
                    const lastRow = Math.max(...slots.map(s => s.row));
                    const index = slots.findIndex(s => s.row === lastRow);
                    const cell = slots[index];
                    const slot = grid.slotFor(grid.sourceItems[index].id);
                    const base = DashMetrics.gridColumns;
                    const others = slots.map((s, i) => i === index ? null : [s.col, s.row]);
                    const step = grid.columnWidth + DashMetrics.gridGap;
                    slot.startResize(0, 0);
                    slot.resizeTo((base - cell.col + 1 - cell.cols) * step, 0);
                    check(DashMetrics.panelPreview?.columns === base + 1 && grid.sizePreview?.changes.w === base - cell.col + 1, "a lone card dragged past the edge widens the panel: " + JSON.stringify([DashMetrics.panelPreview, grid.sizePreview, cell]));
                    check(grid.slotLayout.slots.every((s, i) => i === index || (s.col === others[i][0] && s.row === others[i][1])), "no other card moves for a lone card: " + JSON.stringify(grid.slotLayout.slots.map(s => [s.col, s.row])));
                    slot.cancelResize();
                    check(!DashMetrics.panelPreview && SettingsData.dashOptions?.overview === undefined, "cancel leaves nothing stored");
                    SettingsData.set("dashCards", savedCards);
                }
                root.popout.editMode = false;
                root.popout.requestTab("wallpaper");
                break;
            case 4:
                check(root.popout.activeTabId === "wallpaper" && c.ready, "wallpaper tab loaded");
                root.wallHeightOut = root.popout.popupHeight;
                root.popout.editMode = true;
                break;
            case 5:
                root.wallHeight = root.popout.popupHeight;
                check(c.contentRows === DashMetrics.minimumTabRows && c.panelRows === DashMetrics.defaultTabRows, "wallpaper rests on the shared default rows: " + JSON.stringify([c.contentRows, c.panelRows]));
                check(c.panelResizer.maxRows > c.panelRows, "screen leaves room for one more row: " + JSON.stringify([c.panelResizer.maxRows, c.panelRows]));
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 0, root.rowStep);
                check(DashMetrics.panelPreview?.rows === DashMetrics.defaultTabRows + 1, "wallpaper preview adds a row: " + JSON.stringify(DashMetrics.panelPreview));
                break;
            case 6:
                check(root.popout.popupHeight === root.wallHeight + root.rowStep, "one row of drag adds one row of height: " + JSON.stringify([root.popout.popupHeight, root.wallHeight]));
                dragTo(root.popout, c, 0, 0);
                check(DashMetrics.panelPreview?.rows === DashMetrics.defaultTabRows, "dragging back lands on the default rows");
                break;
            case 7:
                check(root.popout.popupHeight === root.wallHeight, "the default-row preview matches the resting height: " + JSON.stringify([root.popout.popupHeight, root.wallHeight]));
                c.panelResizer.end();
                check(!DashMetrics.panelPreview && SettingsData.dashOptions?.wallpaper === undefined, "release on the start rows stores nothing");
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 0, root.rowStep);
                c.panelResizer.end();
                check(SettingsData.dashOptions?.wallpaper?.panelRows === DashMetrics.defaultTabRows + 1, "wallpaper rows stored: " + JSON.stringify(SettingsData.dashOptions?.wallpaper));
                break;
            case 8:
                check(root.popout.popupHeight === root.wallHeight + root.rowStep, "committed rows keep the preview height: " + JSON.stringify([root.popout.popupHeight, root.wallHeight]));
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 0, -root.rowStep);
                c.panelResizer.end();
                check(SettingsData.dashOptions?.wallpaper === undefined, "dragging back to the default clears the stored rows");
                beginDrag(root.popout, c);
                dragTo(root.popout, c, 0, -root.rowStep);
                c.panelResizer.end();
                check(SettingsData.dashOptions?.wallpaper?.panelRows === DashMetrics.minimumTabRows && c.panelRows === DashMetrics.minimumTabRows, "wallpaper shrinks below the default down to its content: " + JSON.stringify([SettingsData.dashOptions?.wallpaper, c.panelRows]));
                break;
            case 9:
                check(root.popout.popupHeight === root.wallHeight - root.rowStep, "stored rows below the default shrink the panel: " + JSON.stringify([root.popout.popupHeight, root.wallHeight]));
                DashRegistry.resetPanelSize("wallpaper");
                check(SettingsData.dashOptions?.wallpaper === undefined && c.panelRows === DashMetrics.defaultTabRows, "reset returns wallpaper to the default rows: " + c.panelRows);
                root.popout.editMode = false;
                break;
            case 10:
                check(root.popout.popupHeight === root.wallHeightOut, "reset restores the default height outside edit mode: " + JSON.stringify([root.popout.popupHeight, root.wallHeightOut]));
                SettingsData.weatherEnabled = true;
                root.popout.requestTab("weather");
                break;
            case 11:
                check(root.popout.activeTabId === "weather", "weather tab loaded");
                root.popout.editMode = true;
                interval = 600;
                break;
            case 12:
                check(root.popout.editMode, "weather edit mode");
                root.closingHeight = c.height;
                root.popout.dashVisible = false;
                check(root.popout.editMode, "edit mode holds while closing");
                DashRegistry.setPanelSize("weather", DashMetrics.defaultGridColumns, c.panelRows + 1);
                interval = 150;
                break;
            case 13:
                check(root.popout.isClosing && root.popout.popupHeight > root.closingHeight, "target height grew during the close: " + JSON.stringify([root.popout.popupHeight, root.closingHeight]));
                check(c.height === root.closingHeight, "closing body keeps its size: " + JSON.stringify([c.height, root.closingHeight]));
                openControlCenter();
                interval = 1500;
                break;
            case 14:
                {
                    check(!root.popout.editMode && !root.popout.contentWindow.anchors.right, "edit mode resets once closed");
                    const ccContent = root.cc.contentLoader?.item ?? null;
                    check(root.cc.shouldBeVisible && ccContent, "control center open");
                    check(root.cc.popupWidth === CcMetrics.sheetWidthDefault, "control center default width");
                    root.cc.editMode = true;
                    check(root.cc.popupWidth === CcMetrics.sheetWidthDefault, "control center edit mode keeps the sheet width");
                    check(!root.cc.contentWindow.anchors.right && root.cc.contentWindow.implicitWidth >= CcMetrics.sheetWidthFor(root.cc.gridColumnCap) + PopoutMetrics.editOverflow * 4, "control center edit mode holds a bounded surface wide enough for the column cap");
                    beginDrag(root.cc, ccContent);
                    dragTo(root.cc, ccContent, 1.4 * ccGain(), 0);
                    check(CcMetrics.gridColumns === CcMetrics.defaultColumns + 1 && CcMetrics.sheetWidth === CcMetrics.sheetWidthFor(CcMetrics.defaultColumns + 1), "control center preview snaps to a column: " + CcMetrics.sheetWidth);
                    check(snapped(root.cc), "control center drag snaps the body");
                    check(root.cc.popupWidth === CcMetrics.sheetWidthFor(CcMetrics.defaultColumns + 1), "control center popout follows the preview");
                    ccContent.panelResizer.end();
                    check(SettingsData.controlCenterColumns === CcMetrics.defaultColumns + 1, "control center columns stored: " + SettingsData.controlCenterColumns);
                    check(CcMetrics.columnPreview === 0, "control center preview cleared");
                    beginDrag(root.cc, ccContent);
                    dragTo(root.cc, ccContent, -400, 0);
                    check(CcMetrics.gridColumns === CcMetrics.minimumColumns, "control center clamps to the fewest columns: " + CcMetrics.gridColumns);
                    dragTo(root.cc, ccContent, -1.4 * ccGain(), 0);
                    check(CcMetrics.gridColumns === CcMetrics.defaultColumns && CcMetrics.sheetWidth === CcMetrics.sheetWidthDefault, "control center lands back on the default");
                    ccContent.panelResizer.cancel();
                    beginDrag(root.cc, ccContent, -1);
                    dragTo(root.cc, ccContent, -1.4 * ccGain(), 0);
                    check(CcMetrics.gridColumns === CcMetrics.defaultColumns + 2, "left handle grows the control center: " + CcMetrics.gridColumns);
                    root.cc.editMode = false;
                    check(CcMetrics.gridColumns === CcMetrics.defaultColumns + 1, "leaving edit mode cancels the control center drag");
                    root.cc.close();
                    interval = 500;
                }
                break;
            case 15:
                console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
                stop();
                Qt.quit();
                return;
            }
            restart();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.barConfigs = [
            {
                id: "main",
                enabled: true,
                visible: true,
                position: 0,
                spacing: 4,
                innerPadding: 4,
                leftWidgets: [],
                centerWidgets: [],
                rightWidgets: []
            }
        ];
        openDash("overview");
        sequencer.start();
    }
}
