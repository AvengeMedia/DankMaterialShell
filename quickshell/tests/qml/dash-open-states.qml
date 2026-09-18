import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankDash
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var popout: null
    property bool failed: false
    property int step: 0

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function findPages(item, depth) {
        if (!item || depth > 20)
            return null;
        if (item.currentHost !== undefined && item.settledHeight !== undefined)
            return item;
        for (const child of item.children || []) {
            const found = findPages(child, depth + 1);
            if (found)
                return found;
        }
        return null;
    }

    function count(item, type, depth) {
        if (!item || depth > 20)
            return 0;
        let total = typeName(item) === type && item.visible && item.height > 0 ? 1 : 0;
        for (const child of item.children || [])
            total += count(child, type, depth + 1);
        return total;
    }

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function assertOverviewShown(label) {
        const content = popout.contentLoader?.item ?? null;
        const pages = findPages(content, 0);
        const host = pages?.currentHost ?? null;
        const slots = count(host, "DashCardSlot", 0);
        console.log("PARITY " + JSON.stringify({
            label: label,
            visible: popout.shouldBeVisible,
            tab: popout.currentTabId,
            hostOpacity: host?.opacity,
            hostVisible: host?.visible,
            hasItem: !!host?.item,
            hostHeight: host?.height,
            contentHeight: pages?.contentHeight,
            slots: slots,
            popupHeight: popout.popupHeight
        }));
        check(popout.shouldBeVisible && popout.currentTabId === "overview", label + ": overview open");
        check(host && host.visible && host.opacity === 1 && !!host.item, label + ": overview host shown");
        check(slots > 0 && host && host.height > DashMetrics.tabMinHeight / 2, label + ": overview cards laid out");
    }

    Component {
        id: dashComponent
        DankDashPopout {}
    }

    function createAndOpenSync() {
        root.popout = dashComponent.createObject(root);
        root.popout.setBarContext(0, 0);
        root.popout.triggerScreen = Quickshell.screens[0];
        root.popout.setTriggerPosition(640, 0, 40, "center", Quickshell.screens[0]);
        root.popout.requestTab("overview");
        PopoutManager.requestPopout(root.popout, undefined, "main-center-overview");
    }

    Timer {
        id: sequencer
        interval: 1200
        onTriggered: {
            switch (root.step++) {
            case 0:
                assertOverviewShown("cold open from a bar widget");
                root.popout.dashVisible = false;
                interval = 40;
                break;
            case 1:
                root.popout.requestTab(0);
                root.popout.dashVisible = true;
                interval = 1200;
                break;
            case 2:
                assertOverviewShown("reopen right after close");
                root.popout.requestTab("media");
                interval = 30;
                break;
            case 3:
                root.popout.requestTab(0);
                interval = 1200;
                break;
            case 4:
                assertOverviewShown("tab switched away and back mid fade");
                SettingsData.setDashTabEnabled("media", false);
                interval = 60;
                break;
            case 5:
                SettingsData.setDashTabEnabled("media", true);
                interval = 1200;
                break;
            case 6:
                assertOverviewShown("tab list rebuilt while open");
                root.popout.dashVisible = false;
                interval = 60;
                break;
            case 7:
                root.popout.requestTab(0);
                root.popout.dashVisible = true;
                interval = 60;
                break;
            case 8:
                root.popout.dashVisible = false;
                interval = 200;
                break;
            case 9:
                root.popout.requestTab(0);
                root.popout.dashVisible = true;
                interval = 1200;
                break;
            case 10:
                assertOverviewShown("reopen after closing during the open fade");
                root.popout.dashVisible = false;
                root.popout.destroy();
                root.popout = null;
                interval = 300;
                break;
            case 11:
                createAndOpenSync();
                SettingsData.setDashTabEnabled("media", false);
                interval = 1200;
                break;
            case 12:
                assertOverviewShown("tab list rebuilt during cold open");
                console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
                stop();
                Qt.quit();
                return;
            }
            restart();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.barConfigs = [
            {
                id: "main",
                enabled: true,
                visible: true,
                position: 0,
                spacing: 4,
                innerPadding: 4,
                leftWidgets: [],
                centerWidgets: [],
                rightWidgets: []
            }
        ];
        createAndOpenSync();
        sequencer.start();
    }
}
