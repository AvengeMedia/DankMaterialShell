import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    enableBackgroundHover: false
    enableCursor: false
    section: "left"

    property var widgetData: null
    property var hoveredItem: null
    property var topBar: null
    property bool isAutoHideBar: false
    property Item windowRoot: (Window.window ? Window.window.contentItem : null)

    readonly property real effectiveBarThickness: {
        if (barThickness > 0 && barSpacing > 0) {
            return barThickness + barSpacing;
        }
        const innerPadding = barConfig?.innerPadding ?? 4;
        const spacing = barConfig?.spacing ?? 4;
        return Math.max(26 + innerPadding * 0.6, Theme.barHeight - 4 - (8 - innerPadding)) + spacing;
    }

    readonly property var barBounds: {
        if (!parentScreen || !barConfig) {
            return {
                "x": 0,
                "y": 0,
                "width": 0,
                "height": 0,
                "wingSize": 0
            };
        }
        const barPosition = axis.edge === "left" ? 2 : (axis.edge === "right" ? 3 : (axis.edge === "top" ? 0 : 1));
        return SettingsData.getBarBounds(parentScreen, effectiveBarThickness, barPosition, barConfig);
    }

    readonly property real barY: barBounds.y

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            return effectiveBarThickness;
        }

        return 0;
    }

    property int _desktopEntriesUpdateTrigger: 0
    property int _toplevelsUpdateTrigger: 0
    property int _appIdSubstitutionsTrigger: 0

    readonly property bool _currentWorkspace: widgetData?.runningAppsCurrentWorkspace !== undefined ? widgetData.runningAppsCurrentWorkspace : SettingsData.runningAppsCurrentWorkspace
    readonly property bool _currentMonitor: widgetData?.runningAppsCurrentMonitor !== undefined ? widgetData.runningAppsCurrentMonitor : SettingsData.runningAppsCurrentMonitor
    readonly property bool _groupByApp: widgetData?.runningAppsGroupByApp !== undefined ? widgetData.runningAppsGroupByApp : SettingsData.runningAppsGroupByApp

    readonly property var sortedToplevels: {
        _toplevelsUpdateTrigger;
        let toplevels = CompositorService.sortedToplevels;
        if (!toplevels || toplevels.length === 0)
            return [];

        if (_currentWorkspace)
            toplevels = CompositorService.filterCurrentWorkspace(toplevels, parentScreen?.name) || [];
        if (_currentMonitor)
            toplevels = CompositorService.filterCurrentDisplay(toplevels, parentScreen?.name) || [];
        return toplevels;
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            _toplevelsUpdateTrigger++;
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++;
        }
    }

    Connections {
        target: SettingsData
        function onAppIdSubstitutionsChanged() {
            _appIdSubstitutionsTrigger++;
        }
    }
    readonly property var groupedWindows: {
        if (!_groupByApp) {
            return [];
        }
        try {
            if (!sortedToplevels || sortedToplevels.length === 0) {
                return [];
            }
            const appGroups = new Map();
            sortedToplevels.forEach((toplevel, index) => {
                if (!toplevel)
                    return;
                const appId = toplevel?.appId || "unknown";
                if (!appGroups.has(appId)) {
                    appGroups.set(appId, {
                        "appId": appId,
                        "windows": []
                    });
                }
                appGroups.get(appId).windows.push({
                    "toplevel": toplevel,
                    "windowId": index,
                    "windowTitle": toplevel?.title || "(Unnamed)"
                });
            });
            return Array.from(appGroups.values());
        } catch (e) {
            return [];
        }
    }
    readonly property int windowCount: _groupByApp ? (groupedWindows?.length || 0) : (sortedToplevels?.length || 0)
    readonly property real iconCellSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale) + 6

    readonly property string focusedAppId: {
        if (!sortedToplevels || sortedToplevels.length === 0)
            return "";
        for (let i = 0; i < sortedToplevels.length; i++) {
            if (sortedToplevels[i].activated)
                return sortedToplevels[i].appId || "";
        }
        return "";
    }

    visible: windowCount > 0

    property real scrollAccumulator: 0
    property real touchpadThreshold: 500

    onWheel: function (wheelEvent) {
        wheelEvent.accepted = true;
        const deltaY = wheelEvent.angleDelta.y;
        const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

        const windows = root.sortedToplevels;
        if (windows.length < 2)
            return;

        if (isMouseWheel) {
            let currentIndex = -1;
            for (var i = 0; i < windows.length; i++) {
                if (windows[i].activated) {
                    currentIndex = i;
                    break;
                }
            }

            let nextIndex;
            if (deltaY < 0) {
                nextIndex = currentIndex === -1 ? 0 : Math.min(currentIndex + 1, windows.length - 1);
            } else {
                nextIndex = currentIndex === -1 ? windows.length - 1 : Math.max(currentIndex - 1, 0);
            }

            const nextWindow = windows[nextIndex];
            if (nextWindow)
                nextWindow.activate();
        } else {
            scrollAccumulator += deltaY;

            if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                let currentIndex = -1;
                for (var i = 0; i < windows.length; i++) {
                    if (windows[i].activated) {
                        currentIndex = i;
                        break;
                    }
                }

                let nextIndex;
                if (scrollAccumulator < 0) {
                    nextIndex = currentIndex === -1 ? 0 : Math.min(currentIndex + 1, windows.length - 1);
                } else {
                    nextIndex = currentIndex === -1 ? windows.length - 1 : Math.max(currentIndex - 1, 0);
                }

                const nextWindow = windows[nextIndex];
                if (nextWindow)
                    nextWindow.activate();

                scrollAccumulator = 0;
            }
        }
    }

    content: Component {
        Item {
            implicitWidth: layoutLoader.item ? layoutLoader.item.implicitWidth : 0
            implicitHeight: layoutLoader.item ? layoutLoader.item.implicitHeight : 0

            Loader {
                id: layoutLoader
                anchors.centerIn: parent
                sourceComponent: root.isVerticalOrientation ? columnLayout : rowLayout
            }
        }
    }

    Component {
        id: rowLayout
        Row {
            spacing: Theme.spacingXS

            Repeater {
                id: windowRepeater
                model: ScriptModel {
                    values: _groupByApp ? groupedWindows : sortedToplevels
                    objectProp: _groupByApp ? "appId" : "address"
                }

                delegate: Item {
                    id: delegateItem

                    property bool isGrouped: root._groupByApp
                    property var groupData: isGrouped ? modelData : null
                    property var toplevelData: isGrouped ? (modelData.windows.length > 0 ? modelData.windows[0].toplevel : null) : modelData
                    property bool isFocused: isGrouped ? (root.focusedAppId === appId) : (toplevelData ? toplevelData.activated : false)
                    property string appId: isGrouped ? modelData.appId : (modelData.appId || "")
                    readonly property string effectiveAppId: {
                        root._appIdSubstitutionsTrigger;
                        return Paths.moddedAppId(appId);
                    }
                    property string windowTitle: toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)"
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = effectiveAppId ? DesktopEntries.heuristicLookup(effectiveAppId) : null;
                        const appName = effectiveAppId ? Paths.getAppName(effectiveAppId, desktopEntry) : "Unknown";

                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)";
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "");
                    }
                    readonly property real visualWidth: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? root.iconCellSize : (root.iconCellSize + Theme.spacingXS + 120)

                    width: visualWidth
                    height: root.barThickness

                    Rectangle {
                        id: visualContent
                        width: delegateItem.visualWidth
                        height: root.iconCellSize
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: {
                            if (isFocused) {
                                return mouseArea.containsMouse ? Theme.primarySelected : Theme.withAlpha(Theme.primary, 0.2);
                            }
                            return mouseArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent";
                        }

                        // App icon
                        IconImage {
                            id: iconImg
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)) / 2) : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            height: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            source: {
                                root._desktopEntriesUpdateTrigger;
                                root._appIdSubstitutionsTrigger;
                                if (!effectiveAppId)
                                    return "";
                                const desktopEntry = DesktopEntries.heuristicLookup(effectiveAppId);
                                return Paths.getAppIcon(effectiveAppId, desktopEntry);
                            }
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: appId === "org.quickshell"
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                saturation: 0
                                colorization: 1
                                colorizationColor: Theme.primary
                            }
                        }

                        DankIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)) / 2) : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            name: "sports_esports"
                            color: Theme.widgetTextColor
                            visible: !iconImg.visible && Paths.isSteamApp(effectiveAppId)
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !iconImg.visible && !Paths.isSteamApp(effectiveAppId)
                            text: {
                                root._desktopEntriesUpdateTrigger;
                                if (!effectiveAppId)
                                    return "?";
                                const desktopEntry = DesktopEntries.heuristicLookup(effectiveAppId);
                                const appName = Paths.getAppName(effectiveAppId, desktopEntry);
                                return appName.charAt(0).toUpperCase();
                            }
                            font.pixelSize: 10
                            color: Theme.widgetTextColor
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? -2 : 2
                            anchors.bottomMargin: -2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.primary
                            visible: isGrouped && windowCount > 1
                            z: 10

                            StyledText {
                                anchors.centerIn: parent
                                text: windowCount > 9 ? "9+" : windowCount
                                font.pixelSize: 9
                                color: Theme.surface
                            }
                        }

                        StyledText {
                            anchors.left: iconImg.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !(widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                            text: windowTitle
                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                            color: Theme.widgetTextColor
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        DankRipple {
                            id: itemRipple
                            cornerRadius: Theme.cornerRadius
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onPressed: mouse => {
                            const pos = mapToItem(visualContent, mouse.x, mouse.y);
                            itemRipple.trigger(pos.x, pos.y);
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (isGrouped && windowCount > 1) {
                                    let currentIndex = -1;
                                    for (var i = 0; i < groupData.windows.length; i++) {
                                        if (groupData.windows[i].toplevel.activated) {
                                            currentIndex = i;
                                            break;
                                        }
                                    }
                                    const nextIndex = (currentIndex + 1) % groupData.windows.length;
                                    groupData.windows[nextIndex].toplevel.activate();
                                } else if (toplevelObject) {
                                    toplevelObject.activate();
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }
                                tooltipLoader.active = false;

                                windowContextMenuLoader.active = true;
                                if (windowContextMenuLoader.item) {
                                    windowContextMenuLoader.item.currentWindow = toplevelObject;
                                    // Pass bar context
                                    windowContextMenuLoader.item.triggerBarConfig = root.barConfig;
                                    windowContextMenuLoader.item.triggerBarPosition = root.axis.edge === "left" ? 2 : (root.axis.edge === "right" ? 3 : (root.axis.edge === "top" ? 0 : 1));
                                    windowContextMenuLoader.item.triggerBarThickness = root.barThickness;
                                    windowContextMenuLoader.item.triggerBarSpacing = root.barSpacing;
                                    if (root.isVerticalOrientation) {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                        const relativeY = globalPos.y - screenY;
                                        // Add minTooltipY offset to account for top bar
                                        const adjustedY = relativeY + root.minTooltipY;
                                        const xPos = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                        windowContextMenuLoader.item.showAt(xPos, adjustedY, true, root.axis?.edge);
                                    } else {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const relativeX = globalPos.x - screenX;
                                        const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                        const isBottom = root.axis?.edge === "bottom";
                                        const yPos = isBottom ? (screenHeight - root.barThickness - root.barSpacing - 32 - Theme.spacingXS) : (root.barThickness + root.barSpacing + Theme.spacingXS);
                                        windowContextMenuLoader.item.showAt(relativeX, yPos, false, root.axis?.edge);
                                    }
                                }
                            } else if (mouse.button === Qt.MiddleButton) {
                                if (toplevelObject) {
                                    if (typeof toplevelObject.close === "function") {
                                        toplevelObject.close();
                                    }
                                }
                            }
                        }
                        onEntered: {
                            root.hoveredItem = delegateItem;
                            tooltipLoader.active = true;
                            if (tooltipLoader.item) {
                                if (root.isVerticalOrientation) {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                    const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                    const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                    const relativeY = globalPos.y - screenY;
                                    const tooltipX = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                    const isLeft = root.axis?.edge === "left";
                                    const adjustedY = relativeY + root.minTooltipY;
                                    const finalX = screenX + tooltipX;
                                    tooltipLoader.item.show(delegateItem.tooltipText, finalX, adjustedY, root.parentScreen, isLeft, !isLeft);
                                } else {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height);
                                    const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                    const isBottom = root.axis?.edge === "bottom";
                                    const tooltipY = isBottom ? (screenHeight - root.barThickness - root.barSpacing - Theme.spacingXS - 35) : (root.barThickness + root.barSpacing + Theme.spacingXS);
                                    tooltipLoader.item.show(delegateItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false);
                                }
                            }
                        }
                        onExited: {
                            if (root.hoveredItem === delegateItem) {
                                root.hoveredItem = null;
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }

                                tooltipLoader.active = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            spacing: Theme.spacingXS

            Repeater {
                id: windowRepeater
                model: ScriptModel {
                    values: _groupByApp ? groupedWindows : sortedToplevels
                    objectProp: _groupByApp ? "appId" : "address"
                }

                delegate: Item {
                    id: delegateItem

                    property bool isGrouped: root._groupByApp
                    property var groupData: isGrouped ? modelData : null
                    property var toplevelData: isGrouped ? (modelData.windows.length > 0 ? modelData.windows[0].toplevel : null) : modelData
                    property bool isFocused: isGrouped ? (root.focusedAppId === appId) : (toplevelData ? toplevelData.activated : false)
                    property string appId: isGrouped ? modelData.appId : (modelData.appId || "")
                    readonly property string effectiveAppId: {
                        root._appIdSubstitutionsTrigger;
                        return Paths.moddedAppId(appId);
                    }
                    property string windowTitle: toplevelData ? (toplevelData.title || "(Unnamed)") : "(Unnamed)"
                    property var toplevelObject: toplevelData
                    property int windowCount: isGrouped ? modelData.windows.length : 1
                    property string tooltipText: {
                        root._desktopEntriesUpdateTrigger;
                        const desktopEntry = effectiveAppId ? DesktopEntries.heuristicLookup(effectiveAppId) : null;
                        const appName = effectiveAppId ? Paths.getAppName(effectiveAppId, desktopEntry) : "Unknown";

                        if (isGrouped && windowCount > 1) {
                            return appName + " (" + windowCount + " windows)";
                        }
                        return appName + (windowTitle ? " • " + windowTitle : "");
                    }
                    readonly property real visualWidth: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? root.iconCellSize : (root.iconCellSize + Theme.spacingXS + 120)

                    width: root.barThickness
                    height: root.iconCellSize

                    Rectangle {
                        id: visualContent
                        width: delegateItem.visualWidth
                        height: root.iconCellSize
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: {
                            if (isFocused) {
                                return mouseArea.containsMouse ? Theme.primarySelected : Theme.withAlpha(Theme.primary, 0.2);
                            }
                            return mouseArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent";
                        }

                        IconImage {
                            id: iconImg
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)) / 2) : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            height: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            source: {
                                root._desktopEntriesUpdateTrigger;
                                root._appIdSubstitutionsTrigger;
                                if (!effectiveAppId)
                                    return "";
                                const desktopEntry = DesktopEntries.heuristicLookup(effectiveAppId);
                                return Paths.getAppIcon(effectiveAppId, desktopEntry);
                            }
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: appId === "org.quickshell"
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                saturation: 0
                                colorization: 1
                                colorizationColor: Theme.primary
                            }
                        }

                        DankIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? Math.round((parent.width - Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)) / 2) : Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            name: "sports_esports"
                            color: Theme.widgetTextColor
                            visible: !iconImg.visible && Paths.isSteamApp(effectiveAppId)
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !iconImg.visible && !Paths.isSteamApp(effectiveAppId)
                            text: {
                                root._desktopEntriesUpdateTrigger;
                                if (!effectiveAppId)
                                    return "?";
                                const desktopEntry = DesktopEntries.heuristicLookup(effectiveAppId);
                                const appName = Paths.getAppName(effectiveAppId, desktopEntry);
                                return appName.charAt(0).toUpperCase();
                            }
                            font.pixelSize: 10
                            color: Theme.widgetTextColor
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? -2 : 2
                            anchors.bottomMargin: -2
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.primary
                            visible: isGrouped && windowCount > 1
                            z: 10

                            StyledText {
                                anchors.centerIn: parent
                                text: windowCount > 9 ? "9+" : windowCount
                                font.pixelSize: 9
                                color: Theme.surface
                            }
                        }

                        StyledText {
                            anchors.left: iconImg.right
                            anchors.leftMargin: Theme.spacingXS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !(widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                            text: windowTitle
                            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                            color: Theme.widgetTextColor
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        DankRipple {
                            id: itemRipple
                            cornerRadius: Theme.cornerRadius
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: mouse => {
                            const pos = mapToItem(visualContent, mouse.x, mouse.y);
                            itemRipple.trigger(pos.x, pos.y);
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (isGrouped && windowCount > 1) {
                                    let currentIndex = -1;
                                    for (var i = 0; i < groupData.windows.length; i++) {
                                        if (groupData.windows[i].toplevel.activated) {
                                            currentIndex = i;
                                            break;
                                        }
                                    }
                                    const nextIndex = (currentIndex + 1) % groupData.windows.length;
                                    groupData.windows[nextIndex].toplevel.activate();
                                } else if (toplevelObject) {
                                    toplevelObject.activate();
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }
                                tooltipLoader.active = false;

                                windowContextMenuLoader.active = true;
                                if (windowContextMenuLoader.item) {
                                    windowContextMenuLoader.item.currentWindow = toplevelObject;
                                    // Pass bar context
                                    windowContextMenuLoader.item.triggerBarConfig = root.barConfig;
                                    windowContextMenuLoader.item.triggerBarPosition = root.axis.edge === "left" ? 2 : (root.axis.edge === "right" ? 3 : (root.axis.edge === "top" ? 0 : 1));
                                    windowContextMenuLoader.item.triggerBarThickness = root.barThickness;
                                    windowContextMenuLoader.item.triggerBarSpacing = root.barSpacing;
                                    if (root.isVerticalOrientation) {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                        const relativeY = globalPos.y - screenY;
                                        // Add minTooltipY offset to account for top bar
                                        const adjustedY = relativeY + root.minTooltipY;
                                        const xPos = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                        windowContextMenuLoader.item.showAt(xPos, adjustedY, true, root.axis?.edge);
                                    } else {
                                        const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, 0);
                                        const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                        const relativeX = globalPos.x - screenX;
                                        const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                        const isBottom = root.axis?.edge === "bottom";
                                        const yPos = isBottom ? (screenHeight - root.barThickness - root.barSpacing - 32 - Theme.spacingXS) : (root.barThickness + root.barSpacing + Theme.spacingXS);
                                        windowContextMenuLoader.item.showAt(relativeX, yPos, false, root.axis?.edge);
                                    }
                                }
                            }
                        }
                        onEntered: {
                            root.hoveredItem = delegateItem;
                            tooltipLoader.active = true;
                            if (tooltipLoader.item) {
                                if (root.isVerticalOrientation) {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                    const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                    const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                    const relativeY = globalPos.y - screenY;
                                    const tooltipX = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                    const isLeft = root.axis?.edge === "left";
                                    const adjustedY = relativeY + root.minTooltipY;
                                    const finalX = screenX + tooltipX;
                                    tooltipLoader.item.show(delegateItem.tooltipText, finalX, adjustedY, root.parentScreen, isLeft, !isLeft);
                                } else {
                                    const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height);
                                    const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                    const isBottom = root.axis?.edge === "bottom";
                                    const tooltipY = isBottom ? (screenHeight - root.barThickness - root.barSpacing - Theme.spacingXS - 35) : (root.barThickness + root.barSpacing + Theme.spacingXS);
                                    tooltipLoader.item.show(delegateItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false);
                                }
                            }
                        }
                        onExited: {
                            if (root.hoveredItem === delegateItem) {
                                root.hoveredItem = null;
                                if (tooltipLoader.item) {
                                    tooltipLoader.item.hide();
                                }

                                tooltipLoader.active = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader

        active: false

        sourceComponent: DankTooltip {}
    }

    Loader {
        id: windowContextMenuLoader
        active: false
        sourceComponent: PanelWindow {
            id: contextMenuWindow

            property var currentWindow: null
            property bool isVisible: false
            property point anchorPos: Qt.point(0, 0)
            property bool isVertical: false
            property string edge: "top"

            // New properties for bar context
            property int triggerBarPosition: (SettingsData.barConfigs[0]?.position ?? SettingsData.Position.Top)
            property real triggerBarThickness: 0
            property real triggerBarSpacing: 0
            property var triggerBarConfig: null

            readonly property real effectiveBarThickness: {
                if (triggerBarThickness > 0 && triggerBarSpacing > 0) {
                    return triggerBarThickness + triggerBarSpacing;
                }
                return Math.max(26 + (barConfig?.innerPadding ?? 4) * 0.6, Theme.barHeight - 4 - (8 - (barConfig?.innerPadding ?? 4))) + (barConfig?.spacing ?? 4);
            }

            property var barBounds: {
                if (!contextMenuWindow.screen || !triggerBarConfig) {
                    return {
                        "x": 0,
                        "y": 0,
                        "width": 0,
                        "height": 0,
                        "wingSize": 0
                    };
                }
                return SettingsData.getBarBounds(contextMenuWindow.screen, effectiveBarThickness, triggerBarPosition, triggerBarConfig);
            }

            property real barY: barBounds.y

            function showAt(x, y, vertical, barEdge) {
                screen = root.parentScreen;
                anchorPos = Qt.point(x, y);
                isVertical = vertical ?? false;
                edge = barEdge ?? "top";
                isVisible = true;
                visible = true;

                if (screen) {
                    TrayMenuManager.registerMenu(screen.name, contextMenuWindow);
                }
            }

            function close() {
                isVisible = false;
                visible = false;
                windowContextMenuLoader.active = false;

                if (screen) {
                    TrayMenuManager.unregisterMenu(screen.name);
                }
            }

            implicitWidth: 100
            implicitHeight: 40
            visible: false
            color: "transparent"

            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            Component.onDestruction: {
                if (screen) {
                    TrayMenuManager.unregisterMenu(screen.name);
                }
            }

            Connections {
                target: PopoutManager
                function onPopoutOpening() {
                    contextMenuWindow.close();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: contextMenuWindow.close()
            }

            Rectangle {
                x: {
                    if (contextMenuWindow.isVertical) {
                        if (contextMenuWindow.edge === "left") {
                            return Math.min(contextMenuWindow.width - width - 10, contextMenuWindow.anchorPos.x);
                        } else {
                            return Math.max(10, contextMenuWindow.anchorPos.x - width);
                        }
                    } else {
                        const left = 10;
                        const right = contextMenuWindow.width - width - 10;
                        const want = contextMenuWindow.anchorPos.x - width / 2;
                        return Math.max(left, Math.min(right, want));
                    }
                }
                y: {
                    if (contextMenuWindow.isVertical) {
                        const top = Math.max(barY, 10);
                        const bottom = contextMenuWindow.height - height - 10;
                        const want = contextMenuWindow.anchorPos.y - height / 2;
                        return Math.max(top, Math.min(bottom, want));
                    } else {
                        return contextMenuWindow.anchorPos.y;
                    }
                }
                width: 100
                height: 32
                color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: closeMouseArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: I18n.tr("Close")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenuWindow.currentWindow) {
                            contextMenuWindow.currentWindow.close();
                        }
                        contextMenuWindow.close();
                    }
                }
            }
        }
    }
}
