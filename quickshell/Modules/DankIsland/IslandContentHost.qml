pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    x: Math.round(parent.x) - parent.x
    y: Math.round(parent.y) - parent.y
    width: Math.round(parent.x + parent.width) - Math.round(parent.x)
    height: Math.round(parent.y + parent.height) - Math.round(parent.y)
    clip: true

    required property var controller
    required property real islandX
    required property real hostWidth
    required property real springTimeConstantMs
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
            duration: Math.round(root.springTimeConstantMs)
        }

        NumberAnimation {
            target: root
            property: "activityFade"
            to: 1
            duration: Math.round(root.springTimeConstantMs * 3)
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.outgoingActivity = ""
        }
    }

    component CompactFace: Loader {
        required property string activity
        readonly property var target: root.controller.compactTargetFor(activity)

        x: Math.round((root.hostWidth - target.width) / 2 + target.offsetX) - Math.round(root.islandX)
        y: Math.round((parent.height - height) / 2)
        width: target.width
        height: target.height
        asynchronous: false
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    component ExpandedFace: Loader {
        required property string activity
        readonly property var target: root.controller.expandedTargetFor(activity)

        width: target.width
        height: target.height
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    CompactFace {
        active: true
        activity: "home"
        sourceComponent: root.homeCompactComponent
        opacity: root.compactOpacity("home")
    }

    ExpandedFace {
        id: homeExpandedLoader

        activity: "home"
        active: root.homeExpandedTouched
        asynchronous: true
        sourceComponent: root.homeExpandedComponent
        opacity: root.expandedOpacity("home")
    }

    CompactFace {
        active: root.mediaSurfaceActive
        activity: "media"
        sourceComponent: root.mediaCompactComponent
        opacity: root.compactOpacity("media")
    }

    ExpandedFace {
        id: mediaExpandedLoader

        activity: "media"
        active: root.mediaSurfaceActive && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.mediaExpandedComponent
        opacity: root.expandedOpacity("media")
    }

    CompactFace {
        active: root.surfaceActive("launcher")
        activity: "launcher"
        sourceComponent: root.launcherCompactComponent
        opacity: root.compactOpacity("launcher")
    }

    ExpandedFace {
        id: launcherExpandedLoader

        activity: "launcher"
        active: root.controller.visualsRequested("launcher")
        asynchronous: true
        sourceComponent: root.launcherExpandedComponent
        opacity: root.expandedOpacity("launcher")
    }

    CompactFace {
        active: root.surfaceActive("controlcenter")
        activity: "controlcenter"
        sourceComponent: root.controlCenterCompactComponent
        opacity: root.compactOpacity("controlcenter")
    }

    ExpandedFace {
        activity: "controlcenter"
        active: root.controller.visualsRequested("controlcenter")
        asynchronous: false
        sourceComponent: root.controlCenterExpandedComponent
        opacity: root.expandedOpacity("controlcenter")
    }

    CompactFace {
        active: root.surfaceActive("wallpaper")
        activity: "wallpaper"
        sourceComponent: root.wallpaperCompactComponent
        opacity: root.compactOpacity("wallpaper")
    }

    ExpandedFace {
        id: wallpaperExpandedLoader

        activity: "wallpaper"
        active: root.controller.visualsRequested("wallpaper")
        asynchronous: true
        sourceComponent: root.wallpaperExpandedComponent
        opacity: root.expandedOpacity("wallpaper")
    }

    CompactFace {
        active: root.surfaceActive("weather")
        activity: "weather"
        sourceComponent: root.weatherCompactComponent
        opacity: root.compactOpacity("weather")
    }

    ExpandedFace {
        id: weatherExpandedLoader

        activity: "weather"
        active: root.controller.visualsRequested("weather")
        asynchronous: true
        sourceComponent: root.weatherExpandedComponent
        opacity: root.expandedOpacity("weather")
    }

    CompactFace {
        active: root.surfaceActive("notificationcenter")
        activity: "notificationcenter"
        sourceComponent: root.notificationCenterCompactComponent
        opacity: root.compactOpacity("notificationcenter")
    }

    ExpandedFace {
        id: notificationCenterExpandedLoader

        activity: "notificationcenter"
        active: root.controller.visualsRequested("notificationcenter")
        asynchronous: true
        sourceComponent: root.notificationCenterExpandedComponent
        opacity: root.expandedOpacity("notificationcenter")
    }

    CompactFace {
        active: root.systemSurfaceActive
        activity: "volume"
        sourceComponent: root.systemCompactComponent
        opacity: Math.max(root.compactOpacity("volume"), root.compactOpacity("brightness"))
    }

    ExpandedFace {
        activity: "volume"
        active: root.systemSurfaceActive && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.systemExpandedComponent
        opacity: Math.max(root.expandedOpacity("volume"), root.expandedOpacity("brightness"))
    }

    CompactFace {
        active: root.surfaceActive("notification")
        activity: "notification"
        sourceComponent: root.notificationCompactComponent
        opacity: root.compactOpacity("notification")
    }

    ExpandedFace {
        activity: "notification"
        active: root.surfaceActive("notification") && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.notificationExpandedComponent
        opacity: root.expandedOpacity("notification")
    }
}
