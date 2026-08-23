pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

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
    required property bool launcherVisualsRequested
    required property Component controlCenterCompactComponent
    required property Component controlCenterExpandedComponent
    required property bool controlCenterVisualsRequested
    required property Component wallpaperCompactComponent
    required property Component wallpaperExpandedComponent
    required property bool wallpaperVisualsRequested
    required property Component weatherCompactComponent
    required property Component weatherExpandedComponent
    required property bool weatherVisualsRequested
    required property Component systemCompactComponent
    required property Component systemExpandedComponent
    required property Component notificationCompactComponent
    required property Component notificationExpandedComponent
    required property Component notificationCenterCompactComponent
    required property Component notificationCenterExpandedComponent
    required property bool notificationCenterVisualsRequested

    readonly property real compactFade: root.fadeCompact(root.morphProgress)
    readonly property real expandedFade: root.fadeExpanded(root.morphProgress)
    // Outgoing faces freeze at the morph they were drawn at so they do not flash expanded.
    readonly property real outgoingCompactFade: root.fadeCompact(root.outgoingMorph)
    readonly property real outgoingExpandedFade: root.fadeExpanded(root.outgoingMorph)
    readonly property bool mediaSurfaceActive: root.activityId === "media" || root.outgoingActivity === "media"

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
        if (root.activityId === "launcher" && launcherExpandedLoader.item) {
            launcherExpandedLoader.item.focusSearch();
            return true;
        }
        if (root.activityId === "home" && homeExpandedLoader.item) {
            homeExpandedLoader.item.focusOverview();
            return true;
        }
        if (root.activityId === "media" && mediaExpandedLoader.item) {
            mediaExpandedLoader.item.focusPlayer();
            return true;
        }
        if (root.activityId === "wallpaper" && wallpaperExpandedLoader.item) {
            wallpaperExpandedLoader.item.focusGrid();
            return true;
        }
        if (root.activityId === "weather" && weatherExpandedLoader.item) {
            weatherExpandedLoader.item.focusWeather();
            return true;
        }
        if (root.activityId === "notificationcenter" && notificationCenterExpandedLoader.item) {
            notificationCenterExpandedLoader.item.focusList();
            return true;
        }
        return false;
    }

    function latchHomeExpanded() {
        if (!homeExpandedTouched && expanded && activityId === "home")
            homeExpandedTouched = true;
    }

    // Overview is latched on first pointer intent, not at startup.
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
            duration: 45
        }

        NumberAnimation {
            target: root
            property: "activityFade"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.outgoingActivity = ""
        }
    }

    Loader {
        anchors.fill: parent
        active: true
        asynchronous: false
        sourceComponent: root.homeCompactComponent
        opacity: root.compactOpacity("home")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: homeExpandedLoader

        anchors.fill: parent
        // Latched: built on first expansion, then kept so later morphs never hitch.
        active: root.homeExpandedTouched
        asynchronous: true
        sourceComponent: root.homeExpandedComponent
        opacity: root.expandedOpacity("home")
        visible: active || opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.mediaSurfaceActive
        asynchronous: false
        sourceComponent: root.mediaCompactComponent
        opacity: root.compactOpacity("media")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: mediaExpandedLoader

        anchors.fill: parent
        active: root.mediaSurfaceActive && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.mediaExpandedComponent
        opacity: root.expandedOpacity("media")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("launcher")
        asynchronous: false
        sourceComponent: root.launcherCompactComponent
        opacity: root.compactOpacity("launcher")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: launcherExpandedLoader

        anchors.fill: parent
        active: root.launcherVisualsRequested
        asynchronous: true
        sourceComponent: root.launcherExpandedComponent
        opacity: root.expandedOpacity("launcher")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("controlcenter")
        asynchronous: false
        sourceComponent: root.controlCenterCompactComponent
        opacity: root.compactOpacity("controlcenter")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: controlCenterExpandedLoader

        anchors.fill: parent
        active: root.controlCenterVisualsRequested
        asynchronous: false
        sourceComponent: root.controlCenterExpandedComponent
        opacity: root.expandedOpacity("controlcenter")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("wallpaper")
        asynchronous: false
        sourceComponent: root.wallpaperCompactComponent
        opacity: root.compactOpacity("wallpaper")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: wallpaperExpandedLoader

        anchors.fill: parent
        active: root.wallpaperVisualsRequested
        asynchronous: true
        sourceComponent: root.wallpaperExpandedComponent
        opacity: root.expandedOpacity("wallpaper")
        visible: active || opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("weather")
        asynchronous: false
        sourceComponent: root.weatherCompactComponent
        opacity: root.compactOpacity("weather")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: weatherExpandedLoader

        anchors.fill: parent
        active: root.weatherVisualsRequested
        asynchronous: true
        sourceComponent: root.weatherExpandedComponent
        opacity: root.expandedOpacity("weather")
        visible: active || opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("notificationcenter")
        asynchronous: false
        sourceComponent: root.notificationCenterCompactComponent
        opacity: root.compactOpacity("notificationcenter")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        id: notificationCenterExpandedLoader

        anchors.fill: parent
        active: root.notificationCenterVisualsRequested
        asynchronous: true
        sourceComponent: root.notificationCenterExpandedComponent
        opacity: root.expandedOpacity("notificationcenter")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("volume") || root.surfaceActive("brightness")
        asynchronous: false
        sourceComponent: root.systemCompactComponent
        opacity: Math.max(root.compactOpacity("volume"), root.compactOpacity("brightness"))
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: (root.surfaceActive("volume") || root.surfaceActive("brightness")) && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.systemExpandedComponent
        opacity: Math.max(root.expandedOpacity("volume"), root.expandedOpacity("brightness"))
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("notification")
        asynchronous: false
        sourceComponent: root.notificationCompactComponent
        opacity: root.compactOpacity("notification")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }

    Loader {
        anchors.fill: parent
        active: root.surfaceActive("notification") && (root.expanded || root.expandedFade > 0)
        asynchronous: false
        sourceComponent: root.notificationExpandedComponent
        opacity: root.expandedOpacity("notification")
        visible: opacity > 0.001
        enabled: opacity >= 0.5
    }
}
