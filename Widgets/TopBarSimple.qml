import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.SystemTray

PanelWindow {
    id: topBar
    
    property var theme
    property var root
    
    anchors {
        top: true
        left: true
        right: true
    }
    
    WlrLayershell.topMargin: 8
    WlrLayershell.bottomMargin: 8
    WlrLayershell.leftMargin: 16
    WlrLayershell.rightMargin: 16
    
    implicitHeight: theme.barHeight - 4
    color: "transparent"
    
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        anchors.topMargin: 6
        anchors.bottomMargin: 2
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: theme.cornerRadiusXLarge
        color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.75)
        
        // Material 3 elevation shadow
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 4
            radius: 16
            samples: 33
            color: Qt.rgba(0, 0, 0, 0.15)
            transparentBorder: true
        }
        
        // Subtle border for definition
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.08)
            border.width: 1
            radius: parent.radius
        }
        
        // Subtle surface tint overlay with animation
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(theme.surfaceTint.r, theme.surfaceTint.g, theme.surfaceTint.b, 0.04)
            radius: parent.radius
            
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.08
                    duration: theme.extraLongDuration
                    easing.type: theme.standardEasing
                }
                NumberAnimation {
                    to: 0.02
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
        anchors.topMargin: theme.spacingXS
        anchors.bottomMargin: theme.spacingXS
        
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