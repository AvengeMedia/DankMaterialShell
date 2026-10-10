pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.DCommon.Widgets
import "../utils/widgets.js" as WidgetUtils

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var grid
    property bool editMode: false
    property var items: []
    property bool onTop: false
    property var transientSurfaceTracker: null
    // A grid tile hovering the row: {"cells", "end", "at"}, with `at` counted within the start or end group.
    property var incoming: null
    // Takes (savedIndex, cells, scenePoint) and returns true when it takes the dropped item.
    property var dropHandler: null
    // Takes the dragged item's scene rect and returns true while something outside the row will take it.
    property var leavesRow: null
    property int liftedIndex: -1
    property var liftedSlot: null
    property point liftedPoint: Qt.point(0, 0)
    property bool gridDragging: false
    property point gridDragPoint: Qt.point(0, 0)
    // Set from the pointer, not bound: the slot reads the widths that the incoming tile changes.
    property var gridSlot: null
    property var resizePreview: null
    property Item flyingItem: null
    property bool incomingRemovable: true
    readonly property bool dragging: gridDragging || liftedIndex >= 0
    readonly property bool dragRemovable: liftedIndex >= 0 ? WidgetUtils.isRemovable(items.find(item => item.index === liftedIndex)?.widget) : incomingRemovable
    readonly property bool overTrash: trashContains(liftedIndex >= 0 ? liftedPoint : gridDragPoint)

    signal addWidgetRequested
    signal resetRequested
    signal clearRequested
    signal moveRequested
    signal finishRequested
    signal cancelRequested
    signal removeRequested(int index)
    signal configRequested(int index, var widgetData, var anchor)
    signal itemMoved(int index, rect sceneRect, bool leaving)
    signal resized(int index, real cells, bool fill)

    // Grid columns, so footer widths line up with the tiles above.
    readonly property real spacing: CcMetrics.gridGap
    readonly property real pitch: grid.cellWidth
    readonly property real editActionsWidth: Theme.iconButtonSize * 3 + spacing * 2
    // The row owns its full width in both modes, so capacity never changes under the user's feet; edit mode
    // shows the whole row scaled into the room beside the edit buttons, so every width stays reachable.
    readonly property real trackWidth: width
    readonly property real editScale: width > 0 ? Math.min(1, (width - editActionsWidth - CcMetrics.footerGap) / width) : 1
    readonly property real trackScale: editMode ? editScale : 1
    readonly property real step: CcMetrics.gridStep
    readonly property real capacity: Math.max(0, Math.floor((trackWidth + spacing) / pitch / step + 1e-6) * step)
    readonly property var fills: items.map(item => resizePreview?.index === item.index ? resizePreview.fill : WidgetUtils.footerFills(item.widget))
    readonly property var mins: items.map(item => WidgetUtils.footerMinCells(item.widget.id))
    readonly property var ends: items.map(item => WidgetUtils.footerEnds(item.widget))
    readonly property var keeps: items.map(item => !WidgetUtils.isRemovable(item.widget))
    // Fill items count at their minimum, so a drop or a neighbour growing takes room from them first.
    readonly property var fixedCells: WidgetUtils.fitFooterCells(items.map((item, i) => fills[i] ? mins[i] : (resizePreview?.index === item.index ? resizePreview.cells : WidgetUtils.footerCells(item.widget))), mins, capacity, keeps, step)
    readonly property real fixedUsed: fixedCells.reduce((sum, count) => sum + count, 0)
    readonly property var cells: WidgetUtils.spreadFooterFill(fixedCells, fills, capacity - fixedUsed - (incoming?.cells ?? 0), step)
    readonly property int slackIndex: fills.findIndex((fill, i) => fill && cells[i] > 0)
    // The first fill item also takes the part of a cell left over, so it ends exactly at the next item or the edge.
    readonly property real fillSlack: slackIndex < 0 ? 0 : Math.max(0, trackWidth + spacing - (cells.reduce((sum, count) => sum + count, 0) + (incoming?.cells ?? 0)) * pitch)
    // Stable keys keep delegates alive across resizes and reorders, so they update in place instead of rebuilding.
    readonly property var keys: {
        const seen = {};
        return items.map(item => {
            const base = (item.widget.id ?? "") + "|" + (item.widget.instanceId ?? "");
            seen[base] = (seen[base] ?? 0) + 1;
            return base + "#" + seen[base];
        });
    }
    readonly property var layout: {
        const shown = groups();
        const lifted = items.findIndex(item => item.index === liftedIndex);
        const gap = lifted >= 0 ? liftedSlot : incoming;
        const gapCells = lifted >= 0 ? cells[lifted] : (incoming?.cells ?? 0);
        const endGapAt = gap?.end ? gap.at : -1;
        const endFrom = trackWidth + spacing - groupWidth(shown.ends) - (endGapAt >= 0 ? gapCells * pitch : 0);
        const start = placeGroup(shown.starts, 0, gap && !gap.end ? gap.at : -1, gapCells);
        const end = placeGroup(shown.ends, endFrom, endGapAt, gapCells);
        return {
            "offsets": Object.assign(start.offsets, end.offsets),
            "gapOffset": Math.max(start.gapOffset, end.gapOffset),
            "gapCells": gapCells
        };
    }

    implicitHeight: CcMetrics.footerHeight

    onGridDragPointChanged: gridSlot = gridDragging ? insertionAt(gridDragPoint) : null

    function spanWidth(count) {
        return count * pitch - spacing;
    }

    function xFor(offset, span) {
        return track.overhang + (I18n.isRtl ? trackWidth - offset - span : offset);
    }

    function freeCells() {
        return capacity - fixedUsed;
    }

    function trashContains(scenePosition) {
        if (!editMode || !dragging || !dragRemovable)
            return false;
        return trash.contains(trash.mapFromItem(null, scenePosition.x, scenePosition.y));
    }

    function containsScene(scenePosition) {
        const point = mapFromItem(null, scenePosition.x, scenePosition.y);
        return point.x >= 0 && point.x <= width && point.y >= -CcMetrics.gridGap && point.y <= height + CcMetrics.gridGap;
    }

    function spanAt(i) {
        return cells[i] * pitch + (i === slackIndex ? fillSlack : 0);
    }

    function groupWidth(group) {
        return group.reduce((sum, i) => sum + spanAt(i), 0);
    }

    // Shown items other than the lifted one, split into the start and end groups in saved order.
    function groups() {
        const shown = items.map((item, i) => i).filter(i => items[i].index !== liftedIndex && cells[i] > 0);
        return {
            "starts": shown.filter(i => !ends[i]),
            "ends": shown.filter(i => ends[i])
        };
    }

    function placeGroup(group, from, gapAt, gapCells) {
        const offsets = [];
        let gapOffset = -1;
        let offset = from;
        for (let k = 0; k <= group.length; k++) {
            if (k === gapAt) {
                gapOffset = offset;
                offset += gapCells * pitch;
            }
            if (k === group.length)
                break;
            offsets[group[k]] = offset;
            offset += spanAt(group[k]);
        }
        return {
            "offsets": offsets,
            "gapOffset": gapOffset
        };
    }

    // The free space between the groups splits at its middle: the start half appends to the start group, the rest joins the end group.
    function insertionAt(scenePosition) {
        const local = track.mapFromItem(null, scenePosition.x, scenePosition.y).x - track.overhang;
        const distance = I18n.isRtl ? trackWidth - local : local;
        const shown = groups();
        let offset = 0;
        for (let k = 0; k < shown.starts.length; k++) {
            const span = spanAt(shown.starts[k]);
            if (distance < offset + span / 2)
                return {
                    "end": false,
                    "at": k
                };
            offset += span;
        }
        const endFrom = trackWidth + spacing - groupWidth(shown.ends);
        if (distance < (offset + endFrom) / 2)
            return {
                "end": false,
                "at": shown.starts.length
            };
        offset = endFrom;
        for (let k = 0; k < shown.ends.length; k++) {
            const span = spanAt(shown.ends[k]);
            if (distance < offset + span / 2)
                return {
                    "end": true,
                    "at": k
                };
            offset += span;
        }
        return {
            "end": true,
            "at": shown.ends.length
        };
    }

    // The saved index a drop at `slot` goes before, or -1 for the end of the list.
    function savedIndexAt(slot) {
        const group = groups()[slot.end ? "ends" : "starts"];
        if (slot.at < group.length)
            return items[group[slot.at]].index;
        return group.length > 0 ? items[group[group.length - 1]].index + 1 : -1;
    }

    function slotOf(savedIndex) {
        const at = items.findIndex(item => item.index === savedIndex);
        const end = ends[at] ?? false;
        return {
            "end": end,
            "at": groups()[end ? "ends" : "starts"].filter(i => i < at).length
        };
    }

    Item {
        id: track

        // The layer only draws inside the item, so it reaches out far enough for the edit chrome.
        readonly property real overhang: PopoutMetrics.editOverflow

        anchors.left: parent.left
        anchors.leftMargin: -overhang
        anchors.verticalCenter: parent.verticalCenter
        width: root.trackWidth + overhang * 2
        height: CcMetrics.footerHeight + overhang * 2
        // Scaled glyphs and icons alias; a mipmapped full-size layer shrinks them cleanly.
        layer.enabled: trackScale.xScale < 1
        layer.smooth: true
        layer.mipmap: true
        transform: Scale {
            id: trackScale

            origin.x: I18n.isRtl ? track.width - track.overhang : track.overhang
            origin.y: track.height / 2
            xScale: root.trackScale
            yScale: root.trackScale

            Behavior on xScale {
                enabled: CcMetrics.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }

            Behavior on yScale {
                enabled: CcMetrics.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }
        }

        StyledRect {
            x: root.xFor(root.layout.gapOffset, root.spanWidth(root.layout.gapCells))
            y: track.overhang
            width: root.spanWidth(root.layout.gapCells)
            height: CcMetrics.footerHeight
            radius: Theme.fullRadius(width, height)
            color: Theme.withAlpha(Theme.primary, Theme.stateLayerDrag)
            visible: root.layout.gapOffset >= 0 && root.layout.gapCells > 0
        }

        Repeater {
            model: ScriptModel {
                values: root.keys
            }

            Item {
                id: footerItem

                required property int index
                readonly property var entry: root.items[index] ?? ({
                        "index": -1,
                        "widget": ({})
                    })
                readonly property real cells: root.cells[index] ?? 0
                readonly property bool lifted: root.liftedIndex === entry.index
                readonly property real span: root.spanWidth(Math.max(1, cells)) + (index === root.slackIndex ? root.fillSlack : 0)
                readonly property real restX: root.xFor(root.layout.offsets[index] ?? 0, span)
                property point grab: Qt.point(0, 0)
                property point dragScene: Qt.point(0, 0)
                readonly property point dragPosition: {
                    // The panel can grow under a drag and move the row, so the pointer is re-mapped whenever it does.
                    root.y;
                    const point = track.mapFromItem(null, dragScene.x, dragScene.y);
                    return Qt.point(point.x - grab.x, point.y - grab.y);
                }
                property bool landed: false
                readonly property bool flying: lifted || landed
                readonly property bool atEnd: root.ends[index] ?? false

                x: lifted || landed ? dragPosition.x : restX
                y: lifted || landed ? dragPosition.y : track.overhang
                z: lifted || landed ? 1 : 0
                width: span
                height: CcMetrics.footerHeight
                visible: cells > 0

                // A reorder or a switch of side is the moment a dropped item leaves the pointer for its slot.
                onIndexChanged: landed = false
                onAtEndChanged: landed = false
                onFlyingChanged: {
                    if (flying) {
                        root.flyingItem = footerItem;
                        return;
                    }
                    if (root.flyingItem === footerItem)
                        root.flyingItem = null;
                }

                Behavior on x {
                    enabled: !footerItem.lifted && !footerItem.landed && CcMetrics.animationsEnabled
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                    }
                }

                CcTileLoader {
                    id: tile

                    anchors.fill: parent
                    grid: root.grid
                    widgetData: footerItem.entry.widget
                    savedIndex: footerItem.entry.index
                    columns: Math.max(1, footerItem.cells)
                    rows: 1
                    compact: footerItem.cells <= 1
                    small: true
                    docked: true
                }

                CcEditChrome {
                    id: chrome

                    property real startX: 0
                    property real startCells: 0
                    property bool startFill: false

                    anchors.fill: parent
                    anchors.margins: -contentInset
                    z: 2
                    visible: root.editMode
                    widgetData: footerItem.entry.widget
                    passthrough: tile.item?.passthrough ?? null
                    dragging: footerItem.lifted
                    resizing: root.resizePreview?.index === footerItem.entry.index
                    horizontalResize: true
                    sizeText: root.resizePreview?.index === footerItem.entry.index && root.resizePreview.fill ? I18n.tr("Fill") : String(footerItem.cells)
                    cornerRadius: tile.item?.bodyRadius ?? Theme.fullRadius(footerItem.width, footerItem.height)
                    onResizeStarted: (px, py) => {
                        startX = mapToItem(null, px, py).x;
                        startCells = footerItem.cells;
                        startFill = root.fills[footerItem.index] ?? false;
                        root.resizePreview = {
                            "index": footerItem.entry.index,
                            "cells": startCells,
                            "fill": startFill
                        };
                    }
                    // Pulling past the edit buttons turns the item into a fill, which runs on to the row's edge outside edit mode.
                    onResizeMoved: (px, py) => {
                        const delta = (mapToItem(null, px, py).x - startX) * (I18n.isRtl ? -1 : 1) / root.trackScale;
                        const min = root.mins[footerItem.index];
                        const max = Math.max(min, root.capacity - (root.fixedUsed - root.fixedCells[footerItem.index]));
                        const wanted = Math.round((startCells + delta / root.pitch) / root.step) * root.step;
                        root.resizePreview = {
                            "index": footerItem.entry.index,
                            "cells": Math.max(min, Math.min(max, wanted)),
                            "fill": startFill ? wanted >= max : wanted > max
                        };
                    }
                    onResizeEnded: {
                        const preview = root.resizePreview;
                        const cells = preview?.cells ?? startCells;
                        const fill = preview?.fill ?? startFill;
                        if (cells !== startCells || fill !== startFill)
                            root.resized(footerItem.entry.index, cells, fill);
                        root.resizePreview = null;
                    }
                    onResizeCanceled: root.resizePreview = null
                    onRemoveRequested: root.removeRequested(footerItem.entry.index)
                    onConfigRequested: anchor => root.configRequested(footerItem.entry.index, footerItem.entry.widget, anchor)
                }

                HoverHandler {
                    enabled: root.editMode && root.resizePreview === null
                    cursorShape: footerItem.lifted ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }

                DragHandler {
                    id: dragHandler

                    target: null
                    enabled: root.editMode && root.resizePreview === null && !footerItem.landed
                    cursorShape: Qt.ClosedHandCursor
                    onActiveChanged: {
                        if (active) {
                            footerItem.grab = footerItem.mapFromItem(null, centroid.scenePressPosition.x, centroid.scenePressPosition.y);
                            footerItem.dragScene = centroid.scenePosition;
                            root.liftedPoint = centroid.scenePosition;
                            root.liftedIndex = footerItem.entry.index;
                            root.liftedSlot = root.insertionAt(centroid.scenePosition);
                            return;
                        }
                        footerItem.landed = root.dropHandler?.(footerItem.entry.index, footerItem.cells, footerItem.dragScene) ?? false;
                        root.liftedIndex = -1;
                        root.liftedSlot = null;
                    }
                    onCentroidChanged: {
                        if (!active)
                            return;
                        footerItem.dragScene = centroid.scenePosition;
                        root.liftedPoint = centroid.scenePosition;
                        const visual = footerItem.mapToItem(null, 0, 0, footerItem.width, footerItem.height);
                        const leaving = !root.overTrash && (root.leavesRow?.(visual) ?? false);
                        root.liftedSlot = leaving || root.overTrash ? null : root.insertionAt(footerItem.dragScene);
                        root.itemMoved(footerItem.entry.index, visual, leaving);
                    }
                }
            }
        }
    }

    Item {
        id: editActions

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.editActionsWidth
        height: CcMetrics.footerHeight
        visible: root.editMode

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.spacing
            visible: !root.dragging

            DActionButton {
                buttonSize: Theme.iconButtonSize
                iconName: "add"
                iconSize: CcMetrics.iconBoxIconSize
                iconColor: Theme.onSecondaryContainer
                backgroundColor: Theme.secondaryContainer
                tooltipText: I18n.tr("Add widget")
                onClicked: root.addWidgetRequested()
            }

            DActionButton {
                id: moreButton

                buttonSize: Theme.iconButtonSize
                iconName: "more_horiz"
                iconSize: CcMetrics.iconBoxIconSize
                iconColor: CcMetrics.tileInactiveContent
                backgroundColor: CcMetrics.tileInactiveColor
                border.width: Theme.layerOutlineWidth
                border.color: Theme.outlineMedium
                tooltipText: I18n.tr("More")
                onClicked: editMenu.openAt(moreButton)
            }
        }

        StyledRect {
            id: trash

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.editActionsWidth - Theme.iconButtonSize - root.spacing
            height: CcMetrics.footerHeight
            radius: Theme.fullRadius(width, height)
            color: root.overTrash ? Theme.errorContainer : CcMetrics.tileInactiveColor
            visible: root.dragging && root.dragRemovable
            Accessible.role: Accessible.Graphic
            Accessible.name: I18n.tr("Remove")

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            DIcon {
                anchors.centerIn: parent
                name: "delete"
                size: CcMetrics.iconBoxIconSize
                filled: root.overTrash
                color: root.overTrash ? Theme.onErrorContainer : CcMetrics.tileInactiveContent
            }
        }

        DActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            buttonSize: Theme.iconButtonSize
            iconName: "check"
            iconSize: CcMetrics.iconBoxIconSize
            iconColor: Theme.onPrimary
            backgroundColor: Theme.primary
            tooltipText: I18n.tr("Save")
            onClicked: root.finishRequested()
        }
    }

    CcMenu {
        id: editMenu

        transientSurfaceTracker: root.transientSurfaceTracker
        items: [
            {
                "iconName": root.onTop ? "vertical_align_bottom" : "vertical_align_top",
                "label": root.onTop ? I18n.tr("Move row to footer", "control center edit menu, moves the row from the header to the footer") : I18n.tr("Move row to header", "control center edit menu, moves the row from the footer to the header"),
                "action": () => root.moveRequested()
            },
            {
                "iconName": "settings_backup_restore",
                "label": I18n.tr("Reset to default"),
                "action": () => root.resetRequested()
            },
            {
                "iconName": "clear_all",
                "label": I18n.tr("Clear All"),
                "destructive": true,
                "action": () => root.clearRequested()
            },
            {
                "iconName": "close",
                "label": I18n.tr("Discard"),
                "action": () => root.cancelRequested()
            }
        ]
    }

    // The track's layer only draws inside the row, so a lifted item is shown from here while it travels.
    ShaderEffectSource {
        readonly property real pad: PopoutMetrics.editOverflow
        readonly property point at: {
            const item = root.flyingItem;
            if (!item)
                return Qt.point(0, 0);
            item.x;
            item.y;
            trackScale.xScale;
            return root.mapFromItem(item, -pad, -pad);
        }

        visible: root.flyingItem !== null
        sourceItem: root.flyingItem
        hideSource: true
        smooth: true
        mipmap: true
        sourceRect: root.flyingItem ? Qt.rect(-pad, -pad, root.flyingItem.width + pad * 2, root.flyingItem.height + pad * 2) : Qt.rect(0, 0, 0, 0)
        x: at.x
        y: at.y
        width: sourceRect.width * trackScale.xScale
        height: sourceRect.height * trackScale.yScale
    }
}
