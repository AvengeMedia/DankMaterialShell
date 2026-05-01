import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Services

Item {
    id: root

    property var contextMenu: null
    property var trashContextMenu: null
    property bool requestDockShow: false
    property int pinnedAppCount: 0
    property bool groupByApp: false
    property bool isVertical: false
    property var dockScreen: null
    property real iconSize: 40
    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool suppressShiftAnimation: false
    property int maxVisibleApps: SettingsData.dockMaxVisibleApps
    property int maxVisibleRunningApps: SettingsData.dockMaxVisibleRunningApps
    property bool overflowExpanded: false
    property int overflowItemCount: 0

    readonly property real baseImplicitWidth: isVertical ? baseAppHeight : baseAppWidth
    readonly property real baseImplicitHeight: isVertical ? baseAppWidth : baseAppHeight
    readonly property real baseAppWidth: {
        let count = 0;
        const items = repeater.dockItems;
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item.isInOverflow)
                continue;
            if (item.type === "separator") {
                count += 8 / (iconSize * 1.2);
            } else {
                count += 1;
            }
        }
        return count * (iconSize * 1.2) + Math.max(0, count - 1) * layoutFlow.spacing;
    }
    readonly property real baseAppHeight: iconSize

    clip: false
    implicitWidth: isVertical ? appLayout.height : appLayout.width
    implicitHeight: isVertical ? appLayout.width : appLayout.height

    function dockIndexToPinnedIndex(dockIndex) {
        if (!SettingsData.dockLauncherEnabled)
            return dockIndex;

        const launcherPos = SessionData.dockLauncherPosition;
        return dockIndex < launcherPos ? dockIndex : dockIndex - 1;
    }

    function movePinnedApp(fromDockIndex, toDockIndex) {
        const fromPinnedIndex = dockIndexToPinnedIndex(fromDockIndex);
        const toPinnedIndex = dockIndexToPinnedIndex(toDockIndex);

        if (fromPinnedIndex === toPinnedIndex)
            return;

        const currentPinned = [...(SessionData.pinnedApps || [])];
        if (fromPinnedIndex < 0 || fromPinnedIndex >= currentPinned.length || toPinnedIndex < 0 || toPinnedIndex >= currentPinned.length)
            return;

        const movedApp = currentPinned.splice(fromPinnedIndex, 1)[0];
        currentPinned.splice(toPinnedIndex, 0, movedApp);
        SessionData.setPinnedApps(currentPinned);
    }

    Item {
        id: appLayout
        width: layoutFlow.width
        height: layoutFlow.height

        Behavior on width {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }
        anchors.horizontalCenter: root.isVertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined
        anchors.left: root.isVertical && SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined
        anchors.right: root.isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined
        anchors.top: root.isVertical ? undefined : parent.top

        Flow {
            id: layoutFlow
            flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: Math.min(8, Math.max(4, root.iconSize * 0.08))

            Repeater {
                id: repeater

                property var dockItems: []

                model: ScriptModel {
                    values: repeater.dockItems
                    objectProp: "uniqueKey"
                }

                Component.onCompleted: updateModel()

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

                function buildBaseItems() {
                    const items = [];
                    const pinnedApps = [...(SessionData.pinnedApps || [])];
                    const allToplevels = CompositorService.sortedToplevels;
                    const sortedToplevels = (SettingsData.dockIsolateDisplays && root.dockScreen) ? allToplevels.filter(t => isOnScreen(t, root.dockScreen.name)) : allToplevels;

                    if (root.groupByApp) {
                        return buildGroupedItems(pinnedApps, sortedToplevels);
                    }
                    return buildUngroupedItems(pinnedApps, sortedToplevels);
                }

                function buildGroupedItems(pinnedApps, sortedToplevels) {
                    const items = [];
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

                        if (rawAppId === "org.quickshell" || rawAppId === "com.danklinux.dms") {
                            coreAppData = getCoreAppDataByTitle(toplevel.title);
                            if (coreAppData)
                                appId = coreAppData.builtInPluginId;
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
                            index: index
                        });
                    });

                    const pinnedGroups = [];
                    const unpinnedGroups = [];

                    appGroups.forEach((group, appId) => {
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
                        (group.isPinned ? pinnedGroups : unpinnedGroups).push(item);
                    });

                    pinnedGroups.forEach(item => items.push(item));
                    insertLauncher(items);

                    if (pinnedGroups.length > 0 && unpinnedGroups.length > 0) {
                        items.push(createSeparator("separator_grouped"));
                    }
                    unpinnedGroups.forEach(item => items.push(item));

                    root.pinnedAppCount = pinnedGroups.length + (SettingsData.dockLauncherEnabled ? 1 : 0);
                    return {
                        items,
                        pinnedCount: pinnedGroups.length,
                        runningCount: unpinnedGroups.length
                    };
                }

                function buildUngroupedItems(pinnedApps, sortedToplevels) {
                    const items = [];
                    const runningAppIds = new Set();
                    const windowItems = [];

                    sortedToplevels.forEach((toplevel, index) => {
                        let uniqueKey = "window_" + index;
                        if (CompositorService.isHyprland && Hyprland.toplevels) {
                            const hyprlandToplevels = Array.from(Hyprland.toplevels.values);
                            for (let i = 0; i < hyprlandToplevels.length; i++) {
                                if (hyprlandToplevels[i].wayland === toplevel) {
                                    uniqueKey = "window_" + hyprlandToplevels[i].address;
                                    break;
                                }
                            }
                        }

                        const rawAppId = toplevel.appId || "unknown";
                        const moddedAppId = Paths.moddedAppId(rawAppId);
                        let coreAppData = null;
                        let isCoreApp = false;

                        if (rawAppId === "org.quickshell" || rawAppId === "com.danklinux.dms") {
                            coreAppData = getCoreAppDataByTitle(toplevel.title);
                            if (coreAppData)
                                isCoreApp = true;
                        }

                        const finalAppId = isCoreApp ? coreAppData.builtInPluginId : moddedAppId;
                        windowItems.push({
                            uniqueKey: uniqueKey,
                            type: "window",
                            appId: finalAppId,
                            toplevel: toplevel,
                            isPinned: false,
                            isRunning: true,
                            isCoreApp: isCoreApp,
                            coreAppData: coreAppData,
                            isInOverflow: false
                        });
                        runningAppIds.add(finalAppId);
                    });

                    const remainingWindowItems = windowItems.slice();

                    pinnedApps.forEach(rawAppId => {
                        const appId = Paths.moddedAppId(rawAppId);
                        const coreAppData = getCoreAppData(appId);
                        const matchIndex = remainingWindowItems.findIndex(item => item.appId === appId);

                        if (matchIndex !== -1) {
                            const windowItem = remainingWindowItems.splice(matchIndex, 1)[0];
                            windowItem.isPinned = true;
                            windowItem.uniqueKey = "pinned_" + appId;
                            if (!windowItem.isCoreApp && coreAppData) {
                                windowItem.isCoreApp = true;
                                windowItem.coreAppData = coreAppData;
                            }
                            items.push(windowItem);
                        } else {
                            items.push({
                                uniqueKey: "pinned_" + appId,
                                type: "pinned",
                                appId: appId,
                                toplevel: null,
                                isPinned: true,
                                isRunning: runningAppIds.has(appId),
                                isCoreApp: coreAppData !== null,
                                coreAppData: coreAppData,
                                isInOverflow: false
                            });
                        }
                    });

                    root.pinnedAppCount = pinnedApps.length + (SettingsData.dockLauncherEnabled ? 1 : 0);
                    insertLauncher(items);

                    if (pinnedApps.length > 0 && remainingWindowItems.length > 0) {
                        items.push(createSeparator("separator_ungrouped"));
                    }
                    remainingWindowItems.forEach(item => items.push(item));

                    return {
                        items,
                        pinnedCount: pinnedApps.length,
                        runningCount: remainingWindowItems.length
                    };
                }

                function insertLauncher(targetArray) {
                    if (!SettingsData.dockLauncherEnabled)
                        return;
                    const launcherItem = {
                        uniqueKey: "launcher_button",
                        type: "launcher",
                        appId: "__LAUNCHER__",
                        toplevel: null,
                        isPinned: true,
                        isRunning: false
                    };
                    const pos = Math.max(0, Math.min(SessionData.dockLauncherPosition, targetArray.length));
                    targetArray.splice(pos, 0, launcherItem);
                }

                function createSeparator(key) {
                    return {
                        uniqueKey: key,
                        type: "separator",
                        appId: "__SEPARATOR__",
                        toplevel: null,
                        isPinned: false,
                        isRunning: false
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

                function applyOverflow(baseResult) {
                    const {
                        items
                    } = baseResult;
                    const maxPinned = root.maxVisibleApps;
                    const maxRunning = root.maxVisibleRunningApps;

                    const pinnedItems = items.filter(i => (i.type === "pinned" || i.type === "grouped" || i.type === "window") && i.isPinned && i.appId !== "__LAUNCHER__");
                    const runningItems = items.filter(i => (i.type === "window" || i.type === "grouped") && i.isRunning && !i.isPinned);

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
                        case "launcher":
                            finalItems.push(item);
                            break;
                        case "separator":
                            break;
                        case "pinned":
                        case "grouped":
                        case "window":
                            if (item.isPinned && item.appId !== "__LAUNCHER__") {
                                if (visiblePinnedKeys.has(item.uniqueKey)) {
                                    finalItems.push(markAsVisible(item));
                                } else {
                                    finalItems.push(markAsOverflow(item));
                                }
                            } else if (item.isRunning && !item.isPinned) {
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
                            overflowCount: totalOverflow
                        });
                    }

                    return finalItems;
                }

                function updateModel() {
                    const baseResult = buildBaseItems();
                    let finalItems = applyOverflow(baseResult);
                    if (SettingsData.dockShowTrash) {
                        finalItems.push({
                            uniqueKey: "trash_button",
                            type: "trash",
                            appId: "__TRASH__",
                            toplevel: null,
                            isPinned: false,
                            isRunning: false,
                            isInOverflow: false
                        });
                    }
                    dockItems = finalItems;
                }

                delegate: Item {
                    id: delegateItem

                    property var dockButton: {
                        switch (itemData.type) {
                        case "launcher":
                            return launcherButton;
                        case "trash":
                            return trashButton;
                        default:
                            return button;
                        }
                    }
                    property var itemData: modelData
                    readonly property bool isOverflowToggle: itemData.type === "overflow-toggle"
                    readonly property bool isTrash: itemData.type === "trash"
                    readonly property bool isInOverflow: itemData.isInOverflow === true
                    readonly property bool isDragging: {
                        switch (itemData.type) {
                        case "launcher":
                            return launcherButton.dragging;
                        case "trash":
                            return false;
                        default:
                            return button.dragging;
                        }
                    }

                    clip: false
                    z: isDragging ? 100 : 0
                    visible: !isInOverflow || root.overflowExpanded
                    opacity: (isInOverflow && !root.overflowExpanded) ? 0 : 1
                    scale: (isInOverflow && !root.overflowExpanded) ? 0.8 : 1

                    width: (isInOverflow && !root.overflowExpanded) ? 0 : (itemData.type === "separator" ? (root.isVertical ? root.iconSize : 8) : (root.isVertical ? root.iconSize : root.iconSize * 1.2))
                    height: (isInOverflow && !root.overflowExpanded) ? 0 : (itemData.type === "separator" ? (root.isVertical ? 8 : root.iconSize) : (root.isVertical ? root.iconSize * 1.2 : root.iconSize))

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

                    property real shiftOffset: {
                        if (root.draggedIndex < 0 || !itemData.isPinned || itemData.type === "separator")
                            return 0;
                        if (model.index === root.draggedIndex)
                            return 0;

                        const dragIdx = root.draggedIndex;
                        const dropIdx = root.dropTargetIndex;
                        const myIdx = model.index;
                        const shiftAmount = root.iconSize * 1.2 + layoutFlow.spacing;

                        if (dropIdx < 0)
                            return 0;
                        if (dragIdx < dropIdx && myIdx > dragIdx && myIdx <= dropIdx)
                            return -shiftAmount;
                        if (dragIdx > dropIdx && myIdx >= dropIdx && myIdx < dragIdx)
                            return shiftAmount;
                        return 0;
                    }

                    transform: Translate {
                        x: root.isVertical ? 0 : delegateItem.shiftOffset
                        y: root.isVertical ? delegateItem.shiftOffset : 0

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
                        visible: itemData.type === "separator"
                        width: root.isVertical ? root.iconSize * 0.5 : 2
                        height: root.isVertical ? 2 : root.iconSize * 0.5
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        radius: 1
                        anchors.centerIn: parent
                    }

                    DockOverflowButton {
                        id: overflowButton
                        visible: isOverflowToggle
                        anchors.centerIn: parent
                        width: delegateItem.width
                        height: delegateItem.height
                        actualIconSize: root.iconSize
                        overflowCount: itemData.overflowCount || 0
                        overflowExpanded: root.overflowExpanded
                        isVertical: root.isVertical
                        onClicked: root.overflowExpanded = !root.overflowExpanded
                    }

                    DockLauncherButton {
                        id: launcherButton
                        visible: itemData.type === "launcher"
                        anchors.centerIn: parent
                        width: delegateItem.width
                        height: delegateItem.height
                        actualIconSize: root.iconSize
                        dockApps: root
                        index: model.index
                    }

                    DockTrashButton {
                        id: trashButton
                        visible: itemData.type === "trash"
                        anchors.centerIn: parent
                        width: delegateItem.width
                        height: delegateItem.height
                        actualIconSize: root.iconSize
                        dockApps: root
                        contextMenu: root.trashContextMenu
                        parentDockScreen: root.dockScreen
                    }

                    DockAppButton {
                        id: button
                        visible: !isOverflowToggle && itemData.type !== "separator" && itemData.type !== "launcher" && itemData.type !== "trash"
                        anchors.centerIn: parent
                        width: delegateItem.width
                        height: delegateItem.height
                        actualIconSize: root.iconSize
                        appData: itemData
                        contextMenu: root.contextMenu
                        dockApps: root
                        index: model.index
                        parentDockScreen: root.dockScreen
                        showWindowTitle: itemData?.type === "window" || itemData?.type === "grouped"
                        windowTitle: {
                            const title = itemData?.toplevel?.title || "(Unnamed)";
                            return title.length > 50 ? title.substring(0, 47) + "..." : title;
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            repeater.updateModel();
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            root.suppressShiftAnimation = true;
            root.draggedIndex = -1;
            root.dropTargetIndex = -1;
            repeater.updateModel();
            Qt.callLater(() => {
                root.suppressShiftAnimation = false;
            });
        }
        function onDockLauncherPositionChanged() {
            root.suppressShiftAnimation = true;
            root.draggedIndex = -1;
            root.dropTargetIndex = -1;
            repeater.updateModel();
            Qt.callLater(() => {
                root.suppressShiftAnimation = false;
            });
        }
    }

    Connections {
        target: SettingsData
        function onDockIsolateDisplaysChanged() {
            repeater.updateModel();
        }
        function onDockLauncherEnabledChanged() {
            root.suppressShiftAnimation = true;
            root.draggedIndex = -1;
            root.dropTargetIndex = -1;
            repeater.updateModel();
            Qt.callLater(() => {
                root.suppressShiftAnimation = false;
            });
        }
        function onDockMaxVisibleAppsChanged() {
            repeater.updateModel();
        }
        function onDockMaxVisibleRunningAppsChanged() {
            repeater.updateModel();
        }
        function onDockShowTrashChanged() {
            repeater.updateModel();
        }
    }

    onGroupByAppChanged: repeater.updateModel()
}
