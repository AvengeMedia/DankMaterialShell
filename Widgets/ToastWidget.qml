import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: root
    
    visible: ToastService.toastVisible
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Makes the background transparent to mouse events
    mask: Region {            
        item: toast 
    }

    Rectangle {
        id: toast
        width: Math.min(400, Screen.width - Theme.spacingL * 2)
        height: toastContent.height + Theme.spacingL * 2
        
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight + Theme.spacingL
        
        color: {
            switch (ToastService.currentLevel) {
                case ToastService.levelError: return Theme.error
                case ToastService.levelWarn: return Theme.warning
                case ToastService.levelInfo: return Theme.primary
                default: return Theme.primary
            }
        }
        
        radius: Theme.cornerRadiusLarge
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 0.8
            shadowColor: Qt.rgba(0, 0, 0, 0.3)
            shadowOpacity: 0.3
        }
        
        opacity: ToastService.toastVisible ? 0.9 : 0.0
        scale: ToastService.toastVisible ? 1.0 : 0.9
        
        transform: Translate {
            y: ToastService.toastVisible ? 0 : -20
        }
        
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
        
        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        Row {
            id: toastContent
            anchors.centerIn: parent
            spacing: Theme.spacingM
            
            Text {
                text: {
                    switch (ToastService.currentLevel) {
                        case ToastService.levelError: return "error"
                        case ToastService.levelWarn: return "warning"
                        case ToastService.levelInfo: return "info"
                        default: return "info"
                    }
                }
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: Theme.background
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: ToastService.currentMessage
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.background
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 300)
                elide: Text.ElideRight
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: ToastService.hideToast()
        }
    }
}