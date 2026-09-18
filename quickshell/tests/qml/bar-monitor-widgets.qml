import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar.Widgets
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

    property var barConfig: ({
            widgetPadding: 12,
            fontScale: 1,
            iconScale: 1
        })
    property var axes: [
        {
            isVertical: false,
            edge: "top"
        },
        {
            isVertical: true,
            edge: "left"
        }
    ]
    property var cases: [
        {
            name: "cpu",
            component: cpu,
            data: {}
        },
        {
            name: "cpu-nomin",
            component: cpu,
            data: {
                minimumWidth: false
            }
        },
        {
            name: "ram",
            component: ram,
            data: {}
        },
        {
            name: "ram-swap",
            component: ram,
            data: {
                showSwap: true
            }
        },
        {
            name: "ram-gb-swap",
            component: ram,
            data: {
                showInGb: true,
                showSwap: true
            }
        },
        {
            name: "ram-nomin",
            component: ram,
            data: {
                minimumWidth: false,
                showSwap: true
            }
        },
        {
            name: "cputemp",
            component: cpuTemp,
            data: {}
        },
        {
            name: "gputemp",
            component: gpuTemp,
            data: {
                pciId: "0000:01:00.0",
                selectedGpuIndex: 0
            }
        },
        {
            name: "gputemp-missing",
            component: gpuTemp,
            data: {
                pciId: "0000:01:00.0",
                selectedGpuIndex: 4
            }
        },
        {
            name: "disk",
            component: disk,
            data: {}
        },
        {
            name: "disk-size",
            component: disk,
            data: {
                diskUsageMode: 1
            }
        },
        {
            name: "disk-avail",
            component: disk,
            data: {
                diskUsageMode: 2
            }
        },
        {
            name: "disk-both",
            component: disk,
            data: {
                diskUsageMode: 3
            }
        },
        {
            name: "disk-home-nolabel",
            component: disk,
            data: {
                mountPath: "/home",
                showMountPath: false
            }
        },
        {
            name: "disk-nomin",
            component: disk,
            data: {
                minimumWidth: false
            }
        },
        {
            name: "disk-unknown",
            component: disk,
            data: {
                mountPath: "/nope"
            }
        }
    ]
    property var phases: [
        {
            name: "normal",
            cpu: 42,
            mem: 61,
            memMb: 12345,
            temp: 55.4,
            gpu: 48.2,
            disk: "63%"
        },
        {
            name: "warn",
            cpu: 70,
            mem: 80,
            memMb: 30000,
            temp: 75,
            gpu: 70,
            disk: "80%"
        },
        {
            name: "danger",
            cpu: 95,
            mem: 95,
            memMb: 60000,
            temp: 90,
            gpu: 85,
            disk: "95%"
        },
        {
            name: "zero",
            cpu: 0,
            mem: 0,
            memMb: 0,
            temp: -1,
            gpu: 0,
            disk: "0%"
        }
    ]
    property var instances: []
    property int phase: 0

    Component {
        id: cpu
        CpuMonitor {}
    }
    Component {
        id: ram
        RamMonitor {}
    }
    Component {
        id: cpuTemp
        CpuTemperature {}
    }
    Component {
        id: gpuTemp
        GpuTemperature {}
    }
    Component {
        id: disk
        DiskUsage {}
    }

    Item {
        id: stage
        width: 800
        height: 800
    }

    function applyPhase(p) {
        DgopService.cpuUsage = p.cpu;
        DgopService.memoryUsage = p.mem;
        DgopService.usedMemoryMB = p.memMb;
        DgopService.totalSwapKB = 8000000;
        DgopService.usedSwapKB = 1200000;
        DgopService.cpuTemperature = p.temp;
        DgopService.availableGpus = [
            {
                pciId: "0000:01:00.0",
                temperature: p.gpu
            }
        ];
        DgopService.diskMounts = [
            {
                mount: "/",
                percent: p.disk,
                size: "500G",
                avail: "180G"
            },
            {
                mount: "/home",
                percent: "20%",
                size: "1T",
                avail: "800G"
            }
        ];
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function dump(item, origin) {
        const pos = item.mapToItem(origin, 0, 0);
        const entry = {
            type: typeName(item),
            x: Math.round(pos.x * 100) / 100,
            y: Math.round(pos.y * 100) / 100,
            w: item.width,
            h: item.height,
            iw: item.implicitWidth,
            ih: item.implicitHeight
        };
        if (typeof item.text === "string" && item.font !== undefined) {
            entry.text = item.text;
            entry.px = item.font.pixelSize;
            entry.color = String(item.color);
            entry.halign = item.horizontalAlignment;
        }
        entry.children = (item.children || []).filter(child => child.visible).map(child => dump(child, origin));
        return entry;
    }

    function leaves(tree, out) {
        if (tree.text !== undefined)
            out.push(tree);
        for (const child of tree.children)
            leaves(child, out);
        return out;
    }

    function textOf(tree) {
        return leaves(tree, []).map(leaf => leaf.text).join("|");
    }

    property var cpuIconColors: ({})

    function verify(phaseName, instance, tree) {
        const text = textOf(tree);
        const axis = instance.vertical ? "v" : "h";
        const expected = {
            normal: {
                cpu: {
                    h: "42%",
                    v: "42"
                },
                cputemp: {
                    h: "55°",
                    v: "55"
                },
                gputemp: {
                    h: "48°",
                    v: "48"
                },
                "gputemp-missing": {
                    h: "--°",
                    v: "--"
                },
                disk: {
                    h: "63%",
                    v: "63"
                },
                "disk-unknown": {
                    h: "63%",
                    v: "63"
                },
                "ram-gb-swap": {
                    h: "12.1 GB · 15%",
                    v: "12.1|15"
                }
            },
            zero: {
                cpu: {
                    h: "--%",
                    v: "--"
                },
                cputemp: {
                    h: "--°",
                    v: "--"
                },
                disk: {
                    h: "--%",
                    v: "--"
                },
                "ram-gb-swap": {
                    h: "-- GB",
                    v: "--"
                }
            }
        };
        const want = expected[phaseName]?.[instance.name]?.[axis];
        if (want !== undefined)
            check(text.includes(want), phaseName + " " + instance.name + " " + axis + " expected '" + want + "' in '" + text + "'");
        if (instance.name === "cpu") {
            const icon = leaves(tree, []).find(leaf => leaf.text === "memory");
            check(icon !== undefined, phaseName + " cpu icon present");
            root.cpuIconColors[phaseName + axis] = icon?.color;
        }
    }

    function snapshot() {
        const phaseName = root.phases[root.phase].name;
        const widths = {};
        for (const instance of root.instances) {
            const item = instance.item;
            const tree = dump(item.visualContent, item.visualContent);
            verify(phaseName, instance, tree);
            widths[instance.name + (instance.vertical ? "v" : "h")] = instance.vertical ? item.height : item.width;
            const record = {
                phase: phaseName,
                name: instance.name,
                vertical: instance.vertical,
                w: item.width,
                h: item.height,
                visualW: item.visualWidth,
                visualH: item.visualHeight,
                tree: tree
            };
            console.log("PARITY " + JSON.stringify(record));
        }
        check(widths["cpu-nominh"] <= widths.cpuh, phaseName + " minimumWidth reserves space horizontally");
        if (phaseName !== "zero")
            return;
        for (const axis of ["h", "v"]) {
            const colors = ["normal", "warn", "danger"].map(name => root.cpuIconColors[name + axis]);
            check(colors[0] !== colors[1] && colors[1] !== colors[2] && colors[0] !== colors[2], "cpu icon color changes across normal/warn/danger " + axis + ": " + colors.join(","));
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        applyPhase(root.phases[0]);
        const created = [];
        let y = 0;
        for (const axis of root.axes) {
            for (const testCase of root.cases) {
                const item = testCase.component.createObject(stage, {
                    axis: axis,
                    barThickness: 48,
                    widgetThickness: 30,
                    barConfig: root.barConfig,
                    widgetData: testCase.data,
                    y: y
                });
                y += 60;
                created.push({
                    name: testCase.name,
                    vertical: axis.isVertical,
                    item: item
                });
            }
        }
        root.instances = created;
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: {
            root.snapshot();
            root.phase++;
            if (root.phase >= root.phases.length) {
                root.finish();
                stop();
                Qt.quit();
                return;
            }
            root.applyPhase(root.phases[root.phase]);
        }
    }
}
