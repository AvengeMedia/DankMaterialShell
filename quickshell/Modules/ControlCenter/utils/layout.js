function spanWidthFor(baseWidth, widgetWidth, spacing) {
    const w = widgetWidth || 50
    if (w <= 25)
        return (baseWidth - spacing * 3) / 4
    if (w <= 50)
        return (baseWidth - spacing) / 2
    if (w <= 75)
        return (baseWidth - spacing * 3) * 0.75 + spacing * 2
    return baseWidth
}

function widgetWidths(id) {
    switch (id) {
    case "wifi":
    case "bluetooth":
    case "audioOutput":
    case "audioInput":
        return [50, 100]
    default:
        return [25, 50, 100]
    }
}

function nearestWidgetWidth(id, requestedWidth, baseWidth, spacing) {
    const widths = widgetWidths(id)
    return widths.reduce((best, width) => {
        const distance = Math.abs(spanWidthFor(baseWidth, width, spacing) - requestedWidth)
        const bestDistance = Math.abs(spanWidthFor(baseWidth, best, spacing) - requestedWidth)
        return distance < bestDistance ? width : best
    }, widths[0])
}

function isCompactWidth(widgetWidth) {
    return (widgetWidth || 50) <= 25
}

function isSliderWidget(id) {
    return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider"
}

function computeSlots(widgets, order, baseWidth, spacing, rowSpacing, sliderHeight, normalHeight, mirror) {
    const slots = []
    let x = 0
    let y = 0
    let rowRight = 0
    let rowMaxH = 0
    let countInRow = 0

    for (let p = 0; p < order.length; p++) {
        const sourceIndex = order[p]
        const widget = widgets[sourceIndex]
        if (!widget)
            continue

        const itemW = spanWidthFor(baseWidth, widget.width, spacing)
        const itemH = isSliderWidget(widget.id || "") ? sliderHeight : normalHeight

        if (countInRow > 0 && (rowRight + spacing + itemW > baseWidth + 0.5)) {
            y += rowMaxH + rowSpacing
            rowRight = 0
            rowMaxH = 0
            countInRow = 0
        }

        x = countInRow === 0 ? 0 : rowRight + spacing
        slots[sourceIndex] = {
            "x": mirror ? baseWidth - x - itemW : x,
            "y": y,
            "w": itemW,
            "h": itemH
        }
        rowRight = x + itemW
        rowMaxH = Math.max(rowMaxH, itemH)
        countInRow++
    }

    return {
        "slots": slots,
        "totalHeight": y + rowMaxH
    }
}
