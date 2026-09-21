import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Widgets
import "Common/GridLayout.js" as GridUtils
import qs.DankCommon.Common as DC

ShellRoot {
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        Qt.callLater(tester.run);
    }

    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 400

        DankEditableGrid {
            id: editGrid
            property bool mirrored: false
            width: 568
            editMode: true
            slotLayout: GridUtils.packCards(layoutItems, placementOrder, 8, width, 8, 64, mirrored)
            onLayoutCommitted: items => sourceItems = items

            Repeater {
                id: slots
                model: editGrid.tileModel
                DankEditableGridSlot {
                    grid: editGrid
                }
            }
        }
    }

    TestCase {
        id: tester
        when: false
        property var failures: []

        function check(condition, message) {
            if (!condition)
                failures.push(message);
        }

        function placed(label) {
            for (let i = 0; i < slots.count; i++) {
                const item = slots.itemAt(i);
                const target = item.slot;
                check(item.x === target.x && item.y === target.y && item.width === target.w && item.height === target.h, label + " " + i + " starts outside its slot");
            }
        }

        function heldHeight() {
            editGrid.mirrored = false;
            editGrid.animationsEnabled = false;
            editGrid.sourceItems = [
                {
                    id: "a",
                    w: 2,
                    h: 1,
                    col: 0,
                    row: 0
                },
                {
                    id: "b",
                    w: 2,
                    h: 1,
                    col: 0,
                    row: 1
                }
            ];
            const twoRows = editGrid.implicitHeight;
            const rowUnit = editGrid.slotLayout.rowUnit + editGrid.slotLayout.gap;
            editGrid.beginDrag(1);
            editGrid.updateDragTarget(slots.itemAt(0).slot.w + editGrid.slotLayout.gap, 0);
            check(editGrid.slotLayout.rows === 1 && editGrid.implicitHeight === twoRows, "dragging the bottom tile up keeps the grid height");
            editGrid.updateDragTarget(0, rowUnit * 2);
            const threeRows = editGrid.implicitHeight;
            check(threeRows === twoRows + rowUnit, "dragging below the last row grows the grid");
            editGrid.updateDragTarget(0, rowUnit);
            check(editGrid.implicitHeight === threeRows, "the grid never shrinks while a drag is in progress");
            editGrid.endDrag();
            check(editGrid.implicitHeight === twoRows, "releasing the drag settles to the committed layout");
        }

        function run() {
            for (const mirrored of [false, true]) {
                editGrid.animationsEnabled = false;
                editGrid.mirrored = mirrored;
                editGrid.sourceItems = [
                    {
                        id: "a",
                        w: 2,
                        h: 1
                    },
                    {
                        id: "b",
                        w: 2,
                        h: 1
                    },
                    {
                        id: "c",
                        w: 2,
                        h: 1
                    }
                ];
                editGrid.animationsEnabled = true;
                editGrid.animateLayout = true;
                editGrid.sourceItems = editGrid.sourceItems.concat([
                    {
                        id: "d",
                        w: 2,
                        h: 1
                    }
                ]);
                placed("adding a tile");

                editGrid.animateLayout = true;
                const resized = slots.itemAt(1);
                resized.beginResize(resized.width, resized.height);
                editGrid.previewSize(1, {
                    w: 4,
                    h: 2
                });
                check(resized.width === resized.slot.w && resized.height === resized.slot.h, "resizing follows the pointer without a second layout animation");
                editGrid.commitSize();
                placed("committing a resize");

                editGrid.animationsEnabled = false;
                editGrid.beginDrag(0);
                const destination = slots.itemAt(1).slot;
                const dragged = slots.itemAt(0);
                editGrid.updateDragTarget(mirrored ? destination.x + destination.w - dragged.slot.w : destination.x, destination.y);
                dragged.x = dragged.slot.x;
                dragged.y = dragged.slot.y;
                const before = Array.from({
                    length: slots.count
                }, (_, i) => {
                    const item = slots.itemAt(i);
                    return {
                        item,
                        id: JSON.parse(item.json).id,
                        x: item.x,
                        y: item.y
                    };
                });
                editGrid.animationsEnabled = true;
                editGrid.animateLayout = true;
                editGrid.endDrag();
                placed("committing a move");
                for (const entry of before)
                    check(JSON.parse(entry.item.json).id === entry.id && entry.item.x === entry.x && entry.item.y === entry.y, "move preserves each tile and its preview position");
                check(editGrid.sourceItems[0].col === 2 && editGrid.sourceItems[1].row === 1 && editGrid.sourceItems[2].col === 4, "move lands on the cell and pushes only the collided tile ");

                editGrid.animateLayout = true;
                editGrid.sourceItems = editGrid.sourceItems.slice(1);
                placed("removing a tile");
            }
            heldHeight();
            if (failures.length > 0)
                console.error("FIXTURE_FAIL", failures.join("; "));
            else
                console.log("FIXTURE_PASS grid edit layout");
            Qt.quit();
        }
    }
}
