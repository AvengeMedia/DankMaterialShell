import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"

PanelWindow {
    id: settingsPopup
    
    property bool settingsVisible: false
    
    visible: settingsVisible
    
    implicitWidth: 600
    implicitHeight: 700
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Darkened background
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.5
        
        MouseArea {
            anchors.fill: parent
            onClicked: settingsPopup.settingsVisible = false
        }
    }
    
    // Main settings panel - spotlight-like centered appearance
    Rectangle {
        id: mainPanel
        width: Math.min(600, parent.width - Theme.spacingXL * 2)
        height: Math.min(700, parent.height - Theme.spacingXL * 2)
        anchors.centerIn: parent
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        
        // Simple opacity and scale control tied directly to settingsVisible
        opacity: settingsPopup.settingsVisible ? 1.0 : 0.0
        scale: settingsPopup.settingsVisible ? 1.0 : 0.95
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL
            
            // Header
            Row {
                width: parent.width
                spacing: Theme.spacingM
                
                Text {
                    text: "settings"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: "Settings"
                    font.pixelSize: Theme.fontSizeXLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { 
                    width: parent.width - 175 // Spacer to push close button to the right
                    height: 1
                }
                
                // Close button
                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.cornerRadius
                    color: closeButton.containsMouse ? 
                           Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) :
                           "transparent"
                    
                    Text {
                        text: "close"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 4
                        color: Theme.surfaceText
                        anchors.centerIn: parent
                    }
                    
                    MouseArea {
                        id: closeButton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsPopup.settingsVisible = false
                    }
                }
            }
            
            // Settings sections
            ScrollView {
                width: parent.width
                height: parent.height - 80
                clip: true
                
                Column {
                    width: parent.width
                    spacing: Theme.spacingL
                    
                    // Profile Settings
                    SettingsSection {
                        title: "Profile"
                        iconName: "person"
                        
                        content: Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            
                            // Profile Image Preview and Input
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                
                                Text {
                                    text: "Profile Image"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Profile Image Preview with circular crop
                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    
                                    // Circular profile image preview
                                    Item {
                                        id: avatarContainer
                                        width: 54
                                        height: 54

                                        property bool hasImage: avatarImageSource.status === Image.Ready

                                        // This rectangle provides the themed ring via its border.
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: "transparent"
                                            border.color: Theme.primary
                                            border.width: 1 // The ring is 1px thick.
                                            visible: parent.hasImage
                                        }

                                        // Hidden Image loader. Its only purpose is to load the texture.
                                        Image {
                                            id: avatarImageSource
                                            source: {
                                                if (profileImageInput.text === "") return ""
                                                if (profileImageInput.text.startsWith("/")) {
                                                    return "file://" + profileImageInput.text
                                                }
                                                return profileImageInput.text
                                            }
                                            smooth: true
                                            asynchronous: true
                                            mipmap: true
                                            cache: true
                                            visible: false // This item is never shown directly.
                                        }

                                        MultiEffect {
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            source: avatarImageSource
                                            maskEnabled: true
                                            maskSource: settingsCircularMask
                                            visible: avatarContainer.hasImage
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                        }

                                        Item {
                                            id: settingsCircularMask
                                            width: 54 - 10
                                            height: 54 - 10
                                            layer.enabled: true
                                            layer.smooth: true
                                            visible: false

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: width / 2
                                                color: "black"
                                                antialiasing: true
                                            }
                                        }

                                        // Fallback for when there is no image.
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: Theme.primary
                                            visible: !parent.hasImage

                                            Text {
                                                anchors.centerIn: parent
                                                text: "person"
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize + 8
                                                color: Theme.primaryText
                                            }
                                        }

                                        // Error icon for when the image fails to load.
                                        Text {
                                            anchors.centerIn: parent
                                            text: "warning"
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize + 8
                                            color: Theme.primaryText
                                            visible: profileImageInput.text !== "" && avatarImageSource.status === Image.Error
                                        }
                                    }
                                    
                                    // Input field
                                    Column {
                                        width: parent.width - 80 - Theme.spacingM
                                        spacing: Theme.spacingS
                                        
                                        Rectangle {
                                            width: parent.width
                                            height: 48
                                            radius: Theme.cornerRadius
                                            color: Theme.surfaceVariant
                                            border.color: profileImageInput.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                            border.width: profileImageInput.activeFocus ? 2 : 1
                                            
                                            TextInput {
                                                id: profileImageInput
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: Theme.surfaceText
                                                font.pixelSize: Theme.fontSizeMedium
                                                text: Prefs.profileImage
                                                selectByMouse: true
                                                
                                                onEditingFinished: {
                                                    Prefs.setProfileImage(text)
                                                }
                                                
                                                // Placeholder text
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Enter image path or URL..."
                                                    color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.6)
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    visible: profileImageInput.text.length === 0 && !profileImageInput.activeFocus
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.IBeamCursor
                                                    acceptedButtons: Qt.NoButton
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            text: "Local filesystem path or URL to an image file."
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Clock Settings
                    SettingsSection {
                        title: "Clock & Time"
                        iconName: "schedule"
                        
                        content: Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            
                            SettingsToggle {
                                text: "24-Hour Format"
                                description: "Use 24-hour time format instead of 12-hour AM/PM"
                                checked: Prefs.use24HourClock
                                onToggled: (checked) => Prefs.setClockFormat(checked)
                            }
                        }
                    }
                    
                    // Weather Settings
                    SettingsSection {
                        title: "Weather"
                        iconName: "wb_sunny"
                        
                        content: Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            
                            SettingsToggle {
                                text: "Fahrenheit"
                                description: "Use Fahrenheit instead of Celsius for temperature"
                                checked: Prefs.useFahrenheit
                                onToggled: (checked) => Prefs.setTemperatureUnit(checked)
                            }
                            
                            // Weather Location Override
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                
                                SettingsToggle {
                                    text: "Override Location"
                                    description: "Use a specific location instead of auto-detection"
                                    checked: Prefs.weatherLocationOverrideEnabled
                                    onToggled: (checked) => Prefs.setWeatherLocationOverrideEnabled(checked)
                                }
                                
                                // Location input - only visible when override is enabled
                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingS
                                    visible: Prefs.weatherLocationOverrideEnabled
                                    opacity: visible ? 1.0 : 0.0
                                    
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.mediumDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }
                                    
                                    Text {
                                        text: "Location"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }
                                    
                                    // Weather Location Search Component
                                    Item {
                                        width: parent.width
                                        height: searchInputField.height + (searchDropdown.visible ? searchDropdown.height : 0)
                                        
                                        Timer {
                                            id: locationSearchTimer
                                            interval: 500
                                            running: false
                                            repeat: false
                                            onTriggered: {
                                                if (weatherLocationInput.text.length > 2 && !locationSearcher.running) {
                                                    // Clear previous results before starting new search
                                                    locationSearchResults.searchResults = 0
                                                    locationSearchResults.searchResultNames = new Array()
                                                    locationSearchResults.searchResultQueries = new Array()
                                                    locationSearchResults.isLoading = true
                                                    locationSearchResults.currentQuery = weatherLocationInput.text
                                                    
                                                    const searchLocation = weatherLocationInput.text
                                                    console.log("=== Starting location search for:", searchLocation)
                                                    
                                                    // Use OpenStreetMap Nominatim API for location search
                                                    const encodedLocation = encodeURIComponent(searchLocation)
                                                    const curlCommand = `curl -s --connect-timeout 5 --max-time 10 'https://nominatim.openstreetmap.org/search?q=${encodedLocation}&format=json&limit=5&addressdetails=1'`
                                                    console.log("Running command:", curlCommand)
                                                    
                                                    locationSearcher.command = ["bash", "-c", curlCommand]
                                                    locationSearcher.running = true
                                                } else if (locationSearcher.running) {
                                                    console.log("Location search already running, skipping")
                                                }
                                            }
                                        }
                                        
                                        Timer {
                                            id: dropdownHideTimer
                                            interval: 1000  // Even longer delay
                                            running: false
                                            repeat: false
                                            onTriggered: {
                                                console.log("Hide timer triggered, hiding dropdown")
                                                searchDropdown.visible = false
                                            }
                                        }
                                        
                                        // Search input field
                                        Rectangle {
                                            id: searchInputField
                                            width: parent.width
                                            height: 48
                                            radius: Theme.cornerRadius
                                            color: Theme.surfaceVariant
                                            border.color: weatherLocationInput.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                            border.width: weatherLocationInput.activeFocus ? 2 : 1
                                            
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingS
                                                
                                                Text {
                                                    width: 20
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    horizontalAlignment: Text.AlignHCenter
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize - 4
                                                    color: Theme.surfaceVariantText
                                                    text: "search"
                                                }
                                                
                                                TextInput {
                                                    id: weatherLocationInput
                                                    width: parent.width - 40 - Theme.spacingS * 2
                                                    height: parent.height
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    text: Prefs.weatherLocationOverride
                                                    selectByMouse: true
                                                    
                                                    onTextChanged: {
                                                        console.log("Text changed to:", text, "length:", text.length)
                                                        if (text.length > 2) {
                                                            // Don't clear results immediately when starting a new search
                                                            // Only set loading state and restart timer
                                                            locationSearchResults.isLoading = true
                                                            locationSearchTimer.restart()
                                                            searchDropdown.visible = true
                                                            console.log("Starting new search, dropdown visible:", searchDropdown.visible)
                                                        } else {
                                                            locationSearchTimer.stop()
                                                            searchDropdown.visible = false
                                                            locationSearchResults.searchResults = 0
                                                            locationSearchResults.searchResultNames = new Array()
                                                            locationSearchResults.searchResultQueries = new Array()
                                                            locationSearchResults.isLoading = false
                                                            console.log("Text too short, hiding dropdown")
                                                        }
                                                    }
                                                    
                                                    onEditingFinished: {
                                                        if (!searchDropdown.visible) {
                                                            Prefs.setWeatherLocationOverride(text)
                                                        }
                                                    }
                                                    
                                                    onActiveFocusChanged: {
                                                        console.log("Input focus changed:", activeFocus, "dropdown hovered:", searchDropdown.hovered, "aboutToClick:", searchDropdown.aboutToClick, "results count:", locationSearchResults.searchResults)
                                                        // Start timer on focus loss, but only if dropdown is visible
                                                        if (!activeFocus && !searchDropdown.hovered && !searchDropdown.aboutToClick && searchDropdown.visible) {
                                                            console.log("Starting hide timer due to focus loss")
                                                            dropdownHideTimer.start()
                                                        } else if (activeFocus) {
                                                            console.log("Canceling hide timer due to focus gain")
                                                            dropdownHideTimer.stop()
                                                        }
                                                    }
                                                    
                                                    // Placeholder text
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Search for a location..."
                                                        color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.6)
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        visible: weatherLocationInput.text.length === 0 && !weatherLocationInput.activeFocus
                                                    }
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.IBeamCursor
                                                        acceptedButtons: Qt.NoButton
                                                    }
                                                }
                                                
                                                // Status icon
                                                Text {
                                                    width: 20
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    horizontalAlignment: Text.AlignHCenter
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize - 4
                                                    color: {
                                                        if (locationSearchResults.isLoading) return Theme.surfaceVariantText
                                                        if (locationSearchResults.searchResults > 0) return Theme.success || Theme.primary
                                                        if (weatherLocationInput.text.length > 2) return Theme.error
                                                        return "transparent"
                                                    }
                                                    text: {
                                                        if (locationSearchResults.isLoading) return "hourglass_empty"
                                                        if (locationSearchResults.searchResults > 0) return "check_circle"
                                                        if (weatherLocationInput.text.length > 2) return "error"
                                                        return ""
                                                    }
                                                    
                                                    opacity: weatherLocationInput.text.length > 2 ? 1.0 : 0.0
                                                    
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: Theme.shortDuration
                                                            easing.type: Theme.standardEasing
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Search results dropdown
                                        Rectangle {
                                            id: searchDropdown
                                            width: parent.width
                                            height: Math.min(searchResultsColumn.height + Theme.spacingS * 2, 200)
                                            y: searchInputField.height
                                            radius: Theme.cornerRadius
                                            color: Theme.popupBackground()
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                            border.width: 1
                                            visible: false
                                            
                                            property bool hovered: false
                                            property bool aboutToClick: false
                                            
                                            onVisibleChanged: {
                                                console.log("Dropdown visibility changed:", visible)
                                                if (!visible) {
                                                    console.log("Dropdown hidden, current results count:", locationSearchResults.searchResults)
                                                }
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: {
                                                    console.log("Dropdown hovered, canceling hide timer")
                                                    parent.hovered = true
                                                    dropdownHideTimer.stop()
                                                }
                                                onExited: {
                                                    console.log("Dropdown hover exited")
                                                    parent.hovered = false
                                                    if (!weatherLocationInput.activeFocus) {
                                                        console.log("Starting hide timer due to hover exit")
                                                        dropdownHideTimer.start()
                                                    }
                                                }
                                                acceptedButtons: Qt.NoButton
                                            }
                                            
                                            ScrollView {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingS
                                                clip: true
                                                
                                                Column {
                                                    id: searchResultsColumn
                                                    width: parent.width
                                                    spacing: 2
                                                    
                                                    Repeater {
                                                        model: locationSearchResults.searchResults
                                                        
                                                        onModelChanged: {
                                                            console.log("Repeater model changed, new count:", model)
                                                            console.log("Names array length:", locationSearchResults.searchResultNames.length)
                                                            console.log("Queries array length:", locationSearchResults.searchResultQueries.length)
                                                        }
                                                        
                                                        Rectangle {
                                                            width: parent.width
                                                            height: 36
                                                            radius: Theme.cornerRadius
                                                            color: resultMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                                                            
                                                            Row {
                                                                anchors.fill: parent
                                                                anchors.margins: Theme.spacingM
                                                                spacing: Theme.spacingS
                                                                
                                                                Text {
                                                                    font.family: Theme.iconFont
                                                                    font.pixelSize: Theme.iconSize - 6
                                                                    color: Theme.surfaceVariantText
                                                                    text: "place"
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                                
                                                                Text {
                                                                    text: locationSearchResults.searchResultNames[index] || "Unknown"
                                                                    font.pixelSize: Theme.fontSizeMedium
                                                                    color: Theme.surfaceText
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    elide: Text.ElideRight
                                                                    width: parent.width - 30
                                                                }
                                                            }
                                                            
                                                            MouseArea {
                                                                id: resultMouseArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                
                                                                onPressed: {
                                                                    searchDropdown.aboutToClick = true
                                                                }
                                                                
                                                                onClicked: {
                                                                    const selectedName = locationSearchResults.searchResultNames[index]
                                                                    const selectedQuery = locationSearchResults.searchResultQueries[index]
                                                                    
                                                                    // Clear search state first
                                                                    dropdownHideTimer.stop()
                                                                    searchDropdown.aboutToClick = false
                                                                    locationSearchResults.searchResults = 0
                                                                    locationSearchResults.searchResultNames = new Array()
                                                                    locationSearchResults.searchResultQueries = new Array()
                                                                    locationSearchResults.isLoading = false
                                                                    
                                                                    weatherLocationInput.text = selectedName
                                                                    searchDropdown.visible = false
                                                                    Prefs.setWeatherLocationOverride(selectedQuery)
                                                                    console.log("Selected location:", selectedName, "Query:", selectedQuery)
                                                                }
                                                                
                                                                onCanceled: {
                                                                    searchDropdown.aboutToClick = false
                                                                }
                                                            }
                                                        }
                                                    }
                                                    
                                                    // No results message
                                                    Text {
                                                        width: parent.width
                                                        height: 36
                                                        text: locationSearchResults.isLoading ? "Searching..." : "No locations found"
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        color: Theme.surfaceVariantText
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        visible: locationSearchResults.searchResults === 0 && weatherLocationInput.text.length > 2 && !locationSearchResults.isLoading
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: {
                                            if (locationSearchResults.searchResults > 0) {
                                                return `${locationSearchResults.searchResults} location${locationSearchResults.searchResults > 1 ? 's' : ''} found. Click to select.`
                                            } else if (locationSearchResults.isLoading) {
                                                return "Searching for locations..."
                                            } else if (weatherLocationInput.text.length > 2) {
                                                return "No locations found. Try a different search term."
                                            } else {
                                                return "Examples: \"New York\", \"Tokyo\", \"44511\""
                                            }
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: {
                                            if (locationSearchResults.searchResults > 0) {
                                                return Theme.success || Theme.primary
                                            } else if (locationSearchResults.isLoading) {
                                                return Theme.surfaceVariantText
                                            } else if (weatherLocationInput.text.length > 2) {
                                                return Theme.error
                                            } else {
                                                return Theme.surfaceVariantText
                                            }
                                        }
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }
                    
                    // Widget Visibility Settings
                    SettingsSection {
                        title: "Top Bar Widgets"
                        iconName: "widgets"
                        
                        content: Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            
                            SettingsToggle {
                                text: "Focused Window"
                                description: "Show the currently focused application in the top bar"
                                checked: Prefs.showFocusedWindow
                                onToggled: (checked) => Prefs.setShowFocusedWindow(checked)
                            }
                            
                            SettingsToggle {
                                text: "Weather Widget"
                                description: "Display weather information in the top bar"
                                checked: Prefs.showWeather
                                onToggled: (checked) => Prefs.setShowWeather(checked)
                            }
                            
                            SettingsToggle {
                                text: "Media Controls"
                                description: "Show currently playing media in the top bar"
                                checked: Prefs.showMusic
                                onToggled: (checked) => Prefs.setShowMusic(checked)
                            }
                            
                            SettingsToggle {
                                text: "Clipboard Button"
                                description: "Show clipboard access button in the top bar"
                                checked: Prefs.showClipboard
                                onToggled: (checked) => Prefs.setShowClipboard(checked)
                            }
                            
                            SettingsToggle {
                                text: "System Resources"
                                description: "Display CPU and RAM usage indicators"
                                checked: Prefs.showSystemResources
                                onToggled: (checked) => Prefs.setShowSystemResources(checked)
                            }
                            
                            SettingsToggle {
                                text: "System Tray"
                                description: "Show system tray icons in the top bar"
                                checked: Prefs.showSystemTray
                                onToggled: (checked) => Prefs.setShowSystemTray(checked)
                            }
                        }
                    }
                    
                    // Display Settings
                    SettingsSection {
                        title: "Display & Appearance"
                        iconName: "palette"
                        
                        content: Column {
                            width: parent.width
                            spacing: Theme.spacingL
                            
                            SettingsToggle {
                                text: "Night Mode"
                                description: "Apply warm color temperature to reduce eye strain"
                                checked: Prefs.nightModeEnabled
                                onToggled: (checked) => {
                                    Prefs.setNightModeEnabled(checked)
                                    if (checked) {
                                        nightModeEnableProcess.running = true
                                    } else {
                                        nightModeDisableProcess.running = true
                                    }
                                }
                            }
                            
                            SettingsToggle {
                                text: "Light Mode"
                                description: "Use light theme instead of dark theme"
                                checked: Prefs.isLightMode
                                onToggled: (checked) => {
                                    Prefs.setLightMode(checked)
                                    Theme.isLightMode = checked
                                }
                            }
                            
                            // Top Bar Transparency
                            Column {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "Top Bar Transparency"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                CustomSlider {
                                    width: parent.width
                                    value: Math.round(Prefs.topBarTransparency * 100)
                                    minimum: 0
                                    maximum: 100
                                    leftIcon: "opacity"
                                    rightIcon: "circle"
                                    unit: "%"
                                    showValue: true
                                    
                                    onSliderDragFinished: (finalValue) => {
                                        let transparencyValue = finalValue / 100.0
                                        Prefs.setTopBarTransparency(transparencyValue)
                                    }
                                }
                                
                                Text {
                                    text: "Adjust the transparency of the top bar background"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                            
                            // Popup Transparency
                            Column {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "Popup Transparency"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                CustomSlider {
                                    width: parent.width
                                    value: Math.round(Prefs.popupTransparency * 100)
                                    minimum: 0
                                    maximum: 100
                                    leftIcon: "blur_on"
                                    rightIcon: "circle"
                                    unit: "%"
                                    showValue: true
                                    
                                    onSliderDragFinished: (finalValue) => {
                                        let transparencyValue = finalValue / 100.0
                                        Prefs.setPopupTransparency(transparencyValue)
                                    }
                                }
                                
                                Text {
                                    text: "Adjust transparency for dialogs, menus, and popups"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                            
                            // Theme Picker
                            Column {
                                width: parent.width
                                spacing: Theme.spacingS
                                
                                Text {
                                    text: "Theme Color"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                ThemePicker {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Add shadow effect
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1.0
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowOpacity: 0.3
        }
    }
    
    // Night mode processes
    Process {
        id: nightModeEnableProcess
        command: ["bash", "-c", "if command -v wlsunset > /dev/null; then pkill wlsunset; wlsunset -t 3000 & elif command -v redshift > /dev/null; then pkill redshift; redshift -P -O 3000 & else echo 'No night mode tool available'; fi"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to enable night mode")
                Prefs.setNightModeEnabled(false)
            }
        }
    }
    
    Process {
        id: nightModeDisableProcess  
        command: ["bash", "-c", "pkill wlsunset; pkill redshift; if command -v wlsunset > /dev/null; then wlsunset -t 6500 -T 6500 & sleep 1; pkill wlsunset; elif command -v redshift > /dev/null; then redshift -P -O 6500; redshift -x; fi"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to disable night mode")
            }
        }
    }
    
    // Weather location search results
    QtObject {
        id: locationSearchResults
        property var searchResults: []
        property var searchResultNames: []
        property var searchResultQueries: []
        property bool isLoading: false
        property string currentQuery: ""
    }
    
    // Weather location validation
    QtObject {
        id: locationValidationStatus
        property string validationState: "none"  // "none", "validating", "valid", "invalid"
        property string lastValidatedLocation: ""
        property string validatedLocationName: ""
    }
    
    
    Process {
        id: locationSearcher
        command: ["bash", "-c", "echo"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                locationSearchResults.isLoading = false
                console.log("=== Location search response received")
                console.log("Response length:", raw.length)
                console.log("Response preview:", raw.substring(0, 300))
                
                if (!raw) {
                    console.log("Empty response from location search")
                    locationSearchResults.searchResults = 0
                    locationSearchResults.searchResultNames = new Array()
                    locationSearchResults.searchResultQueries = new Array()
                    return
                }
                
                if (raw[0] !== "[") {
                    console.log("Non-JSON array response from location search:", raw)
                    locationSearchResults.searchResults = 0
                    locationSearchResults.searchResultNames = new Array()
                    locationSearchResults.searchResultQueries = new Array()
                    return
                }
                
                try {
                    const data = JSON.parse(raw)
                    console.log("Parsed JSON array length:", data.length)
                    
                    if (data.length === 0) {
                        console.log("No locations found in search results")
                        locationSearchResults.searchResults = 0
                        // Force new empty arrays to trigger QML reactivity
                        locationSearchResults.searchResultNames = new Array()
                        locationSearchResults.searchResultQueries = new Array()
                        console.log("Cleared arrays - Names length:", locationSearchResults.searchResultNames.length, "Queries length:", locationSearchResults.searchResultQueries.length)
                        return
                    }
                    
                    const results = []
                    
                    for (let i = 0; i < Math.min(data.length, 5); i++) {
                        const location = data[i]
                        console.log(`Location ${i}:`, {
                            display_name: location.display_name,
                            lat: location.lat,
                            lon: location.lon,
                            type: location.type,
                            class: location.class
                        })
                        
                        if (location.display_name && location.lat && location.lon) {
                            // Create a clean location name from display_name
                            const parts = location.display_name.split(', ')
                            let cleanName = parts[0] // Start with the first part
                            
                            // Add state/region if available and different from first part
                            if (parts.length > 1) {
                                const state = parts[parts.length - 2] // Usually the state is second to last
                                if (state && state !== cleanName) {
                                    cleanName += `, ${state}`
                                }
                            }
                            
                            // Use coordinates as the query for wttr.in (most reliable)
                            const query = `${location.lat},${location.lon}`
                            
                            const result = {
                                "name": cleanName,
                                "query": query
                            }
                            
                            results.push(result)
                            console.log(`Added result ${i}: name="${cleanName}" query="${query}"`)
                        } else {
                            console.log(`Skipped location ${i}: missing required fields`)
                        }
                    }
                    
                    console.log("=== Final results array:", results)
                    
                    // Create separate arrays for names and queries
                    const names = []
                    const queries = []
                    
                    for (let i = 0; i < results.length; i++) {
                        names.push(results[i].name)
                        queries.push(results[i].query)
                    }
                    
                    // Set all arrays atomically
                    locationSearchResults.searchResultNames = names
                    locationSearchResults.searchResultQueries = queries
                    locationSearchResults.searchResults = results.length // Just use count for now
                    
                    console.log("Location search completed:", results.length, "results set")
                    console.log("Names:", names)
                    console.log("Queries:", queries)
                } catch (e) {
                    console.log("Location search JSON parse error:", e.message)
                    console.log("Raw response:", raw.substring(0, 500))
                    locationSearchResults.searchResults = 0
                    locationSearchResults.searchResultNames = new Array()
                    locationSearchResults.searchResultQueries = new Array()
                }
            }
        }
        
        onExited: (exitCode) => {
            locationSearchResults.isLoading = false
            if (exitCode !== 0) {
                console.log("Location search process failed with exit code:", exitCode)
                locationSearchResults.searchResults = []
            }
        }
    }

    // Keyboard focus and shortcuts
    FocusScope {
        anchors.fill: parent
        focus: settingsPopup.settingsVisible
        
        Keys.onEscapePressed: settingsPopup.settingsVisible = false
    }
}