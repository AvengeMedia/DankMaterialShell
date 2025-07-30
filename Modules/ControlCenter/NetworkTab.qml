import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Network

Item {
    id: networkTab

    property var wifiPasswordModalRef: wifiPasswordModal
    property var networkInfoModalRef: networkInfoModal

    // Properly sorted WiFi networks with connected networks first
    property var sortedWifiNetworks: {
        if (!NetworkService.wifiAvailable || !NetworkService.wifiEnabled) {
            return [];
        }
        
        // Explicitly reference both arrays to ensure reactivity
        var allNetworks = NetworkService.wifiNetworks;
        var savedNetworks = NetworkService.savedWifiNetworks;
        var currentSSID = NetworkService.currentWifiSSID;
        var signalStrength = NetworkService.wifiSignalStrength;
        var refreshTrigger = forceRefresh; // Force recalculation
        
        var networks = [...allNetworks];
        
        // Update connected status, saved status and signal strength based on current state
        networks.forEach(function(network) {
            network.connected = (network.ssid === currentSSID);
            // Update saved status based on savedWifiNetworks
            network.saved = savedNetworks.some(function(saved) {
                return saved.ssid === network.ssid;
            });
            // Use current connection's signal strength for connected network
            if (network.connected && signalStrength) {
                network.signalStrength = signalStrength;
            }
        });
        
        // Sort: connected networks first, then by signal strength
        networks.sort(function(a, b) {
            // Connected networks always come first
            if (a.connected && !b.connected) return -1;
            if (!a.connected && b.connected) return 1;
            // If both connected or both not connected, sort by signal strength
            return b.signal - a.signal;
        });
        
        return networks;
    }

    // Force refresh of sortedWifiNetworks when networks are updated
    property int forceRefresh: 0
    
    Connections {
        target: NetworkService
        function onNetworksUpdated() {
            forceRefresh++;
        }
    }
    
    // Auto-enable WiFi auto-refresh when network tab is visible
    Component.onCompleted: {
        NetworkService.addRef();
        NetworkService.autoRefreshEnabled = true;
        if (NetworkService.wifiEnabled)
            NetworkService.scanWifi();
        // Start smart monitoring
        wifiMonitorTimer.start();
    }
    
    Component.onDestruction: {
        NetworkService.removeRef();
        NetworkService.autoRefreshEnabled = false;
    }

    // Two-column layout for WiFi and Ethernet (WiFi on left, Ethernet on right)
    Row {
        anchors.fill: parent
        spacing: Theme.spacingM

        // WiFi Column (left side)
        Column {
            width: (parent.width - Theme.spacingM) / 2
            height: parent.height
            spacing: Theme.spacingS

            // WiFi Content in Flickable
            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentWidth: width
                contentHeight: wifiContent.height
                boundsBehavior: Flickable.DragAndOvershootBounds
                flickDeceleration: 8000
                maximumFlickVelocity: 15000

                Column {
                    id: wifiContent
                    width: parent.width
                    spacing: Theme.spacingM

                    // Current WiFi connection status card
                    WiFiCard {
                        refreshTimer: refreshTimer
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }

        // Ethernet Column (right side)
        Column {
            width: (parent.width - Theme.spacingM) / 2
            height: parent.height
            spacing: Theme.spacingS

            // Ethernet Content in Flickable
            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentWidth: width
                contentHeight: ethernetContent.height
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 8000
                maximumFlickVelocity: 15000

                Column {
                    id: ethernetContent
                    width: parent.width
                    spacing: Theme.spacingM

                    // Ethernet connection status card (matching WiFi height)
                    EthernetCard {
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }

    // WiFi disabled message spanning across both columns
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "transparent"
        visible: !NetworkService.wifiEnabled

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "wifi_off"
                size: 48
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "WiFi is turned off"
                font.pixelSize: Theme.fontSizeLarge
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                font.weight: Font.Medium
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn on WiFi to see networks"
                font.pixelSize: Theme.fontSizeMedium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
            }
        }
    }

    // WiFi networks spanning across both columns when WiFi is enabled
    WiFiNetworksList {
        wifiContextMenuWindow: wifiContextMenuWindow
        sortedWifiNetworks: networkTab.sortedWifiNetworks
        wifiPasswordModalRef: networkTab.wifiPasswordModalRef
    }

    // Timer for refreshing network status after WiFi toggle
    Timer {
        id: refreshTimer
        interval: 2000
        running: visible && refreshTimer.triggered
        property bool triggered: false
        onTriggered: {
            NetworkService.refreshNetworkStatus();
            if (NetworkService.wifiEnabled && !NetworkService.isScanning) {
                NetworkService.scanWifi();
            }
            triggered = false;
        }
    }

    // Auto-refresh when WiFi state changes
    Connections {
        target: NetworkService
        function onWifiEnabledChanged() {
            if (NetworkService.wifiEnabled && visible) {
                // When WiFi is enabled, scan and update info (only if tab is visible)
                // Add a small delay to ensure WiFi service is ready
                wifiScanDelayTimer.start();
                // Start monitoring when WiFi comes back on
                wifiMonitorTimer.start();
            } else {
                // When WiFi is disabled, clear all cached WiFi data
                NetworkService.currentWifiSSID = "";
                NetworkService.wifiSignalStrength = "excellent";
                NetworkService.wifiNetworks = [];
                NetworkService.savedWifiNetworks = [];
                NetworkService.connectionStatus = "";
                NetworkService.connectingSSID = "";
                NetworkService.isScanning = false;
                NetworkService.refreshNetworkStatus();
                // Stop monitoring when WiFi is off
                wifiMonitorTimer.stop();
            }
        }
    }

    // Delayed WiFi scan timer to ensure service is ready
    Timer {
        id: wifiScanDelayTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            if (NetworkService.wifiEnabled && visible) {
                if (!NetworkService.isScanning) {
                    NetworkService.scanWifi();
                } else {
                    // If still scanning, try again in a bit
                    wifiRetryTimer.start();
                }
            }
        }
    }

    // Retry timer for when WiFi is still scanning
    Timer {
        id: wifiRetryTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            if (NetworkService.wifiEnabled && visible && NetworkService.wifiNetworks.length === 0) {
                if (!NetworkService.isScanning) {
                    NetworkService.scanWifi();
                }
            }
        }
    }

    // Smart WiFi monitoring - only runs when tab visible and conditions met
    Timer {
        id: wifiMonitorTimer
        interval: 8000 // Check every 8 seconds
        running: false
        repeat: true
        onTriggered: {
            if (!visible || !NetworkService.wifiEnabled) {
                // Stop monitoring when not needed
                running = false;
                return;
            }

            // Monitor connection changes and refresh networks when disconnected
            var shouldScan = false;
            var reason = "";

            // Always scan if not connected to WiFi
            if (NetworkService.networkStatus !== "wifi") {
                shouldScan = true;
                reason = "not connected to WiFi";
            }
            // Also scan occasionally even when connected to keep networks fresh
            else if (NetworkService.wifiNetworks.length === 0) {
                shouldScan = true;
                reason = "no networks cached";
            }

            if (shouldScan && !NetworkService.isScanning) {
                NetworkService.scanWifi();
            }
        }
    }

    // Monitor tab visibility to start/stop smart monitoring
    onVisibleChanged: {
        if (visible && NetworkService.wifiEnabled) {
            wifiMonitorTimer.start();
        } else {
            wifiMonitorTimer.stop();
        }
    }

    // WiFi Context Menu Window
    WiFiContextMenu {
        id: wifiContextMenuWindow
        parentItem: networkTab
        wifiPasswordModalRef: networkTab.wifiPasswordModalRef
        networkInfoModalRef: networkTab.networkInfoModalRef
    }

    // Background MouseArea to close the context menu
    MouseArea {
        anchors.fill: parent
        visible: wifiContextMenuWindow.visible
        onClicked: {
            wifiContextMenuWindow.hide();
        }

        MouseArea {
            x: wifiContextMenuWindow.x
            y: wifiContextMenuWindow.y
            width: wifiContextMenuWindow.width
            height: wifiContextMenuWindow.height
            onClicked: {
                // Prevent clicks on menu from closing it
            }
        }
    }
}