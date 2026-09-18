import QtQuick
import qs.Common
import qs.Modules.SurfaceWidgets

Item {
    id: root

    property real alongPos: 0
    property real alongSize: 0
    property real alongExtent: 0
    property real crossSize: 0
    property bool isVertical: false
    property bool crossFar: false
    property bool trailing: false
    property bool edgeAligned: false
    property real pad: 0
    property real cornerRadius: Theme.cornerRadius
    property real sweep: 0
    property bool gothEnabled: false
    property color fillColor: "transparent"

    readonly property real chromeAlongPos: edgeAligned && !trailing ? 0 : alongPos - pad
    readonly property real chromeAlongSize: alongSize <= 0 ? 0 : edgeAligned ? (trailing ? alongExtent - chromeAlongPos : alongPos + alongSize + pad) : alongSize + pad * 2
    readonly property real cornerR: Math.max(0, Math.min(cornerRadius, crossSize / 2))
    readonly property real sweepR: gothEnabled ? Math.max(0, Math.min(sweep, crossSize - cornerR, chromeAlongSize - cornerR)) : 0
    readonly property bool canonicalBottomEdge: !isVertical && crossFar
    readonly property bool canonicalRightSide: isVertical ? (crossFar ? trailing : !trailing) : trailing
    readonly property bool startAttached: edgeAligned && !canonicalRightSide
    readonly property bool endAttached: edgeAligned && canonicalRightSide
    readonly property alias body: body

    visible: chromeAlongSize > 0
    x: isVertical ? 0 : chromeAlongPos
    y: isVertical ? chromeAlongPos : 0
    width: isVertical ? crossSize : chromeAlongSize
    height: isVertical ? chromeAlongSize : crossSize

    Item {
        id: canvas

        anchors.centerIn: parent
        width: root.chromeAlongSize
        height: root.crossSize
        rotation: root.isVertical ? (root.crossFar ? 90 : -90) : 0
        transform: Scale {
            yScale: root.canonicalBottomEdge ? -1 : 1
            origin.y: canvas.height / 2
        }

        Rectangle {
            id: body
            anchors.fill: parent
            color: root.fillColor
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.startAttached ? 0 : root.cornerR
            bottomRightRadius: root.endAttached ? 0 : root.cornerR
        }

        GothCorner {
            visible: !root.startAttached && radius > 0
            radius: root.sweepR
            color: root.fillColor
            x: -radius
            y: 0
            corner: "bottomLeft"
        }

        GothCorner {
            visible: !root.endAttached && radius > 0
            radius: root.sweepR
            color: root.fillColor
            x: canvas.width
            y: 0
            corner: "bottomRight"
        }

        GothCorner {
            visible: root.startAttached && radius > 0
            radius: root.sweepR
            color: root.fillColor
            x: 0
            y: canvas.height
            corner: "bottomRight"
        }

        GothCorner {
            visible: root.endAttached && radius > 0
            radius: root.sweepR
            color: root.fillColor
            x: canvas.width - radius
            y: canvas.height
            corner: "bottomLeft"
        }
    }
}
