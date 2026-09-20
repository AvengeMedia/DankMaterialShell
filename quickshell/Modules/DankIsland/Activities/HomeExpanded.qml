pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash

DashTabFace {
    id: root

    activityId: "home"
    entryId: DashRegistry.overviewId
    tabComponent: Component {
        OverviewTab {
            live: root.live
            editMode: root.editMode
            rowBudget: root.controller.dashboardRowBudget
            onTabRequested: id => {
                switch (id) {
                case "media":
                    root.controller.requestActivity("media", true, true);
                    break;
                case "weather":
                    if (SettingsData.weatherEnabled)
                        root.controller.requestWeather(false);
                    break;
                case "notifications":
                    root.controller.requestNotificationCenter(false);
                    break;
                }
            }
        }
    }
}
