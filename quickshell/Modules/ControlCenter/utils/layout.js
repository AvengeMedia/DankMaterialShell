function spanWidthFor(baseWidth, widgetWidth, spacing) {
    const w = widgetWidth || 50
    if (w <= 25)
        return (baseWidth - spacing * 3) / 4
    if (w <= 50)
        return (baseWidth - spacing) / 2
    if (w <= 75)
        return (baseWidth - spacing * 2) * 0.75
    return baseWidth
}

function isSliderWidget(id) {
    return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider"
}

function computeSlots(widgets, order, baseWidth, spacing, rowSpacing, sliderHeight, normalHeight) {
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
            "x": x,
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

function slotContainingPoint(slots, order, px, py) {
    for (let p = 0; p < order.length; p++) {
        const s = slots[order[p]]
        if (!s)
            continue
        if (px >= s.x && px < s.x + s.w && py >= s.y && py < s.y + s.h)
            return p
    }
    return -1
}

function calculateRowsAndWidgets(controlCenterColumn, expandedSection, expandedWidgetIndex) {
    var rows = []
    var currentRow = []
    var currentWidth = 0
    var expandedRow = -1

    const widgets = SettingsData.controlCenterWidgets || []
    const baseWidth = controlCenterColumn.width
    const spacing = Theme.spacingS

    for (var i = 0; i < widgets.length; i++) {
        const widget = widgets[i]
        const widgetWidth = widget.width || 50

        var itemWidth
        if (widgetWidth <= 25) {
            itemWidth = (baseWidth - spacing * 3) / 4
        } else if (widgetWidth <= 50) {
            itemWidth = (baseWidth - spacing) / 2
        } else if (widgetWidth <= 75) {
            itemWidth = (baseWidth - spacing * 2) * 0.75
        } else {
            itemWidth = baseWidth
        }

        if (currentRow.length > 0 && (currentWidth + spacing + itemWidth > baseWidth)) {
            rows.push([...currentRow])
            currentRow = [widget]
            currentWidth = itemWidth
        } else {
            currentRow.push(widget)
            currentWidth += (currentRow.length > 1 ? spacing : 0) + itemWidth
        }

        if (expandedWidgetIndex === i) {
            expandedRow = rows.length
        }
    }

    if (currentRow.length > 0) {
        rows.push(currentRow)
    }

    return { rows: rows, expandedRowIndex: expandedRow }
}
