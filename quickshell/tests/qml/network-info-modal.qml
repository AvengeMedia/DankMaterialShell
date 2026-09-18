import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modals
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

    property var modals: []
    property int step: 0

    Component {
        id: infoModal
        NetworkInfoModal {}
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function texts(modal) {
        const content = modal.contentLoader?.item;
        if (!content)
            return [];
        const out = [];
        const walk = tree => {
            if (tree.text !== undefined)
                out.push(tree.text);
            for (const child of tree.children)
                walk(child);
        };
        walk(dump(content, content));
        return out;
    }

    function dump(item, origin) {
        const pos = item.mapToItem(origin, 0, 0);
        const entry = {
            type: typeName(item),
            x: Math.round(pos.x * 100) / 100,
            y: Math.round(pos.y * 100) / 100,
            w: item.width,
            h: item.height
        };
        if (typeof item.text === "string" && item.font !== undefined) {
            entry.text = item.text;
            entry.px = item.font.pixelSize;
        }
        if (item.color !== undefined)
            entry.color = String(item.color);
        entry.children = (item.children || []).filter(child => child.visible).map(child => dump(child, origin));
        return entry;
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        NetworkService.networkInfoDetails = "SSID: Home\\nSignal: 80%";
        NetworkService.networkWiredInfoDetails = "Interface: eth0\\nSpeed: 1000";
        const wifi = infoModal.createObject(root);
        const wired = infoModal.createObject(root, {
            wired: true
        });
        root.modals = [
            {
                name: "wifi",
                item: wifi
            },
            {
                name: "wired",
                item: wired
            }
        ];
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.modals[0].item.showNetworkInfo("Home WiFi", {
                    ssid: "Home WiFi"
                });
                return;
            case 1:
                for (const modal of root.modals) {
                    const content = modal.item.contentLoader?.item;
                    console.log("PARITY " + JSON.stringify({
                        name: modal.name,
                        visible: modal.item.visible,
                        namespace: modal.item.layerNamespace,
                        w: modal.item.alignedWidth,
                        h: modal.item.alignedHeight,
                        tree: content ? dump(content, content) : null
                    }));
                }
                check(root.modals[0].item.networkInfoModalVisible && !root.modals[1].item.networkInfoModalVisible, "only the wifi modal is open");
                check(texts(root.modals[0].item).includes('Details for "Home WiFi"') && texts(root.modals[0].item).includes("SSID: Home\nSignal: 80%"), "wifi modal shows name and details: " + texts(root.modals[0].item));
                root.modals[0].item.hideDialog();
                root.modals[1].item.showNetworkInfo("Wired connection 1", {
                    uuid: "1234"
                });
                return;
            case 2:
                for (const modal of root.modals) {
                    const content = modal.item.contentLoader?.item;
                    console.log("PARITY " + JSON.stringify({
                        name: modal.name + "-2",
                        visible: modal.item.visible,
                        namespace: modal.item.layerNamespace,
                        w: modal.item.alignedWidth,
                        h: modal.item.alignedHeight,
                        tree: content ? dump(content, content) : null
                    }));
                }
                check(!root.modals[0].item.networkInfoModalVisible && root.modals[1].item.networkInfoModalVisible, "only the wired modal is open");
                check(texts(root.modals[1].item).includes('Details for "Wired connection 1"') && texts(root.modals[1].item).includes("Interface: eth0\nSpeed: 1000"), "wired modal shows connection name and details: " + texts(root.modals[1].item));
                check(root.modals[0].item.layerNamespace !== root.modals[1].item.layerNamespace, "wifi and wired use distinct layer namespaces");
                root.modals[1].item.hideDialog();
                return;
            default:
                root.finish();
                stop();
                Qt.quit();
            }
        }
    }
}
