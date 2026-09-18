import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false
    property int step: 0

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function collect(item, origin, out) {
        const kids = (item.children || []).filter(child => child.visible && child.width > 0 && child.height > 0);
        const paints = item.color !== undefined || (typeof item.text === "string" && item.font !== undefined);
        if (paints || kids.length === 0) {
            const pos = item.mapToItem(origin, 0, 0);
            const entry = {
                type: typeName(item),
                x: Math.round(pos.x * 100) / 100,
                y: Math.round(pos.y * 100) / 100,
                w: Math.round(item.width * 100) / 100,
                h: Math.round(item.height * 100) / 100
            };
            if (typeof item.text === "string" && item.font !== undefined) {
                entry.text = item.text;
                entry.px = item.font.pixelSize;
            }
            if (item.color !== undefined)
                entry.color = String(item.color);
            out.push(entry);
        }
        for (const child of kids)
            collect(child, origin, out);
    }

    function findAll(item, pred, out) {
        if (pred(item))
            out.push(item);
        for (const child of item.children || [])
            findAll(child, pred, out);
        return out;
    }

    function snapshot(label) {
        for (const pair of [["plain", plain], ["rows", rows]]) {
            const nodes = [];
            collect(pair[1], host, nodes);
            console.log("PARITY " + JSON.stringify({
                label: label,
                name: pair[0],
                items: pair[1].items,
                saves: host.saves,
                nodes: nodes
            }));
        }
    }

    PanelWindow {
        id: win
        implicitWidth: 640
        implicitHeight: 600
        color: "transparent"

        Item {
            id: host
            anchors.fill: parent
            property var store: ({
                    "plain": ["alpha", "beta"],
                    "rows": [
                        {
                            "name": "Docs",
                            "url": "https://docs"
                        }
                    ]
                })
            property var saves: []

            function loadValue(key, fallback) {
                return store[key] !== undefined ? store[key] : fallback;
            }

            function saveValue(key, value) {
                saves = saves.concat([key + "=" + JSON.stringify(value)]);
            }

            Column {
                width: parent.width - 32
                x: 16
                y: 16
                spacing: 24

                ListSetting {
                    id: plain
                    settingKey: "plain"
                    label: "Blocked words"
                    description: "Words to hide"
                }

                ListSettingWithInput {
                    id: rows
                    settingKey: "rows"
                    label: "Bookmarks"
                    description: "Name and address"
                    fields: [
                        {
                            "id": "name",
                            "label": "Name",
                            "width": 140,
                            "required": true
                        },
                        {
                            "id": "url",
                            "label": "URL",
                            "placeholder": "https://",
                            "width": 260
                        }
                    ]
                }
            }
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.snapshot("loaded");
                check(JSON.stringify(plain.items) === JSON.stringify(["alpha", "beta"]), "plain list loads stored items");
                check(JSON.stringify(rows.items) === JSON.stringify([
                    {
                        "name": "Docs",
                        "url": "https://docs"
                    }
                ]), "row list loads stored items");
                check(host.saves.length === 0, "loading does not write back " + JSON.stringify(host.saves));
                plain.addItem("gamma");
                plain.removeItem(0);
                return;
            case 1:
                root.snapshot("edited");
                check(JSON.stringify(plain.items) === JSON.stringify(["beta", "gamma"]), "plain add/remove");
                check(JSON.stringify(host.saves) === JSON.stringify(["plain=[\"alpha\",\"beta\",\"gamma\"]", "plain=[\"beta\",\"gamma\"]"]), "plain saves " + JSON.stringify(host.saves));
                const inputs = root.findAll(rows, item => item.placeholderText !== undefined && item.text !== undefined && root.typeName(item) === "DankTextField", []);
                const button = root.findAll(rows, item => root.typeName(item) === "DankButton", [])[0];
                check(inputs.length === 2 && !!button, "row input fields and add button present");
                inputs[1].text = "https://x";
                button.clicked();
                check(rows.items.length === 1, "required name blocks add");
                inputs[0].text = "X";
                button.clicked();
                return;
            case 2:
                root.snapshot("added");
                check(JSON.stringify(rows.items) === JSON.stringify([
                    {
                        "name": "Docs",
                        "url": "https://docs"
                    },
                    {
                        "name": "X",
                        "url": "https://x"
                    }
                ]), "row add " + JSON.stringify(rows.items));
                const fields = root.findAll(rows, item => item.placeholderText !== undefined && item.text !== undefined && root.typeName(item) === "DankTextField", []);
                check(fields.every(field => field.text === ""), "inputs cleared after add");
                rows.removeItem(0);
                plain.removeItem(0);
                plain.removeItem(0);
                return;
            case 3:
                root.snapshot("emptied");
                check(plain.items.length === 0 && rows.items.length === 1, "removals applied");
                root.finish();
                stop();
                Qt.quit();
            }
        }
    }
}
