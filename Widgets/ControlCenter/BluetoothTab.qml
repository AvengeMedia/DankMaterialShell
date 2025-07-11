import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../Common"
import "../../Services"

ScrollView {
    id: bluetoothTab
    clip: true
    
    // These should be bound from parent
    property bool bluetoothEnabled: false
    property var bluetoothDevices: []
    
    Column {
        width: parent.width
        spacing: Theme.spacingL
        
        // Bluetooth toggle
        Rectangle {
            width: parent.width
            height: 60
            radius: Theme.cornerRadius
            color: bluetoothToggle.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                   (bluetoothTab.bluetoothEnabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12))
            border.color: bluetoothTab.bluetoothEnabled ? Theme.primary : "transparent"
            border.width: 2
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM
                
                Text {
                    text: "bluetooth"
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSizeLarge
                    color: bluetoothTab.bluetoothEnabled ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        text: "Bluetooth"
                        font.pixelSize: Theme.fontSizeLarge
                        color: bluetoothTab.bluetoothEnabled ? Theme.primary : Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    Text {
                        text: bluetoothTab.bluetoothEnabled ? "Enabled" : "Disabled"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    }
                }
            }
            
            MouseArea {
                id: bluetoothToggle
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    BluetoothService.toggleBluetooth()
                }
            }
        }
        
        // Bluetooth devices (when enabled)
        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: bluetoothTab.bluetoothEnabled
            
            Text {
                text: "Paired Devices"
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
            }
            
            // Real Bluetooth devices
            Repeater {
                model: bluetoothTab.bluetoothDevices
                
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: Theme.cornerRadius
                    color: btDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                           (modelData.connected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                    border.color: modelData.connected ? Theme.primary : "transparent"
                    border.width: 1
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: {
                                switch (modelData.type) {
                                    case "headset": return "headset"
                                    case "mouse": return "mouse"
                                    case "keyboard": return "keyboard"
                                    case "phone": return "smartphone"
                                    default: return "bluetooth"
                                }
                            }
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: modelData.connected ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeMedium
                                color: modelData.connected ? Theme.primary : Theme.surfaceText
                                font.weight: modelData.connected ? Font.Medium : Font.Normal
                            }
                            
                            Row {
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: modelData.connected ? "Connected" : "Disconnected"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                }
                                
                                Text {
                                    text: modelData.battery >= 0 ? "• " + modelData.battery + "%" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                    visible: modelData.battery >= 0
                                }
                            }
                        }
                    }
                    
                    MouseArea {
                        id: btDeviceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            BluetoothService.toggleBluetoothDevice(modelData.mac)
                        }
                    }
                }
            }
        }
        
        // Available devices for pairing (when enabled)
        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: bluetoothTab.bluetoothEnabled
            
            Row {
                width: parent.width
                spacing: Theme.spacingM
                
                Text {
                    text: "Available Devices"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { width: 1; height: 1 }
                
                Rectangle {
                    width: Math.max(100, scanText.contentWidth + Theme.spacingM * 2)
                    height: 32
                    radius: Theme.cornerRadius
                    color: scanArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                    border.color: Theme.primary
                    border.width: 1
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        Text {
                            text: BluetoothService.scanning ? "search" : "bluetooth_searching"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 4
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            
                            RotationAnimation on rotation {
                                running: BluetoothService.scanning
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 2000
                            }
                        }
                        
                        Text {
                            id: scanText
                            text: BluetoothService.scanning ? "Scanning..." : "Scan"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primary
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !BluetoothService.scanning
                        
                        onClicked: {
                            BluetoothService.startDiscovery()
                        }
                    }
                }
            }
            
            // Available devices list
            Repeater {
                model: BluetoothService.availableDevices
                
                Rectangle {
                    width: parent.width
                    height: 70
                    radius: Theme.cornerRadius
                    color: availableDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                           (modelData.paired ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                    border.color: modelData.paired ? Theme.secondary : (modelData.canPair ? Theme.primary : "transparent")
                    border.width: 1
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: {
                                switch (modelData.type) {
                                    case "headset": return "headset"
                                    case "mouse": return "mouse"
                                    case "keyboard": return "keyboard"
                                    case "phone": return "smartphone"
                                    case "watch": return "watch"
                                    case "speaker": return "speaker"
                                    case "tv": return "tv"
                                    default: return "bluetooth"
                                }
                            }
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: modelData.paired ? Theme.secondary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeMedium
                                color: modelData.paired ? Theme.secondary : Theme.surfaceText
                                font.weight: modelData.paired ? Font.Medium : Font.Normal
                            }
                            
                            Row {
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: {
                                        if (modelData.paired && modelData.connected) return "Connected"
                                        if (modelData.paired) return "Paired"
                                        return "Signal: " + modelData.signalStrength
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                }
                                
                                Text {
                                    text: modelData.rssi !== 0 ? "• " + modelData.rssi + " dBm" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                                    visible: modelData.rssi !== 0
                                }
                            }
                        }
                    }
                    
                    // Action button on the right
                    Rectangle {
                        width: 80
                        height: 28
                        radius: Theme.cornerRadiusSmall
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        color: actionButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                        border.color: Theme.primary
                        border.width: 1
                        visible: modelData.canPair || modelData.paired
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.paired ? (modelData.connected ? "Disconnect" : "Connect") : "Pair"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                        }
                        
                        MouseArea {
                            id: actionButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                if (modelData.paired) {
                                    if (modelData.connected) {
                                        BluetoothService.toggleBluetoothDevice(modelData.mac)
                                    } else {
                                        BluetoothService.connectDevice(modelData.mac)
                                    }
                                } else {
                                    BluetoothService.pairDevice(modelData.mac)
                                }
                            }
                        }
                    }
                    
                    MouseArea {
                        id: availableDeviceArea
                        anchors.fill: parent
                        anchors.rightMargin: 90  // Don't overlap with action button
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            if (modelData.paired) {
                                BluetoothService.toggleBluetoothDevice(modelData.mac)
                            } else {
                                BluetoothService.pairDevice(modelData.mac)
                            }
                        }
                    }
                }
            }
            
            // No devices message
            Text {
                text: "No devices found. Put your device in pairing mode and click Scan."
                font.pixelSize: Theme.fontSizeMedium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                visible: BluetoothService.availableDevices.length === 0 && !BluetoothService.scanning
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}