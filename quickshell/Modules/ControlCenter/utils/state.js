function setTriggerPosition(root, x, y, width, section, screen) {
    root.triggerX = x
    root.triggerY = y
    root.triggerWidth = width
    root.triggerSection = section
    root.triggerScreen = screen
}

function openWithSection(root, section) {
    if (root.shouldBeVisible) {
        root.close()
    } else {
        root.expandedSection = section
        root.open()
    }
}

function toggleSection(root, section) {
    if (root.expandedSection === section) {
        root.expandedSection = ""
        root.expandedWidgetIndex = -1
    } else {
        root.expandedSection = section
    }
}
