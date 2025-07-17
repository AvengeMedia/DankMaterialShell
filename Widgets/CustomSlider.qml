import QtQuick
import qs.Common

Item {
    id: slider
    
    property int value: 50
    property int minimum: 0
    property int maximum: 100
    property string leftIcon: ""
    property string rightIcon: ""
    property bool enabled: true
    property string unit: "%"
    property bool showValue: true
    
    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)
    
    height: 80
    
    Column {
        anchors.fill: parent
        spacing: Theme.spacingM
        
        // Value display
        Text {
            text: slider.value + slider.unit
            font.pixelSize: Theme.fontSizeMedium
            color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            font.weight: Font.Medium
            visible: slider.showValue
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Slider row
        Row {
            width: parent.width
            spacing: Theme.spacingM
            
            // Left icon
            Text {
                text: slider.leftIcon
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: slider.leftIcon.length > 0
            }
            
            // Slider track
            Rectangle {
                id: sliderTrack
                width: parent.width - (leftIconWidth + rightIconWidth + (slider.leftIcon.length > 0 ? Theme.spacingM : 0) + (slider.rightIcon.length > 0 ? Theme.spacingM : 0))
                height: 6
                radius: 3
                color: slider.enabled ? 
                    Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3) :
                    Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                anchors.verticalCenter: parent.verticalCenter
                
                property int leftIconWidth: slider.leftIcon.length > 0 ? Theme.iconSize : 0
                property int rightIconWidth: slider.rightIcon.length > 0 ? Theme.iconSize : 0
                
                // Fill
                Rectangle {
                    id: sliderFill
                    width: parent.width * ((slider.value - slider.minimum) / (slider.maximum - slider.minimum))
                    height: parent.height
                    radius: parent.radius
                    color: slider.enabled ? Theme.primary : Theme.surfaceVariantText
                    
                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }
                
                // Draggable handle
                Rectangle {
                    id: sliderHandle
                    width: 18
                    height: 18
                    radius: 9
                    color: slider.enabled ? Theme.primary : Theme.surfaceVariantText
                    border.color: slider.enabled ? Qt.lighter(Theme.primary, 1.3) : Qt.lighter(Theme.surfaceVariantText, 1.3)
                    border.width: 2
                    
                    x: Math.max(0, Math.min(parent.width - width, sliderFill.width - width/2))
                    anchors.verticalCenter: parent.verticalCenter
                    
                    scale: sliderMouseArea.containsMouse || sliderMouseArea.pressed ? 1.2 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                    
                    // Handle glow effect when active
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 4
                        height: parent.height + 4
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                        border.width: 2
                        visible: sliderMouseArea.containsMouse && slider.enabled
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
                
                Item {
                    id: sliderContainer
                    anchors.fill: parent
                    
                    MouseArea {
                        id: sliderMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: slider.enabled
                        preventStealing: true
                        
                        property bool isDragging: false
                        
                        onPressed: (mouse) => {
                            if (slider.enabled) {
                                isDragging = true
                                let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                let newValue = Math.round(slider.minimum + ratio * (slider.maximum - slider.minimum))
                                slider.value = newValue
                                slider.sliderValueChanged(newValue)
                            }
                        }
                        
                        onReleased: {
                            if (slider.enabled) {
                                isDragging = false
                                slider.sliderDragFinished(slider.value)
                            }
                        }
                        
                        onPositionChanged: (mouse) => {
                            if (pressed && isDragging && slider.enabled) {
                                let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                let newValue = Math.round(slider.minimum + ratio * (slider.maximum - slider.minimum))
                                slider.value = newValue
                                slider.sliderValueChanged(newValue)
                            }
                        }
                        
                        onClicked: (mouse) => {
                            if (slider.enabled) {
                                let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                let newValue = Math.round(slider.minimum + ratio * (slider.maximum - slider.minimum))
                                slider.value = newValue
                                slider.sliderValueChanged(newValue)
                            }
                        }
                    }
                    
                    // Global mouse area for drag tracking
                    MouseArea {
                        id: sliderGlobalMouseArea
                        anchors.fill: sliderContainer
                        enabled: sliderMouseArea.isDragging
                        visible: false
                        preventStealing: true
                        
                        onPositionChanged: (mouse) => {
                            if (sliderMouseArea.isDragging && slider.enabled) {
                                let globalPos = mapToItem(sliderTrack, mouse.x, mouse.y)
                                let ratio = Math.max(0, Math.min(1, globalPos.x / sliderTrack.width))
                                let newValue = Math.round(slider.minimum + ratio * (slider.maximum - slider.minimum))
                                slider.value = newValue
                                slider.sliderValueChanged(newValue)
                            }
                        }
                        
                        onReleased: {
                            if (sliderMouseArea.isDragging && slider.enabled) {
                                sliderMouseArea.isDragging = false
                                slider.sliderDragFinished(slider.value)
                            }
                        }
                    }
                }
            }
            
            // Right icon
            Text {
                text: slider.rightIcon
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: slider.rightIcon.length > 0
            }
        }
    }
}