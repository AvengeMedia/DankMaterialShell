import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"
import "../Services"

PanelWindow {
    id: spotlightLauncher
    
    property bool spotlightOpen: false
    property var recentApps: []
    property var filteredApps: []
    property int selectedIndex: 0
    property int maxResults: 50
    property var categories: AppSearchService.getAllCategories().filter(cat => cat !== "Education" && cat !== "Science")
    property string selectedCategory: "All"
    property string viewMode: "list" // "list" or "grid"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: spotlightOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-spotlight"
    
    visible: spotlightOpen
    
    onVisibleChanged: {
        console.log("SpotlightLauncher visibility changed to:", visible)
    }
    color: "transparent"
    

    // ...existing code...
    function show() {
        console.log("SpotlightLauncher: show() called")
        spotlightOpen = true
        console.log("SpotlightLauncher: spotlightOpen set to", spotlightOpen)
        loadRecentApps()
        updateFilteredApps()
        Qt.callLater(function() {
            searchField.forceActiveFocus()
            searchField.selectAll()
        })
    }
    
    function hide() {
        spotlightOpen = false
        searchField.text = ""
        selectedIndex = 0
        selectedCategory = "All"
        updateFilteredApps()
    }
    
    function toggle() {
        if (spotlightOpen) {
            hide()
        } else {
            show()
        }
    }
    
    function loadRecentApps() {
        recentApps = PreferencesService.getRecentApps()
    }
    
    function updateFilteredApps() {
        filteredApps = []
        selectedIndex = 0
        
        var apps = []
        
        if (searchField.text.length === 0) {
            // Show recent apps first, then all apps from category
            if (selectedCategory === "All") {
                // For "All" category, show recent apps first, then all available apps
                var allApps = AppSearchService.applications || []
                var combined = []
                
                // Add recent apps first
                recentApps.forEach(recentApp => {
                    var found = allApps.find(app => app.exec === recentApp.exec)
                    if (found) {
                        combined.push(found)
                    }
                })
                
                // Add remaining apps not in recent
                var remaining = allApps.filter(app => {
                    return !recentApps.some(recentApp => recentApp.exec === app.exec)
                })
                
                combined = combined.concat(remaining)
                apps = combined // Show all apps for "All" category
            } else {
                // For specific categories, limit results
                var categoryApps = AppSearchService.getAppsInCategory(selectedCategory)
                var combined = []
                
                // Add recent apps first if they match category
                recentApps.forEach(recentApp => {
                    var found = categoryApps.find(app => app.exec === recentApp.exec)
                    if (found) {
                        combined.push(found)
                    }
                })
                
                // Add remaining apps not in recent
                var remaining = categoryApps.filter(app => {
                    return !recentApps.some(recentApp => recentApp.exec === app.exec)
                })
                
                combined = combined.concat(remaining)
                apps = combined.slice(0, maxResults)
            }
        } else {
            // Search with category filter
            var baseApps = selectedCategory === "All" ? 
                AppSearchService.applications : 
                AppSearchService.getAppsInCategory(selectedCategory)
            var searchResults = AppSearchService.searchApplications(searchField.text)
            
            if (selectedCategory === "All") {
                // For "All" category, show all search results without limit
                apps = searchResults.filter(app => baseApps.includes(app))
            } else {
                // For specific categories, still apply limit
                apps = searchResults.filter(app => baseApps.includes(app)).slice(0, maxResults)
            }
        }
        
        // Convert to our format
        filteredApps = apps.map(app => ({
            name: app.name,
            exec: app.execString || "",
            icon: app.icon || "application-x-executable",
            comment: app.comment || "",
            categories: app.categories || [],
            desktopEntry: app
        }))
        
        filteredModel.clear()
        filteredApps.forEach(app => filteredModel.append(app))
    }
    
    function launchApp(app) {
        PreferencesService.addRecentApp(app)
        if (app.desktopEntry) {
            AppSearchService.launchApp(app.desktopEntry)
        } else {
            var cleanExec = app.exec.replace(/%[fFuU]/g, "").trim()
            console.log("Spotlight: Launching app directly:", cleanExec)
            Quickshell.execDetached(["sh", "-c", cleanExec])
        }
        hide()
    }
    
    function selectNext() {
        if (filteredApps.length > 0) {
            if (viewMode === "grid") {
                // Grid navigation: move by columns (6 columns)
                var columnsCount = 6
                selectedIndex = Math.min(selectedIndex + columnsCount, filteredApps.length - 1)
            } else {
                // List navigation: next item
                selectedIndex = (selectedIndex + 1) % filteredApps.length
            }
        }
    }
    
    function selectPrevious() {
        if (filteredApps.length > 0) {
            if (viewMode === "grid") {
                // Grid navigation: move by columns (6 columns)
                var columnsCount = 6
                selectedIndex = Math.max(selectedIndex - columnsCount, 0)
            } else {
                // List navigation: previous item
                selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : filteredApps.length - 1
            }
        }
    }
    
    function selectNextInRow() {
        if (filteredApps.length > 0 && viewMode === "grid") {
            selectedIndex = Math.min(selectedIndex + 1, filteredApps.length - 1)
        }
    }
    
    function selectPreviousInRow() {
        if (filteredApps.length > 0 && viewMode === "grid") {
            selectedIndex = Math.max(selectedIndex - 1, 0)
        }
    }
    
    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            launchApp(filteredApps[selectedIndex])
        }
    }
    
    ListModel { id: filteredModel }

    Connections {
        target: AppSearchService
        function onReadyChanged() {
            if (AppSearchService.ready) {
                categories = AppSearchService.getAllCategories().filter(cat => cat !== "Education" && cat !== "Science")
                if (spotlightOpen) updateFilteredApps()
            }
        }
    }
    
    // Dimmed overlay background
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: spotlightOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
        MouseArea { anchors.fill: parent; enabled: spotlightOpen; onClicked: hide() }
    }
    
    // Main container with search and results
    Rectangle {
        id: mainContainer
        width: 600
        height: 650
        anchors.centerIn: parent
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusXLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        layer.enabled: true
        layer.effect: DropShadow { radius: 32; samples: 64; color: Qt.rgba(0,0,0,0.3); horizontalOffset:0; verticalOffset:8 }
        transform: Scale { origin.x: width/2; origin.y: height/2; xScale: spotlightOpen?1:0.9; yScale: spotlightOpen?1:0.9;
            Behavior on xScale { NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutBack; easing.overshoot:1.1 } }
            Behavior on yScale { NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutBack; easing.overshoot:1.1 } }
        }
        opacity: spotlightOpen?1:0
        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        Column {
            anchors.fill: parent; anchors.margins: Theme.spacingXL; spacing: Theme.spacingL
            
            // Combined row for categories and view mode toggle
            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: categories.length > 1 || filteredModel.count > 0
                
                // Categories organized in 2 rows: 4 + 5
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    
                    // Top row: All, Development, Graphics, Internet (4 items)
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        
                        property var topRowCategories: ["All", "Development", "Graphics", "Internet"]
                        
                        Repeater {
                            model: parent.topRowCategories.filter(cat => categories.includes(cat))
                            Rectangle { 
                                height: 36
                                width: (parent.width - (parent.topRowCategories.length - 1) * Theme.spacingS) / parent.topRowCategories.length
                                radius: Theme.cornerRadiusLarge
                                color: selectedCategory === modelData ? Theme.primary : "transparent"
                                border.color: selectedCategory === modelData ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                
                                Text { 
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: selectedCategory === modelData ? Theme.onPrimary : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }
                                
                                MouseArea { 
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { 
                                        selectedCategory = modelData
                                        updateFilteredApps() 
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bottom row: Media, Office, Settings, System, Utilities (5 items)
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        
                        property var bottomRowCategories: ["Media", "Office", "Settings", "System", "Utilities"]
                        
                        Repeater {
                            model: parent.bottomRowCategories.filter(cat => categories.includes(cat))
                            Rectangle { 
                                height: 36
                                width: (parent.width - (parent.bottomRowCategories.length - 1) * Theme.spacingS) / parent.bottomRowCategories.length
                                radius: Theme.cornerRadiusLarge
                                color: selectedCategory === modelData ? Theme.primary : "transparent"
                                border.color: selectedCategory === modelData ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                
                                Text { 
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: selectedCategory === modelData ? Theme.onPrimary : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }
                                
                                MouseArea { 
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { 
                                        selectedCategory = modelData
                                        updateFilteredApps() 
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Search field with view toggle buttons
            Row {
                width: parent.width
                spacing: Theme.spacingM
                
                Rectangle { 
                    id: searchContainer
                    width: parent.width - 80 - Theme.spacingM // Leave space for view toggle buttons
                    height: 56
                    radius: Theme.cornerRadiusLarge
                    color: Theme.surfaceVariant
                    border.width: searchField.activeFocus ? 2 : 1
                    border.color: searchField.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    Behavior on border.color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                    
                    Row { 
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingL
                        anchors.rightMargin: Theme.spacingL
                        spacing: Theme.spacingM
                        
                        Text { 
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: searchField.activeFocus ? Theme.primary : Theme.surfaceVariantText 
                        }
                        
                        TextInput { 
                            id: searchField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - parent.spacing - Theme.iconSize - 32
                            height: parent.height - Theme.spacingS
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            verticalAlignment: Text.AlignVCenter
                            focus: spotlightOpen
                            selectByMouse: true
                            onTextChanged: updateFilteredApps
                            Keys.onPressed: { 
                                if(event.key === Qt.Key_Escape) { hide(); event.accepted = true }
                                else if(event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { launchSelected(); event.accepted = true }
                                else if(event.key === Qt.Key_Down) { selectNext(); event.accepted = true }
                                else if(event.key === Qt.Key_Up) { selectPrevious(); event.accepted = true }
                                else if(event.key === Qt.Key_Right && viewMode === "grid") { selectNextInRow(); event.accepted = true }
                                else if(event.key === Qt.Key_Left && viewMode === "grid") { selectPreviousInRow(); event.accepted = true }
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: recentApps.length > 0 ? "Search applications or select from recent..." : "Search applications..."
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeLarge
                                visible: searchField.text.length === 0 && !searchField.activeFocus
                            }
                        }
                    }
                }
                
                // View mode toggle buttons next to search bar
                Row {
                    spacing: Theme.spacingXS
                    visible: filteredModel.count > 0
                    anchors.verticalCenter: parent.verticalCenter
                    
                    // List view button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: Theme.cornerRadiusLarge
                        color: viewMode === "list" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                              listViewArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08) : "transparent"
                        border.color: viewMode === "list" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                        border.width: 1
                        
                        Text {
                            anchors.centerIn: parent
                            text: "view_list"
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: viewMode === "list" ? Theme.primary : Theme.surfaceText
                        }
                        
                        MouseArea {
                            id: listViewArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: viewMode = "list"
                        }
                    }
                    
                    // Grid view button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: Theme.cornerRadiusLarge
                        color: viewMode === "grid" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                              gridViewArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08) : "transparent"
                        border.color: viewMode === "grid" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                        border.width: 1
                        
                        Text {
                            anchors.centerIn: parent
                            text: "grid_view"
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: viewMode === "grid" ? Theme.primary : Theme.surfaceText
                        }
                        
                        MouseArea {
                            id: gridViewArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: viewMode = "grid"
                        }
                    }
                }
            }
            
            // Results container
            Rectangle {
                id: resultsContainer
                width: parent.width
                height: Math.min(filteredModel.count * (viewMode === "grid" ? 100 : 60), 480)
                color: "transparent"
                
                // List view
                ListView { 
                    id: resultsList
                    anchors.fill: parent
                    visible: viewMode === "list"
                    model: filteredModel
                    currentIndex: selectedIndex
                    clip: true
                    focus: spotlightOpen
                    interactive: true
                    flickDeceleration: 8000
                    maximumFlickVelocity: 15000
                    
                    // Make mouse wheel scrolling more responsive
                    property real wheelStepSize: 60
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        
                        onWheel: (wheel) => {
                            var delta = wheel.angleDelta.y
                            var steps = delta / 120  // Standard wheel step
                            resultsList.contentY -= steps * resultsList.wheelStepSize
                            
                            // Ensure we stay within bounds
                            if (resultsList.contentY < 0) {
                                resultsList.contentY = 0
                            } else if (resultsList.contentY > resultsList.contentHeight - resultsList.height) {
                                resultsList.contentY = Math.max(0, resultsList.contentHeight - resultsList.height)
                            }
                        }
                    }
                    
                    delegate: Rectangle { 
                        width: parent.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: ListView.isCurrentItem ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                               listMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent"
                        
                        Row { 
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingL
                            
                            Rectangle { 
                                width: 40
                                height: 40
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                                
                                IconImage { 
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: model.icon ? Quickshell.iconPath(model.icon, "") : ""
                                }
                            }
                            
                            Column { 
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                
                                Text { 
                                    text: model.name
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                
                                Text { 
                                    text: model.comment
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    visible: model.comment && model.comment.length > 0
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        MouseArea { 
                            id: listMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: selectedIndex = index
                            onClicked: launchApp(model)
                        }
                    }
                    
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }
                }
                
                // Grid view
                GridView {
                    id: resultsGrid
                    // Center the grid within the parent space
                    anchors.centerIn: parent
                    width: Math.min(parent.width, baseCellWidth * 6 + 16) // Optimal width for 6 columns plus spacing
                    height: parent.height
                    visible: viewMode === "grid"
                    model: filteredModel
                    clip: true
                    focus: spotlightOpen
                    interactive: true
                    flickDeceleration: 8000
                    maximumFlickVelocity: 15000
                    
                    // Optimized cell sizes for maximum space efficiency - 6 columns
                    property int baseCellWidth: Math.max(85, Math.min(100, width / 6))
                    property int baseCellHeight: baseCellWidth + 30
                    
                    cellWidth: baseCellWidth
                    cellHeight: baseCellHeight
                    
                    // Use full width with minimal 2px right margin for scrollbar
                    leftMargin: 0
                    rightMargin: 2
                    topMargin: Theme.spacingXS
                    bottomMargin: Theme.spacingXS
                    
                    // Make mouse wheel scrolling more responsive
                    property real wheelStepSize: 60
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        
                        onWheel: (wheel) => {
                            var delta = wheel.angleDelta.y
                            var steps = delta / 120  // Standard wheel step
                            resultsGrid.contentY -= steps * resultsGrid.wheelStepSize
                            
                            // Ensure we stay within bounds
                            if (resultsGrid.contentY < 0) {
                                resultsGrid.contentY = 0
                            } else if (resultsGrid.contentY > resultsGrid.contentHeight - resultsGrid.height) {
                                resultsGrid.contentY = Math.max(0, resultsGrid.contentHeight - resultsGrid.height)
                            }
                        }
                    }
                    
                    delegate: Rectangle {
                        width: resultsGrid.cellWidth - 8
                        height: resultsGrid.cellHeight - 8
                        radius: Theme.cornerRadius
                        color: selectedIndex === index ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                               gridMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent"
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            
                            Item {
                                property int iconSize: Math.min(48, Math.max(32, resultsGrid.cellWidth * 0.55))
                                width: iconSize
                                height: iconSize
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                    border.width: 1
                                    
                                    IconImage {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: model.icon ? Quickshell.iconPath(model.icon, "") : ""
                                    }
                                }
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: resultsGrid.cellWidth - 16
                                text: model.name
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        
                        MouseArea {
                            id: gridMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: selectedIndex = index
                            onClicked: launchApp(model)
                        }
                    }
                    
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }
        }
    }

    IpcHandler {
        target: "spotlight"
        function open() {
            console.log("SpotlightLauncher: IPC open() called")
            spotlightLauncher.show()
            return "SPOTLIGHT_OPEN_SUCCESS"
        }
        function close() {
            console.log("SpotlightLauncher: IPC close() called")
            spotlightLauncher.hide()
            return "SPOTLIGHT_CLOSE_SUCCESS"
        }
        function toggle() {
            console.log("SpotlightLauncher: IPC toggle() called")
            spotlightLauncher.toggle()
            return "SPOTLIGHT_TOGGLE_SUCCESS"
        }
    }

    Component.onCompleted: {
        console.log("SpotlightLauncher: Component.onCompleted called - component loaded successfully!")
        if (AppSearchService.ready) {
            categories = AppSearchService.getAllCategories().filter(cat => cat !== "Education" && cat !== "Science")
        }
    }
}