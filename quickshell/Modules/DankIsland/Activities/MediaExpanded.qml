pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.DankDash

DashTabFace {
    id: root

    readonly property real tabHeight: root.tab?.implicitHeight ?? 0

    activityId: "media"
    inset: 1
    tabComponent: Component {
        MediaPlayerTab {
            chrome: "island"
            live: root.live
        }
    }

    onTabHeightChanged: {
        if (root.tabHeight > 0)
            root.controller.setMediaExpandedHeight(root.tabHeight + root.inset * 2);
    }
}
