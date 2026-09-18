import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var tab: null
    readonly property int pageHeight: 1800

    Component {
        id: tabComponent
        NetworkWifiTab {}
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 1800
        anchors {
            top: true
            left: true
        }

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function collect(item, out) {
        if (!item.visible)
            return out;
        switch (typeName(item)) {
        case "DankIcon":
            out.icons.push(item.name);
            return out;
        case "StyledText":
            out.texts.push(item.text);
            break;
        case "DankToggle":
            out.toggles.push(item.checked);
            break;
        case "DankDropdown":
            out.dropdowns.push(item.currentValue);
            break;
        }
        if (out.contentHeight < 0 && item.contentHeight !== undefined && item.contentItem !== undefined) {
            out.contentHeight = Math.round(item.contentHeight);
            const column = item.contentItem.children[0];
            out.sections = Array.from(column?.children ?? []).filter(child => child.visible && child.height > 0).map(child => Math.round(child.height));
        }
        for (const child of item.children || [])
            collect(child, out);
        return out;
    }

    property var states: []

    function snapshot() {
        const layout = collect(root.tab, {
            texts: [],
            icons: [],
            toggles: [],
            dropdowns: [],
            contentHeight: -1
        });
        layout.implicitHeight = Math.round(root.tab.implicitHeight);
        return layout;
    }

    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children || []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function has(name, state, texts) {
        for (const text of texts)
            check(state.texts.includes(text), name + " missing text '" + text + "'");
    }

    function lacks(name, state, texts) {
        for (const text of texts)
            check(!state.texts.includes(text), name + " still shows '" + text + "'");
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
        Qt.quit();
    }

    function verify(states) {
        check(states.length === 2, "network captured two states, got " + states.length);
        const [expanded, scanning] = states;
        has("network expanded", expanded, ["HomeNet", "wlan0", "192.168.1.20", "70%", "Available networks", "3", "Connected • Saved • 70%", "5.2 GHz", "36", "866 Mbps", "aa:bb:cc:dd:ee:ff", "WPA/WPA2", "Autoconnect", "CoffeeShop", "Open • 40%", "Hidden5G", "Secured • Saved • Hidden • 20%", "Saved networks", "OldCabin", "Secured • 0%", "Hotspot", "Hotspot name", "Save & Start"]);
        check(expanded.dropdowns.length === 3 && expanded.dropdowns.every(value => value === "Auto"), "device and band dropdowns default to Auto, got " + JSON.stringify(expanded.dropdowns));
        has("network scanning", scanning, ["Scanning...", "0", "Saved networks", "DankHotspot", "WPA2 password • 5 GHz", "Edit", "Start"]);
        lacks("network scanning", scanning, ["CoffeeShop", "Open • 40%", "Save & Start", "Hotspot name"]);
        check(scanning.contentHeight < expanded.contentHeight, "empty scan list shrinks the page");
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            if (step++ === 0) {
                Quickshell.watchFiles = false;
                DC.Style.theme = Theme;
                DC.Style.settings = SettingsData;
                DC.I18n.backend = I18n;
                DMSService.apiVersion = 20;
                NetworkService.backend = "networkmanager";
                NetworkService.wifiEnabled = true;
                NetworkService.wifiToggling = false;
                NetworkService.wifiConnected = true;
                NetworkService.currentWifiSSID = "HomeNet";
                NetworkService.wifiInterface = "wlan0";
                NetworkService.wifiIP = "192.168.1.20";
                NetworkService.wifiSignalStrength = 70;
                NetworkService.wifiDevices = [
                    {
                        name: "wlan0",
                        apCapable: true
                    },
                    {
                        name: "wlan1",
                        apCapable: true
                    }
                ];
                NetworkService.wifiNetworks = [
                    {
                        ssid: "HomeNet",
                        signal: 70,
                        secured: true,
                        saved: true,
                        autoconnect: true,
                        frequency: 5180,
                        channel: 36,
                        rate: 866,
                        mode: "infra",
                        bssid: "aa:bb:cc:dd:ee:ff"
                    },
                    {
                        ssid: "CoffeeShop",
                        signal: 40,
                        secured: false,
                        saved: false
                    },
                    {
                        ssid: "Hidden5G",
                        signal: 20,
                        secured: true,
                        saved: true,
                        hidden: true
                    }
                ];
                NetworkService.savedWifiNetworks = [
                    {
                        ssid: "HomeNet",
                        autoconnect: true
                    },
                    {
                        ssid: "Hidden5G",
                        hidden: true
                    },
                    {
                        ssid: "OldCabin",
                        secured: true
                    }
                ];
                NetworkService.hotspotAvailable = true;
                NetworkService.hotspotConfigured = false;
                root.tab = tabComponent.createObject(stage, {
                    width: stage.width,
                    height: root.pageHeight
                });
                if (!root.tab) {
                    console.error("FIXTURE_FAIL " + tabComponent.errorString());
                    Qt.quit();
                }
                return;
            }
            if (step === 2) {
                const wifiCard = root.find(root.tab, item => item.expandedWifiSsid !== undefined);
                const savedCard = root.find(root.tab, item => item.savedNetworks !== undefined);
                wifiCard.expandedWifiSsid = "HomeNet";
                wifiCard.expandedSavedWifiSsid = "Hidden5G";
                savedCard.expanded = true;
                return;
            }
            root.states.push(root.snapshot());
            if (step === 3) {
                NetworkService.hotspotConfigured = true;
                NetworkService.hotspotSSID = "DankHotspot";
                NetworkService.hotspotSecured = true;
                NetworkService.hotspotBand = "a";
                NetworkService.isScanning = true;
                NetworkService.wifiNetworks = [];
                return;
            }
            stop();
            root.verify(root.states);
            root.finish();
        }
    }
}
