import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"
import "../Services"

PanelWindow {
    id: launcher
    
    property bool isVisible: false
    
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
    
    // App management
    property var categories: AppSearchService.getAllCategories()
    property string selectedCategory: "All"
    property var recentApps: []
    property var pinnedApps: ["firefox", "code", "terminal", "file-manager"]
    property bool showCategories: false
    property string viewMode: "list" // "list" or "grid"
    
    ListModel { id: filteredModel }
    
    // Background dim with click to close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: launcher.isVisible ? 1.0 : 0.0
        visible: launcher.isVisible
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: launcher.isVisible
            onClicked: launcher.hide()
        }
    }
    
    Connections {
        target: AppSearchService
        function onReadyChanged() {
            if (AppSearchService.ready) {
                categories = AppSearchService.getAllCategories()
                updateFilteredModel()
            }
        }
    }
    
    Connections {
        target: LauncherService
        function onShowAppLauncher() {
            launcher.show()
        }
        function onHideAppLauncher() {
            launcher.hide()
        }
        function onToggleAppLauncher() {
            launcher.toggle()
        }
    }
    
    function updateFilteredModel() {
        filteredModel.clear()
        
        var apps = []
        
        // Get apps based on category and search
        if (searchField.text.length > 0) {
            // Search across all apps or category
            var baseApps = selectedCategory === "All" ? 
                AppSearchService.applications : 
                AppSearchService.getAppsInCategory(selectedCategory)
            apps = AppSearchService.searchApplications(searchField.text).filter(app => 
                baseApps.includes(app)
            )
        } else {
            // Just category filter
            apps = AppSearchService.getAppsInCategory(selectedCategory)
        }
        
        // Add to model
        apps.forEach(app => {
            filteredModel.append({
                name: app.name,
                exec: app.execString || "",
                icon: app.icon || "application-x-executable",
                comment: app.comment || "",
                categories: app.categories || [],
                desktopEntry: app
            })
        })
    }

    Component {
        id: iconComponent
        Item {
            property var appData: parent.modelData || {}
            
            IconImage {
                id: iconImg
                anchors.fill: parent
                source: appData.icon ? Quickshell.iconPath(appData.icon, "") : ""
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
            }
            
            Rectangle {
                anchors.fill: parent
                visible: !iconImg.visible
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                radius: Theme.cornerRadiusLarge
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)

                Text {
                    anchors.centerIn: parent
                    text: appData.name ? appData.name.charAt(0).toUpperCase() : "A"
                    font.pixelSize: 28
                    color: Theme.primary
                    font.weight: Font.Bold
                }
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
            topMargin: Theme.barHeight + Theme.spacingXS
            leftMargin: Theme.spacingL
        }
        
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
        radius: Theme.cornerRadiusXLarge
        
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
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
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
                        duration: Theme.mediumDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
                
                Behavior on yScale {
                    NumberAnimation {
                        duration: Theme.mediumDuration
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
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
                
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        ]
        
        opacity: launcher.isVisible ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
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
                anchors.margins: Theme.spacingXL
                spacing: Theme.spacingL
                
                // Header section
                Row {
                    width: parent.width
                    height: 40
                    
                    // App launcher title
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Applications"
                        font.pixelSize: Theme.fontSizeLarge + 4
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }
                    
                    Item { width: parent.width - 200; height: 1 }
                    
                    // Quick stats
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: filteredModel.count + " apps"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                    }
                }
                
                // Enhanced search field
                Rectangle {
                    id: searchContainer
                    width: parent.width
                    height: 52
                    radius: Theme.cornerRadiusLarge
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.6)
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
                            
                            focus: launcher.isVisible
                            selectByMouse: true
                            activeFocusOnTab: true
                            
                            // Placeholder text
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search applications..."
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeLarge
                                visible: searchField.text.length === 0 && !searchField.activeFocus
                            }
                            
                            // Clear button
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: clearSearchArea.containsMouse ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12) : "transparent"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text.length > 0
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 16
                                    color: clearSearchArea.containsMouse ? Theme.outline : Theme.surfaceVariantText
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
                                    var firstApp = filteredModel.get(0)
                                    if (firstApp.desktopEntry) {
                                        AppSearchService.launchApp(firstApp.desktopEntry)
                                    } else {
                                        launcher.launchApp(firstApp.exec)
                                    }
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
                    spacing: Theme.spacingM
                    visible: searchField.text.length === 0
                    
                    // Category filter
                    Rectangle {
                        width: 200
                        height: 36
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        border.width: 1
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            
                            Text {
                                text: "category"
                                font.family: Theme.iconFont
                                font.pixelSize: 18
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: selectedCategory
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                font.weight: Font.Medium
                            }
                        }
                        
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            text: showCategories ? "expand_less" : "expand_more"
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: Theme.surfaceVariantText
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
                            radius: Theme.cornerRadius
                            color: viewMode === "list" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                  listViewArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "view_list"
                                font.family: Theme.iconFont
                                font.pixelSize: 20
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
                            radius: Theme.cornerRadius
                            color: viewMode === "grid" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                  gridViewArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "grid_view"
                                font.family: Theme.iconFont
                                font.pixelSize: 20
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
                
                // App grid/list container
                Rectangle {
                    width: parent.width
                    height: {
                        // Calculate more precise remaining height
                        let usedHeight = 40 + Theme.spacingL // Header
                        usedHeight += 52 + Theme.spacingL // Search container
                        usedHeight += (searchField.text.length === 0 ? 40 + Theme.spacingL : 0) // Category/controls when visible
                        return parent.height - usedHeight
                    }
                    color: "transparent"
                    
                    // List view scroll container
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        visible: viewMode === "list"
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        ListView {
                            id: appList
                            width: parent.width
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS
                            
                            model: filteredModel
                            delegate: listDelegate
                            
                            // Make mouse wheel scrolling more responsive
                            property real wheelStepSize: 60
                            
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                
                                onWheel: (wheel) => {
                                    var delta = wheel.angleDelta.y
                                    var steps = delta / 120  // Standard wheel step
                                    appList.contentY -= steps * appList.wheelStepSize
                                    
                                    // Ensure we stay within bounds
                                    if (appList.contentY < 0) {
                                        appList.contentY = 0
                                    } else if (appList.contentY > appList.contentHeight - appList.height) {
                                        appList.contentY = Math.max(0, appList.contentHeight - appList.height)
                                    }
                                }
                            }
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
                            anchors.margins: Theme.spacingS
                            
                            // Responsive cell sizes based on screen width
                            property int baseCellWidth: Math.max(100, Math.min(140, width / 8))
                            property int baseCellHeight: baseCellWidth + 20
                            
                            cellWidth: baseCellWidth
                            cellHeight: baseCellHeight
                            
                            // Center the grid content
                            property int columnsCount: Math.floor(width / cellWidth)
                            property int remainingSpace: width - (columnsCount * cellWidth)
                            leftMargin: Math.max(Theme.spacingS, remainingSpace / 2)
                            rightMargin: leftMargin
                            
                            model: filteredModel
                            delegate: gridDelegate
                            
                            // Make mouse wheel scrolling more responsive
                            property real wheelStepSize: 60
                            
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                
                                onWheel: (wheel) => {
                                    var delta = wheel.angleDelta.y
                                    var steps = delta / 120  // Standard wheel step
                                    appGrid.contentY -= steps * appGrid.wheelStepSize
                                    
                                    // Ensure we stay within bounds
                                    if (appGrid.contentY < 0) {
                                        appGrid.contentY = 0
                                    } else if (appGrid.contentY > appGrid.contentHeight - appGrid.height) {
                                        appGrid.contentY = Math.max(0, appGrid.contentHeight - appGrid.height)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Category dropdown overlay - now positioned absolutely
                Rectangle {
                    id: categoryDropdown
                    width: 200
                    height: Math.min(250, categories.length * 40 + Theme.spacingM * 2)
                    radius: Theme.cornerRadiusLarge
                    color: Theme.surfaceContainer
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
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
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            shadowBlur: 0.25  // radius/32
                            shadowColor: Qt.rgba(0, 0, 0, 0.2)
                            shadowOpacity: 0.2
                        }
                    }
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        ListView {
                            model: categories
                            spacing: 4
                            
                            // Make mouse wheel scrolling more responsive
                            property real wheelStepSize: 60
                            
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                
                                onWheel: (wheel) => {
                                    var delta = wheel.angleDelta.y
                                    var steps = delta / 120  // Standard wheel step
                                    parent.contentY -= steps * parent.wheelStepSize
                                    
                                    // Ensure we stay within bounds
                                    if (parent.contentY < 0) {
                                        parent.contentY = 0
                                    } else if (parent.contentY > parent.contentHeight - parent.height) {
                                        parent.contentY = Math.max(0, parent.contentHeight - parent.height)
                                    }
                                }
                            }
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                radius: Theme.cornerRadiusSmall
                                color: catArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: selectedCategory === modelData ? Theme.primary : Theme.surfaceText
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
            radius: Theme.cornerRadiusLarge
            color: appMouseArea.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                         : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.03)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingL

                Item {
                    width: 56
                    height: 56
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Loader {
                        id: listIconLoader
                        anchors.fill: parent
                        property var modelData: model
                        sourceComponent: iconComponent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - Theme.spacingL
                    spacing: Theme.spacingXS

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
                onClicked: {
                    if (model.desktopEntry) {
                        AppSearchService.launchApp(model.desktopEntry)
                    } else {
                        launcher.launchApp(model.exec)
                    }
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
            radius: Theme.cornerRadiusLarge
            color: gridAppArea.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                       : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.03)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Item {
                    property int iconSize: Math.min(56, Math.max(32, appGrid.cellWidth * 0.6))
                    width: iconSize
                    height: iconSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    Loader {
                        id: gridIconLoader
                        anchors.fill: parent
                        property var modelData: model
                        sourceComponent: iconComponent
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 88
                    text: model.name
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
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
                    if (model.desktopEntry) {
                        AppSearchService.launchApp(model.desktopEntry)
                    } else {
                        launcher.launchApp(model.exec)
                    }
                    launcher.hide()
                }
            }
        }
    }
    
    function launchApp(exec) {
        // Try to find the desktop entry
        var app = AppSearchService.getAppByExec(exec)
        if (app) {
            AppSearchService.launchApp(app)
        } else {
            // Fallback to direct execution
            var cleanExec = exec.replace(/%[fFuU]/g, "").trim()
            console.log("Launching app directly:", cleanExec)
            Quickshell.execDetached(["sh", "-c", cleanExec])
        }
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
        if (AppSearchService.ready) {
            categories = AppSearchService.getAllCategories()
            updateFilteredModel()
        }
    }
}