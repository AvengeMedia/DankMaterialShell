import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../Common"
import "../../Services"
import "../"

ScrollView {
    id: displayTab
    clip: true
    
    // These should be bound from parent
    property bool nightModeEnabled: false
    
    Column {
        width: parent.width
        spacing: Theme.spacingL
        
        // Brightness Control
        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: BrightnessService.brightnessAvailable
            
            Text {
                text: "Brightness"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
            }
            
            CustomSlider {
                width: parent.width
                value: BrightnessService.brightnessLevel
                leftIcon: "brightness_low"
                rightIcon: "brightness_high"
                enabled: BrightnessService.brightnessAvailable
                
                onSliderValueChanged: (newValue) => {
                    BrightnessService.setBrightness(newValue)
                }
            }
        }
        
        // Display settings
        Column {
            width: parent.width
            spacing: Theme.spacingM
            
            Text {
                text: "Display Settings"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
            }
            
            // Night mode toggle
            Rectangle {
                width: parent.width
                height: 50
                radius: Theme.cornerRadius
                color: displayTab.nightModeEnabled ? 
                    Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                    (nightModeToggle.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                border.color: displayTab.nightModeEnabled ? Theme.primary : "transparent"
                border.width: displayTab.nightModeEnabled ? 1 : 0
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM
                    
                    Text {
                        text: displayTab.nightModeEnabled ? "nightlight" : "dark_mode"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                        color: displayTab.nightModeEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "Night Mode" + (displayTab.nightModeEnabled ? " (On)" : "")
                        font.pixelSize: Theme.fontSizeMedium
                        color: displayTab.nightModeEnabled ? Theme.primary : Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: nightModeToggle
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        if (displayTab.nightModeEnabled) {
                            // Disable night mode - kill any running color temperature processes
                            nightModeDisableProcess.running = true
                            displayTab.nightModeEnabled = false
                        } else {
                            // Enable night mode using wlsunset or redshift
                            nightModeEnableProcess.running = true
                            displayTab.nightModeEnabled = true
                        }
                    }
                }
            }

            // Theme Picker
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                Text {
                    text: "Theme"
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
    
    // Night mode processes
    Process {
        id: nightModeEnableProcess
        command: ["bash", "-c", "if command -v wlsunset > /dev/null; then pkill wlsunset; wlsunset -t 3000 & elif command -v redshift > /dev/null; then pkill redshift; redshift -P -O 3000 & else echo 'No night mode tool available'; fi"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to enable night mode")
                displayTab.nightModeEnabled = false
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
}