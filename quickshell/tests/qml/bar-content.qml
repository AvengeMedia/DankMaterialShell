import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankBar
import qs.Modules.SurfaceWidgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function hosts(section) {
        const found = [];
        function visit(item) {
            if (item.sectionContext !== undefined)
                found.push(item);
            for (const child of item.children || [])
                visit(child);
        }
        visit(section);
        return found;
    }

    function texts(item) {
        if (!item.visible)
            return [];
        if (typeof item.text === "string")
            return [item.text];
        return (item.children || []).reduce((result, child) => result.concat(texts(child)), []);
    }

    property var retainedClockItem: null

    property var axis: ({
            isVertical: false,
            edge: "top"
        })
    property var entries: [
        {
            widgetId: "clock",
            id: "clock_0",
            testWidth: 30,
            testHeight: 22,
            enabled: true
        },
        {
            widgetId: "clock",
            id: "clock_1",
            testWidth: 80,
            testHeight: 30,
            enabled: false
        },
        {
            widgetId: "clock",
            id: "clock_2",
            testWidth: 60,
            testHeight: 44,
            enabled: true
        }
    ]
    ScriptModel {
        id: widgets
        values: root.entries
    }
    property var components: ({
            clock: mockWidget,
            spacer: mockWidget
        })

    Component {
        id: mockWidget
        Item {
            property var widgetData: null
            property var surfaceContext: null
            property string widgetInstanceId: ""
            property bool surfaceLive: true
            property var axis: null
            property var parentScreen: null
            property string section: ""
            property real widgetThickness: 0
            property real barThickness: 0
            property real barSpacing: 0
            property var barConfig: null
            property var blurBarWindow: null
            property bool isFirst: false
            property bool isLast: false
            property real sectionSpacing: 0
            property real sectionAvailablePrimarySize: 0
            property bool isLeftBarEdge: false
            property bool isRightBarEdge: false
            property bool isTopBarEdge: false
            property bool isBottomBarEdge: false
            property real crossEdgeExtension: 0
            property string segmentRole: "solo"
            width: axis?.isVertical ? widgetThickness : (widgetData?.testWidth ?? 0)
            height: axis?.isVertical ? (widgetData?.testHeight ?? 0) : widgetThickness
        }
    }

    Component {
        id: pluginWidget
        Item {
            property var axis: null
            readonly property bool isVertical: axis?.isVertical ?? false
            property var widgetData: null
            property var parentScreen: null
            property var pluginService: null
            property var popoutService: null
            property string pluginId: ""
            property var variantId: null
            property var variantData: null
            signal clicked
            width: 20
            height: 20
        }
    }

    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 700

        Loader {
            id: pluginContainer
            sourceComponent: SurfaceWidgetHost {
                widgetId: "fixture:variant"
                components: PluginService.getWidgetComponents()
                axis: root.axis
                isInColumn: root.axis.isVertical
                parentScreen: ({
                        name: "fixture"
                    })
                widgetData: ({
                        enabled: true,
                        payload: 42
                    })
            }
        }

        LeftSection {
            id: left
            width: 600
            height: 80
            axis: root.axis
            widgetsModel: widgets
            components: root.components
            surfaceContext: ({
                    kind: "bar",
                    id: "fixture",
                    live: false
                })
            parentScreen: ({
                    name: "fixture"
                })
            widgetThickness: 32
            barThickness: 48
            barSpacing: 6
            barConfig: ({
                    id: "fixture",
                    widgetOutlineEnabled: true,
                    widgetOutlineThickness: 2,
                    widgetStyle: "segments"
                })
            sectionAvailablePrimarySize: 500
            crossEdgeExtension: 7
        }
        RightSection {
            id: right
            y: 90
            width: 600
            height: 80
            axis: root.axis
            widgetsModel: widgets
            components: root.components
            barConfig: ({
                    id: "fixture",
                    widgetStyle: "segments"
                })
            crossEdgeExtension: 7
        }
        Item {
            y: 180
            width: 600
            height: 300
            CenterSection {
                id: center
                axis: root.axis
                widgetsModel: widgets
                components: root.components
                barConfig: ({
                        id: "fixture",
                        widgetStyle: "segments"
                    })
            }
        }
        ClockContent {
            id: clock
            y: 500
            date: new Date(2026, 8, 9, 0, 5, 9)
            locale: Qt.locale("en_US")
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 0
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        onTriggered: {
            PluginService.availablePlugins = {
                fixture: {
                    id: "fixture"
                }
            };
            SettingsData.setPluginSetting("fixture", "variants", [
                {
                    id: "variant",
                    payload: 17
                }
            ]);
            PluginService.pluginWidgetComponents = {
                fixture: pluginWidget
            };
            SettingsData.centeringMode = "geometric";
            SettingsData.clockDateFormat = "";
            SettingsData.clockFormat = "24h";
            SettingsData.showSeconds = true;
            checks.start();
        }
    }

    Timer {
        id: checks
        interval: 150
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                const leftHosts = root.hosts(left);
                const rightHosts = root.hosts(right);
                const centerHosts = root.hosts(center);
                root.check(leftHosts.length === 3 && rightHosts.length === 3 && centerHosts.length === 3, "all sections load each occurrence");
                const first = leftHosts[0].item;
                const last = leftHosts[2].item;
                root.check((leftHosts[1].item !== null) === (step >= 8) && last.isLast && first.isFirst, "enabled and boundary injection");
                root.check(first.section === "left" && rightHosts[0].item.section === "right" && centerHosts[0].item.section === "center", "section injection");
                root.check(first.widgetThickness === left.widgetThickness && first.barThickness === 48 && first.barSpacing === 6 && first.parentScreen.name === "fixture" && first.sectionAvailablePrimarySize === 500 && first.barConfig.id === "fixture", "host context injection");
                root.check(first.surfaceContext === left.surfaceContext && first.widgetInstanceId === "clock_0" && first.surfaceLive === (step >= 8), "surface context and instance injection");
                switch (step++) {
                case 0:
                    const plugin = pluginContainer.item.item;
                    root.check(plugin.pluginService === PluginService && plugin.popoutService === PopoutService, "plugin service injection");
                    root.check(plugin.pluginId === "fixture" && plugin.variantId === "variant" && plugin.variantData.payload === 17 && plugin.widgetData.payload === 42, "plugin variant and widget metadata");
                    root.check(BarWidgetService.getWidget("fixture:variant", "fixture") === plugin, "plugin registration");
                    root.check(BarWidgetService.getWidget("clock", "fixture", "bar:fixture:left:clock_0") === first && BarWidgetService.getWidget("clock", "fixture", "bar:fixture:left:clock_2") === last, "duplicate widget instance registration");
                    root.check(first.isLeftBarEdge && rightHosts[2].item.isRightBarEdge && first.crossEdgeExtension === 7, "horizontal edge injection");
                    root.check(first.segmentRole === "first" && last.segmentRole === "last" && centerHosts[0].item.segmentRole === "first" && centerHosts[2].item.segmentRole === "last", "segment roles skip the hidden middle occurrence");
                    root.check(left.widgetSpacing === 6 && left.segmented, "segments spacing adds the outline");
                    root.check(clock.timeText === "00:05:09" && clock.dateText === "Wed 9", "default 24-hour time and date");
                    SettingsData.clockFormat = "12h";
                    SettingsData.padHours12Hour = false;
                    break;
                case 1:
                    root.check(clock.timeText === "12:05:09 AM", "midnight in 12-hour time");
                    clock.date = new Date(2026, 8, 9, 7, 5, 9);
                    SettingsData.showSeconds = false;
                    break;
                case 2:
                    root.check(clock.timeText === "7:05 AM", "unpadded hours and hidden seconds");
                    SettingsData.padHours12Hour = true;
                    SettingsData.clockDateFormat = "yyyy/MM/dd 'custom'";
                    clock.vertical = true;
                    root.axis = {
                        isVertical: true,
                        edge: "left"
                    };
                    break;
                case 3:
                    root.check(pluginContainer.item.item.isVertical && pluginContainer.item.item.parentScreen.name === "fixture", "readonly plugin orientation and optional properties");
                    root.check(clock.timeText === "07:05 AM" && clock.timeLines.join("|") === "07|05|AM", "vertical uses the same padding and period, got " + clock.timeText + " / " + clock.timeLines.join("|"));
                    root.check(clock.dateText === "2026/09/09 custom", "custom date preserved vertically");
                    root.check(first.isTopBarEdge && !first.isLeftBarEdge && first.crossEdgeExtension === 0 && rightHosts[2].item.isBottomBarEdge, "vertical edge injection");
                    left.edgeIsScreenEdge = false;
                    SettingsData.showSeconds = true;
                    clock.date = new Date(2026, 8, 9, 12, 5, 9);
                    break;
                case 4:
                    root.check(!first.isTopBarEdge, "edge changes remain bound");
                    root.check(clock.timeText === "12:05:09 PM" && clock.timeLines.join("|") === "12|05|09|PM", "noon and vertical seconds");
                    for (const locale of ["en_US", "de_DE", "fr_FR", "ar_EG", "zh_CN"]) {
                        clock.locale = Qt.locale(locale);
                        SettingsData.clockDateFormat = "dddd d MMMM yyyy";
                        root.check(clock.dateText === clock.date.toLocaleDateString(Qt.locale(locale), "dddd d MMMM yyyy"), locale + " custom date");
                        root.check(clock.timeText === clock.date.toLocaleTimeString(Qt.locale(locale), "hh:mm:ss AP"), locale + " time");
                    }
                    clock.locale = Qt.locale("en_US");
                    SettingsData.clockDateFormat = "";
                    clock.vertical = false;
                    clock.displayMode = "time";
                    break;
                case 5:
                    root.check(root.texts(clock).join("|") === "12:05:09 PM", "time-only presentation");
                    clock.displayMode = "date";
                    break;
                case 6:
                    root.check(root.texts(clock).join("|") === "Wed 9", "date-only presentation");
                    clock.displayMode = "both";
                    clock.dateFirst = true;
                    break;
                case 7:
                    root.check(root.texts(clock).join("|") === "Wed 9|•|12:05:09 PM", "date-first presentation");
                    left.widgetThickness = 36;
                    left.surfaceContext = {
                        kind: "bar",
                        id: "fixture",
                        live: true
                    };
                    root.entries = root.entries.map(entry => Object.assign({}, entry, {
                            enabled: true
                        }));
                    break;
                case 8:
                    root.check(leftHosts[1].item.visible && first.widgetThickness === 36, "enabled and context updates remain bound");
                    root.check(first.segmentRole === "first" && leftHosts[1].item.segmentRole === "middle" && last.segmentRole === "last" && centerHosts[1].item.segmentRole === "middle", "segment roles after enabling the middle occurrence");
                    left.barConfig = {
                        id: "fixture",
                        widgetOutlineEnabled: true,
                        widgetOutlineThickness: 2,
                        widgetStyle: "pills"
                    };
                    function findTime(item) {
                        if (typeof item.reserveText === "string" && item.text === clock.timeText)
                            return item;
                        for (const child of item.children || []) {
                            const found = findTime(child);
                            if (found)
                                return found;
                        }
                        return null;
                    }
                    pluginContainer.active = false;
                    root.retainedClockItem = findTime(clock);
                    clock.date = new Date(2026, 8, 9, 12, 5, 10);
                    break;
                case 9:
                    root.check(!BarWidgetService.getWidget("fixture:variant", "fixture"), "plugin host teardown unregisters its widget");
                    root.check(root.retainedClockItem && root.retainedClockItem.text === "12:05:10 PM", "clock ticks update retained text items");
                    root.check(!left.segmented && first.segmentRole === "solo" && leftHosts[1].item.segmentRole === "solo" && last.segmentRole === "solo" && left.widgetSpacing === 8, "pills style keeps every widget solo");
                    left.barConfig = {
                        id: "fixture",
                        widgetOutlineEnabled: true,
                        widgetOutlineThickness: 2,
                        widgetStyle: "segments"
                    };
                    root.entries = [root.entries[0],
                        {
                            widgetId: "spacer",
                            id: "spacer_1",
                            testWidth: 10,
                            testHeight: 10,
                            enabled: true
                        },
                        root.entries[2]];
                    break;
                case 10:
                    root.check(first.segmentRole === "solo" && leftHosts[1].item.segmentRole === "solo" && last.segmentRole === "solo" && centerHosts[2].item.segmentRole === "solo", "a spacer breaks the run");
                    console.log("FIXTURE_PASS");
                    stop();
                    Qt.quit();
                }
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
