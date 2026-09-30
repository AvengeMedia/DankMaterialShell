import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
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
    QtObject {
        id: userHost
        property bool editMode: false
        property bool tapToClose: true
        property var model: registry
        property int closes: 0
        property int accounts: 0
        function closeRequested() {
            closes++;
        }
        function accountsRequested() {
            accounts++;
        }
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
            check(!isPolishScheduled(surface) || waitForPolish(surface, 20000), "layout settled");
        }

        function waitFor(condition, label) {
            const deadline = Date.now() + 20000;
            while (!condition()) {
                check(Date.now() < deadline, "timed out: " + label);
                wait(10);
            }
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
                waitFor(() => scene.Window.active, "fixture window takes keyboard focus");
                SettingsData.controlCenterWidgets = [
                    {
                        id: "wifi",
                        w: 10,
                        h: 12
                    },
                    {
                        id: "colorPicker",
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
                grid.beginDrag(1);
                grid.updateDragTarget(0, 0);
                grid.endDrag();
                check(SettingsData.controlCenterWidgets[0].w === 10 && SettingsData.controlCenterWidgets[0].h === 12 && SettingsData.controlCenterWidgets[0].row === 2 && SettingsData.controlCenterWidgets[1].row === 0, "moving on a smaller screen preserves saved spans and pushes the collided tile " + JSON.stringify(SettingsData.controlCenterWidgets));
                grid.beginDrag(0);
                grid.updateDragTarget(0, grid.cellWidth * 4);
                grid.endDrag();
                check(SettingsData.controlCenterWidgets[0].row === 2, "gravity closes the gap a drop below free space would leave " + JSON.stringify(SettingsData.controlCenterWidgets));
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
                SettingsData.controlCenterWidgets = [
                    {
                        id: "lock",
                        w: 1,
                        h: 1
                    }
                ];
                const buttonSlot = grid.children.find(child => typeof child.beginResize === "function");
                const buttonChrome = buttonSlot.children.find(child => typeof child.resizeStarted === "function");
                const resizeButton = delta => {
                    buttonChrome.resizeStarted(0, 0, 1);
                    buttonSlot.resizeTo(delta, delta);
                    buttonSlot.finishResize();
                    return SettingsData.controlCenterWidgets[0];
                };
                let button = resizeButton(-grid.cellWidth / 2);
                check(button.small === true && button.w === 1 && button.h === 1 && buttonSlot.tileItem.small, "shrinking a 1x1 below its cell keeps the cell and makes the button small " + JSON.stringify(button));
                button = resizeButton(0);
                check(button.small === true, "grabbing a small button without moving keeps it small");
                button = resizeButton(grid.cellWidth * 0.3);
                check(button.small === false && button.w === 1 && button.h === 1, "growing a small button passes through a full 1x1 " + JSON.stringify(button));
                button = resizeButton(-grid.cellWidth / 2);
                button = resizeButton(grid.cellWidth);
                check(button.small === false && button.w === 2 && button.h === 2, "past full size a small button grows a cell per cell of travel like a full one " + JSON.stringify(button));
                SettingsData.controlCenterWidgets = [
                    {
                        id: "darkMode",
                        w: 4,
                        h: 1
                    }
                ];
                const wideSlot = grid.children.find(child => typeof child.beginResize === "function");
                const wideChrome = wideSlot.children.find(child => typeof child.resizeStarted === "function");
                const resizeWide = delta => {
                    wideChrome.resizeStarted(0, 0, 1);
                    wideSlot.resizeTo(0, delta);
                    wideSlot.finishResize();
                    return SettingsData.controlCenterWidgets[0];
                };
                let wide = resizeWide(-grid.cellWidth / 2);
                check(wide.small === true && wide.w === 4 && wide.h === 1 && wideSlot.tileItem.small, "wide tiles take the half-height step too " + JSON.stringify(wide));
                wide = resizeWide(grid.cellWidth * 0.3);
                check(wide.small === false && wide.w === 4 && wide.h === 1, "a half-height tile grows back to a full row " + JSON.stringify(wide));
                SettingsData.controlCenterWidgets = [
                    {
                        id: "user",
                        w: 5,
                        h: 1
                    },
                    {
                        id: "lock",
                        w: 1,
                        h: 1,
                        small: true
                    },
                    {
                        id: "edit",
                        w: 1,
                        h: 1,
                        small: true
                    }
                ];
                WidgetUtils.setCardAction(0, "lock", true, 8);
                WidgetUtils.setCardAction(0, "edit", true, 8);
                let card = SettingsData.controlCenterWidgets[0];
                check(SettingsData.controlCenterWidgets.length === 1 && JSON.stringify(card.actions) === JSON.stringify(["user", "lock", "edit"]) && card.w === 7, "card actions take their tiles out of the grid and widen the card by their columns " + JSON.stringify(SettingsData.controlCenterWidgets));
                check(WidgetUtils.sizeSpec(Object.assign({}, card, {
                    h: 2
                }), 8).minW === 2 && WidgetUtils.sizeSpec(card, 8).minW === 3, "card buttons wrap into rows before they claim columns");
                check(WidgetUtils.sizeSpec(Object.assign({}, card, {
                    h: 2,
                    actions: ["lock", "user", "edit"]
                }), 8).minW === 3, "buttons on both sides of the identity claim a column each");
                const cardTile = grid.children.find(child => typeof child.beginResize === "function").tileItem;
                const sceneOf = point => cardTile.mapToItem(null, point.x, point.y);
                const edit = cardTile.actionSlot("edit");
                cardTile.beginReorder("edit", sceneOf(Qt.point(edit.x + 1, edit.y + 1)));
                cardTile.moveReorder(sceneOf(Qt.point(cardTile.identityStart + cardTile.identityWidth * 0.75, cardTile.height / 2)));
                check(JSON.stringify(cardTile.order) === JSON.stringify(["user", "lock", "edit"]), "a button stays put on its own side of the identity");
                cardTile.moveReorder(sceneOf(Qt.point(cardTile.identityStart + cardTile.identityWidth * 0.25, cardTile.height / 2)));
                cardTile.moveReorder(sceneOf(Qt.point(cardTile.identityStart + cardTile.identityWidth * 0.4, cardTile.height / 2)));
                cardTile.finishReorder();
                card = SettingsData.controlCenterWidgets[0];
                check(JSON.stringify(card.actions) === JSON.stringify(["edit", "user", "lock"]), "dragging a button past the identity's centre saves it on the other side " + JSON.stringify(card));
                check(Math.abs(cardTile.actionSlot("edit").x - cardTile.buttonInset) < 0.5 && cardTile.identityStart === cardTile.pitch, "the identity makes room for leading buttons");
                const lock = cardTile.actionSlot("lock");
                const lockCenter = Qt.point(lock.x + CcMetrics.iconBoxSize / 2, lock.y + CcMetrics.iconBoxSize / 2);
                const dropPoint = Qt.point(cardTile.identityStart + cardTile.identityWidth * 0.25, cardTile.height / 2);
                mousePress(cardTile, lockCenter.x, lockCenter.y);
                for (let i = 1; i <= 8; i++)
                    mouseMove(cardTile, lockCenter.x + (dropPoint.x - lockCenter.x) * i / 8, lockCenter.y + (dropPoint.y - lockCenter.y) * i / 8);
                check(grid.draggingSourceIndex === -1 && cardTile.draggedAction === "lock", "dragging a card button reorders it instead of moving the card");
                mouseRelease(cardTile, dropPoint.x, dropPoint.y);
                check(JSON.stringify(SettingsData.controlCenterWidgets[0].actions) === JSON.stringify(["edit", "lock", "user"]), "a mouse drop saves the new order " + JSON.stringify(SettingsData.controlCenterWidgets[0]));
                const corner = Qt.point(cardTile.width - 2, cardTile.height - 2);
                mousePress(cardTile, corner.x, corner.y);
                mouseMove(cardTile, corner.x, corner.y + grid.cellWidth / 2);
                mouseMove(cardTile, corner.x, corner.y + grid.cellWidth);
                check(grid.sizePreview?.index === 0 && grid.draggingSourceIndex === -1, "the card's resize corner still works around its buttons");
                mouseRelease(cardTile, corner.x, corner.y + grid.cellWidth);
                SettingsData.controlCenterWidgets = [
                    {
                        id: "user",
                        w: 7,
                        h: 1,
                        col: 0,
                        row: 0,
                        actions: ["settings", "user", "lock"]
                    },
                    {
                        id: "wifi",
                        w: 4,
                        h: 1,
                        col: 0,
                        row: 1
                    }
                ];
                let cardIndex = WidgetUtils.setCardAction(0, "settings", false, 8);
                cardIndex = WidgetUtils.setCardAction(cardIndex, "lock", false, 8);
                const returned = SettingsData.controlCenterWidgets;
                const at = id => grid.slotLayout.slots[SettingsData.controlCenterWidgets.findIndex(widget => widget.id === id)];
                check(returned[cardIndex].id === "user" && returned[cardIndex].w === 5 && at("user").col === 1 && at("settings").col === 0 && at("lock").col === 6 && at("settings").row === 0 && at("lock").row === 0 && at("wifi").row === 1 && returned.every(widget => widget.id === "user" || widget.id === "wifi" || widget.small), "buttons taken off a placed card return as small tiles where they sat " + JSON.stringify(returned));
                SettingsData.controlCenterWidgets = [
                    {
                        id: "wifi",
                        w: 2,
                        h: 1
                    },
                    {
                        id: "user",
                        w: 6,
                        h: 1,
                        actions: ["power", "user"]
                    }
                ];
                cardIndex = WidgetUtils.setCardAction(1, "power", false, 8);
                check(cardIndex === 2 && SettingsData.controlCenterWidgets[1].id === "power" && at("power").col === 2 && at("user").col === 3 && at("user").row === 0, "a button taken off an unplaced card packs next to it and the card index follows " + JSON.stringify(SettingsData.controlCenterWidgets));
                check(WidgetUtils.setCardAction(cardIndex, "power", true, 8) === 1, "adding a tile before the card to it reports the card's new index");
                grid.dockEdit = true;
                SettingsData.controlCenterWidgets = [
                    {
                        id: "wifi",
                        w: 8,
                        h: 1
                    },
                    {
                        id: "runningApps",
                        w: 7,
                        h: 1,
                        small: true
                    }
                ];
                const dock = grid.editDock;
                check(dock !== null && Math.abs(dock.x - grid.cellWidth * 7) < 0.5 && Math.abs(dock.y - grid.cellWidth) < 0.5, "the edit button joins a last row with a free trailing cell " + JSON.stringify(dock));
                SettingsData.controlCenterWidgets = [
                    {
                        id: "wifi",
                        w: 4,
                        h: 1
                    },
                    {
                        id: "runningApps",
                        w: 8,
                        h: 1
                    }
                ];
                check(grid.editDock === null, "a full last row keeps the edit button in the footer");
                grid.dockEdit = false;
                grid.destroy();
                wait(0);
                const userTile = registry.componentForWidget({
                    id: "user"
                }).createObject(scene);
                size(userTile, 6, 2);
                userTile.widgetData = {
                    id: "user",
                    actions: ["user", "lock", "power"],
                    background: true
                };
                const cardRadius = userTile.bodyRadius;
                userTile.widgetData = {
                    id: "user",
                    actions: ["user", "lock", "power"]
                };
                check(userTile.bodyRadius === cardRadius && cardRadius < userTile.height / 2, "a tall card with buttons keeps its card outline without a background");
                userTile.host = userHost;
                const avatarButton = named(userTile, "userAvatarButton");
                const closeButton = named(userTile, "userCloseButton");
                const shownAvatar = item => {
                    if (item !== userTile && item.visible && (item.imageSource !== undefined || item.shape !== undefined))
                        return item;
                    for (const child of item.children || []) {
                        const found = shownAvatar(child);
                        if (found)
                            return found;
                    }
                    return null;
                };
                for (const layout of [[5, 1, {}], [6, 2, {
                            background: true,
                            actions: ["settings", "user", "lock"]
                        }], [1, 1, {}], [3, 3, {
                            background: true
                        }]]) {
                    size(userTile, layout[0], layout[1]);
                    userTile.widgetData = Object.assign({
                        id: "user"
                    }, layout[2]);
                    settle();
                    const shown = shownAvatar(userTile);
                    const at = shown.mapToItem(userTile, 0, 0);
                    const hit = avatarButton.mapToItem(userTile, 0, 0);
                    check(Math.abs(at.x - hit.x) < 1 && Math.abs(at.y - hit.y) < 1 && Math.abs(shown.width - avatarButton.width) < 1, "the avatar's click area covers the picture at " + layout[0] + "x" + layout[1] + " " + JSON.stringify([at.x, at.y, shown.width, hit.x, hit.y, avatarButton.width]));
                }
                size(userTile, 5, 1);
                userTile.widgetData = {
                    id: "user"
                };
                settle();
                const avatarCenter = avatarButton.mapToItem(userTile, avatarButton.width / 2, avatarButton.height / 2);
                mouseMove(userTile, avatarCenter.x, avatarCenter.y);
                check(avatarButton.hovered && !closeButton.hovered, "hovering the avatar lights only the avatar");
                mouseClick(userTile, avatarCenter.x, avatarCenter.y);
                check(userHost.accounts === 1 && userHost.closes === 0, "clicking the avatar opens accounts without closing through the card");
                mouseClick(userTile, userTile.width - Theme.spacingL, userTile.height / 2);
                check(userHost.accounts === 1 && userHost.closes === 1, "clicking the rest of the card only closes");
                userTile.destroy();
                wait(0);
                const tile = tileComponent.createObject(scene);
                size(tile, 4, 1);
                tile.small = true;
                settle();
                const smallBox = named(tile, "tileIconBox");
                check(smallBox.height <= tile.bodyHeight - tile.tilePadding * 2 && named(tile, "tileLabels").height <= tile.bodyHeight, "a half-height tile keeps its icon and labels inside its body");
                tile.small = false;
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
                const detail = detailComponent.createObject(scene, {
                    width: 600,
                    height: 400
                });
                NetworkService.wifiEnabled = true;
                NetworkService.wifiInterface = "wlan0";
                NetworkService.wifiNetworks = Array.from({
                    length: 8
                }, (_, i) => ({
                            ssid: "Net" + i,
                            signal: 90 - i * 8,
                            secured: true
                        }));
                detail.section = "wifi";
                waitFor(() => !detail.transitioning && detail.pageItem !== null, "wifi detail page loads");
                settle();
                const networkList = named(detail.pageItem, "networkList");
                waitFor(() => networkList.count === 8, "wifi rows load");
                settle();
                check(networkList.atYBeginning, "network popup opens at the top, contentY " + networkList.contentY + " vs origin " + networkList.originY);
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
