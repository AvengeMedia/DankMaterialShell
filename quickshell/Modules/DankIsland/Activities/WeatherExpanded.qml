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
            transientSurfaceTracker: root.controller.transientSurfaces
        }
    }

    Component.onCompleted: root.controller.markVisualsReady("weather")
    Component.onDestruction: root.controller.setVisualsReady("weather", false)
}
