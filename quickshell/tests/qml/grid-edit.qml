import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter.Components
import qs.Modules.ControlCenter.Models
import qs.Modules.DankDash.Overview
import qs.DankCommon.Common as DC

ShellRoot {
    Component.onCompleted: {
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        DC.Paths.backend = Paths;
    }

    WidgetModel {
        id: ccModel
    }

    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 800
        color: Theme.surfaceContainerLow

        Item {
            id: scene
            anchors.fill: parent

            DankFlickable {
                id: flick
                x: 30
                y: 30
                width: 520
                height: 160
                contentWidth: width
                contentHeight: 800

                CcTileGrid {
                    id: ccGrid
                    width: parent.width
                    editMode: true
                    model: ccModel
                    live: false
                }
            }

            DashCardGrid {
                id: dashGrid
                x: 30
                y: 250
                width: 790
                editMode: true
                rowBudget: 5
                live: false
            }
        }

        TestCase {
            id: tester
            when: false

            function check(condition, label) {
                if (!condition)
                    throw new Error(label);
                console.log("PASS " + label);
            }

            function slotFor(grid, index) {
                return grid.children.find(item => item.index === index && item.json !== undefined);
            }

            function reset() {
                SessionData.locale = "en";
                ccGrid.editMode = true;
                dashGrid.editMode = true;
                SettingsData.controlCenterWidgets = [
                    {
                        id: "darkMode",
                        w: 1,
                        h: 1
                    },
                    {
                        id: "diskUsage",
                        w: 1,
                        h: 1
                    }
                ];
                SettingsData.dashCards = [
                    {
                        id: "clock",
                        w: 2,
                        h: 2
                    },
                    {
                        id: "user",
                        w: 2,
                        h: 2
                    }
                ];
                wait(400);
            }

            function pointOn(item, x, y) {
                return item.mapToItem(scene, x, y);
            }

            function resize(grid, dx, dy, touch) {
                const slot = slotFor(grid, 0);
                const x = I18n.isRtl ? 6 : slot.width - 6;
                const y = slot.height - 6;
                const start = pointOn(slot, x, y);
                const sequence = touch ? touchEvent(scene) : null;
                if (touch)
                    sequence.press(0, scene, start.x, start.y).commit();
                else
                    mousePress(scene, start.x, start.y);
                wait(20);
                check(slot.resizing && !slot.dragging && slot.resizeOrigin !== null, "resize press retains ownership");
                check(!slotFor(grid, 1).interactionEnabled, "other tile input is blocked");
                for (let i = 1; i <= 10; i++) {
                    const px = start.x + dx * i / 10;
                    const py = start.y + dy * i / 10;
                    if (touch)
                        sequence.move(0, scene, px, py).commit();
                    else
                        mouseMove(scene, px, py);
                    wait(20);
                }
                check(slot.resizing && !slot.dragging, "resize remains active during motion");
                if (touch)
                    sequence.release(0, scene, start.x + dx, start.y + dy).commit();
                else
                    mouseRelease(scene, start.x + dx, start.y + dy);
                wait(400);
                check(!grid.interacting && slot.resizeOrigin === null, "resize release clears ownership");
                check(flick.contentY === 0, "resize does not scroll parent");
            }

            function reorder(grid, touch) {
                const slot = slotFor(grid, 0);
                const start = pointOn(slot, 24, 24);
                const other = slotFor(grid, 1);
                const end = pointOn(other, other.width / 2, other.height / 2);
                const sequence = touch ? touchEvent(scene) : null;
                if (touch)
                    sequence.press(0, scene, start.x, start.y).commit();
                else
                    mousePress(scene, start.x, start.y);
                wait(20);
                check(!grid.interacting, "press alone does not reorder");
                for (let i = 1; i <= 10; i++) {
                    const px = start.x + (end.x - start.x) * i / 10;
                    const py = start.y + (end.y - start.y) * i / 10;
                    if (touch)
                        sequence.move(0, scene, px, py).commit();
                    else
                        mouseMove(scene, px, py);
                    wait(20);
                }
                check(slot.dragging, "drag retains ownership");
                if (touch)
                    sequence.release(0, scene, end.x, end.y).commit();
                else
                    mouseRelease(scene, end.x, end.y);
                wait(400);
                check(!grid.interacting, "move releases ownership");
            }

            function cancelResize(grid) {
                const slot = slotFor(grid, 0);
                const start = pointOn(slot, slot.width - 6, slot.height - 6);
                const before = JSON.stringify(grid.sourceItems);
                mousePress(scene, start.x, start.y);
                mouseMove(scene, start.x + 140, start.y + 104);
                wait(40);
                check(slot.resizing, "cancel starts from active resize");
                grid.editMode = false;
                wait(20);
                mouseRelease(scene, start.x + 140, start.y + 104);
                wait(40);
                check(!grid.interacting && slot.resizeOrigin === null, "mode exit releases resize");
                check(JSON.stringify(grid.sourceItems) === before, "cancel preserves saved size");
            }

            function run() {
                reset();
                resize(ccGrid, ccGrid.cellWidth, ccGrid.cellWidth, false);
                check(SettingsData.controlCenterWidgets[0].w === 2 && SettingsData.controlCenterWidgets[0].h === 2, "control center mouse resize persists both axes");
                resize(dashGrid, 140, 104, false);
                check(SettingsData.dashCards[0].w === 3 && SettingsData.dashCards[0].h === 3, "dashboard mouse resize persists both axes");
                reset();
                resize(ccGrid, ccGrid.cellWidth, 0, true);
                check(SettingsData.controlCenterWidgets[0].w === 2 && SettingsData.controlCenterWidgets[0].h === 1, "control center touch resize persists");
                resize(dashGrid, 140, 104, true);
                check(SettingsData.dashCards[0].w === 3 && SettingsData.dashCards[0].h === 3, "dashboard touch resize persists both axes");
                reset();
                reorder(ccGrid, false);
                check(SettingsData.controlCenterWidgets[0].id === "darkMode" && SettingsData.controlCenterWidgets[0].col === 1 && SettingsData.controlCenterWidgets[1].row === 1, "control center mouse move lands on the cell and pushes the occupant down");
                reorder(dashGrid, true);
                check(SettingsData.dashCards[0].id === "clock" && SettingsData.dashCards[0].col === 3 && SettingsData.dashCards[0].row === 1 && SettingsData.dashCards[1].row === 3, "dashboard touch move lands on the cell and pushes the occupant down");
                reset();
                cancelResize(ccGrid);
                cancelResize(dashGrid);
                reset();
                SessionData.locale = "ar";
                wait(400);
                resize(ccGrid, -ccGrid.cellWidth, 0, false);
                check(SettingsData.controlCenterWidgets[0].w === 2, "RTL control center resize persists");
                resize(dashGrid, -140, 104, true);
                check(SettingsData.dashCards[0].w === 3 && SettingsData.dashCards[0].h === 3, "RTL dashboard resize persists");
                reset();
                SessionData.locale = "en";
                SettingsData.dashCards = [
                    {
                        id: "clock",
                        w: 6,
                        h: 4
                    },
                    {
                        id: "user",
                        w: 2,
                        h: 1
                    }
                ];
                wait(400);
                resize(dashGrid, 0, 300, false);
                check(SettingsData.dashCards[0].h === 4, "dashboard resize stops at the board edge");
                check(dashGrid.addableEntries.every(candidate => candidate.entry.id !== "calendar"), "cards that cannot fit are not addable");
                check(dashGrid.addableEntries.find(candidate => candidate.entry.id === "media")?.size.h === 1, "addable cards shrink to the free space");
                SettingsData.dashCards = [
                    {
                        id: "clock",
                        w: 6,
                        h: 5
                    }
                ];
                wait(400);
                check(dashGrid.addableEntries.length === 0, "full board offers nothing to add");
                console.log("GRID_EDIT_PASS");
                Qt.quit();
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            try {
                tester.run();
            } catch (error) {
                console.log("GRID_EDIT_FAIL " + error);
                Qt.quit();
            }
        }
    }
}
