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
            slotLayout: GridUtils.packCards(layoutItems, visualOrder, 8, width, 8, 64, mirrored)
            onReorderCommitted: items => sourceItems = items
            onResizeCommitted: (index, changes) => sourceItems = sourceItems.map((item, i) => i === index ? Object.assign({}, item, changes) : item)

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
                editGrid.updateDragTarget(destination.x + destination.w / 2, destination.y + destination.h / 2);
                const dragged = slots.itemAt(0);
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
                placed("committing a reorder");
                for (const entry of before)
                    check(JSON.parse(entry.item.json).id === entry.id && entry.item.x === entry.x && entry.item.y === entry.y, "reorder preserves each tile and its preview position");

                editGrid.animateLayout = true;
                editGrid.sourceItems = editGrid.sourceItems.slice(1);
                placed("removing a tile");
            }
            if (failures.length > 0)
                console.error("FIXTURE_FAIL", failures.join("; "));
            else
                console.log("FIXTURE_PASS grid edit layout");
            Qt.quit();
        }
    }
}
