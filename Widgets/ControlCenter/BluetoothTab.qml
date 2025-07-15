import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../Common"
import "../../Services"

Item {
    id: bluetoothTab
    
    property bool bluetoothEnabled: false
    property var bluetoothDevices: []
    
    ScrollView {
        anchors.fill: parent
        clip: true
        
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        
        Column {
            width: parent.width
            spacing: Theme.spacingL
            
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
                                color: {
                                    if (modelData.connecting) return Theme.primary
                                    if (modelData.connected) return Theme.primary
                                    return Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: modelData.connecting ? 0.6 : 1.0
                                
                                Behavior on opacity {
                                    SequentialAnimation {
                                        running: modelData.connecting
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                        NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                                    }
                                }
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
                                        text: modelData.connectionStatus
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: {
                                            if (modelData.connecting) return Theme.primary
                                            if (modelData.connectionFailed) return Theme.error
                                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                        }
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
                        
                        Rectangle {
                            id: btMenuButton
                            width: 32
                            height: 32
                            radius: Theme.cornerRadius
                            color: btMenuButtonArea.containsMouse ? 
                                   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : 
                                   "transparent"
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: "more_vert"
                                font.family: Theme.iconFont
                                font.weight: Theme.iconFontWeight
                                font.pixelSize: Theme.iconSize
                                color: Theme.surfaceText
                                opacity: 0.6
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                id: btMenuButtonArea
                                anchors.fill: parent
                                hoverEnabled: !modelData.connecting
                                enabled: !modelData.connecting
                                cursorShape: modelData.connecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                
                                onClicked: {
                                    if (!modelData.connecting) {
                                        bluetoothContextMenuWindow.deviceData = modelData
                                        let localPos = btMenuButtonArea.mapToItem(bluetoothTab, btMenuButtonArea.width / 2, btMenuButtonArea.height)
                                        bluetoothContextMenuWindow.show(localPos.x, localPos.y)
                                    }
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation { duration: Theme.shortDuration }
                            }
                        }
                        
                        MouseArea {
                            id: btDeviceArea
                            anchors.fill: parent
                            anchors.rightMargin: 40  // Don't overlap with menu button
                            hoverEnabled: !modelData.connecting
                            enabled: !modelData.connecting
                            cursorShape: modelData.connecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                            
                            onClicked: {
                                if (!modelData.connecting) {
                                    BluetoothService.toggleBluetoothDevice(modelData.mac)
                                }
                            }
                        }
                    }
                }
            }
            
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
                        width: Math.max(140, scanText.contentWidth + Theme.spacingL * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: scanArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        border.color: Theme.primary
                        border.width: 1
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS
                            
                            Text {
                                text: BluetoothService.scanning ? "stop" : "bluetooth_searching"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 4
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                id: scanText
                                text: BluetoothService.scanning ? "Stop Scanning" : "Start Scanning"
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
                            
                            onClicked: {
                                if (BluetoothService.scanning) {
                                    BluetoothService.stopDiscovery()
                                } else {
                                    BluetoothService.startDiscovery()
                                }
                            }
                        }
                    }
                }
                
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
                
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: BluetoothService.scanning && BluetoothService.availableDevices.length === 0
                    
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "sync"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeLarge
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            
                            RotationAnimation on rotation {
                                running: true
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 2000
                            }
                        }
                        
                        Text {
                            text: "Scanning for devices..."
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Text {
                        text: "Make sure your device is in pairing mode"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                Text {
                    text: "No devices found. Put your device in pairing mode and click Start Scanning."
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
    
    Rectangle {
        id: bluetoothContextMenuWindow
        property var deviceData: null
        property bool menuVisible: false
        
        visible: false
        width: 160
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadiusLarge
        color: Theme.popupBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        z: 1000
        
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }
        
        opacity: menuVisible ? 1.0 : 0.0
        scale: menuVisible ? 1.0 : 0.85
        
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
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: 1
            
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadiusSmall
                color: connectArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS
                    
                    Text {
                        text: bluetoothContextMenuWindow.deviceData && bluetoothContextMenuWindow.deviceData.connected ? "link_off" : "link"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 2
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: bluetoothContextMenuWindow.deviceData && bluetoothContextMenuWindow.deviceData.connected ? "Disconnect" : "Connect"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: connectArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        if (bluetoothContextMenuWindow.deviceData) {
                            BluetoothService.toggleBluetoothDevice(bluetoothContextMenuWindow.deviceData.mac)
                        }
                        bluetoothContextMenuWindow.hide()
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
            
            Rectangle {
                width: parent.width - Theme.spacingS * 2
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }
            }
            
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadiusSmall
                color: forgetArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS
                    
                    Text {
                        text: "delete"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 2
                        color: forgetArea.containsMouse ? Theme.error : Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "Forget Device"
                        font.pixelSize: Theme.fontSizeSmall
                        color: forgetArea.containsMouse ? Theme.error : Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: forgetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        if (bluetoothContextMenuWindow.deviceData) {
                            BluetoothService.removeDevice(bluetoothContextMenuWindow.deviceData.mac)
                        }
                        bluetoothContextMenuWindow.hide()
                    }
                }
                
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }
        
        function show(x, y) {
            const menuWidth = 160
            const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2
            
            let finalX = x - menuWidth / 2
            let finalY = y
            
            finalX = Math.max(0, Math.min(finalX, bluetoothTab.width - menuWidth))
            finalY = Math.max(0, Math.min(finalY, bluetoothTab.height - menuHeight))
            
            bluetoothContextMenuWindow.x = finalX
            bluetoothContextMenuWindow.y = finalY
            bluetoothContextMenuWindow.visible = true
            bluetoothContextMenuWindow.menuVisible = true
        }
        
        function hide() {
            bluetoothContextMenuWindow.menuVisible = false
            Qt.callLater(() => { bluetoothContextMenuWindow.visible = false })
        }
    }
    
    MouseArea {
        anchors.fill: parent
        visible: bluetoothContextMenuWindow.visible
        onClicked: {
            bluetoothContextMenuWindow.hide()
        }
        
        MouseArea {
            x: bluetoothContextMenuWindow.x
            y: bluetoothContextMenuWindow.y
            width: bluetoothContextMenuWindow.width
            height: bluetoothContextMenuWindow.height
            onClicked: {
            }
        }
    }
}