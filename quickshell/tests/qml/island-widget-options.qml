import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DankCommon.Common as DC

// Routing rows preserve legacy destinations, then update and reset independently through the widget entry.
ShellRoot {
    id: root

    readonly property string barId: "main"

    QtObject {
        id: fakePage

        readonly property string barId: root.barId
        readonly property string section: "right"
    }

    function check(value, label) {
        if (!value)
            throw new Error(label);
    }

    function findRow(item, settingKey) {
        for (const child of item.children) {
            if (child.settingKey === settingKey)
                return child;
            const found = findRow(child, settingKey);
            if (found)
                return found;
        }
        return null;
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
            SettingsData.barConfigs = [{ id: root.barId, enabled: true, visible: true, position: 0, screenPreferences: ["all"], leftWidgets: ["clock"], centerWidgets: ["clock"], rightWidgets: [{ id: "island", enabled: true, islandNotificationPopups: false, islandRouteDash: "island" }, "clock"] }];
            host.setSource("Modules/Settings/BarWidgetOptions/IslandOptions.qml", { "page": fakePage });
        }
    }

    Item {
        width: 720
        height: 900

        Loader {
            id: host

            width: parent.width
        }
    }

    Timer {
        property int waited: 0

        interval: 25
        repeat: true
        running: host.status === Loader.Ready

        onTriggered: {
            try {
                const page = host.item;
                const entry = () => SettingsData.islandWidgetEntry(SettingsData.getBarConfig(root.barId));
                const shared = root.findRow(page, "islandWidgetSharedRouting");
                const routes = root.findRow(page, "islandWidgetRouteActivities");
                const routeSuffixes = ["Launcher", "ControlCenter", "NotificationCenter", "Dash", "Media", "Weather", "Wallpaper"];
                const routeRows = routeSuffixes.map(suffix => root.findRow(page, "islandWidgetRoute" + suffix));
                const popups = root.findRow(page, "islandWidgetNotificationPopups");
                const mode = root.findRow(page, "islandWidgetInteractionMode");
                if (!shared || !routes || !popups || !mode || routeRows.some(row => !row)) {
                    if (++waited < 80)
                        return;
                    throw new Error("rows never appeared: " + [shared, routes, popups, mode].map(row => !!row).join(","));
                }
                root.check(!shared.visible, "a hosted island has no shared rule to pick");
                root.check(routeRows.every(row => row.visible), "all seven destination rows are visible");
                root.check(routeRows.every((row, index) => row.checked === (index >= 3)), "legacy dashboard routing is reflected in every dashboard activity");
                root.check(popups.checked === false, "rows read the widget entry, not the defaults");
                root.check(mode.visible, "a hosted island is always docked, so expansion mode shows");
                popups.toggled(true);
                root.check(entry().islandNotificationPopups === true, "toggle writes land on the widget entry: " + JSON.stringify(entry()));
                routeRows[1].toggled(true);
                root.check(entry().islandRouteControlCenter === "island", "a pick routes that activity to the island: " + JSON.stringify(entry()));
                routeRows[1].toggled(false);
                root.check(entry().islandRouteControlCenter === "bar", "an unpick hands it back to the bar's popout: " + JSON.stringify(entry()));
                routeRows[4].toggled(false);
                root.check(!routeRows[4].checked && routeRows[3].checked && routeRows[5].checked, "media changes independently and rows follow persisted values");
                routeRows[3].toggled(false);
                root.check(!routeRows[3].checked && !routeRows[4].checked && routeRows[5].checked && routeRows[6].checked, "editing dashboard preserves the other legacy destinations");
                routeRows[5].toggled(false);
                root.check(!routeRows[5].checked, "weather can override its island default");
                routeRows[5].resetRequested();
                root.check(entry().islandRouteWeather === "island" && routeRows[5].checked && !routeRows[3].checked && !routeRows[4].checked, "reset returns weather to the island without changing dashboard or media");
                routes.resetRequested();
                root.check(routeRows.every((row, index) => row.checked === (index >= 3)), "group reset restores dashboard activities to the island and other destinations to standard surfaces");
                root.check(SettingsData.islandWidgetEntry(SettingsData.getBarConfig(root.barId)).islandSharedRouting === undefined, "the shared rule is never written for a hosted island");
                console.log("FIXTURE_PASS");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            stop();
            Qt.quit();
        }
    }
}
