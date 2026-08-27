import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services

Item {
    id: root

    property bool rightSide: false
    property bool bottomEdge: false
    property bool floating: false
    property color fillColor: "transparent"
    property bool gothEnabled: true
    property real sweep: 24
    property real bodyRadius: Theme.cornerRadius
    property var parentScreen: null

    readonly property real cornerR: Math.max(0, Math.min(root.bodyRadius, root.height / 2))
    readonly property real sweepR: root.gothEnabled ? Math.max(0, Math.min(root.sweep, root.height - root.cornerR, root.width - root.cornerR)) : 0

    readonly property string fillPath: {
        root.width;
        root.height;
        root.cornerR;
        root.sweepR;
        root.rightSide;
        root.bottomEdge;
        root.floating;
        return root.buildPath();
    }

    function buildPath() {
        const w = root.width;
        const h = root.height;
        const cr = root.cornerR;
        const s = root.sweepR;
        if (root.floating)
            return root.bottomEdge ? floatBottomPath(w, h, cr, s) : floatTopPath(w, h, cr, s);
        if (root.bottomEdge)
            return root.rightSide ? rightBottomPath(w, h, cr, s) : leftBottomPath(w, h, cr, s);
        return root.rightSide ? rightTopPath(w, h, cr, s) : leftTopPath(w, h, cr, s);
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
