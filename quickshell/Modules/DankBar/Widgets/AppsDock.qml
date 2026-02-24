import QtQuick
import QtQuick.Effects
import Quickshell
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

    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool suppressShiftAnimation: false
    property int pinnedAppCount: 0

    property int maxVisibleApps: widgetData?.barMaxVisibleApps !== undefined ? widgetData.barMaxVisibleApps : SettingsData.barMaxVisibleApps
    property int maxVisibleRunningApps: widgetData?.barMaxVisibleRunningApps !== undefined ? widgetData.barMaxVisibleRunningApps : SettingsData.barMaxVisibleRunningApps
    property bool showOverflowBadge: widgetData?.barShowOverflowBadge !== undefined ? widgetData.barShowOverflowBadge : SettingsData.barShowOverflowBadge
    property bool overflowExpanded: false
    property int overflowItemCount: 0

    onMaxVisibleAppsChanged: updateModel()
    onMaxVisibleRunningAppsChanged: updateModel()

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

    // --- Dock Logic Helpers ---
    function movePinnedApp(fromDockIndex, toDockIndex) {
        if (fromDockIndex === toDockIndex)
            return;

        const currentPinned = [...(SessionData.barPinnedApps || [])];
        if (fromDockIndex < 0 || fromDockIndex >= currentPinned.length || toDockIndex < 0 || toDockIndex >= currentPinned.length) {
            return;
        }

        const movedApp = currentPinned.splice(fromDockIndex, 1)[0];
        currentPinned.splice(toDockIndex, 0, movedApp);

        SessionData.setBarPinnedApps(currentPinned);
    }

    property int _desktopEntriesUpdateTrigger: 0
    property int _toplevelsUpdateTrigger: 0
    property int _appIdSubstitutionsTrigger: 0

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            _toplevelsUpdateTrigger++;
            updateModel();
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
            updateModel();
        }
        function onRunningAppsCurrentWorkspaceChanged() {
            updateModel();
        }
        function onBarMaxVisibleAppsChanged() {
            updateModel();
        }
        function onBarMaxVisibleRunningAppsChanged() {
            updateModel();
        }
    }

    Connections {
        target: SessionData
        function onBarPinnedAppsChanged() {
            root.suppressShiftAnimation = true;
            root.draggedIndex = -1;
            root.dropTargetIndex = -1;
            updateModel();
            Qt.callLater(() => {
                root.suppressShiftAnimation = false;
            });
        }
    }

    property var dockItems: []

    function isOnScreen(toplevel, screenName) {
        if (!toplevel.screens)
            return false;
        for (let i = 0; i < toplevel.screens.length; i++) {
            if (toplevel.screens[i]?.name === screenName)
                return true;
        }
        return false;
    }

    function getCoreAppData(appId) {
        if (typeof AppSearchService === "undefined")
            return null;
        const coreApps = AppSearchService.coreApps || [];
        for (let i = 0; i < coreApps.length; i++) {
            if (coreApps[i].builtInPluginId === appId)
                return coreApps[i];
        }
        return null;
    }

    function getCoreAppDataByTitle(windowTitle) {
        if (typeof AppSearchService === "undefined" || !windowTitle)
            return null;
        const coreApps = AppSearchService.coreApps || [];
        for (let i = 0; i < coreApps.length; i++) {
            if (coreApps[i].name === windowTitle)
                return coreApps[i];
        }
        return null;
    }

    function createSeparator(key) {
        return {
            uniqueKey: key,
            type: "separator",
            appId: "__SEPARATOR__",
            toplevel: null,
            isPinned: false,
            isRunning: false,
            isInOverflow: false
        };
    }

    function markAsOverflow(item) {
        return {
            uniqueKey: item.uniqueKey,
            type: item.type,
            appId: item.appId,
            toplevel: item.toplevel,
            isPinned: item.isPinned,
            isRunning: item.isRunning,
            windowCount: item.windowCount,
            allWindows: item.allWindows,
            isCoreApp: item.isCoreApp,
            coreAppData: item.coreAppData,
            isInOverflow: true
        };
    }

    function markAsVisible(item) {
        return {
            uniqueKey: item.uniqueKey,
            type: item.type,
            appId: item.appId,
            toplevel: item.toplevel,
            isPinned: item.isPinned,
            isRunning: item.isRunning,
            windowCount: item.windowCount,
            allWindows: item.allWindows,
            isCoreApp: item.isCoreApp,
            coreAppData: item.coreAppData,
            isInOverflow: false
        };
    }

    function buildBaseItems() {
        const items = [];
        const pinnedApps = [...(SessionData.barPinnedApps || [])];
        _toplevelsUpdateTrigger;
        const allToplevels = CompositorService.sortedToplevels;

        let sortedToplevels = allToplevels;
        if (SettingsData.runningAppsCurrentWorkspace && parentScreen) {
            sortedToplevels = CompositorService.filterCurrentWorkspace(allToplevels, parentScreen.name) || [];
        }

        const appGroups = new Map();

        pinnedApps.forEach(rawAppId => {
            const appId = Paths.moddedAppId(rawAppId);
            const coreAppData = getCoreAppData(appId);
            appGroups.set(appId, {
                appId: appId,
                isPinned: true,
                windows: [],
                isCoreApp: coreAppData !== null,
                coreAppData: coreAppData
            });
        });

        sortedToplevels.forEach((toplevel, index) => {
            const rawAppId = toplevel.appId || "unknown";
            let appId = Paths.moddedAppId(rawAppId);

            let coreAppData = null;
            if (rawAppId === "org.quickshell") {
                coreAppData = getCoreAppDataByTitle(toplevel.title);
                if (coreAppData) {
                    appId = coreAppData.builtInPluginId;
                }
            }

            if (!appGroups.has(appId)) {
                appGroups.set(appId, {
                    appId: appId,
                    isPinned: false,
                    windows: [],
                    isCoreApp: coreAppData !== null,
                    coreAppData: coreAppData
                });
            }

            appGroups.get(appId).windows.push({
                toplevel: toplevel,
                index: index,
                windowTitle: toplevel.title
            });
        });

        const pinnedGroups = [];
        const unpinnedGroups = [];

        Array.from(appGroups.entries()).forEach(([appId, group]) => {
            const firstWindow = group.windows.length > 0 ? group.windows[0] : null;

            const item = {
                uniqueKey: "grouped_" + appId,
                type: "grouped",
                appId: appId,
                toplevel: firstWindow ? firstWindow.toplevel : null,
                isPinned: group.isPinned,
                isRunning: group.windows.length > 0,
                windowCount: group.windows.length,
                allWindows: group.windows,
                isCoreApp: group.isCoreApp || false,
                coreAppData: group.coreAppData || null,
                isInOverflow: false
            };

            if (group.isPinned) {
                pinnedGroups.push(item);
            } else {
                unpinnedGroups.push(item);
            }
        });

        pinnedGroups.forEach(item => items.push(item));

        if (pinnedGroups.length > 0 && unpinnedGroups.length > 0) {
            items.push(createSeparator("separator_grouped"));
        }

        unpinnedGroups.forEach(item => items.push(item));

        root.pinnedAppCount = pinnedGroups.length;
        return {
            items,
            pinnedCount: pinnedGroups.length,
            runningCount: unpinnedGroups.length
        };
    }

    function applyOverflow(baseResult) {
        const {
            items
        } = baseResult;
        const maxPinned = root.maxVisibleApps;
        const maxRunning = root.maxVisibleRunningApps;

        const pinnedItems = items.filter(i => i.type === "grouped" && i.isPinned);
        const runningItems = items.filter(i => i.type === "grouped" && i.isRunning && !i.isPinned);

        const pinnedOverflow = maxPinned > 0 && pinnedItems.length > maxPinned;
        const runningOverflow = maxRunning > 0 && runningItems.length > maxRunning;

        if (!pinnedOverflow && !runningOverflow) {
            root.overflowItemCount = 0;
            return items.map(i => markAsVisible(i));
        }

        const visiblePinnedKeys = new Set(pinnedOverflow ? pinnedItems.slice(0, maxPinned).map(i => i.uniqueKey) : pinnedItems.map(i => i.uniqueKey));
        const visibleRunningKeys = new Set(runningOverflow ? runningItems.slice(0, maxRunning).map(i => i.uniqueKey) : runningItems.map(i => i.uniqueKey));

        const overflowPinnedCount = pinnedOverflow ? pinnedItems.length - maxPinned : 0;
        const overflowRunningCount = runningOverflow ? runningItems.length - maxRunning : 0;
        const totalOverflow = overflowPinnedCount + overflowRunningCount;
        root.overflowItemCount = totalOverflow;

        const finalItems = [];
        let addedSeparator = false;

        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            switch (item.type) {
            case "separator":
                break;
            case "grouped":
                if (item.isPinned) {
                    if (visiblePinnedKeys.has(item.uniqueKey)) {
                        finalItems.push(markAsVisible(item));
                    } else {
                        finalItems.push(markAsOverflow(item));
                    }
                } else if (item.isRunning) {
                    if (!addedSeparator && finalItems.length > 0) {
                        finalItems.push(createSeparator("separator_overflow"));
                        addedSeparator = true;
                    }
                    if (visibleRunningKeys.has(item.uniqueKey)) {
                        finalItems.push(markAsVisible(item));
                    } else {
                        finalItems.push(markAsOverflow(item));
                    }
                }
                break;
            default:
                finalItems.push(item);
                break;
            }
        }

        if (totalOverflow > 0) {
            const toggleIndex = finalItems.findIndex(i => i.type === "separator");
            const insertPos = toggleIndex >= 0 ? toggleIndex : finalItems.length;
            finalItems.splice(insertPos, 0, {
                uniqueKey: "overflow_toggle",
                type: "overflow-toggle",
                appId: "__OVERFLOW_TOGGLE__",
                toplevel: null,
                isPinned: false,
                isRunning: false,
                isInOverflow: false,
                overflowCount: totalOverflow
            });
        }

        return finalItems;
    }

    function updateModel() {
        const baseResult = buildBaseItems();
        dockItems = applyOverflow(baseResult);
    }

    Component.onCompleted: updateModel()

    visible: dockItems.length > 0
    readonly property real iconCellSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale) + 6

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
                id: repeater
                model: ScriptModel {
                    values: root.dockItems
                    objectProp: "uniqueKey"
                }

                delegate: dockDelegate
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            spacing: Theme.spacingXS

            Repeater {
                model: ScriptModel {
                    values: root.dockItems
                    objectProp: "uniqueKey"
                }
                delegate: dockDelegate
            }
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Component {
        id: dockDelegate
        Item {
            id: delegateItem
            property bool isSeparator: modelData.type === "separator"
            readonly property bool isOverflowToggle: modelData.type === "overflow-toggle"
            readonly property bool isInOverflow: modelData.isInOverflow === true

            readonly property real visualSize: isSeparator ? 8 : ((widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode) ? root.iconCellSize : (root.iconCellSize + Theme.spacingXS + 120))
            readonly property real visualWidth: root.isVerticalOrientation ? root.barThickness : visualSize
            readonly property real visualHeight: root.isVerticalOrientation ? visualSize : root.barThickness

            visible: !isInOverflow || root.overflowExpanded
            opacity: (isInOverflow && !root.overflowExpanded) ? 0 : 1
            scale: (isInOverflow && !root.overflowExpanded) ? 0.8 : 1

            width: (isInOverflow && !root.overflowExpanded) ? 0 : visualWidth
            height: (isInOverflow && !root.overflowExpanded) ? 0 : visualHeight

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }

            z: (dragHandler.dragging) ? 100 : 0

            // --- Drag and Drop Shift Animation Logic ---
            property real shiftOffset: {
                if (root.draggedIndex < 0 || !modelData.isPinned || isSeparator)
                    return 0;
                if (index === root.draggedIndex)
                    return 0;

                const dragIdx = root.draggedIndex;
                const dropIdx = root.dropTargetIndex;
                const myIdx = index;
                const shiftAmount = visualSize + Theme.spacingXS;

                if (dropIdx < 0)
                    return 0;
                if (dragIdx < dropIdx && myIdx > dragIdx && myIdx <= dropIdx)
                    return -shiftAmount;
                if (dragIdx > dropIdx && myIdx >= dropIdx && myIdx < dragIdx)
                    return shiftAmount;
                return 0;
            }

            transform: Translate {
                x: root.isVerticalOrientation ? 0 : delegateItem.shiftOffset
                y: root.isVerticalOrientation ? delegateItem.shiftOffset : 0

                Behavior on x {
                    enabled: !root.suppressShiftAnimation
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: !root.suppressShiftAnimation
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                visible: isSeparator
                width: root.isVerticalOrientation ? root.barThickness * 0.6 : 2
                height: root.isVerticalOrientation ? 2 : root.barThickness * 0.6
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                radius: 1
                anchors.centerIn: parent
            }

            AppsDockOverflowButton {
                visible: isOverflowToggle
                anchors.centerIn: parent
                width: delegateItem.visualWidth
                height: delegateItem.visualHeight
                iconSize: 24
                overflowCount: modelData.overflowCount || 0
                overflowExpanded: root.overflowExpanded
                isVertical: root.isVerticalOrientation
                showBadge: root.showOverflowBadge
                z: 10
                onClicked: {
                    console.log("Overflow button clicked! Current state:", root.overflowExpanded);
                    root.overflowExpanded = !root.overflowExpanded;
                    console.log("New state:", root.overflowExpanded);
                }
            }

            Item {
                id: appItem
                visible: !isSeparator && !isOverflowToggle
                anchors.fill: parent

                property bool isFocused: {
                    if (modelData.type === "grouped") {
                        return modelData.allWindows.some(w => w.toplevel && w.toplevel.activated);
                    }
                    return modelData.toplevel ? modelData.toplevel.activated : false;
                }

                property var appId: modelData.appId
                property int windowCount: modelData.windowCount || (modelData.isRunning ? 1 : 0)
                property string windowTitle: {
                    if (modelData.type === "grouped") {
                        const active = modelData.allWindows.find(w => w.toplevel && w.toplevel.activated);
                        if (active)
                            return active.windowTitle || "(Unnamed)";
                        if (modelData.allWindows.length > 0)
                            return modelData.allWindows[0].windowTitle || "(Unnamed)";
                        return "";
                    }
                    return modelData.toplevel ? (modelData.toplevel.title || "(Unnamed)") : "";
                }

                property string tooltipText: {
                    root._desktopEntriesUpdateTrigger;
                    const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
                    const appName = appId ? Paths.getAppName(appId, desktopEntry) : "Unknown";

                    if (modelData.type === "grouped" && windowCount > 1) {
                        return appName + " (" + windowCount + " windows)";
                    }
                    return appName + (windowTitle ? " • " + windowTitle : "");
                }

                readonly property bool enlargeEnabled: (widgetData?.appsDockEnlargeOnHover !== undefined ? widgetData.appsDockEnlargeOnHover : SettingsData.appsDockEnlargeOnHover)
                readonly property real enlargeScale: enlargeEnabled && mouseArea.containsMouse ? (widgetData?.appsDockEnlargePercentage !== undefined ? widgetData.appsDockEnlargePercentage : SettingsData.appsDockEnlargePercentage) / 100.0 : 1.0
                readonly property real baseIconSizeMultiplier: (widgetData?.appsDockIconSizePercentage !== undefined ? widgetData.appsDockIconSizePercentage : SettingsData.appsDockIconSizePercentage) / 100.0
                readonly property real effectiveIconSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale) * baseIconSizeMultiplier

                readonly property color activeOverlayColor: {
                    switch (SettingsData.appsDockActiveColorMode) {
                    case "secondary":
                        return Theme.secondary;
                    case "primaryContainer":
                        return Theme.primaryContainer;
                    case "error":
                        return Theme.error;
                    case "success":
                        return Theme.success;
                    default:
                        return Theme.primary;
                    }
                }

                transform: Translate {
                    x: (dragHandler.dragging && !root.isVerticalOrientation) ? dragHandler.dragAxisOffset : 0
                    y: (dragHandler.dragging && root.isVerticalOrientation) ? dragHandler.dragAxisOffset : 0
                }

                Rectangle {
                    id: visualContent
                    width: root.isVerticalOrientation ? root.iconCellSize : delegateItem.visualSize
                    height: root.isVerticalOrientation ? delegateItem.visualSize : root.iconCellSize
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: {
                        const colorizeEnabled = (widgetData?.appsDockColorizeActive !== undefined ? widgetData.appsDockColorizeActive : SettingsData.appsDockColorizeActive);

                        if (appItem.isFocused && colorizeEnabled) {
                            return mouseArea.containsMouse ? Theme.withAlpha(Qt.lighter(appItem.activeOverlayColor, 1.3), 0.4) : Theme.withAlpha(appItem.activeOverlayColor, 0.3);
                        }
                        return mouseArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent";
                    }

                    border.width: dragHandler.dragging ? 2 : 0
                    border.color: Theme.primary
                    opacity: dragHandler.dragging ? 0.8 : 1.0

                    AppIconRenderer {
                        id: coreIcon
                        readonly property bool isCompact: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                        anchors.left: (root.isVerticalOrientation || isCompact) ? undefined : parent.left
                        anchors.leftMargin: (root.isVerticalOrientation || isCompact) ? 0 : Theme.spacingXS
                        anchors.top: (root.isVerticalOrientation && !isCompact) ? parent.top : undefined
                        anchors.topMargin: (root.isVerticalOrientation && !isCompact) ? Theme.spacingXS : 0
                        anchors.centerIn: (root.isVerticalOrientation || isCompact) ? parent : undefined

                        iconSize: appItem.effectiveIconSize
                        materialIconSizeAdjustment: 0
                        iconValue: {
                            if (!modelData || !modelData.isCoreApp || !modelData.coreAppData)
                                return "";
                            const appId = modelData.coreAppData.id || modelData.coreAppData.builtInPluginId;
                            if ((appId === "dms_settings" || appId === "dms_notepad" || appId === "dms_sysmon") && modelData.coreAppData.cornerIcon) {
                                return "material:" + modelData.coreAppData.cornerIcon;
                            }
                            return modelData.coreAppData.icon || "";
                        }
                        colorOverride: Theme.widgetIconColor
                        fallbackText: "?"
                        visible: iconValue !== ""
                        z: 2

                        transformOrigin: Item.Center
                        scale: appItem.enlargeScale
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    IconImage {
                        id: iconImg
                        readonly property bool isCompact: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                        anchors.left: (root.isVerticalOrientation || isCompact) ? undefined : parent.left
                        anchors.leftMargin: (root.isVerticalOrientation || isCompact) ? 0 : Theme.spacingXS
                        anchors.top: (root.isVerticalOrientation && !isCompact) ? parent.top : undefined
                        anchors.topMargin: (root.isVerticalOrientation && !isCompact) ? Theme.spacingXS : 0
                        anchors.centerIn: (root.isVerticalOrientation || isCompact) ? parent : undefined

                        width: appItem.effectiveIconSize
                        height: appItem.effectiveIconSize
                        source: {
                            root._desktopEntriesUpdateTrigger;
                            root._appIdSubstitutionsTrigger;
                            if (!appItem.appId)
                                return "";
                            if (modelData.isCoreApp)
                                return "";
                            const desktopEntry = DesktopEntries.heuristicLookup(appItem.appId);
                            return Paths.getAppIcon(appItem.appId, desktopEntry);
                        }
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: status === Image.Ready && !coreIcon.visible
                        layer.enabled: appItem.appId === "org.quickshell"
                        layer.smooth: true
                        layer.mipmap: true
                        layer.effect: MultiEffect {
                            saturation: 0
                            colorization: 1
                            colorizationColor: Theme.primary
                        }
                        z: 2

                        transformOrigin: Item.Center
                        scale: appItem.enlargeScale
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    DankIcon {
                        readonly property bool isCompact: (widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                        anchors.left: (root.isVerticalOrientation || isCompact) ? undefined : parent.left
                        anchors.leftMargin: (root.isVerticalOrientation || isCompact) ? 0 : Theme.spacingXS
                        anchors.top: (root.isVerticalOrientation && !isCompact) ? parent.top : undefined
                        anchors.topMargin: (root.isVerticalOrientation && !isCompact) ? Theme.spacingXS : 0
                        anchors.centerIn: (root.isVerticalOrientation || isCompact) ? parent : undefined

                        size: appItem.effectiveIconSize
                        name: "sports_esports"
                        color: Theme.widgetTextColor
                        visible: !iconImg.visible && !coreIcon.visible && Paths.isSteamApp(appItem.appId)

                        transformOrigin: Item.Center
                        scale: appItem.enlargeScale
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !iconImg.visible && !coreIcon.visible && !Paths.isSteamApp(appItem.appId)
                        text: {
                            root._desktopEntriesUpdateTrigger;
                            if (!appItem.appId)
                                return "?";
                            const desktopEntry = DesktopEntries.heuristicLookup(appItem.appId);
                            const appName = Paths.getAppName(appItem.appId, desktopEntry);
                            return appName.charAt(0).toUpperCase();
                        }
                        font.pixelSize: 10
                        color: Theme.widgetTextColor

                        transformOrigin: Item.Center
                        scale: appItem.enlargeScale
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
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
                        visible: modelData.type === "grouped" && appItem.windowCount > 1 && (widgetData?.barShowOverflowBadge !== undefined ? widgetData.barShowOverflowBadge : SettingsData.barShowOverflowBadge)
                        z: 10

                        StyledText {
                            anchors.centerIn: parent
                            text: appItem.windowCount > 9 ? "9+" : appItem.windowCount
                            font.pixelSize: 9
                            color: Theme.surface
                        }
                    }

                    StyledText {
                        visible: !root.isVerticalOrientation && !(widgetData?.runningAppsCompactMode !== undefined ? widgetData.runningAppsCompactMode : SettingsData.runningAppsCompactMode)
                        anchors.left: iconImg.right
                        anchors.leftMargin: Theme.spacingXS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: appItem.windowTitle || appItem.appId
                        font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Rectangle {
                        visible: modelData.isRunning && !(widgetData?.appsDockHideIndicators !== undefined ? widgetData.appsDockHideIndicators : SettingsData.appsDockHideIndicators)
                        width: root.isVerticalOrientation ? 2 : 20
                        height: root.isVerticalOrientation ? 20 : 2
                        radius: 1
                        color: appItem.isFocused ? Theme.primary : Theme.surfaceText
                        opacity: appItem.isFocused ? 1 : 0.5

                        anchors.bottom: root.isVerticalOrientation ? undefined : parent.bottom
                        anchors.right: root.isVerticalOrientation ? parent.right : undefined
                        anchors.horizontalCenter: root.isVerticalOrientation ? undefined : parent.horizontalCenter
                        anchors.verticalCenter: root.isVerticalOrientation ? parent.verticalCenter : undefined

                        anchors.margins: 0
                        z: 5
                    }
                }
            }

            // Handler for Drag Logic
            Item {
                id: dragHandler
                anchors.fill: parent
                property bool dragging: false
                property point dragStartPos: Qt.point(0, 0)
                property real dragAxisOffset: 0
                property bool longPressing: false

                Timer {
                    id: longPressTimer
                    interval: 500
                    repeat: false
                    onTriggered: {
                        if (modelData.isPinned) {
                            dragHandler.longPressing = true;
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dragHandler.longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.LeftButton && modelData.isPinned) {
                            dragHandler.dragStartPos = Qt.point(mouse.x, mouse.y);
                            longPressTimer.start();
                        }
                    }

                    onReleased: mouse => {
                        longPressTimer.stop();
                        const wasDragging = dragHandler.dragging;
                        const didReorder = wasDragging && root.dropTargetIndex >= 0 && root.dropTargetIndex !== root.draggedIndex;

                        if (didReorder) {
                            root.movePinnedApp(root.draggedIndex, root.dropTargetIndex);
                        }

                        dragHandler.longPressing = false;
                        dragHandler.dragging = false;
                        dragHandler.dragAxisOffset = 0;
                        root.draggedIndex = -1;
                        root.dropTargetIndex = -1;

                        if (wasDragging || mouse.button !== Qt.LeftButton)
                            return;

                        if (wasDragging || mouse.button !== Qt.LeftButton)
                            return;

                        if (modelData.type === "grouped") {
                            if (modelData.windowCount === 0) {
                                if (modelData.isCoreApp && modelData.coreAppData) {
                                    AppSearchService.executeCoreApp(modelData.coreAppData);
                                } else {
                                    const moddedId = Paths.moddedAppId(modelData.appId);
                                    const desktopEntry = DesktopEntries.heuristicLookup(moddedId);
                                    if (desktopEntry)
                                        SessionService.launchDesktopEntry(desktopEntry);
                                }
                            } else if (modelData.windowCount === 1) {
                                if (modelData.allWindows[0].toplevel)
                                    modelData.allWindows[0].toplevel.activate();
                            } else {
                                let currentIndex = -1;
                                for (var i = 0; i < modelData.allWindows.length; i++) {
                                    if (modelData.allWindows[i].toplevel.activated) {
                                        currentIndex = i;
                                        break;
                                    }
                                }
                                const nextIndex = (currentIndex + 1) % modelData.allWindows.length;
                                modelData.allWindows[nextIndex].toplevel.activate();
                            }
                        }
                    }

                    onPositionChanged: mouse => {
                        if (dragHandler.longPressing && !dragHandler.dragging) {
                            const distance = Math.sqrt(Math.pow(mouse.x - dragHandler.dragStartPos.x, 2) + Math.pow(mouse.y - dragHandler.dragStartPos.y, 2));
                            if (distance > 5) {
                                dragHandler.dragging = true;
                                root.draggedIndex = index;
                                root.dropTargetIndex = index;
                            }
                        }

                        if (!dragHandler.dragging)
                            return;

                        const axisOffset = root.isVerticalOrientation ? (mouse.y - dragHandler.dragStartPos.y) : (mouse.x - dragHandler.dragStartPos.x);
                        dragHandler.dragAxisOffset = axisOffset;

                        const itemSize = (root.isVerticalOrientation ? delegateItem.height : delegateItem.width) + Theme.spacingXS;
                        const slotOffset = Math.round(axisOffset / itemSize);
                        const newTargetIndex = Math.max(0, Math.min(root.pinnedAppCount - 1, index + slotOffset));

                        if (newTargetIndex !== root.dropTargetIndex) {
                            root.dropTargetIndex = newTargetIndex;
                        }
                    }

                    onEntered: {
                        root.hoveredItem = delegateItem;
                        if (isSeparator || isOverflowToggle)
                            return;

                        tooltipLoader.active = true;
                        if (tooltipLoader.item) {
                            if (root.isVerticalOrientation) {
                                const globalPos = delegateItem.mapToGlobal(0, delegateItem.height / 2);
                                const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                const isLeft = root.axis?.edge === "left";
                                const tooltipX = isLeft ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (root.parentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                                const screenRelativeY = globalPos.y - screenY + root.minTooltipY;
                                tooltipLoader.item.show(appItem.tooltipText, screenX + tooltipX, screenRelativeY, root.parentScreen, isLeft, !isLeft);
                            } else {
                                const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height);
                                const screenHeight = root.parentScreen ? root.parentScreen.height : Screen.height;
                                const isBottom = root.axis?.edge === "bottom";
                                const tooltipY = isBottom ? (screenHeight - root.barThickness - root.barSpacing - Theme.spacingXS - 35) : (root.barThickness + root.barSpacing + Theme.spacingXS);
                                tooltipLoader.item.show(appItem.tooltipText, globalPos.x, tooltipY, root.parentScreen, false, false);
                            }
                        }
                    }
                    onExited: {
                        if (root.hoveredItem === delegateItem) {
                            root.hoveredItem = null;
                            if (tooltipLoader.item)
                                tooltipLoader.item.hide();
                            tooltipLoader.active = false;
                        }
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (tooltipLoader.item) {
                                tooltipLoader.item.hide();
                            }
                            tooltipLoader.active = false;
                            contextMenuLoader.active = true;

                            if (contextMenuLoader.item) {
                                const globalPos = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2);
                                const screenX = root.parentScreen ? root.parentScreen.x : 0;
                                const screenY = root.parentScreen ? root.parentScreen.y : 0;
                                const isBarVertical = root.axis?.isVertical ?? false;
                                const barEdge = root.axis?.edge ?? "top";

                                let x = globalPos.x - screenX;
                                let y = globalPos.y - screenY;

                                switch (barEdge) {
                                case "bottom":
                                    y = (root.parentScreen ? root.parentScreen.height : Screen.height) - root.barThickness - root.barSpacing;
                                    break;
                                case "top":
                                    y = root.barThickness + root.barSpacing;
                                    break;
                                case "left":
                                    x = root.barThickness + root.barSpacing;
                                    break;
                                case "right":
                                    x = (root.parentScreen ? root.parentScreen.width : Screen.width) - root.barThickness - root.barSpacing;
                                    break;
                                }

                                const shouldHidePin = modelData.appId === "org.quickshell";
                                const moddedId = Paths.moddedAppId(modelData.appId);
                                const desktopEntry = moddedId ? DesktopEntries.heuristicLookup(moddedId) : null;

                                contextMenuLoader.item.showAt(x, y, isBarVertical, barEdge, modelData, shouldHidePin, desktopEntry, root.parentScreen);
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: contextMenuLoader
        active: false
        source: "AppsDockContextMenu.qml"
    }
}
