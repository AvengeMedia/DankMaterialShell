.pragma library

// Geometry for connected-frame arc connectors.
// `barSide` is one of "top" | "bottom" | "left" | "right" — the edge where the
// host bar/dock sits. `placement` is "left" (start) or "right" (end) of the
// body's far edge. `radius` is the connector's arc radius. `spacing` is the
// gap between the host edge and the body.

function isVertical(barSide) {
    return barSide === "left" || barSide === "right";
}

function isHorizontal(barSide) {
    return barSide === "top" || barSide === "bottom";
}

function connectorWidth(barSide, spacing, radius) {
    return isVertical(barSide) ? (spacing + radius) : radius;
}

function connectorHeight(barSide, spacing, radius) {
    return isVertical(barSide) ? radius : (spacing + radius);
}

function seamX(barSide, baseX, bodyWidth, placement) {
    if (!isVertical(barSide))
        return placement === "left" ? baseX : baseX + bodyWidth;
    return barSide === "left" ? baseX : baseX + bodyWidth;
}

function seamY(barSide, baseY, bodyHeight, placement) {
    if (barSide === "top")
        return baseY;
    if (barSide === "bottom")
        return baseY + bodyHeight;
    return placement === "left" ? baseY : baseY + bodyHeight;
}

function connectorX(barSide, baseX, bodyWidth, placement, spacing, radius) {
    var s = seamX(barSide, baseX, bodyWidth, placement);
    var w = connectorWidth(barSide, spacing, radius);
    if (!isVertical(barSide))
        return placement === "left" ? s - w : s;
    return barSide === "left" ? s : s - w;
}

function connectorY(barSide, baseY, bodyHeight, placement, spacing, radius) {
    var s = seamY(barSide, baseY, bodyHeight, placement);
    var h = connectorHeight(barSide, spacing, radius);
    if (barSide === "top")
        return s;
    if (barSide === "bottom")
        return s - h;
    return placement === "left" ? s - h : s;
}

// Which corner of the connector's bounding rect hosts the concave arc that
// carves into the body. Used for arc-sweep orientation.
function arcCorner(barSide, placement) {
    var left = placement === "left";
    if (barSide === "top")
        return left ? "bottomLeft" : "bottomRight";
    if (barSide === "bottom")
        return left ? "topLeft" : "topRight";
    if (barSide === "left")
        return left ? "topRight" : "bottomRight";
    return left ? "topLeft" : "bottomLeft";
}
