import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.DankCommon.Common as DC
import "Modules/DankBar/WidgetModel.js" as WidgetModel

ShellRoot {
    id: root

    property real barLength: 600
    property real titleWidth: 80
    property bool vertical: false
    property bool fitted: false
    property var retainedItem: null
    property var openSurface: null
    property var retainedRegistration: null
    property var config: ({
        id: "overflow-fixture", enabled: true, visible: true, position: vertical ? 2 : 0,
        innerPadding: 4, widgetPadding: 8, spacing: 4, popupGapsAuto: true,
        widgetStyle: "segments", leftOverflowPosition: 1, leftOverflowMode: "auto",
        leftWidgets: [
            { id: "clock", testWidth: 100, overflowMode: "bar" },
            { id: "fixture:variant", testWidth: 40, overflowMode: "always", collapses: true },
            { id: "clock", dynamic: true }
        ],
        centerWidgets: [{ id: "clock", testWidth: 20, overflowMode: "always" }, { id: "clock", testWidth: 80 }, { id: "clock", testWidth: 30 }],
        rightWidgets: [{ id: "clock", testWidth: 50 }]
    })

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }
    function section() { return vertical ? bar.vLeftSection : bar.hLeftSection; }
    function automatic() { return section().entryRepeater.itemAt(2); }

    QtObject {
        id: fixtureAxis
        readonly property bool isVertical: root.vertical
        readonly property string edge: root.vertical ? "left" : "top"
    }
    QtObject {
        id: fixtureBarWindow
        readonly property var screen: window.screen
        readonly property var axis: fixtureAxis
        readonly property var hostWindow: window
        readonly property bool isVertical: root.vertical
        readonly property bool fitToWidgets: root.fitted
        readonly property bool usesFrameBarChrome: false
        readonly property bool hostsIsland: false
        readonly property bool hasAdjacentTopBar: false
        readonly property bool hasAdjacentBottomBar: false
        readonly property bool hasAdjacentLeftBar: false
        readonly property bool hasAdjacentRightBar: false
        readonly property real effectiveBarThickness: 48
        readonly property real widgetThickness: 32
        readonly property real fittedAvailableLength: root.barLength
        readonly property real lengthPaddingStartPx: 0
        readonly property real width: window.width
        readonly property real height: window.height
        readonly property string screenName: window.screen.name
    }
    ScriptModel {
        id: leftModel
        values: WidgetModel.normalize(root.config.leftWidgets)
        objectProp: "id"
    }
    ScriptModel {
        id: centerModel
        values: WidgetModel.normalize(root.config.centerWidgets)
        objectProp: "id"
    }
    ScriptModel {
        id: rightModel
        values: WidgetModel.normalize(root.config.rightWidgets)
        objectProp: "id"
    }
    Component {
        id: widget
        Rectangle {
            property var widgetData: null
            property var surfaceContext: null
            property var axis: null
            property bool surfaceLive: true
            property string widgetInstanceId: ""
            property string segmentRole: "solo"
            property real barThickness: 0
            readonly property real naturalSize: widgetData?.dynamic ? root.titleWidth : (widgetData?.collapses && root.titleWidth === 0 ? 0 : (widgetData?.testWidth ?? 0))
            width: axis?.isVertical ? barThickness : naturalSize
            height: axis?.isVertical ? naturalSize : barThickness
            color: Theme.primary
        }
    }
    PanelWindow {
        id: window
        visible: true
        anchors.top: true
        anchors.left: true
        implicitWidth: root.vertical ? 48 : root.barLength
        implicitHeight: root.vertical ? root.barLength : 48
        WlrLayershell.namespace: "dms:test-bar-overflow"
        DankBarContent {
            id: bar
            barWindow: fixtureBarWindow
            rootWindow: window
            barConfig: root.config
            leftWidgetsModel: leftModel
            centerWidgetsModel: centerModel
            rightWidgetsModel: rightModel
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        for (const section of [bar.hLeftSection, bar.hCenterSection, bar.hRightSection, bar.vLeftSection, bar.vCenterSection, bar.vRightSection])
            section.components = { clock: widget, fixture: widget };
    }
    Timer {
        interval: 0
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        onTriggered: {
            SettingsData.barConfigs = [root.config];
            SettingsData.centeringMode = "index";
            checks.start();
        }
    }
    Timer {
        id: checks
        interval: 16
        repeat: true
        property int step: 0
        property real stepStarted: 0
        onTriggered: {
            if (!stepStarted)
                stepStarted = Date.now();
            try {
                const section = root.section();
                const automatic = root.automatic();
                root.check(automatic?.item && (step === 8 || section.overflowButton), "widget and holder loaded");
                const center = root.vertical ? bar.vCenterSection : bar.hCenterSection;
                const clock = center.entryRepeater.itemAt(1);
                if (!root.fitted)
                    root.check(clock && Math.abs((root.vertical ? clock.y + clock.height / 2 - center.height / 2 : clock.x + clock.width / 2 - center.width / 2)) < 0.01, "the center holder preserves the configured clock anchor");
                switch (step) {
                case 0:
                    root.check(!automatic.inOverflow && section.hiddenEntries.length === 1, "only the always-overflow occurrence is hidden");
                    root.check(automatic.host.height === 48 && automatic.host.y === 0 && automatic.slot.parent === automatic, "inline widgets sit centered in their wrapper: " + JSON.stringify([automatic.host.y, automatic.host.height, automatic.height]));
                    root.check(section.overflowButton.segmentRole === "middle" && automatic.item.segmentRole === "last", "a moved holder joins its neighboring segments");
                    root.retainedItem = automatic.item;
                    root.retainedRegistration = automatic.host.registration;
                    root.barLength = 400;
                    break;
                case 1:
                    root.check(automatic.inOverflow && section.hiddenEntries.length === 2 && bar.overflowPlan.fits, "all sections resolve their collision");
                    root.check(automatic.item === root.retainedItem && automatic.host.registration === root.retainedRegistration, "overflow retains the item and registration");
                    root.check(automatic.primarySize === 80 && automatic.slot.parent === section.parkingHost && !automatic.item.surfaceLive, "parked widgets retain natural size and suspend visual work");
                    root.check(section.overflowButton.segmentRole === "last" && automatic.item.segmentRole === "solo", "overflowed widgets leave the bar's segment run");
                    root.barLength = 600;
                    break;
                case 2:
                    root.check(!automatic.inOverflow && automatic.item === root.retainedItem && automatic.item.surfaceLive, "restoration keeps the item and resumes visual work");
                    root.titleWidth = 240;
                    break;
                case 3:
                    root.check(automatic.inOverflow && automatic.primarySize === 240, "dynamic title growth triggers overflow");
                    section.overflowButton.clicked();
                    break;
                case 4:
                    root.check(section.overflowOpen && automatic.inPopup && automatic.slot.parent === section.overflowParent && automatic.item.surfaceLive, "the actual widget moves into the popup");
                    root.check(automatic.item === root.retainedItem && automatic.host.registration === root.retainedRegistration, "opening overflow does not duplicate a widget");
                    root.check(automatic.popupY > 0 && automatic.slot.y === automatic.popupY && automatic.host.y === 0, "a widget that was inline stacks below earlier popup entries: " + JSON.stringify([automatic.popupY, automatic.slot.y, automatic.host.y]));
                    root.openSurface = section.overflowSurface;
                    const anchor = automatic.item.surfaceContext.popupAnchor(automatic.item);
                    root.check(anchor && anchor.trigger.y >= section.overflowSurface.renderedAlignedY + section.overflowSurface.renderedAlignedHeight, "child popouts clear the overflow surface");
                    root.titleWidth = 0;
                    break;
                case 5:
                    root.check(section.overflowCount === 0 && section.overflowOpen && section.overflowSurface === root.openSurface, "a widget collapsing while the popup is open keeps the holder and its popout alive: " + JSON.stringify([section.overflowCount, section.overflowOpen, section.overflowSurface === root.openSurface, !!section.overflowItem, automatic.inOverflow, automatic.available]));
                    root.titleWidth = 240;
                    section.overflowSurface.backgroundClicked();
                    break;
                case 6:
                    root.check(!section.overflowOpen && automatic.slot.parent === section.parkingHost && !automatic.item.surfaceLive, "clicking outside closes the popup and returns the widget to its parking host");
                    root.titleWidth = 80;
                    break;
                case 7:
                    root.check(!automatic.inOverflow && automatic.item === root.retainedItem, "a shorter title restores the same item");
                    root.barLength = 900;
                    root.config = Object.assign({}, root.config, { leftWidgets: root.config.leftWidgets.map(entry => Object.assign({}, entry, { overflowMode: "bar" })) });
                    break;
                case 8:
                    root.check(section.overflowCount === 0 && !section.overflowSurface && automatic.item === root.retainedItem, "an empty holder releases its popup and retains its widgets");
                    root.config = Object.assign({}, root.config, { position: 2, leftWidgets: root.config.leftWidgets.map((entry, index) => Object.assign({}, entry, { overflowMode: index === 2 ? "auto" : index === 1 ? "always" : "bar" })) });
                    root.vertical = true;
                    root.barLength = 400;
                    break;
                case 9:
                    root.check(automatic.inOverflow && automatic.primarySize === 80 && bar.overflowPlan.fits, "vertical bars overflow along their height");
                    root.retainedItem = automatic.item;
                    section.overflowButton.clicked();
                    break;
                case 10:
                    root.check(automatic.inPopup && automatic.slot.parent === section.overflowParent, "vertical overflow widgets remain interactive");
                    const verticalAnchor = automatic.item.surfaceContext.popupAnchor(automatic.item);
                    root.check(verticalAnchor && verticalAnchor.trigger.x >= section.overflowSurface.renderedAlignedX + section.overflowSurface.renderedAlignedWidth, "vertical child popouts clear the overflow surface");
                    section.overflowButton.clicked();
                    root.fitted = true;
                    root.barLength = 600;
                    break;
                case 11:
                    root.check(!automatic.inOverflow && automatic.item === root.retainedItem && bar.overflowPlan.fits, "fitted bars restore the retained widget within their available length");
                    console.log("FIXTURE_PASS");
                    stop();
                    Qt.quit();
                    return;
                }
                step++;
                stepStarted = Date.now();
            } catch (error) {
                if (Date.now() - stepStarted < 10000)
                    return;
                console.error("FIXTURE_FAIL", "step " + step + ": " + error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
