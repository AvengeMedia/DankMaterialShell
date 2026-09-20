import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.DankIsland
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Widgets
import "Modules/ControlCenter/utils/widgets.js" as WidgetUtils
import qs.Modules.ControlCenter.Models
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property int toggles: 0
    property int expansions: 0
    property int actions: 0

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.animationDuration = 0;
        Qt.callLater(tester.run);
    }

    WidgetModel {
        id: registry
    }
    IslandController {
        id: island
        dashboardAvailableWidth: CcMetrics.sheetWidthFor(20) + controlCenterSheetInset + PopoutMetrics.editOverflow * 2
        dashboardAvailableHeight: CcMetrics.fallbackScreenHeight
        controlCenterMaxHeight: dashboardAvailableHeight
    }

    Component {
        id: tileComponent
        CcTile {
            title: "Headphones with a long device name"
            subtitle: "Connected · 75%"
            iconName: "headphones"
            showExpand: true
            onClicked: root.toggles++
            onExpandClicked: root.expansions++
            expandedContent: Component {
                CcTileActions {
                    actions: [
                        {
                            text: "Device one with a name long enough to wrap over several lines",
                            icon: "headphones",
                            trigger: () => root.actions++
                        },
                        {
                            text: "Device two",
                            icon: "speaker",
                            enabled: false,
                            trigger: () => root.actions++
                        }
                    ]
                }
            }
        }
    }

    Component {
        id: sliderComponent
        CcSliderRow {
            iconName: "volume_up"
            iconLabel: "Mute"
            sliderLabel: "Volume"
        }
    }

    Component {
        id: detailComponent
        CcDetailPage {
            model: registry
        }
    }

    Component {
        id: gridComponent
        CcTileGrid {
            id: testGrid
            columns: CcMetrics.defaultColumns
            width: CcMetrics.sheetWidthFor(columns) - CcMetrics.sheetPadding * 2
            availableHeight: CcMetrics.gridRowUnit * 12 + CcMetrics.gridGap * 11
            editMode: true
            live: false
            model: WidgetModel {
                columns: testGrid.columns
                maximumRows: testGrid.maximumRows
            }
        }
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1200
        implicitHeight: 800
        color: Theme.surface
        Item {
            id: scene
            anchors.fill: parent
        }
    }

    TestCase {
        id: tester
        when: false

        function check(condition, message) {
            if (!condition)
                throw new Error(message);
        }

        function settle() {
            wait(0);
            const surface = scene.Window.window;
            check(!isPolishScheduled(surface) || waitForPolish(surface, 5000), "layout settled");
        }

        function named(item, name) {
            if (item.objectName === name)
                return item;
            for (const child of item.children || []) {
                const found = named(child, name);
                if (found)
                    return found;
            }
            return null;
        }

        function inside(item, container, label) {
            if (!item || !item.visible)
                return;
            const point = item.mapToItem(container, 0, 0);
            check(item.width >= 0 && item.height >= 0 && point.x >= -0.5 && point.y >= -0.5 && point.x + item.width <= container.width + 0.5 && point.y + item.height <= container.height + 0.5, label + " out of bounds " + JSON.stringify({
                x: point.x,
                y: point.y,
                w: item.width,
                h: item.height,
                cw: container.width,
                ch: container.height
            }));
        }

        function actionBounds(item, container) {
            if (item.isSettingsRow)
                inside(item, container, "inline action");
            for (const child of item.children || [])
                actionBounds(child, container);
        }

        function swatches(item, container) {
            let count = 0;
            if (item.swatchColor !== undefined && typeof item.click === "function") {
                inside(item, container, "color swatch");
                count++;
            }
            for (const child of item.children || [])
                count += swatches(child, container);
            return count;
        }

        function size(tile, columns, rows) {
            tile.columns = columns;
            tile.rows = rows;
            tile.width = CcMetrics.columnWidth * columns + CcMetrics.gridGap * (columns - 1);
            tile.height = CcMetrics.gridRowUnit * rows + CcMetrics.gridGap * (rows - 1);
        }

        function run() {
            try {
                check(waitForRendering(scene), "window rendered");
                SettingsData.controlCenterWidgets = [
                    {
                        id: "wifi",
                        w: 10,
                        h: 12
                    },
                    {
                        id: "diskUsage",
                        w: 2,
                        h: 2
                    }
                ];
                const grid = gridComponent.createObject(scene);
                check(grid.maximumRows === 12 && grid.slotLayout.slots[0].rows === 12, "list height is independent of panel columns");
                check(grid.slotLayout.slots[0].cols === 8, "wide saved tiles fit the current panel");
                check(island.controlCenterColumnCap === 20, "Island columns use available screen width");
                island.setDestinationContentHeight("controlcenter", CcMetrics.fallbackScreenHeight);
                check(island.controlCenterHeight === CcMetrics.fallbackScreenHeight, "Island allows taller lists within its screen height");
                const square = grid.slotLayout.slots[1];
                check(Math.abs(square.w - square.h) < 0.01, "2x2 has square geometry");
                grid.width += Theme.spacingL;
                check(Math.abs(grid.slotLayout.slots[1].w - grid.slotLayout.slots[1].h) < 0.01, "host inset preserves square geometry");
                grid.availableHeight = CcMetrics.gridRowUnit * 5 + CcMetrics.gridGap * 4;
                check(grid.slotLayout.slots[0].rows <= 5, "tile height fits the available screen");
                grid.beginDrag(0);
                grid.updateDragTarget(0, grid.cellWidth);
                grid.endDrag();
                check(SettingsData.controlCenterWidgets[0].w === 10 && SettingsData.controlCenterWidgets[0].h === 12 && SettingsData.controlCenterWidgets[0].row === 1 && SettingsData.controlCenterWidgets[1].row === grid.maximumRows + 1, "moving on a smaller screen preserves saved spans and pushes the collided tile " + JSON.stringify(SettingsData.controlCenterWidgets));
                grid.previewSize(0, {
                    w: 6
                });
                grid.commitSize();
                check(SettingsData.controlCenterWidgets[0].w === 6 && SettingsData.controlCenterWidgets[0].h === 12, "width edits preserve the saved height on a smaller screen");
                grid.previewSize(0, {
                    w: 2.5
                });
                grid.commitSize();
                grid.previewSize(0, {
                    h: 1.5
                });
                grid.commitSize();
                const half = grid.slotLayout.slots[0];
                const cell = grid.cellWidth - CcMetrics.gridGap;
                check(SettingsData.controlCenterWidgets[0].w === 2.5 && SettingsData.controlCenterWidgets[0].h === 1.5 && half.cols === 2.5 && half.rows === 1.5, "half steps are saved on both axes");
                check(Math.abs(half.w - (cell * 2.5 + CcMetrics.gridGap * 1.5)) < 0.01 && Math.abs(half.h - (cell * 1.5 + CcMetrics.gridGap * 0.5)) < 0.01, "half spans pack at half pitch");
                check(WidgetUtils.clampSize({
                    id: "volumeSlider",
                    w: 1.5,
                    h: 1
                }, 8, 1).w === 2, "sliders under two cells on both axes keep a usable track");
                check(WidgetUtils.clampSize({
                    id: "volumeSlider",
                    w: 1,
                    h: 1
                }, 8, 12).h === 2, "sliders keep room for their action and track");
                check(CcMetrics.columnCapFor(CcMetrics.sheetWidthFor(20)) === 20, "wide screens allow more than six columns");
                SettingsData.controlCenterWidgets = [
                    {
                        id: "volumeSlider",
                        w: 2,
                        h: 1
                    }
                ];
                const sliderSlot = grid.children.find(child => typeof child.beginResize === "function");
                check(sliderSlot !== undefined, "slider slot available");
                sliderSlot.resizeRequested(grid.cellWidth - CcMetrics.gridGap, grid.cellWidth - CcMetrics.gridGap);
                grid.commitSize();
                check(SettingsData.controlCenterWidgets[0].w === 1 && SettingsData.controlCenterWidgets[0].h === 2, "narrowing a slider retains a usable portrait layout");
                sliderSlot.resizeRequested(grid.cellWidth - CcMetrics.gridGap, grid.cellWidth - CcMetrics.gridGap);
                grid.commitSize();
                check(SettingsData.controlCenterWidgets[0].w === 2 && SettingsData.controlCenterWidgets[0].h === 1, "shortening a slider retains a usable strip layout");
                sliderSlot.resizeRequested(grid.cellWidth * 3.5 - CcMetrics.gridGap, grid.cellWidth - CcMetrics.gridGap);
                grid.commitSize();
                check(SettingsData.controlCenterWidgets[0].w === 3.5 && sliderSlot.tileItem.columns === 3.5, "resizing snaps to half columns");
                grid.destroy();
                wait(0);
                const tile = tileComponent.createObject(scene);
                for (const fontScale of [1, 1.5]) {
                    Theme.fontScale = fontScale;
                    for (const rtl of [false, true]) {
                        tile.LayoutMirroring.enabled = rtl;
                        for (const [columns, rows] of [[1, 1], [2, 1], [1, 2], [2, 2], [3, 2], [4, 3], [10, 12]]) {
                            size(tile, columns, rows);
                            settle();
                            for (const name of ["tileIconBox", "tileTitle", "tileSubtitle", "tileExpandedContent"])
                                inside(named(tile, name), tile, name + " " + columns + "x" + rows + " font " + fontScale);
                            actionBounds(tile, tile);
                        }
                    }
                }
                for (const scale of [0.5, 1.5]) {
                    SettingsData.controlCenterIconScale = scale;
                    for (const dimensions of [[1, 2], [2, 1], [2, 2], [2, 3]]) {
                        size(tile, dimensions[0], dimensions[1]);
                        settle();
                        inside(named(tile, "tileIconBox"), tile, "scaled icon");
                        inside(named(tile, "tileTitle"), tile, "scaled title");
                    }
                }
                SettingsData.controlCenterIconScale = 1;
                Theme.fontScale = 1;
                tile.LayoutMirroring.enabled = false;
                size(tile, 4, 3);
                settle();
                check(tile.expanded && tile.expandedItem !== null, "large tile exposes inline actions");
                const inline = tile.expandedItem;
                check(inline.tile === tile && inline.columns === 4 && inline.rows === 3, "plugin content receives its tile context");
                const before = root.toggles;
                const content = named(tile, "tileExpandedContent");
                mouseClick(tile, tile.width / 2, content.y + Theme.spacingM + Theme.listItemHeight / 2);
                check(root.actions === 1 && root.toggles === before && root.expansions === 0, "inline action does not activate tile");
                mouseClick(tile, tile.width / 2, tile.height - Theme.spacingL * 2);
                check(root.actions === 1 && root.expansions === 0 && root.toggles === before, "disabled inline action does not activate tile");
                mouseClick(named(tile, "tileIconBox"));
                check(root.toggles === before + 1, "icon toggles independently");
                tile.forceActiveFocus();
                keyClick(Qt.Key_Return);
                check(root.expansions === 1, "tile keyboard activation opens details");
                tile.live = false;
                check(tile.expandedItem === null, "hidden control center unloads inline controls");
                tile.destroy();
                wait(0);

                const verticalSlider = sliderComponent.createObject(scene);
                size(verticalSlider, 1, 3);
                settle();
                check(verticalSlider.vertical, "portrait slider uses vertical track");
                verticalSlider.slider.forceActiveFocus();
                keyClick(Qt.Key_End);
                check(verticalSlider.slider.value === 100, "vertical slider End reaches maximum");
                keyClick(Qt.Key_Home);
                keyClick(Qt.Key_Up);
                check(verticalSlider.slider.value === 1, "vertical slider Up increases value");
                mouseClick(verticalSlider.slider, verticalSlider.slider.width * 0.75, verticalSlider.slider.height / 2);
                check(verticalSlider.slider.value >= 74 && verticalSlider.slider.value <= 77, "portrait pointer coordinates follow slider value");
                verticalSlider.destroy();
                wait(0);

                const ids = ["wifi", "bluetooth", "audioOutput", "audioInput", "volumeSlider", "inputVolumeSlider", "brightnessSlider", "nightMode", "darkMode", "doNotDisturb", "idleInhibitor", "battery", "diskUsage", "colorPicker"];
                for (const id of ids) {
                    const component = registry.componentForWidget({
                        id
                    });
                    check(component.status === Component.Ready, id + " compiled: " + component.errorString());
                    const widget = component.createObject(scene, {
                        widgetData: {
                            id
                        }
                    });
                    check(widget !== null, id + " created");
                    if (widget.slider) {
                        check(WidgetUtils.clampSize({
                            id,
                            w: 1,
                            h: 3
                        }, 4).h === 3, id + " allows vertical resizing");
                        SettingsData.controlCenterIconScale = 1.5;
                    }
                    for (const dimensions of [[1, 1], [1, 2], [2, 2], [3, 2], [4, 3], [10, 12]]) {
                        const supported = WidgetUtils.clampSize({
                            id,
                            w: dimensions[0],
                            h: dimensions[1]
                        }, 10, 12);
                        size(widget, supported.w, supported.h);
                        settle();
                        if (widget.slider) {
                            check(widget.slider.width >= Theme.minimumTouchTargetSize, id + " retains a usable track at " + dimensions);
                            inside(named(widget, "sliderTrackArea"), widget, id + " track");
                        }
                    }
                    SettingsData.controlCenterIconScale = 1;
                    widget.destroy();
                    wait(0);
                }
                SessionData.recentColors = Array.from({
                    length: 18
                }, (_, i) => Qt.rgba(i / 18, 0.5, 0.5, 1).toString());
                const colorTile = registry.componentForWidget({
                    id: "colorPicker"
                }).createObject(scene);
                size(colorTile, 4, 6);
                settle();
                check(swatches(colorTile, colorTile) === 18, "taller color tiles show multiple rows of recent colors");
                colorTile.destroy();
                wait(0);
                for (const definition of registry.builtinDefinitions) {
                    check(definition.component.status === Component.Ready, definition.id + " compiled: " + definition.component.errorString());
                    const instance = definition.component.createObject(scene);
                    check(instance !== null, definition.id + " created");
                    const body = instance.ccExpandedContent.createObject(scene, {
                        width: 220,
                        height: 120
                    });
                    check(body !== null, definition.id + " inline content created");
                    body.destroy();
                    instance.destroy();
                    wait(0);
                }
                const detail = detailComponent.createObject(scene, {
                    width: 600,
                    height: 400
                });
                detail.section = "doNotDisturb";
                settle();
                detail.section = "";
                settle();
                check(!detail.visible, "closed detail page hides");
                detail.width = 800;
                settle();
                check(!detail.visible, "closed detail page stays hidden after the panel widens");
                detail.destroy();
                wait(0);
                console.log("FIXTURE_PASS control center sizes and actions");
            } catch (error) {
                console.error("FIXTURE_FAIL " + error.message);
            }
            Qt.quit();
        }
    }
}
