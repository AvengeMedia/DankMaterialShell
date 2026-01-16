import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    clip: false
    property var appData
    property var contextMenu: null
    property var dockApps: null
    property int index: -1
    property var parentDockScreen: null
    property bool longPressing: false
    property bool dragging: false
    property point dragStartPos: Qt.point(0, 0)
    property real dragAxisOffset: 0
    property int targetIndex: -1
    property int originalIndex: -1
    property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    property bool showWindowTitle: false
    property string windowTitle: ""
    property bool isHovered: mouseArea.containsMouse && !dragging
    property bool showTooltip: mouseArea.containsMouse && !dragging
    property var cachedDesktopEntry: null
    property real actualIconSize: 40

    function updateDesktopEntry() {
        if (!appData || appData.appId === "__SEPARATOR__") {
            cachedDesktopEntry = null;
            return;
        }
        const moddedId = Paths.moddedAppId(appData.appId);
        cachedDesktopEntry = DesktopEntries.heuristicLookup(moddedId);
    }

    Component.onCompleted: updateDesktopEntry()

    onAppDataChanged: updateDesktopEntry()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            updateDesktopEntry();
        }
    }

    Connections {
        target: SettingsData
        function onAppIdSubstitutionsChanged() {
            updateDesktopEntry();
        }
    }
    property bool isWindowFocused: {
        if (!appData) {
            return false;
        }

        if (appData.type === "window") {
            const toplevel = getToplevelObject();
            if (!toplevel) {
                return false;
            }
            return toplevel.activated;
        } else if (appData.type === "grouped") {
            // For grouped apps, check if any window is focused
            const allToplevels = ToplevelManager.toplevels.values;
            for (let i = 0; i < allToplevels.length; i++) {
                const toplevel = allToplevels[i];
                if (toplevel.appId === appData.appId && toplevel.activated) {
                    return true;
                }
            }
        }

        return false;
    }
    property string tooltipText: {
        if (!appData || !appData.appId) {
            return "";
        }

        const appName = Paths.getAppName(appData.appId, cachedDesktopEntry);

        if ((appData.type === "window" && showWindowTitle) || (appData.type === "grouped" && appData.windowTitle)) {
            const title = appData.type === "window" ? windowTitle : appData.windowTitle;
            return appName + (title ? " • " + title : "");
        }

        return appName;
    }

    function getToplevelObject() {
        return appData?.toplevel || null;
    }

    function getGroupedToplevels() {
        return appData?.allWindows?.map(w => w.toplevel).filter(t => t !== null) || [];
    }
    onIsHoveredChanged: {
        if (mouseArea.pressed || dragging)
            return;
        if (isHovered) {
            exitAnimation.stop();
            if (!bounceAnimation.running) {
                bounceAnimation.restart();
            }
        } else {
            bounceAnimation.stop();
            exitAnimation.restart();
        }
    }

    readonly property bool animateX: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right
    readonly property real animationDistance: actualIconSize
    readonly property real animationDirection: {
        if (SettingsData.dockPosition === SettingsData.Position.Bottom)
            return -1;
        if (SettingsData.dockPosition === SettingsData.Position.Top)
            return 1;
        if (SettingsData.dockPosition === SettingsData.Position.Right)
            return -1;
        if (SettingsData.dockPosition === SettingsData.Position.Left)
            return 1;
        return -1;
    }

    SequentialAnimation {
        id: bounceAnimation

        running: false

        NumberAnimation {
            target: root
            property: "hoverAnimOffset"
            to: animationDirection * animationDistance * 0.25
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: root
            property: "hoverAnimOffset"
            to: animationDirection * animationDistance * 0.2
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    NumberAnimation {
        id: exitAnimation

        running: false
        target: root
        property: "hoverAnimOffset"
        to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }

    Timer {
        id: longPressTimer

        interval: 500
        repeat: false
        onTriggered: {
            if (appData && appData.isPinned) {
                longPressing = true;
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: true
        preventStealing: true
        cursorShape: longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton && appData && appData.isPinned) {
                dragStartPos = Qt.point(mouse.x, mouse.y);
                longPressTimer.start();
            }
        }
        onReleased: mouse => {
            longPressTimer.stop();

            const wasDragging = dragging;
            const didReorder = wasDragging && targetIndex >= 0 && targetIndex !== originalIndex && dockApps;

            if (didReorder)
                dockApps.movePinnedApp(originalIndex, targetIndex);

            longPressing = false;
            dragging = false;
            dragAxisOffset = 0;
            targetIndex = -1;
            originalIndex = -1;

            if (dockApps && !didReorder) {
                dockApps.draggedIndex = -1;
                dockApps.dropTargetIndex = -1;
            }

            if (wasDragging || mouse.button !== Qt.LeftButton)
                return;

            handleLeftClick();
        }

        function handleLeftClick() {
            if (!appData)
                return;

            switch (appData.type) {
            case "pinned":
                if (!appData.appId)
                    return;
                const pinnedEntry = cachedDesktopEntry;
                if (pinnedEntry) {
                    AppUsageHistoryData.addAppUsage({
                        "id": appData.appId,
                        "name": pinnedEntry.name || appData.appId,
                        "icon": pinnedEntry.icon ? String(pinnedEntry.icon) : "",
                        "exec": pinnedEntry.exec || "",
                        "comment": pinnedEntry.comment || ""
                    });
                }
                SessionService.launchDesktopEntry(pinnedEntry);
                break;
            case "window":
                const windowToplevel = getToplevelObject();
                if (windowToplevel)
                    windowToplevel.activate();
                break;
            case "grouped":
                if (appData.windowCount === 0) {
                    if (!appData.appId)
                        return;
                    const groupedEntry = cachedDesktopEntry;
                    if (groupedEntry) {
                        AppUsageHistoryData.addAppUsage({
                            "id": appData.appId,
                            "name": groupedEntry.name || appData.appId,
                            "icon": groupedEntry.icon ? String(groupedEntry.icon) : "",
                            "exec": groupedEntry.exec || "",
                            "comment": groupedEntry.comment || ""
                        });
                    }
                    SessionService.launchDesktopEntry(groupedEntry);
                } else if (appData.windowCount === 1) {
                    const groupedToplevel = getToplevelObject();
                    if (groupedToplevel)
                        groupedToplevel.activate();
                } else if (contextMenu) {
                    const shouldHidePin = appData.appId === "org.quickshell";
                    contextMenu.showForButton(root, appData, root.height + 25, shouldHidePin, cachedDesktopEntry, parentDockScreen);
                }
                break;
            }
        }
        onPositionChanged: mouse => {
            if (longPressing && !dragging) {
                const distance = Math.sqrt(Math.pow(mouse.x - dragStartPos.x, 2) + Math.pow(mouse.y - dragStartPos.y, 2));
                if (distance > 5) {
                    dragging = true;
                    targetIndex = index;
                    originalIndex = index;
                    if (dockApps) {
                        dockApps.draggedIndex = index;
                        dockApps.dropTargetIndex = index;
                    }
                }
            }

            if (!dragging || !dockApps)
                return;

            const axisOffset = isVertical ? (mouse.y - dragStartPos.y) : (mouse.x - dragStartPos.x);
            dragAxisOffset = axisOffset;

            const spacing = Math.min(8, Math.max(4, actualIconSize * 0.08));
            const itemSize = actualIconSize * 1.2 + spacing;
            const slotOffset = Math.round(axisOffset / itemSize);
            const newTargetIndex = Math.max(0, Math.min(dockApps.pinnedAppCount - 1, originalIndex + slotOffset));

            if (newTargetIndex !== targetIndex) {
                targetIndex = newTargetIndex;
                dockApps.dropTargetIndex = newTargetIndex;
            }
        }
        onClicked: mouse => {
            if (!appData)
                return;

            if (mouse.button === Qt.MiddleButton) {
                switch (appData.type) {
                case "window":
                    appData.toplevel?.close();
                    break;
                case "grouped":
                    if (contextMenu) {
                        const shouldHidePin = appData.appId === "org.quickshell";
                        contextMenu.showForButton(root, appData, root.height, shouldHidePin, cachedDesktopEntry, parentDockScreen);
                    }
                    break;
                default:
                    if (!appData.appId)
                        return;
                    const desktopEntry = cachedDesktopEntry;
                    if (desktopEntry) {
                        AppUsageHistoryData.addAppUsage({
                            "id": appData.appId,
                            "name": desktopEntry.name || appData.appId,
                            "icon": desktopEntry.icon ? String(desktopEntry.icon) : "",
                            "exec": desktopEntry.exec || "",
                            "comment": desktopEntry.comment || ""
                        });
                    }
                    SessionService.launchDesktopEntry(desktopEntry);
                    break;
                }
            } else if (mouse.button === Qt.RightButton) {
                if (!contextMenu)
                    return;
                const shouldHidePin = appData.appId === "org.quickshell";
                contextMenu.showForButton(root, appData, root.height, shouldHidePin, cachedDesktopEntry, parentDockScreen);
            }
        }
    }

    property real hoverAnimOffset: 0

    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            id: iconTransform
            x: {
                if (dragging && !isVertical)
                    return dragAxisOffset;
                if (!dragging && isVertical)
                    return hoverAnimOffset;
                return 0;
            }
            y: {
                if (dragging && isVertical)
                    return dragAxisOffset;
                if (!dragging && !isVertical)
                    return hoverAnimOffset;
                return 0;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
            border.width: 2
            border.color: Theme.primary
            visible: dragging
            z: -1
        }

        IconImage {
            id: iconImg

            anchors.centerIn: parent
            implicitSize: appData && appData.appId === "org.quickshell" ? actualIconSize * 0.85 : actualIconSize
            source: {
                if (!appData || appData.appId === "__SEPARATOR__") {
                    return "";
                }
                return Paths.getAppIcon(appData.appId, cachedDesktopEntry);
            }
            mipmap: true
            smooth: true
            asynchronous: true
            visible: status === Image.Ready
            layer.enabled: appData && appData.appId === "org.quickshell"
            layer.smooth: true
            layer.mipmap: true
            layer.effect: MultiEffect {
                saturation: 0
                colorization: 1
                colorizationColor: Theme.primary
            }
        }

        Rectangle {
            width: actualIconSize
            height: actualIconSize
            anchors.centerIn: parent
            visible: iconImg.status !== Image.Ready && appData && appData.appId && !Paths.isSteamApp(appData.appId)
            color: Theme.surfaceLight
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.primarySelected

            Text {
                anchors.centerIn: parent
                text: {
                    if (!appData || !appData.appId) {
                        return "?";
                    }

                    const appName = Paths.getAppName(appData.appId, cachedDesktopEntry);
                    return appName.charAt(0).toUpperCase();
                }
                font.pixelSize: Math.max(8, parent.width * 0.35)
                color: Theme.primary
                font.weight: Font.Bold
            }
        }

        DankIcon {
            anchors.centerIn: parent
            size: actualIconSize
            name: "sports_esports"
            color: Theme.surfaceText
            visible: iconImg.status !== Image.Ready && appData && appData.appId && Paths.isSteamApp(appData.appId)
        }

        Loader {
            anchors.horizontalCenter: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right ? undefined : parent.horizontalCenter
            anchors.verticalCenter: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right ? parent.verticalCenter : undefined
            anchors.bottom: SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined
            anchors.top: SettingsData.dockPosition === SettingsData.Position.Top ? parent.top : undefined
            anchors.left: SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined
            anchors.right: SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined
            anchors.bottomMargin: SettingsData.dockPosition === SettingsData.Position.Bottom ? -(SettingsData.dockSpacing / 2) : 0
            anchors.topMargin: SettingsData.dockPosition === SettingsData.Position.Top ? -(SettingsData.dockSpacing / 2) : 0
            anchors.leftMargin: SettingsData.dockPosition === SettingsData.Position.Left ? -(SettingsData.dockSpacing / 2) : 0
            anchors.rightMargin: SettingsData.dockPosition === SettingsData.Position.Right ? -(SettingsData.dockSpacing / 2) : 0

            sourceComponent: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right ? columnIndicator : rowIndicator

            visible: {
                if (!appData)
                    return false;
                if (appData.type === "window")
                    return true;
                if (appData.type === "grouped")
                    return appData.windowCount > 0;
                return appData.isRunning;
            }
        }
    }

    Component {
        id: rowIndicator

        Row {
            spacing: 2

            Repeater {
                model: {
                    if (!appData)
                        return 0;
                    if (appData.type === "grouped") {
                        return Math.min(appData.windowCount, 4);
                    } else if (appData.type === "window" || appData.isRunning) {
                        return 1;
                    }
                    return 0;
                }

                Rectangle {
                    width: {
                        if (SettingsData.dockIndicatorStyle === "circle") {
                            return Math.max(4, actualIconSize * 0.1);
                        }
                        return appData && appData.type === "grouped" && appData.windowCount > 1 ? Math.max(3, actualIconSize * 0.1) : Math.max(6, actualIconSize * 0.2);
                    }
                    height: {
                        if (SettingsData.dockIndicatorStyle === "circle") {
                            return Math.max(4, actualIconSize * 0.1);
                        }
                        return Math.max(2, actualIconSize * 0.05);
                    }
                    radius: SettingsData.dockIndicatorStyle === "circle" ? width / 2 : Theme.cornerRadius
                    color: {
                        if (!appData) {
                            return "transparent";
                        }

                        if (appData.type !== "grouped" || appData.windowCount === 1) {
                            if (isWindowFocused) {
                                return Theme.primary;
                            }
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6);
                        }

                        if (appData.type === "grouped" && appData.windowCount > 1) {
                            const groupToplevels = getGroupedToplevels();
                            if (index < groupToplevels.length && groupToplevels[index].activated) {
                                return Theme.primary;
                            }
                        }

                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6);
                    }
                }
            }
        }
    }

    Component {
        id: columnIndicator

        Column {
            spacing: 2

            Repeater {
                model: {
                    if (!appData)
                        return 0;
                    if (appData.type === "grouped") {
                        return Math.min(appData.windowCount, 4);
                    } else if (appData.type === "window" || appData.isRunning) {
                        return 1;
                    }
                    return 0;
                }

                Rectangle {
                    width: {
                        if (SettingsData.dockIndicatorStyle === "circle") {
                            return Math.max(4, actualIconSize * 0.1);
                        }
                        return Math.max(2, actualIconSize * 0.05);
                    }
                    height: {
                        if (SettingsData.dockIndicatorStyle === "circle") {
                            return Math.max(4, actualIconSize * 0.1);
                        }
                        return appData && appData.type === "grouped" && appData.windowCount > 1 ? Math.max(3, actualIconSize * 0.1) : Math.max(6, actualIconSize * 0.2);
                    }
                    radius: SettingsData.dockIndicatorStyle === "circle" ? width / 2 : Theme.cornerRadius
                    color: {
                        if (!appData) {
                            return "transparent";
                        }

                        if (appData.type !== "grouped" || appData.windowCount === 1) {
                            if (isWindowFocused) {
                                return Theme.primary;
                            }
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6);
                        }

                        if (appData.type === "grouped" && appData.windowCount > 1) {
                            const groupToplevels = getGroupedToplevels();
                            if (index < groupToplevels.length && groupToplevels[index].activated) {
                                return Theme.primary;
                            }
                        }

                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6);
                    }
                }
            }
        }
    }
}
