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
    property int maxResults: 12
    property var categories: AppSearchService.getAllCategories()
    property string selectedCategory: "All"
    
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
        } else {
            // Search with category filter
            var baseApps = selectedCategory === "All" ? 
                AppSearchService.applications : 
                AppSearchService.getAppsInCategory(selectedCategory)
            var searchResults = AppSearchService.searchApplications(searchField.text)
            apps = searchResults.filter(app => baseApps.includes(app)).slice(0, maxResults)
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
            selectedIndex = (selectedIndex + 1) % filteredApps.length
        }
    }
    
    function selectPrevious() {
        if (filteredApps.length > 0) {
            selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : filteredApps.length - 1
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
                categories = AppSearchService.getAllCategories()
                if (spotlightOpen) {
                    updateFilteredApps()
                }
            }
        }
    }
    
    
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: spotlightOpen ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: spotlightOpen
            onClicked: hide()
        }
    }
    
    Rectangle {
        id: mainContainer
        
        width: 600
        height: Math.min(600, categoryFlow.height + (categoryFlow.visible ? Theme.spacingL : 0) + searchContainer.height + resultsList.height + Theme.spacingXL * 2 + Theme.spacingL)
        
        anchors.centerIn: parent
        
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusXLarge
        
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        
        transform: Scale {
            origin.x: mainContainer.width / 2
            origin.y: mainContainer.height / 2
            xScale: spotlightOpen ? 1.0 : 0.9
            yScale: spotlightOpen ? 1.0 : 0.9
            
            Behavior on xScale {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }
            
            Behavior on yScale {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }
        }
        
        opacity: spotlightOpen ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 32
            samples: 64
            color: Qt.rgba(0, 0, 0, 0.3)
            horizontalOffset: 0
            verticalOffset: 8
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL
            
            // Category selector
            Flow {
                id: categoryFlow
                width: parent.width
                height: categories.length > 1 ? implicitHeight : 0
                visible: categories.length > 1
                spacing: Theme.spacingM
                
                Repeater {
                    model: categories
                    
                    Rectangle {
                        height: 32
                        width: Math.min(categoryText.implicitWidth + Theme.spacingL * 2, parent.width - Theme.spacingM)
                        radius: Theme.cornerRadius
                        color: selectedCategory === modelData ? Theme.primary : "transparent"
                        border.color: selectedCategory === modelData ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        border.width: 1
                        
                        Text {
                            id: categoryText
                            anchors.centerIn: parent
                            text: modelData
                            color: selectedCategory === modelData ? Theme.onPrimary : Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - Theme.spacingS * 2)
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
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                id: searchContainer
                width: parent.width
                height: 56
                radius: Theme.cornerRadiusLarge
                color: Theme.surfaceVariant
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? Theme.primary : 
                              Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                
                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
                
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
                        font.weight: Theme.iconFontWeight
                    }
                    
                    TextInput {
                        id: searchField
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - parent.spacing - Theme.iconSize - 32
                        height: parent.height - Theme.spacingS
                        
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeLarge
                        verticalAlignment: TextInput.AlignVCenter
                        
                        focus: spotlightOpen
                        selectByMouse: true
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: searchField.text.length === 0 ? (recentApps.length > 0 ? "Search applications or select from recent..." : "Search applications...") : ""
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeLarge
                            visible: searchField.text.length === 0 && !searchField.activeFocus
                        }
                        
                        onTextChanged: {
                            updateFilteredApps()
                        }
                        
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                hide()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                launchSelected()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                selectNext()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                selectPrevious()
                                event.accepted = true
                            }
                        }
                    }
                }
            }
            
            Column {
                id: resultsList
                width: parent.width
                height: filteredApps.length > 0 ? Math.min(filteredApps.length * 60, 320) : 0
                
                visible: filteredApps.length > 0
                
                Repeater {
                    model: filteredModel
                    
                    Rectangle {
                        width: resultsList.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: index === selectedIndex ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                               appMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : 
                               "transparent"
                        
                        border.color: index === selectedIndex ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                        border.width: index === selectedIndex ? 1 : 0
                        
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
                                    id: appIcon
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: model.icon ? Quickshell.iconPath(model.icon, "") : ""
                                    smooth: true
                                    asynchronous: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error || status === Image.Null) {
                                            fallbackText.visible = true
                                        } else {
                                            fallbackText.visible = false
                                        }
                                    }
                                }
                                
                                Text {
                                    id: fallbackText
                                    anchors.centerIn: parent
                                    text: model.name ? model.name.charAt(0).toUpperCase() : "A"
                                    font.pixelSize: 18
                                    color: Theme.primary
                                    font.weight: Font.Bold
                                    visible: false
                                }
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 40 - Theme.spacingL
                                spacing: 2
                                
                                Text {
                                    width: parent.width
                                    text: model.name
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    width: parent.width
                                    text: model.comment || "Application"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    visible: model.comment && model.comment.length > 0
                                }
                            }
                        }
                        
                        MouseArea {
                            id: appMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onEntered: {
                                selectedIndex = index
                            }
                            
                            onClicked: {
                                launchApp(model)
                            }
                        }
                    }
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
            categories = AppSearchService.getAllCategories()
        }
    }
}