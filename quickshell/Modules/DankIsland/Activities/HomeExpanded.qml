pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash

DashTabFace {
    id: root

    activityId: "home"
    tabComponent: Component {
        OverviewTab {
            live: root.live
            onCloseDash: root.controller.requestCollapse()
            onNavFocusRequested: root.focusFace()
            onSwitchToMediaTab: root.controller.requestActivity("media", true, true)
            onSwitchToWeatherTab: {
                if (SettingsData.weatherEnabled)
                    root.controller.requestWeather(false);
            }
        }
    }
}
