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
