pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    required property var controller
    required property real morphProgress
    required property bool expanded
    required property bool pointerInside
    required property string activityId
    required property Component homeCompactComponent
    required property Component homeExpandedComponent
    required property Component mediaCompactComponent
    required property Component mediaExpandedComponent
    required property Component launcherCompactComponent
    required property Component launcherExpandedComponent
    required property Component controlCenterCompactComponent
    required property Component controlCenterExpandedComponent
    required property Component wallpaperCompactComponent
    required property Component wallpaperExpandedComponent
    required property Component weatherCompactComponent
    required property Component weatherExpandedComponent
    required property Component systemCompactComponent
    required property Component systemExpandedComponent
    required property Component notificationCompactComponent
    required property Component notificationExpandedComponent
    required property Component notificationCenterCompactComponent
    required property Component notificationCenterExpandedComponent

    readonly property real compactFade: root.fadeCompact(root.morphProgress)
    readonly property real expandedFade: root.fadeExpanded(root.morphProgress)
    readonly property real outgoingCompactFade: root.fadeCompact(root.outgoingMorph)
    readonly property real outgoingExpandedFade: root.fadeExpanded(root.outgoingMorph)
    readonly property bool mediaSurfaceActive: root.surfaceActive("media")
    readonly property bool systemSurfaceActive: root.surfaceActive("volume") || root.surfaceActive("brightness")

    property string renderedActivity: "home"
    property string outgoingActivity: ""
    property real activityFade: 1
    property real outgoingMorph: 0
    property bool homeExpandedTouched: false

    function fadeCompact(morph) {
        return 1 - Math.max(0, Math.min(1, morph / 0.34));
    }

    function fadeExpanded(morph) {
        return Math.max(0, Math.min(1, (morph - 0.22) / 0.42));
    }

    function surfaceActive(activity) {
        return root.renderedActivity === activity || root.outgoingActivity === activity;
    }

    function compactOpacity(activity) {
        const incoming = root.renderedActivity === activity ? root.activityFade * root.compactFade : 0;
        const outgoing = root.outgoingActivity === activity ? (1 - root.activityFade) * root.outgoingCompactFade : 0;
        return Math.max(incoming, outgoing);
    }

    function expandedOpacity(activity) {
        const incoming = root.renderedActivity === activity ? root.activityFade * root.expandedFade : 0;
        const outgoing = root.outgoingActivity === activity ? (1 - root.activityFade) * root.outgoingExpandedFade : 0;
        return Math.max(incoming, outgoing);
    }

    function requestActivityFocus() {
        switch (root.activityId) {
        case "launcher":
            if (!launcherExpandedLoader.item)
                return false;
            launcherExpandedLoader.item.focusSearch();
            return true;
        case "home":
            if (!homeExpandedLoader.item)
                return false;
            homeExpandedLoader.item.focusOverview();
            return true;
        case "media":
            return mediaExpandedLoader.item?.focusPlayer() === true;
        case "wallpaper":
            if (!wallpaperExpandedLoader.item)
                return false;
            wallpaperExpandedLoader.item.focusGrid();
            return true;
        case "weather":
            if (!weatherExpandedLoader.item)
                return false;
            weatherExpandedLoader.item.focusWeather();
            return true;
        case "notificationcenter":
            return notificationCenterExpandedLoader.item?.focusList() === true;
        }
        return false;
    }

    function latchHomeExpanded() {
        if (!homeExpandedTouched && expanded && activityId === "home")
            homeExpandedTouched = true;
    }

    onPointerInsideChanged: {
        if (root.pointerInside)
            root.homeExpandedTouched = true;
    }

    onExpandedChanged: latchHomeExpanded()

    onActivityIdChanged: {
        latchHomeExpanded();
        if (activityId === renderedActivity)
            return;
        outgoingMorph = morphProgress;
        outgoingActivity = renderedActivity;
        renderedActivity = activityId;
        activityFade = 0;
        activityTransition.restart();
    }

    SequentialAnimation {
        id: activityTransition

        PauseAnimation {
            duration: Theme.shorterDuration
        }

        NumberAnimation {
            target: root
            property: "activityFade"
            to: 1
            duration: Theme.mediumDuration
            easing.type: Theme.standardEasing
        }

        ScriptAction {
            script: root.outgoingActivity = ""
        }
    }

    component CompactFace: Loader {
        anchors.fill: parent
        asynchronous: false
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    component ExpandedFace: Loader {
        anchors.fill: parent
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    CompactFace {
        active: true
        sourceComponent: root.homeCompactComponent
        opacity: root.compactOpacity("home")
    }

    ExpandedFace {
        id: homeExpandedLoader

        active: root.homeExpandedTouched
        asynchronous: true
        sourceComponent: root.homeExpandedComponent
        opacity: root.expandedOpacity("home")
    }

    CompactFace {
        active: root.mediaSurfaceActive
        sourceComponent: root.mediaCompactComponent
        opacity: root.compactOpacity("media")
    }

    ExpandedFace {
        id: mediaExpandedLoader

        active: root.mediaSurfaceActive && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.mediaExpandedComponent
        opacity: root.expandedOpacity("media")
    }

    CompactFace {
        active: root.surfaceActive("launcher")
        sourceComponent: root.launcherCompactComponent
        opacity: root.compactOpacity("launcher")
    }

    ExpandedFace {
        id: launcherExpandedLoader

        active: root.controller.visualsRequested("launcher")
        asynchronous: true
        sourceComponent: root.launcherExpandedComponent
        opacity: root.expandedOpacity("launcher")
    }

    CompactFace {
        active: root.surfaceActive("controlcenter")
        sourceComponent: root.controlCenterCompactComponent
        opacity: root.compactOpacity("controlcenter")
    }

    ExpandedFace {
        active: root.controller.visualsRequested("controlcenter")
        asynchronous: false
        sourceComponent: root.controlCenterExpandedComponent
        opacity: root.expandedOpacity("controlcenter")
    }

    CompactFace {
        active: root.surfaceActive("wallpaper")
        sourceComponent: root.wallpaperCompactComponent
        opacity: root.compactOpacity("wallpaper")
    }

    ExpandedFace {
        id: wallpaperExpandedLoader

        active: root.controller.visualsRequested("wallpaper")
        asynchronous: true
        sourceComponent: root.wallpaperExpandedComponent
        opacity: root.expandedOpacity("wallpaper")
    }

    CompactFace {
        active: root.surfaceActive("weather")
        sourceComponent: root.weatherCompactComponent
        opacity: root.compactOpacity("weather")
    }

    ExpandedFace {
        id: weatherExpandedLoader

        active: root.controller.visualsRequested("weather")
        asynchronous: true
        sourceComponent: root.weatherExpandedComponent
        opacity: root.expandedOpacity("weather")
    }

    CompactFace {
        active: root.surfaceActive("notificationcenter")
        sourceComponent: root.notificationCenterCompactComponent
        opacity: root.compactOpacity("notificationcenter")
    }

    ExpandedFace {
        id: notificationCenterExpandedLoader

        active: root.controller.visualsRequested("notificationcenter")
        asynchronous: true
        sourceComponent: root.notificationCenterExpandedComponent
        opacity: root.expandedOpacity("notificationcenter")
    }

    CompactFace {
        active: root.systemSurfaceActive
        sourceComponent: root.systemCompactComponent
        opacity: Math.max(root.compactOpacity("volume"), root.compactOpacity("brightness"))
    }

    ExpandedFace {
        active: root.systemSurfaceActive && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.systemExpandedComponent
        opacity: Math.max(root.expandedOpacity("volume"), root.expandedOpacity("brightness"))
    }

    CompactFace {
        active: root.surfaceActive("notification")
        sourceComponent: root.notificationCompactComponent
        opacity: root.compactOpacity("notification")
    }

    ExpandedFace {
        active: root.surfaceActive("notification") && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.notificationExpandedComponent
        opacity: root.expandedOpacity("notification")
    }
}
