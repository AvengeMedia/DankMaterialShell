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
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
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
                                        id: avatarBox
                                        width: 54
                                        height: 54
                                        property bool hasImage: profileImageInput.text !== "" && avatarImage.status !== Image.Error

                                        /* 1 px inner padding; change both "1" values to "2" for 2 px */
                                        ClippingRectangle {
                                            id: avatarClip
                                            anchors.fill: parent
                                            anchors.margins: 1          // ← inner gap between photo & ring
                                            radius: width / 2           // = perfect circle
                                            antialiasing: true          // smooth edge
                                            color: "transparent"
                                            visible: avatarBox.hasImage // show only when we have a real photo

                                            Image {
                                                id: avatarImage
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectCrop
                                                source: profileImageInput.text.startsWith("/")
                                                          ? "file://" + profileImageInput.text
                                                          : profileImageInput.text
                                                smooth: true
                                                asynchronous: true
                                                mipmap: true
                                                cache: false
                                                
                                                onStatusChanged: {
                                                    console.log("Profile image status:", status, "source:", source)
                                                    if (status === Image.Ready) {
                                                        console.log("Image loaded successfully, size:", sourceSize.width + "x" + sourceSize.height)
                                                    } else if (status === Image.Error) {
                                                        console.log("Image failed to load")
                                                    }
                                                }
                                            }
                                        }

                                        /* Fallback / error icon */
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: Theme.primary
                                            visible: !avatarBox.hasImage
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: profileImageInput.text === "" ? "person" : "warning"
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize + 8
                                            color: Theme.onPrimary
                                            visible: !avatarBox.hasImage
                                        }

                                        /* Decorative rings (drawn only when a real image is shown) */
                                        Rectangle {                      // dark outline
                                            anchors.fill: parent
                                            radius: width / 2
                                            border.color: Qt.rgba(0, 0, 0, 0.15)
                                            border.width: 1
                                            color: "transparent"
                                            visible: avatarBox.hasImage
                                        }
                                        Rectangle {                      // light highlight
                                            anchors.fill: parent
                                            anchors.margins: -1          // hugs just outside the dark outline
                                            radius: width / 2 + 1
                                            border.color: Qt.rgba(255, 255, 255, 0.1)
                                            border.width: 1
                                            color: "transparent"
                                            visible: avatarBox.hasImage
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
                                                    text: "Enter image path or URL"
                                                    color: Theme.surfaceVariantText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    visible: profileImageInput.text.length === 0 && !profileImageInput.activeFocus
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            text: "Image will be automatically cropped to a circle"
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