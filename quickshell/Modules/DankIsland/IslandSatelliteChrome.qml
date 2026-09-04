import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services

Item {
    id: root

    property bool rightSide: false
    property bool crossFar: false
    property bool isVertical: false
    property bool floating: false
    property color fillColor: "transparent"
    property bool gothEnabled: true
    property real sweep: 24
    property real bodyRadius: Theme.cornerRadius
    property var parentScreen: null

    readonly property real alongSize: root.isVertical ? root.height : root.width
    readonly property real crossSize: root.isVertical ? root.width : root.height
    readonly property real cornerR: Math.max(0, Math.min(root.bodyRadius, root.crossSize / 2))
    readonly property real sweepR: root.gothEnabled ? Math.max(0, Math.min(root.sweep, root.crossSize - root.cornerR, root.alongSize - root.cornerR)) : 0

    // Paths are authored once for a top-edge horizontal strip and rotated into place, so
    // "bottomEdge"/"rightSide" below are canonical, not screen, directions.
    readonly property bool canonicalBottomEdge: root.isVertical ? false : root.crossFar
    readonly property bool canonicalRightSide: root.isVertical ? (root.crossFar ? root.rightSide : !root.rightSide) : root.rightSide

    readonly property string fillPath: {
        root.alongSize;
        root.crossSize;
        root.cornerR;
        root.sweepR;
        root.canonicalRightSide;
        root.canonicalBottomEdge;
        root.floating;
        return root.buildPath();
    }

    function buildPath() {
        const w = root.alongSize;
        const h = root.crossSize;
        const cr = root.cornerR;
        const s = root.sweepR;
        if (root.floating)
            return root.canonicalBottomEdge ? floatBottomPath(w, h, cr, s) : floatTopPath(w, h, cr, s);
        if (root.canonicalBottomEdge)
            return root.canonicalRightSide ? rightBottomPath(w, h, cr, s) : leftBottomPath(w, h, cr, s);
        return root.canonicalRightSide ? rightTopPath(w, h, cr, s) : leftTopPath(w, h, cr, s);
    }

    function floatTopPath(w, h, cr, s) {
        if (s > 0)
            return `M ${-s} 0 A ${s} ${s} 0 0 1 0 ${s} L 0 ${h - cr} A ${cr} ${cr} 0 0 0 ${cr} ${h} L ${w - cr} ${h} A ${cr} ${cr} 0 0 0 ${w} ${h - cr} L ${w} ${s} A ${s} ${s} 0 0 1 ${w + s} 0 Z`;
        return `M 0 0 L ${w} 0 L ${w} ${h - cr} A ${cr} ${cr} 0 0 1 ${w - cr} ${h} L ${cr} ${h} A ${cr} ${cr} 0 0 1 0 ${h - cr} Z`;
    }

    function floatBottomPath(w, h, cr, s) {
        if (s > 0)
            return `M ${-s} ${h} A ${s} ${s} 0 0 0 0 ${h - s} L 0 ${cr} A ${cr} ${cr} 0 0 1 ${cr} 0 L ${w - cr} 0 A ${cr} ${cr} 0 0 1 ${w} ${cr} L ${w} ${h - s} A ${s} ${s} 0 0 0 ${w + s} ${h} Z`;
        return `M 0 ${h} L ${w} ${h} L ${w} ${cr} A ${cr} ${cr} 0 0 0 ${w - cr} 0 L ${cr} 0 A ${cr} ${cr} 0 0 0 0 ${cr} Z`;
    }

    function leftTopPath(w, h, cr, s) {
        if (s > 0)
            return `M 0 0 L ${w + s} 0 A ${s} ${s} 0 0 0 ${w} ${s} L ${w} ${h - cr} A ${cr} ${cr} 0 0 1 ${w - cr} ${h} L ${s} ${h} A ${s} ${s} 0 0 0 0 ${h + s} Z`;
        return `M 0 0 L ${w} 0 L ${w} ${h - cr} A ${cr} ${cr} 0 0 1 ${w - cr} ${h} L ${cr} ${h} A ${cr} ${cr} 0 0 1 0 ${h - cr} Z`;
    }

    function rightTopPath(w, h, cr, s) {
        if (s > 0)
            return `M ${w} 0 L ${-s} 0 A ${s} ${s} 0 0 1 0 ${s} L 0 ${h - cr} A ${cr} ${cr} 0 0 0 ${cr} ${h} L ${w - s} ${h} A ${s} ${s} 0 0 1 ${w} ${h + s} Z`;
        return `M ${w} 0 L 0 0 L 0 ${h - cr} A ${cr} ${cr} 0 0 0 ${cr} ${h} L ${w - cr} ${h} A ${cr} ${cr} 0 0 0 ${w} ${h - cr} Z`;
    }

    function leftBottomPath(w, h, cr, s) {
        if (s > 0)
            return `M 0 ${h} L ${w + s} ${h} A ${s} ${s} 0 0 1 ${w} ${h - s} L ${w} ${cr} A ${cr} ${cr} 0 0 0 ${w - cr} 0 L ${s} 0 A ${s} ${s} 0 0 1 0 ${-s} Z`;
        return `M 0 ${h} L ${w} ${h} L ${w} ${cr} A ${cr} ${cr} 0 0 0 ${w - cr} 0 L ${cr} 0 A ${cr} ${cr} 0 0 0 0 ${cr} Z`;
    }

    function rightBottomPath(w, h, cr, s) {
        if (s > 0)
            return `M ${w} ${h} L ${-s} ${h} A ${s} ${s} 0 0 0 0 ${h - s} L 0 ${cr} A ${cr} ${cr} 0 0 1 ${cr} 0 L ${w - s} 0 A ${s} ${s} 0 0 0 ${w} ${-s} Z`;
        return `M ${w} ${h} L 0 ${h} L 0 ${cr} A ${cr} ${cr} 0 0 1 ${cr} 0 L ${w - cr} 0 A ${cr} ${cr} 0 0 1 ${w} ${cr} Z`;
    }

    // Canonical (along, cross) rect to item-local coordinates, matching the canvas rotation.
    function localRect(cx, cy, cw, ch) {
        if (!root.isVertical)
            return Qt.rect(cx, cy, cw, ch);
        if (root.crossFar)
            return Qt.rect(root.crossSize - cy - ch, cx, ch, cw);
        return Qt.rect(cy, root.alongSize - cx - cw, ch, cw);
    }

    readonly property real canonicalEdgeCross: root.canonicalBottomEdge ? root.crossSize - root.cornerR : 0
    readonly property real canonicalSweepCross: root.canonicalBottomEdge ? 0 : root.crossSize - root.cornerR
    readonly property bool sweepSquared: !root.floating && root.sweepR > 0

    // The chrome paints square corners where it meets the screen edge (and above the sweep in
    // edge mode); the blur regions have to square the same ones off.
    readonly property rect leadCornerSquare: root.localRect(0, root.canonicalEdgeCross, root.cornerR, root.cornerR)
    readonly property rect trailCornerSquare: root.localRect(root.alongSize - root.cornerR, root.canonicalEdgeCross, root.cornerR, root.cornerR)
    readonly property rect sweepCornerSquare: root.sweepSquared ? root.localRect(root.canonicalRightSide ? root.alongSize - root.cornerR : 0, root.canonicalSweepCross, root.cornerR, root.cornerR) : Qt.rect(0, 0, 0, 0)

    function sweepPieceOrigin(isWing) {
        const s = root.sweepR;
        if (root.floating)
            return [isWing ? -s : root.alongSize, root.canonicalBottomEdge ? root.crossSize - s : 0];
        if (isWing)
            return [root.canonicalRightSide ? root.alongSize - s : 0, root.canonicalBottomEdge ? -s : root.crossSize];
        return [root.canonicalRightSide ? -s : root.alongSize, root.canonicalBottomEdge ? root.crossSize - s : 0];
    }

    function sweepPieceRect(isWing) {
        const origin = root.sweepPieceOrigin(isWing);
        return root.localRect(origin[0], origin[1], root.sweepR, root.sweepR);
    }

    // The fillet is that square minus a quarter disc; this is the disc's bounding box.
    function sweepDiscRect(isWing) {
        const s = root.sweepR;
        const leadsIn = root.floating ? isWing : root.canonicalRightSide;
        const origin = root.sweepPieceOrigin(isWing);
        return root.localRect(origin[0] - (leadsIn ? s : 0), origin[1] - (root.canonicalBottomEdge ? s : 0), s * 2, s * 2);
    }

    readonly property rect sweepBodyRect: root.sweepR > 0 ? root.sweepPieceRect(false) : Qt.rect(0, 0, 0, 0)
    readonly property rect sweepBodyDisc: root.sweepR > 0 ? root.sweepDiscRect(false) : Qt.rect(0, 0, 0, 0)
    readonly property rect sweepWingRect: root.sweepR > 0 ? root.sweepPieceRect(true) : Qt.rect(0, 0, 0, 0)
    readonly property rect sweepWingDisc: root.sweepR > 0 ? root.sweepDiscRect(true) : Qt.rect(0, 0, 0, 0)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: {
            const activePopout = PopoutManager.getActivePopout(root.parentScreen);
            if (activePopout) {
                if (activePopout.dashVisible !== undefined) {
                    activePopout.dashVisible = false;
                } else if (activePopout.notificationHistoryVisible !== undefined) {
                    activePopout.notificationHistoryVisible = false;
                } else {
                    activePopout.close();
                }
            }
            TrayMenuManager.closeAllMenus();
        }
    }

    Item {
        id: canvas

        anchors.centerIn: parent
        width: root.alongSize
        height: root.crossSize
        rotation: root.isVertical ? (root.crossFar ? 90 : -90) : 0

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.fillColor
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: root.fillPath
                }
            }
        }
    }
}
