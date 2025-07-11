import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"

// Fixed version – icon loaders now swap to fallback components instead of showing the magenta checkerboard
PanelWindow {
    id: launcher
    
    property var theme
    property bool isVisible: false
    
    // Default theme fallback
    property var defaultTheme: QtObject {
        property color primary: "#D0BCFF"
        property color background: "#10121E"
        property color surfaceContainer: "#1D1B20"
        property color surfaceText: "#E6E0E9"
        property color surfaceVariant: "#49454F"
        property color surfaceVariantText: "#CAC4D0"
        property color outline: "#938F99"
        property real cornerRadius: 12
        property real cornerRadiusLarge: 16
        property real cornerRadiusXLarge: 24
        property real spacingXS: 4
        property real spacingS: 8
        property real spacingM: 12
        property real spacingL: 16
        property real spacingXL: 24
        property real fontSizeLarge: 16
        property real fontSizeMedium: 14
        property real fontSizeSmall: 12
        property real iconSize: 24
        property real iconSizeLarge: 32
        property real barHeight: 48
        property string iconFont: "Material Symbols Rounded"
        property int iconFontWeight: Font.Normal
        property int shortDuration: 150
        property int mediumDuration: 300
        property int standardEasing: Easing.OutCubic
        property int emphasizedEasing: Easing.OutQuart
    }
    
    property var activeTheme: theme || defaultTheme
    
    // Full screen overlay setup for proper focus
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Proper layer shell configuration
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-launcher"
    
    visible: isVisible
    color: "transparent"
    
    // Enhanced app management
    property var currentApp: ({})
    property var allApps: []
    property var categories: ["All"]
    property string selectedCategory: "All"
    property var recentApps: []
    property var pinnedApps: ["firefox", "code", "terminal", "file-manager"]
    property bool showCategories: false
    property string viewMode: "list" // "list" or "grid"
    property var appCategories: ({
        "AudioVideo": "Media",
        "Audio": "Media", 
        "Video": "Media",
        "Development": "Development",
        "TextEditor": "Development",
        "IDE": "Development",
        "Programming": "Development",
        "Education": "Education", 
        "Game": "Games",
        "Graphics": "Graphics",
        "Photography": "Graphics",
        "Network": "Internet",
        "WebBrowser": "Internet",
        "Office": "Office",
        "WordProcessor": "Office",
        "Spreadsheet": "Office",
        "Presentation": "Office",
        "Science": "Science",
        "Settings": "Settings",
        "System": "System",
        "Utility": "Utilities",
        "Accessories": "Utilities",
        "FileManager": "Utilities",
        "TerminalEmulator": "Utilities"
    })
    
    ListModel { id: filteredModel }
    ListModel { id: categoryModel }
    
    // Background dim with click to close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: launcher.isVisible ? 1.0 : 0.0
        visible: launcher.isVisible
        
        Behavior on opacity {
            NumberAnimation {
                duration: activeTheme.shortDuration
                easing.type: activeTheme.standardEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: launcher.isVisible
            onClicked: launcher.hide()
        }
    }
    
    // Desktop applications scanning
    Process {
        id: desktopScanner
        command: ["sh", "-c", `
            for dir in "/usr/share/applications/" "/usr/local/share/applications/" "$HOME/.local/share/applications/" "/run/current-system/sw/share/applications/"; do
                if [ -d "$dir" ]; then
                    find "$dir" -name "*.desktop" 2>/dev/null | while read file; do
                        echo "===FILE:$file"
                        sed -n '/^\\[Desktop Entry\\]/,/^\\[.*\\]/{/^\\[Desktop Entry\\]/d; /^\\[.*\\]/q; /^Name=/p; /^Exec=/p; /^Icon=/p; /^Hidden=/p; /^NoDisplay=/p; /^Categories=/p; /^Comment=/p}' "$file" 2>/dev/null || true
                    done
                fi
            done
        `]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line.startsWith("===FILE:")) {
                    // Save previous app if valid
                    if (currentApp.name && currentApp.exec && !currentApp.hidden && !currentApp.noDisplay) {
                        allApps.push({
                            name: currentApp.name,
                            exec: currentApp.exec,
                            icon: currentApp.icon || "application-x-executable",
                            comment: currentApp.comment || "",
                            categories: currentApp.categories || []
                        })
                    }
                    // Start new app
                    currentApp = { name: "", exec: "", icon: "", comment: "", categories: [], hidden: false, noDisplay: false }
                } else if (line.startsWith("Name=")) {
                    currentApp.name = line.substring(5)
                } else if (line.startsWith("Exec=")) {
                    currentApp.exec = line.substring(5)
                } else if (line.startsWith("Icon=")) {
                    currentApp.icon = line.substring(5)
                } else if (line.startsWith("Comment=")) {
                    currentApp.comment = line.substring(8)
                } else if (line.startsWith("Categories=")) {
                    currentApp.categories = line.substring(11).split(";").filter(cat => cat.length > 0)
                } else if (line === "Hidden=true") {
                    currentApp.hidden = true
                } else if (line === "NoDisplay=true") {
                    currentApp.noDisplay = true
                }
            }
        }
        
        onExited: {
            // Save last app
            if (currentApp.name && currentApp.exec && !currentApp.hidden && !currentApp.noDisplay) {
                allApps.push({
                    name: currentApp.name,
                    exec: currentApp.exec,
                    icon: currentApp.icon || "application-x-executable",
                    comment: currentApp.comment || "",
                    categories: currentApp.categories || []
                })
            }
            
            // Extract unique categories
            let uniqueCategories = new Set(["All"])
            allApps.forEach(app => {
                app.categories.forEach(cat => {
                    if (appCategories[cat]) {
                        uniqueCategories.add(appCategories[cat])
                    }
                })
            })
            categories = Array.from(uniqueCategories)
            
            console.log("Loaded", allApps.length, "applications with", categories.length, "categories")
            updateFilteredModel()
        }
    }
    
    function updateFilteredModel() {
        filteredModel.clear()
        
        let apps = allApps
        
        // Filter by category
        if (selectedCategory !== "All") {
            apps = apps.filter(app => {
                return app.categories.some(cat => appCategories[cat] === selectedCategory)
            })
        }
        
        // Filter by search
        if (searchField.text.length > 0) {
            const query = searchField.text.toLowerCase()
            apps = apps.filter(app => {
                return app.name.toLowerCase().includes(query) || 
                       (app.comment && app.comment.toLowerCase().includes(query))
            }).sort((a, b) => {
                // Sort by relevance
                const aName = a.name.toLowerCase()
                const bName = b.name.toLowerCase()
                const aStartsWith = aName.startsWith(query)
                const bStartsWith = bName.startsWith(query)
                
                if (aStartsWith && !bStartsWith) return -1
                if (!aStartsWith && bStartsWith) return 1
                return aName.localeCompare(bName)
            })
        }
        
        // Sort alphabetically if no search
        if (searchField.text.length === 0) {
            apps.sort((a, b) => a.name.localeCompare(b.name))
        }
        
        // Add to model
        apps.forEach(app => {
            filteredModel.append(app)
        })
    }

    /* ----------------------------------------------------------------------------
     *  LOADER UTILITIES
     * ---------------------------------------------------------------------------- */
    /** Returns an IconImage component or the fallback badge depending on availability. */
    function makeIconLoader(iconName, appName, fallbackId) {
        return Qt.createComponent("", {
            "anchors.fill": parent,
            "_iconName": iconName,
            "_appName": appName,
            "sourceComponent": iconComponent
        })
    }

    Component {
        id: iconComponent
        IconImage {
            id: img
            anchors.fill: parent
            source: _iconName ? Quickshell.iconPath(_iconName, "") : ""
            smooth: true
            asynchronous: true
            
            onStatusChanged: {
                // Image.Null = 0, Image.Ready = 1, Image.Loading = 2, Image.Error = 3
                if (status === Image.Error || 
                    status === Image.Null || 
                    (!source && _iconName)) {
                    // defer the swap to avoid re‑entrancy in Loader
                    Qt.callLater(() => img.parent.sourceComponent = fallbackComponent)
                }
            }
            
            // Add timeout fallback for stuck loading icons
            Timer {
                interval: 3000  // 3 second timeout
                running: img.status === Image.Loading
                onTriggered: {
                    if (img.status === Image.Loading) {
                        Qt.callLater(() => img.parent.sourceComponent = fallbackComponent)
                    }
                }
            }
        }
    }

    Component {
        id: fallbackComponent
        Rectangle {
            color: Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.10)
            radius: activeTheme.cornerRadiusLarge
            border.width: 1
            border.color: Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.20)

            Text {
                anchors.centerIn: parent
                text: _appName ? _appName.charAt(0).toUpperCase() : "A"
                font.pixelSize: 28
                color: activeTheme.primary
                font.weight: Font.Bold
            }
        }
    }

    // Main launcher panel with enhanced design
    Rectangle {
        id: launcherPanel
        
        width: 520
        height: 600
        
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 50
            leftMargin: activeTheme.spacingL
        }
        
        color: Qt.rgba(activeTheme.surfaceContainer.r, activeTheme.surfaceContainer.g, activeTheme.surfaceContainer.b, 0.98)
        radius: activeTheme.cornerRadiusXLarge
        
        // Material 3 elevation with multiple layers
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            color: "transparent"
            radius: parent.radius + 3
            border.color: Qt.rgba(0, 0, 0, 0.05)
            border.width: 1
            z: -3
        }
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            radius: parent.radius + 2
            border.color: Qt.rgba(0, 0, 0, 0.08)
            border.width: 1
            z: -2
        }
        
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.12)
            border.width: 1
            radius: parent.radius
            z: -1
        }
        
        // Animated entrance with spring effect
        transform: [
            Scale {
                id: scaleTransform
                origin.x: 0
                origin.y: 0
                xScale: launcher.isVisible ? 1.0 : 0.92
                yScale: launcher.isVisible ? 1.0 : 0.92
                
                Behavior on xScale {
                    NumberAnimation {
                        duration: activeTheme.mediumDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
                
                Behavior on yScale {
                    NumberAnimation {
                        duration: activeTheme.mediumDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
            },
            Translate {
                id: translateTransform
                x: launcher.isVisible ? 0 : -30
                y: launcher.isVisible ? 0 : -15
                
                Behavior on x {
                    NumberAnimation {
                        duration: activeTheme.mediumDuration
                        easing.type: activeTheme.emphasizedEasing
                    }
                }
                
                Behavior on y {
                    NumberAnimation {
                        duration: activeTheme.mediumDuration
                        easing.type: activeTheme.emphasizedEasing
                    }
                }
            }
        ]
        
        opacity: launcher.isVisible ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: activeTheme.mediumDuration
                easing.type: activeTheme.emphasizedEasing
            }
        }
        
        // Content with focus management
        Item {
            anchors.fill: parent
            focus: true
            
            // Handle keyboard shortcuts
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    launcher.hide()
                    event.accepted = true
                }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: activeTheme.spacingXL
                spacing: activeTheme.spacingL
                
                // Header section
                Row {
                    width: parent.width
                    height: 40
                    
                    // App launcher title
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Applications"
                        font.pixelSize: activeTheme.fontSizeLarge + 4
                        font.weight: Font.Bold
                        color: activeTheme.surfaceText
                    }
                    
                    Item { width: parent.width - 200; height: 1 }
                    
                    // Quick stats
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: filteredModel.count + " apps"
                        font.pixelSize: activeTheme.fontSizeMedium
                        color: activeTheme.surfaceVariantText
                    }
                }
                
                // Enhanced search field
                Rectangle {
                    id: searchContainer
                    width: parent.width
                    height: 52
                    radius: activeTheme.cornerRadiusLarge
                    color: Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.6)
                    border.width: searchField.activeFocus ? 2 : 1
                    border.color: searchField.activeFocus ? activeTheme.primary : 
                                  Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.3)
                    
                    Behavior on border.color {
                        ColorAnimation {
                            duration: activeTheme.shortDuration
                            easing.type: activeTheme.standardEasing
                        }
                    }
                    
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: activeTheme.spacingL
                        anchors.rightMargin: activeTheme.spacingL
                        spacing: activeTheme.spacingM
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            font.family: activeTheme.iconFont
                            font.pixelSize: activeTheme.iconSize
                            color: searchField.activeFocus ? activeTheme.primary : activeTheme.surfaceVariantText
                            font.weight: activeTheme.iconFontWeight
                        }
                        
                        TextInput {
                            id: searchField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - parent.spacing - activeTheme.iconSize - 32
                            height: parent.height - activeTheme.spacingS
                            
                            color: activeTheme.surfaceText
                            font.pixelSize: activeTheme.fontSizeLarge
                            verticalAlignment: TextInput.AlignVCenter
                            
                            focus: launcher.isVisible
                            selectByMouse: true
                            activeFocusOnTab: true
                            
                            // Placeholder text
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search applications..."
                                color: activeTheme.surfaceVariantText
                                font.pixelSize: activeTheme.fontSizeLarge
                                visible: searchField.text.length === 0 && !searchField.activeFocus
                            }
                            
                            // Clear button
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: clearSearchArea.containsMouse ? Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.12) : "transparent"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text.length > 0
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.family: activeTheme.iconFont
                                    font.pixelSize: 16
                                    color: clearSearchArea.containsMouse ? activeTheme.outline : activeTheme.surfaceVariantText
                                }
                                
                                MouseArea {
                                    id: clearSearchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchField.text = ""
                                }
                            }
                            
                            onTextChanged: updateFilteredModel()

                            Keys.onPressed: function (event) {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && filteredModel.count) {
                                    launcher.launchApp(filteredModel.get(0).exec)
                                    launcher.hide()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    launcher.hide()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
                
                // Category filter and view mode controls
                Row {
                    width: parent.width
                    height: 40
                    spacing: activeTheme.spacingM
                    visible: searchField.text.length === 0
                    
                    // Category filter
                    Rectangle {
                        width: 200
                        height: 36
                        radius: activeTheme.cornerRadius
                        color: Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.3)
                        border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.2)
                        border.width: 1
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: activeTheme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: activeTheme.spacingS
                            
                            Text {
                                text: "category"
                                font.family: activeTheme.iconFont
                                font.pixelSize: 18
                                color: activeTheme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: selectedCategory
                                font.pixelSize: activeTheme.fontSizeMedium
                                color: activeTheme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                font.weight: Font.Medium
                            }
                        }
                        
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: activeTheme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            text: showCategories ? "expand_less" : "expand_more"
                            font.family: activeTheme.iconFont
                            font.pixelSize: 18
                            color: activeTheme.surfaceVariantText
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showCategories = !showCategories
                        }
                    }
                    
                    Item { width: parent.width - 300; height: 1 }
                    
                    // View mode toggle
                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // List view button
                        Rectangle {
                            width: 36
                            height: 36
                            radius: activeTheme.cornerRadius
                            color: viewMode === "list" ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.12) : 
                                  listViewArea.containsMouse ? Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.08) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "view_list"
                                font.family: activeTheme.iconFont
                                font.pixelSize: 20
                                color: viewMode === "list" ? activeTheme.primary : activeTheme.surfaceText
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
                            radius: activeTheme.cornerRadius
                            color: viewMode === "grid" ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.12) : 
                                  gridViewArea.containsMouse ? Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.08) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "grid_view"
                                font.family: activeTheme.iconFont
                                font.pixelSize: 20
                                color: viewMode === "grid" ? activeTheme.primary : activeTheme.surfaceText
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
                
                // App grid/list container
                Rectangle {
                    width: parent.width
                    height: parent.height - searchContainer.height - (searchField.text.length === 0 ? 128 : 60) - parent.spacing * 3
                    color: "transparent"
                    
                    // List view scroll container
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        visible: viewMode === "list"
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        ListView {
                            id: appList
                            width: parent.width
                            anchors.margins: activeTheme.spacingS
                            spacing: activeTheme.spacingS
                            
                            model: filteredModel
                            delegate: listDelegate
                        }
                    }
                
                    // Grid view scroll container  
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        visible: viewMode === "grid"
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        GridView {
                            id: appGrid
                            width: parent.width
                            anchors.margins: activeTheme.spacingS
                            
                            // Responsive cell sizes based on screen width
                            property int baseCellWidth: Math.max(100, Math.min(140, width / 8))
                            property int baseCellHeight: baseCellWidth + 20
                            
                            cellWidth: baseCellWidth
                            cellHeight: baseCellHeight
                            
                            // Center the grid content
                            property int columnsCount: Math.floor(width / cellWidth)
                            property int remainingSpace: width - (columnsCount * cellWidth)
                            leftMargin: Math.max(activeTheme.spacingS, remainingSpace / 2)
                            rightMargin: leftMargin
                            
                            model: filteredModel
                            delegate: gridDelegate
                        }
                    }
                }
                
                // Category dropdown overlay - now positioned absolutely
                Rectangle {
                    id: categoryDropdown
                    width: 200
                    height: Math.min(250, categories.length * 40 + activeTheme.spacingM * 2)
                    radius: activeTheme.cornerRadiusLarge
                    color: activeTheme.surfaceContainer
                    border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.2)
                    border.width: 1
                    visible: showCategories
                    z: 1000
                    
                    // Position it below the category button
                    anchors.top: parent.top
                    anchors.topMargin: 140 + (searchField.text.length === 0 ? 0 : -40)
                    anchors.left: parent.left
                    
                    // Drop shadow
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        radius: parent.radius + 4
                        z: -1
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            radius: 8
                            samples: 16
                            color: Qt.rgba(0, 0, 0, 0.2)
                        }
                    }
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: activeTheme.spacingS
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        ListView {
                            model: categories
                            spacing: 4
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                radius: activeTheme.cornerRadiusSmall
                                color: catArea.containsMouse ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.08) : "transparent"
                                
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: activeTheme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    font.pixelSize: activeTheme.fontSizeMedium
                                    color: selectedCategory === modelData ? activeTheme.primary : activeTheme.surfaceText
                                    font.weight: selectedCategory === modelData ? Font.Medium : Font.Normal
                                }
                                
                                MouseArea {
                                    id: catArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selectedCategory = modelData
                                        showCategories = false
                                        updateFilteredModel()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // List delegate with new loader
    Component {
        id: listDelegate
        Rectangle {
            width: appList.width
            height: 72
            radius: activeTheme.cornerRadiusLarge
            color: appMouseArea.hovered ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.08)
                                         : Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.03)
            border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.08)
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: activeTheme.spacingM
                spacing: activeTheme.spacingL

                Item {
                    width: 56
                    height: 56
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Loader {
                        id: listIconLoader
                        anchors.fill: parent
                        property string _iconName: model.icon
                        property string _appName: model.name
                        sourceComponent: iconComponent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - activeTheme.spacingL
                    spacing: activeTheme.spacingXS

                    Text {
                        width: parent.width
                        text: model.name
                        font.pixelSize: activeTheme.fontSizeLarge
                        color: activeTheme.surfaceText
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: model.comment || "Application"
                        font.pixelSize: activeTheme.fontSizeMedium
                        color: activeTheme.surfaceVariantText
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
                onClicked: {
                    launcher.launchApp(model.exec)
                    launcher.hide()
                }
            }
        }
    }

    // Grid delegate with new loader (uses dynamic icon size)
    Component {
        id: gridDelegate
        Rectangle {
            width: appGrid.cellWidth - 8
            height: appGrid.cellHeight - 8
            radius: activeTheme.cornerRadiusLarge
            color: gridAppArea.hovered ? Qt.rgba(activeTheme.primary.r, activeTheme.primary.g, activeTheme.primary.b, 0.08)
                                       : Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.03)
            border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.08)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: activeTheme.spacingS

                Item {
                    property int iconSize: Math.min(56, Math.max(32, appGrid.cellWidth * 0.6))
                    width: iconSize
                    height: iconSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    Loader {
                        id: gridIconLoader
                        anchors.fill: parent
                        property string _iconName: model.icon
                        property string _appName: model.name
                        sourceComponent: iconComponent
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 88
                    text: model.name
                    font.pixelSize: activeTheme.fontSizeSmall
                    color: activeTheme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
            }

            MouseArea {
                id: gridAppArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    launcher.launchApp(model.exec)
                    launcher.hide()
                }
            }
        }
    }
    
    Process {
        id: appLauncher
        
        function start(exec) {
            // Clean up exec command (remove field codes)
            var cleanExec = exec.replace(/%[fFuU]/g, "").trim()
            command = ["sh", "-c", cleanExec]
            running = true
        }
        
        onExited: {
            if (exitCode !== 0) {
                console.log("Failed to launch application, exit code:", exitCode)
            }
        }
    }
    
    function launchApp(exec) {
        appLauncher.start(exec)
    }
    
    function show() {
        launcher.isVisible = true
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })
    }
    
    function hide() {
        launcher.isVisible = false
        searchField.text = ""
        showCategories = false
    }
    
    function toggle() {
        if (launcher.isVisible) {
            hide()
        } else {
            show()
        }
    }
    
    Component.onCompleted: {
        desktopScanner.running = true
    }
}