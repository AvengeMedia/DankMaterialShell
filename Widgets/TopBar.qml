import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../Services"

PanelWindow {
    id: topBar
    
    property var theme
    property var root
    
    anchors {
        top: true
        left: true
        right: true
    }
    
    implicitHeight: theme.barHeight
    color: "transparent"
    
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.95)
        
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
            border.width: 1
        }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(theme.surfaceTint.r, theme.surfaceTint.g, theme.surfaceTint.b, 0.08)
            
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.12
                    duration: theme.extraLongDuration
                    easing.type: theme.standardEasing
                }
                NumberAnimation {
                    to: 0.06
                    duration: theme.extraLongDuration
                    easing.type: theme.standardEasing
                }
            }
        }
    }
    
    Item {
        anchors.fill: parent
        anchors.leftMargin: theme.spacingL
        anchors.rightMargin: theme.spacingL
        
        // Left section - Apps and Workspace Switcher
        Row {
            id: leftSection
            height: parent.height
            spacing: theme.spacingL
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            
            AppLauncherButton {
                theme: topBar.theme
                root: topBar.root
            }
            
            WorkspaceSwitcher {
                theme: topBar.theme
                root: topBar.root
            }
        }
        
        // Center section - Clock/Media Player
        ClockWidget {
            id: clockWidget
            theme: topBar.theme
            root: topBar.root
            anchors.centerIn: parent
        }
        
        // Right section - System controls
        Row {
            id: rightSection
            height: parent.height
            spacing: theme.spacingXS
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            
            SystemTrayWidget {
                theme: topBar.theme
                root: topBar.root
            }
            
            ClipboardButton {
                theme: topBar.theme
                root: topBar.root
            }
            
            ColorPickerButton {
                theme: topBar.theme
                root: topBar.root
            }
            
            NotificationButton {
                theme: topBar.theme
                root: topBar.root
            }
        }
    }
}