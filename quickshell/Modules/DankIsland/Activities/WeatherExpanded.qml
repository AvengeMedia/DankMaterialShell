pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.DankDash

DashTabFace {
    id: root

    activityId: "weather"
    tabComponent: Component {
        WeatherTab {
            live: root.live
            editMode: root.editMode
        }
    }

    Component.onCompleted: root.controller.markVisualsReady("weather")
    Component.onDestruction: root.controller.setVisualsReady("weather", false)
}
