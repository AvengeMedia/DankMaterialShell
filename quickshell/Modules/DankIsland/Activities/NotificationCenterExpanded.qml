pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.DankDash

DashTabFace {
    id: root

    activityId: "notificationcenter"
    entryId: "notifications"
    tabComponent: Component {
        NotificationsTab {
            live: root.live
        }
    }

    Component.onCompleted: root.controller.markVisualsReady("notificationcenter")
    Component.onDestruction: root.controller.setVisualsReady("notificationcenter", false)
}
