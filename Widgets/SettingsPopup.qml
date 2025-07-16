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
    signal closingPopup()

    onSettingsVisibleChanged: {
        if (!settingsVisible) {
            closingPopup()
        }
    }
    
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
                                        id: weatherLocationSearchComponent
                                        width: parent.width
                                        height: searchInputField.height + (searchDropdown.visible ? searchDropdown.height : 0)

                                        property bool _internalChange: false
                                        property bool isLoading: false
                                        property string helperTextState: "default" // "default", "prompt", "searching", "found", "not_found"
                                        property string currentSearchText: ""

                                        ListModel {
                                            id: searchResultsModel
                                        }

                                        Connections {
                                            target: settingsPopup
                                            function onClosingPopup() {
                                                weatherLocationSearchComponent.resetSearchState()
                                            }
                                        }

                                        function resetSearchState() {
                                            locationSearchTimer.stop()
                                            dropdownHideTimer.stop()
                                            if (locationSearcher.running) {
                                                locationSearcher.running = false;
                                            }
                                            isLoading = false
                                            searchResultsModel.clear()
                                            helperTextState = "default"
                                        }
                                        
                                        Timer {
                                            id: locationSearchTimer
                                            interval: 500
                                            running: false
                                            repeat: false
                                            onTriggered: {
                                                if (weatherLocationInput.text.length > 2) {
                                                    // Stop any running search first
                                                    if (locationSearcher.running) {
                                                        locationSearcher.running = false
                                                    }
                                                    
                                                    searchResultsModel.clear()
                                                    weatherLocationSearchComponent.isLoading = true
                                                    weatherLocationSearchComponent.helperTextState = "searching"
                                                    
                                                    const searchLocation = weatherLocationInput.text
                                                    weatherLocationSearchComponent.currentSearchText = searchLocation
                                                    const encodedLocation = encodeURIComponent(searchLocation)
                                                    const curlCommand = `curl -s --connect-timeout 5 --max-time 10 'https://nominatim.openstreetmap.org/search?q=${encodedLocation}&format=json&limit=5&addressdetails=1'`
                                                    
                                                    locationSearcher.command = ["bash", "-c", curlCommand]
                                                    locationSearcher.running = true
                                                }
                                            }
                                        }
                                        
                                        Timer {
                                            id: dropdownHideTimer
                                            interval: 200 // Short delay to allow clicks
                                            running: false
                                            repeat: false
                                            onTriggered: {
                                                if (!weatherLocationInput.activeFocus && !searchDropdown.hovered) {
                                                    weatherLocationSearchComponent.resetSearchState()
                                                }
                                            }
                                        }

                                        Process {
                                            id: locationSearcher
                                            command: ["bash", "-c", "echo"]
                                            running: false
                                            
                                            stdout: StdioCollector {
                                                onStreamFinished: {
                                                    // Only process if this is still the current search
                                                    if (weatherLocationSearchComponent.currentSearchText !== weatherLocationInput.text) {
                                                        return
                                                    }
                                                    
                                                    const raw = text.trim()
                                                    weatherLocationSearchComponent.isLoading = false
                                                    searchResultsModel.clear()

                                                    if (!raw || raw[0] !== "[") {
                                                        weatherLocationSearchComponent.helperTextState = "not_found"
                                                        return
                                                    }
                                                    
                                                    try {
                                                        const data = JSON.parse(raw)
                                                        if (data.length === 0) {
                                                            weatherLocationSearchComponent.helperTextState = "not_found"
                                                            return
                                                        }
                                                        
                                                        for (let i = 0; i < Math.min(data.length, 5); i++) {
                                                            const location = data[i]
                                                            if (location.display_name && location.lat && location.lon) {
                                                                const parts = location.display_name.split(', ')
                                                                let cleanName = parts[0]
                                                                if (parts.length > 1) {
                                                                    const state = parts[parts.length - 2]
                                                                    if (state && state !== cleanName) {
                                                                        cleanName += `, ${state}`
                                                                    }
                                                                }
                                                                const query = `${location.lat},${location.lon}`
                                                                searchResultsModel.append({ "name": cleanName, "query": query })
                                                            }
                                                        }
                                                        weatherLocationSearchComponent.helperTextState = "found"
                                                    } catch (e) {
                                                        weatherLocationSearchComponent.helperTextState = "not_found"
                                                    }
                                                }
                                            }
                                            
                                            onExited: (exitCode) => {
                                                weatherLocationSearchComponent.isLoading = false
                                                if (exitCode !== 0) {
                                                    searchResultsModel.clear()
                                                    weatherLocationSearchComponent.helperTextState = "not_found"
                                                }
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
                                                        if (weatherLocationSearchComponent._internalChange) return
                                                        if (activeFocus) {
                                                            if (text.length > 2) {
                                                                weatherLocationSearchComponent.isLoading = true
                                                                weatherLocationSearchComponent.helperTextState = "searching"
                                                                locationSearchTimer.restart()
                                                            } else {
                                                                weatherLocationSearchComponent.resetSearchState()
                                                                weatherLocationSearchComponent.helperTextState = "prompt"
                                                            }
                                                        }
                                                    }
                                                    
                                                    onEditingFinished: {
                                                        if (!searchDropdown.visible) {
                                                            Prefs.setWeatherLocationOverride(text)
                                                        }
                                                    }
                                                    
                                                    onActiveFocusChanged: {
                                                        if (activeFocus) {
                                                            dropdownHideTimer.stop()
                                                            if (weatherLocationInput.text.length <= 2) {
                                                                weatherLocationSearchComponent.helperTextState = "prompt"
                                                            }
                                                        }
                                                        else {
                                                            dropdownHideTimer.start()
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
                                                        if (weatherLocationSearchComponent.isLoading) return Theme.surfaceVariantText
                                                        if (searchResultsModel.count > 0) return Theme.success || Theme.primary
                                                        if (weatherLocationInput.activeFocus && weatherLocationInput.text.length > 2) return Theme.error
                                                        return "transparent"
                                                    }
                                                    text: {
                                                        if (weatherLocationSearchComponent.isLoading) return "hourglass_empty"
                                                        if (searchResultsModel.count > 0) return "check_circle"
                                                        if (weatherLocationInput.activeFocus && weatherLocationInput.text.length > 2 && !weatherLocationSearchComponent.isLoading) return "error"
                                                        return ""
                                                    }
                                                    
                                                    opacity: (weatherLocationInput.activeFocus && weatherLocationInput.text.length > 2) ? 1.0 : 0.0
                                                    
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
                                            height: Math.min(Math.max(searchResultsModel.count * 38 + Theme.spacingS * 2, 50), 200)
                                            
                                            y: searchInputField.height
                                            radius: Theme.cornerRadius
                                            color: Theme.popupBackground()
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                            border.width: 1
                                            visible: weatherLocationInput.activeFocus && weatherLocationInput.text.length > 2 && (searchResultsModel.count > 0 || weatherLocationSearchComponent.isLoading)
                                            
                                            
                                            property bool hovered: false
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: {
                                                    parent.hovered = true
                                                    dropdownHideTimer.stop()
                                                }
                                                onExited: {
                                                    parent.hovered = false
                                                    if (!weatherLocationInput.activeFocus) {
                                                        dropdownHideTimer.start()
                                                    }
                                                }
                                                acceptedButtons: Qt.NoButton
                                            }
                                            
                                            Item {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingS
                                                
                                                ListView {
                                                    id: searchResultsList
                                                    anchors.fill: parent
                                                    clip: true
                                                    model: searchResultsModel
                                                    spacing: 2
                                                    
                                                    
                                                    delegate: Rectangle {
                                                        width: searchResultsList.width
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
                                                                text: model.name || "Unknown"
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
                                                            
                                                            onClicked: {
                                                                weatherLocationSearchComponent._internalChange = true
                                                                const selectedName = model.name
                                                                const selectedQuery = model.query
                                                                
                                                                weatherLocationInput.text = selectedName
                                                                Prefs.setWeatherLocationOverride(selectedQuery)
                                                                
                                                                weatherLocationSearchComponent.resetSearchState()
                                                                weatherLocationInput.focus = false
                                                                weatherLocationSearchComponent._internalChange = false
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                // Show message when no results
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: weatherLocationSearchComponent.isLoading ? "Searching..." : "No locations found"
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: Theme.surfaceVariantText
                                                    visible: searchResultsList.count === 0 && weatherLocationInput.text.length > 2
                                                }
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: {
                                            switch (weatherLocationSearchComponent.helperTextState) {
                                                case "default":
                                                    return "Examples: \"New York\", \"Tokyo\", \"44511\""
                                                case "prompt":
                                                    return "Enter 3+ characters to search."
                                                case "searching":
                                                    return "Searching for locations..."
                                                case "found":
                                                    return `${searchResultsModel.count} location${searchResultsModel.count > 1 ? 's' : ''} found. Click to select.`
                                                case "not_found":
                                                    return "No locations found. Try a different search term."
                                            }
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: {
                                            switch (weatherLocationSearchComponent.helperTextState) {
                                                case "found":
                                                    return Theme.success || Theme.primary
                                                case "not_found":
                                                    return Theme.error
                                                default:
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

    // Keyboard focus and shortcuts
    FocusScope {
        anchors.fill: parent
        focus: settingsPopup.settingsVisible
        
        Keys.onEscapePressed: settingsPopup.settingsVisible = false
    }
}