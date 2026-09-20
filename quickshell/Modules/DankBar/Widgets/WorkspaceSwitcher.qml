import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.WindowManager
import qs.Common
import qs.Modules.DankBar
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "../../../Common/WorkspaceModel.js" as WorkspaceModel

BasePill {
    id: root

    enableBackgroundHover: false

    property bool isVertical: axis?.isVertical ?? false
    property var widgetData: null
    property string screenName: ""
    property var hyprlandOverviewLoader: null
    property var surfaceContext: null
    readonly property string indicatorStyle: root.opt("workspaceIndicatorStyle")
    readonly property bool linesStyle: indicatorStyle === "lines"
    readonly property bool cardsStyle: indicatorStyle === "cards"
    readonly property bool segmented: !linesStyle && !cardsStyle && surfaceContext?.kind !== "dock" && BarMetrics.widgetStyle(barConfig) === "segments" && !noBackground
    readonly property real compactRatio: cardsStyle ? 0.75 : 0.7
    readonly property real slimRatio: 0.5
    readonly property real activeSlimRatio: 0.6
    readonly property real activeRatio: linesStyle ? 1.6 : cardsStyle ? 0.9 : 1.05
    readonly property real activeIconRatio: 1.6
    readonly property real iconRatio: 1.2
    readonly property real lineRatio: 0.12
    readonly property real activeLineRatio: 0.2
    readonly property real overviewTintAlpha: 0.18
    readonly property real dragOpacity: 0.8
    readonly property real hoverFadeAlpha: 0.7
    readonly property real cardWindowRatio: 0.45

    readonly property bool useAqueous: CompositorService.isAqueous && AqueousService.available && Quickshell.env("DMS_FORCE_EXTWS") !== "1"

    function opt(key) {
        return SettingsData.widgetOption("workspaceSwitcher", widgetData, key);
    }

    property int _desktopEntriesUpdateTrigger: 0

    readonly property string effectiveScreenName: {
        if (!root.opt("workspaceFollowFocus"))
            return root.screenName;
        return BarWidgetService.getFocusedScreenName() || root.screenName;
    }
    readonly property bool workspacesHiddenByOverview: CompositorService.workspacesHiddenByOverview(effectiveScreenName)

    readonly property bool isFocusedMonitor: {
        const focused = BarWidgetService.getFocusedScreenName();
        return focused === "" || root.screenName === "" || focused === root.screenName;
    }
    readonly property bool useUnfocusedAppearance: !isFocusedMonitor && root.opt("workspaceUnfocusedMonitorSeparateAppearance") && BarWidgetService.focusedScreenDetectionSupported

    readonly property var extProjection: (useExtWorkspace && parentScreen) ? WindowManager.screenProjection(CompositorService.isAqueous ? Quickshell.screens.find(s => s.name === effectiveScreenName) || parentScreen : parentScreen) : null
    readonly property bool useExtWorkspace: {
        if (useAqueous)
            return false;
        if (Quickshell.env("DMS_FORCE_EXTWS") === "1")
            return (WindowManager.windowsets?.length ?? 0) > 0;
        if (!CompositorService.compositorDetected || CompositorService.hasWorkspaceIpc)
            return false;
        return (WindowManager.windowsets?.length ?? 0) > 0;
    }
    readonly property bool useNativeWorkspaces: useAqueous || (!useExtWorkspace && CompositorService.hasWorkspaceIpc)

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++;
        }
    }

    readonly property string compositorName: CompositorService.compositor

    onCompositorNameChanged: {
        _placeholderPool = [];
        _hyprSlotPool = {};
    }

    property var currentWorkspace: {
        if (useExtWorkspace)
            return getExtWorkspaceActiveWorkspace();
        if (!useNativeWorkspaces)
            return 1;
        return CompositorService.currentWorkspaceKey(root.screenName, root.opt("workspaceFollowFocus"));
    }
    property var workspaceList: {
        if (useExtWorkspace) {
            const baseList = getExtWorkspaceWorkspaces();
            return root.opt("showWorkspacePadding") ? padWorkspaces(baseList) : baseList;
        }
        if (!useNativeWorkspaces)
            return [1];
        if (root.workspacesHiddenByOverview)
            return [];

        const baseList = CompositorService.workspacesForScreen(root.screenName, root.opt("workspaceFollowFocus"), {
            "occupiedOnly": root.opt("showOccupiedWorkspacesOnly"),
            "showAllTags": root.opt("dwlShowAllTags"),
            "minCount": root.opt("showWorkspacePadding") ? root.opt("workspacePaddingCount") : 0,
            "showSpecial": root.opt("showSpecialWorkspaces")
        });
        if (CompositorService.ephemeralWorkspaces)
            return hyprlandSlotList(baseList);
        if (!root.opt("showWorkspacePadding") || CompositorService.supportsPersistentWorkspaces || (root.useAqueous && baseList.length === 0))
            return baseList;
        return padWorkspaces(baseList);
    }

    function getWorkspaceIcons(ws) {
        _desktopEntriesUpdateTrigger;
        if (!root.opt("showWorkspaceApps") || !ws || !root.useNativeWorkspaces || ws.placeholder) {
            return [];
        }

        const byApp = {};
        const isActiveWs = CompositorService.workspaceAppsActive(ws, root.currentWorkspace);

        CompositorService.windowsOnWorkspace(ws).forEach((w, i) => {
            const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown");
            const moddedId = Paths.moddedAppId(keyBase);
            const groupThisWs = root.opt("groupWorkspaceApps") && (!isActiveWs || root.opt("groupActiveWorkspaceApps"));
            const key = groupThisWs ? moddedId : (w.aqueousKey || `${moddedId}_${i}`);

            if (!byApp[key]) {
                const isQuickshell = keyBase === "org.quickshell" || keyBase === "com.danklinux.dms";
                const isSteamApp = Paths.isSteamApp(moddedId);
                const desktopEntry = DesktopEntries.heuristicLookup(moddedId);
                const icon = Paths.getAppIcon(moddedId, desktopEntry);
                const appName = Paths.getAppName(moddedId, desktopEntry);
                byApp[key] = {
                    "type": "icon",
                    "icon": icon,
                    "isQuickshell": isQuickshell,
                    "isSteamApp": isSteamApp,
                    "active": !!(w.activated || w.is_focused),
                    "count": 1,
                    "windowId": w.address || w.id,
                    "windowSession": useAqueous ? w.aqueousSession : "",
                    "fallbackText": appName || ""
                };
            } else {
                byApp[key].count++;
                if (w.activated || w.is_focused) {
                    byApp[key].active = true;
                }
            }
        });

        return Object.values(byApp);
    }

    // Hyprland creates/destroys workspaces on empty enter/leave; slots keyed by id keep delegate identity so pills animate instead of popping
    property var _hyprSlotPool: ({})

    Component {
        id: hyprSlotComponent

        QtObject {
            property var ws: null
        }
    }

    function recordOf(entry) {
        if (!entry || entry.ws === undefined)
            return entry;
        return entry.ws;
    }

    function _hyprSlot(key, ws) {
        let slot = _hyprSlotPool[key];
        if (!slot) {
            slot = hyprSlotComponent.createObject(root);
            _hyprSlotPool[key] = slot;
        }
        if (slot.ws !== ws)
            slot.ws = ws;
        return slot;
    }

    function hyprlandSlotList(raw) {
        return raw.map(ws => _hyprSlot(ws.id > 0 ? ws.id : (ws.special ? "special:" : "name:") + (ws.name ?? ""), ws));
    }

    // Stable placeholder instances so ScriptModel (identity-diffed) reuses padding delegates instead of recreating them on workspace churn
    property var _placeholderPool: []

    function padWorkspaces(list) {
        const padded = list.slice();
        const minCount = root.opt("workspacePaddingCount");
        let slot = 0;
        while (padded.length < minCount) {
            if (root._placeholderPool.length <= slot)
                root._placeholderPool.push(WorkspaceModel.placeholder());
            padded.push(root._placeholderPool[slot]);
            slot++;
        }
        return padded;
    }

    function getExtWorkspaceWorkspaces() {
        const fallback = [
            {
                "id": "1",
                "name": "1",
                "active": false
            }
        ];
        if (!extProjection)
            return fallback;

        let visible = extProjection.windowsets.filter(ws => ws.shouldDisplay);

        const hasValidCoordinates = visible.some(ws => ws.coordinates && ws.coordinates.length > 0);
        if (hasValidCoordinates) {
            visible = visible.slice().sort((a, b) => {
                const coordsA = a.coordinates || [0, 0];
                const coordsB = b.coordinates || [0, 0];
                if (coordsA[0] !== coordsB[0])
                    return coordsA[0] - coordsB[0];
                return coordsA[1] - coordsB[1];
            });
        }

        return visible.length > 0 ? visible : fallback;
    }

    function getExtWorkspaceActiveWorkspace() {
        if (!extProjection)
            return "";
        const activeWs = extProjection.windowsets.find(ws => ws.active);
        return activeWs || null;
    }

    readonly property real appIconSize: Theme.barIconSize(barThickness, -6 + root.opt("workspaceAppIconSizeOffset"), root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => ws && !root.recordOf(ws).placeholder);
    }

    function switchToWorkspaceByModelData(entry) {
        const data = root.recordOf(entry);
        if (!data || data.placeholder)
            return;
        if (root.useNativeWorkspaces) {
            CompositorService.switchToWorkspace(data, root.effectiveScreenName);
            return;
        }
        if (root.useExtWorkspace && typeof data.activate === "function")
            data.activate();
    }

    function toggleHyprlandOverview() {
        const overview = root.hyprlandOverviewLoader?.item;
        if (!overview)
            return;
        overview.overviewOpen = !overview.overviewOpen;
    }

    function findClosestWorkspaceIndex(localX, localY) {
        if (workspaceRepeater.count === 0)
            return -1;

        let closestIdx = -1;
        let closestDist = Infinity;

        for (let i = 0; i < workspaceRepeater.count; i++) {
            const item = workspaceRepeater.itemAt(i);
            if (!item || item.isPlaceholder)
                continue;
            const center = item.mapToItem(root, item.width / 2, item.height / 2);
            const dist = isVertical ? Math.abs(localY - center.y) : Math.abs(localX - center.x);
            if (dist < closestDist) {
                closestDist = dist;
                closestIdx = i;
            }
        }
        return closestIdx;
    }

    function switchWorkspace(direction) {
        if (useAqueous) {
            const workspaces = getRealWorkspaces();
            const index = workspaces.findIndex(w => w.id === currentWorkspace);
            const next = Math.max(0, Math.min(workspaces.length - 1, index + (direction > 0 ? 1 : -1)));
            if (next !== index)
                CompositorService.switchToWorkspace(workspaces[next]);
            return;
        }
        if (useExtWorkspace) {
            const realWorkspaces = getRealWorkspaces();
            if (realWorkspaces.length < 2) {
                return;
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex === validIndex) {
                return;
            }

            const nextWorkspace = realWorkspaces[nextIndex];
            if (typeof nextWorkspace.activate === "function")
                nextWorkspace.activate();
            return;
        }
        if (!useNativeWorkspaces)
            return;
        // specials are overlays you toggle, not positions you scroll to
        CompositorService.stepWorkspace(getRealWorkspaces().map(ws => root.recordOf(ws)).filter(ws => ws.special !== true), root.currentWorkspace, direction);
    }

    function getWorkspaceIndexFallback(modelData, index) {
        if (root.useExtWorkspace)
            return index + 1;
        if (!root.useNativeWorkspaces)
            return modelData - 1;
        return modelData?.idx ?? modelData?.name ?? "";
    }

    function getWorkspaceIndex(modelData, index) {
        if (modelData?.placeholder === true)
            return index + 1;

        let workspaceName = "";
        if (root.opt("showWorkspaceName")) {
            workspaceName = modelData?.name ?? "";

            if (workspaceName && workspaceName !== "") {
                if (root.isVertical) {
                    workspaceName = workspaceName.charAt(0);
                }
            } else {
                workspaceName = "";
            }
        }

        if (workspaceName) {
            if (root.opt("showWorkspaceIndex")) {
                const indexLabel = getWorkspaceIndexFallback(modelData, index);
                return indexLabel ? `${indexLabel}: ${workspaceName}` : workspaceName;
            }
            return workspaceName;
        }

        return getWorkspaceIndexFallback(modelData, index);
    }

    readonly property bool hasWorkspaces: getRealWorkspaces().length > 0
    readonly property bool shouldShow: useNativeWorkspaces || (useExtWorkspace && hasWorkspaces)

    width: shouldShow ? (isVertical ? barThickness : visualWidth) : 0
    height: shouldShow ? (isVertical ? visualHeight : barThickness) : 0
    visible: shouldShow

    content: Component {
        Item {
            implicitWidth: workspaceRow.implicitWidth
            implicitHeight: workspaceRow.implicitHeight
        }
    }

    property real touchpadAccumulator: 0
    property real mouseAccumulator: 0
    property bool scrollInProgress: false

    Timer {
        id: scrollCooldown
        interval: 100
        onTriggered: root.scrollInProgress = false
    }

    onRightClicked: {
        CompositorService.workspaceSecondaryAction(null, root.effectiveScreenName);
        root.toggleHyprlandOverview();
    }

    onPressedAt: (rootX, rootY) => {
        const idx = root.findClosestWorkspaceIndex(rootX, rootY);
        if (idx >= 0)
            root.switchToWorkspaceByModelData(root.workspaceList[idx]);
    }

    onWheel: wheel => {
        if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y))
            return;
        wheel.accepted = true;

        if (scrollInProgress)
            return;

        const delta = wheel.angleDelta.y;
        const isTouchpad = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
        const reverse = root.opt("reverseScrolling") ? -1 : 1;

        if (isTouchpad) {
            touchpadAccumulator += delta;
            if (Math.abs(touchpadAccumulator) < 500)
                return;
            const direction = touchpadAccumulator * reverse < 0 ? 1 : -1;
            root.switchWorkspace(direction);
            scrollInProgress = true;
            scrollCooldown.restart();
            touchpadAccumulator = 0;
            return;
        }

        mouseAccumulator += delta;
        if (Math.abs(mouseAccumulator) < 120)
            return;
        const direction = mouseAccumulator * reverse < 0 ? 1 : -1;
        root.switchWorkspace(direction);
        scrollInProgress = true;
        scrollCooldown.restart();
        mouseAccumulator = 0;
    }

    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property bool suppressShiftAnimation: false

    onWorkspaceListChanged: {
        if (dragSourceIndex >= 0) {
            dragSourceIndex = -1;
            dragTargetIndex = -1;
            suppressShiftAnimation = false;
        }
    }

    BarSegment {
        id: workspaceRow

        anchors.centerIn: root.visualContent
        spacing: root.segmented ? BarMetrics.segmentGap : Theme.spacingS
        vertical: root.isVertical

        // mango reports active_tags=0 while the overview is open; surface it as a pill
        Item {
            id: overviewPill
            visible: CompositorService.workspacesHiddenByOverview(CompositorService.getFocusedScreenName())
            width: root.isVertical ? root.widgetThickness : overviewBg.width
            height: root.isVertical ? overviewBg.height : root.widgetThickness

            readonly property real labelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)

            Rectangle {
                id: overviewBg
                anchors.centerIn: parent
                width: root.isVertical ? Math.max(root.widgetThickness * root.compactRatio, overviewContent.implicitWidth + Theme.spacingS) : (overviewContent.implicitWidth + Theme.spacingS * 2)
                height: Math.max(root.widgetThickness * root.slimRatio, overviewContent.implicitHeight + Theme.spacingXS)
                radius: BarMetrics.pillRadius(Math.min(width, height), BarMetrics.widgetStyle(root.barConfig))
                color: Theme.withAlpha(Theme.primary, root.overviewTintAlpha)

                Row {
                    id: overviewContent
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "grid_view"
                        size: overviewPill.labelSize + 2
                        color: Theme.primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.isVertical
                        text: I18n.tr("Overview", "noun, niri compositor overview mode label")
                        color: Theme.primary
                        font.pixelSize: overviewPill.labelSize
                        font.weight: Theme.fontWeightMedium
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: CompositorService.toggleOverview(root.effectiveScreenName)
            }
        }

        Repeater {
            id: workspaceRepeater
            model: ScriptModel {
                values: root.workspaceList
            }

            Item {
                id: delegateRoot

                property bool isDropTarget: root.dragTargetIndex === index

                z: dragHandler.dragging ? 1000 : 1

                property real shiftOffset: {
                    if (root.dragSourceIndex < 0 || index === root.dragSourceIndex)
                        return 0;
                    const dragIdx = root.dragSourceIndex;
                    const dropIdx = root.dragTargetIndex;
                    if (dropIdx < 0)
                        return 0;
                    const shiftAmount = delegateRoot.width + workspaceRow.spacing;
                    if (dragIdx < dropIdx && index > dragIdx && index <= dropIdx)
                        return -shiftAmount;
                    if (dragIdx > dropIdx && index >= dropIdx && index < dragIdx)
                        return shiftAmount;
                    return 0;
                }

                readonly property var shiftSpringParams: Theme.springPreset("fast", 150)

                SpringMotion {
                    id: shiftXSpring
                    enabled: !root.suppressShiftAnimation
                    positionEpsilon: 0.05
                    velocityEpsilon: 0.05
                    stiffness: delegateRoot.shiftSpringParams.stiffness
                    damping: delegateRoot.shiftSpringParams.damping
                    value: delegateRoot.shiftOffset

                    Component.onCompleted: snapTo(delegateRoot.shiftOffset)
                }

                SpringMotion {
                    id: shiftYSpring
                    enabled: !root.suppressShiftAnimation
                    positionEpsilon: 0.05
                    velocityEpsilon: 0.05
                    stiffness: delegateRoot.shiftSpringParams.stiffness
                    damping: delegateRoot.shiftSpringParams.damping
                    value: delegateRoot.shiftOffset

                    Component.onCompleted: snapTo(delegateRoot.shiftOffset)
                }

                onShiftOffsetChanged: {
                    shiftXSpring.retarget(shiftOffset);
                    shiftYSpring.retarget(shiftOffset);
                }

                transform: Translate {
                    x: root.isVertical ? 0 : shiftXSpring.value
                    y: root.isVertical ? shiftYSpring.value : 0
                }

                readonly property var record: root.recordOf(modelData)
                property bool isActive: {
                    if (root.useExtWorkspace || !root.useNativeWorkspaces)
                        return modelData === root.currentWorkspace;
                    return CompositorService.isCurrentWorkspace(record, root.currentWorkspace);
                }
                property bool isOccupied: root.useNativeWorkspaces && CompositorService.workspaceOccupied(record)
                property bool isPlaceholder: !!(record && record.placeholder)
                property bool isHovered: mouseArea.containsMouse

                property bool loadedIsUrgent: false
                property bool isUrgent: root.useNativeWorkspaces ? CompositorService.workspaceUrgent(record, loadedIsUrgent) : (modelData?.urgent ?? false)
                readonly property var loadedIconData: {
                    if (isPlaceholder)
                        return null;
                    const name = record?.name;
                    if (!name)
                        return null;
                    const custom = SettingsData.getWorkspaceNameIcon(name);
                    if (custom || record.special !== true)
                        return custom;
                    return {
                        "type": "icon",
                        "value": "inbox"
                    };
                }
                readonly property bool loadedHasIcon: loadedIconData !== null
                property var loadedIcons: []

                readonly property int stableIconCount: {
                    if (!root.opt("showWorkspaceApps") || isPlaceholder)
                        return 0;

                    if (root.useAqueous)
                        return loadedIcons.length;

                    if (!root.useNativeWorkspaces)
                        return 0;

                    const wins = CompositorService.windowsOnWorkspace(delegateRoot.record);
                    const seen = {};
                    let groupedCount = 0;

                    for (let i = 0; i < wins.length; i++) {
                        const w = wins[i];
                        const appKey = w.app_id || w.appId || w.class || w.windowClass || "unknown";
                        if (!seen[appKey]) {
                            seen[appKey] = true;
                            groupedCount++;
                        }
                    }

                    return (root.opt("groupWorkspaceApps") && (!isActive || root.opt("groupActiveWorkspaceApps"))) ? groupedCount : wins.length;
                }

                readonly property real lineThickness: Math.max(Theme.spacingXXS, root.widgetThickness * (isActive ? root.activeLineRatio : root.lineRatio))
                readonly property real primaryBase: isActive ? Math.max(root.widgetThickness * root.activeRatio, root.appIconSize * root.activeIconRatio) : Math.max(root.widgetThickness * root.compactRatio, root.appIconSize * root.iconRatio)
                readonly property real crossBase: root.opt("showWorkspaceApps") ? Math.max(widgetThickness * root.compactRatio, root.appIconSize + Theme.spacingXS * 2) : widgetThickness * (root.cardsStyle && isActive ? root.activeSlimRatio : root.slimRatio)
                readonly property real baseWidth: root.isVertical ? (root.linesStyle ? lineThickness : crossBase) : primaryBase
                readonly property real baseHeight: root.isVertical ? primaryBase : (root.linesStyle ? lineThickness : crossBase)
                readonly property bool hasWorkspaceName: root.opt("showWorkspaceName") && record?.name && record.name !== ""
                readonly property real contentImplicitWidth: appIconsLoader.item?.contentWidth ?? 0
                readonly property real contentImplicitHeight: appIconsLoader.item?.contentHeight ?? 0

                // lines can't hold content, so it sits beside the line as an M3 tab underline facing the screen
                readonly property bool underline: root.linesStyle && contentImplicitWidth > 0 && contentImplicitHeight > 0
                readonly property bool lineAfterContent: root.axis?.edge !== "bottom" && root.axis?.edge !== "right"
                readonly property real underlineContentShift: underline ? (lineThickness + Theme.spacingXXS) / 2 * (lineAfterContent ? -1 : 1) : 0
                readonly property real underlineLineShift: underline ? ((root.isVertical ? contentImplicitWidth : contentImplicitHeight) + Theme.spacingXXS) / 2 * (lineAfterContent ? 1 : -1) : 0

                readonly property real iconsExtraWidth: {
                    if (!root.isVertical && root.opt("showWorkspaceApps") && stableIconCount > 0) {
                        const numIcons = Math.min(stableIconCount, root.opt("maxWorkspaceIcons"));
                        return numIcons * root.appIconSize + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0);
                    }
                    return 0;
                }
                readonly property real iconsExtraHeight: {
                    if (root.isVertical && root.opt("showWorkspaceApps") && stableIconCount > 0) {
                        const numIcons = Math.min(stableIconCount, root.opt("maxWorkspaceIcons"));
                        return numIcons * root.appIconSize + (numIcons > 0 ? (numIcons - 1) * Theme.spacingXS : 0) + (isActive ? Theme.spacingXS : 0);
                    }
                    return 0;
                }

                readonly property real visualWidth: {
                    if (contentImplicitWidth <= 0 || (underline && root.isVertical))
                        return baseWidth + iconsExtraWidth;
                    const padding = root.isVertical ? Theme.spacingXS : Theme.spacingS;
                    return Math.max(baseWidth + iconsExtraWidth, contentImplicitWidth + padding);
                }
                readonly property real visualHeight: {
                    if (contentImplicitHeight <= 0 || (underline && !root.isVertical))
                        return baseHeight + iconsExtraHeight;
                    const padding = root.isVertical ? Theme.spacingS : Theme.spacingXS;
                    return Math.max(baseHeight + iconsExtraHeight, contentImplicitHeight + padding);
                }

                function colorFromMode(mode, fallbackColor, customColor, customFallbackColor) {
                    switch (mode) {
                    case "primary":
                    case "pri":
                        return Theme.primary;
                    case "primaryContainer":
                        return Theme.primaryContainer;
                    case "secondary":
                    case "sec":
                        return Theme.secondary;
                    case "secondaryContainer":
                        return Theme.secondaryContainer;
                    case "tertiary":
                    case "ter":
                        return Theme.tertiary;
                    case "tertiaryContainer":
                        return Theme.tertiaryContainer;
                    case "surfaceText":
                        return Theme.surfaceText;
                    case "s":
                        return Theme.surface;
                    case "sc":
                        return Theme.surfaceContainer;
                    case "sch":
                        return Theme.surfaceContainerHigh;
                    case "schh":
                        return Theme.surfaceContainerHighest;
                    case "error":
                    case "err":
                        return Theme.error;
                    case "custom":
                        return Theme.safeColor(customColor, customFallbackColor);
                    default:
                        return fallbackColor;
                    }
                }

                function effectiveColorMode(focusedMode, unfocusedMode) {
                    return root.useUnfocusedAppearance ? unfocusedMode : focusedMode;
                }

                function effectiveCustomColor(focusedCustom, unfocusedCustom) {
                    return root.useUnfocusedAppearance ? unfocusedCustom : focusedCustom;
                }

                readonly property color unfocusedColor: colorFromMode(effectiveColorMode(root.opt("workspaceUnfocusedColorMode"), root.opt("workspaceUnfocusedMonitorUnfocusedColorMode")), Theme.surfaceTextAlpha, effectiveCustomColor(root.opt("workspaceUnfocusedCustomColor"), root.opt("workspaceUnfocusedMonitorUnfocusedCustomColor")), Theme.surfaceTextAlpha)

                readonly property string activeColorMode: effectiveColorMode(root.opt("workspaceColorMode"), root.opt("workspaceUnfocusedMonitorColorMode"))
                readonly property color activeColor: {
                    if (activeColorMode === "none")
                        return unfocusedColor;
                    return colorFromMode(activeColorMode, Theme.primary, effectiveCustomColor(root.opt("workspaceFocusedCustomColor"), root.opt("workspaceUnfocusedMonitorFocusedCustomColor")), Theme.primary);
                }

                readonly property color occupiedColor: {
                    const mode = effectiveColorMode(root.opt("workspaceOccupiedColorMode"), root.opt("workspaceUnfocusedMonitorOccupiedColorMode"));
                    if (mode === "none")
                        return unfocusedColor;
                    return colorFromMode(mode, unfocusedColor, effectiveCustomColor(root.opt("workspaceOccupiedCustomColor"), root.opt("workspaceUnfocusedMonitorOccupiedCustomColor")), Theme.secondary);
                }

                readonly property color urgentColor: colorFromMode(effectiveColorMode(root.opt("workspaceUrgentColorMode"), root.opt("workspaceUnfocusedMonitorUrgentColorMode")), Theme.error, effectiveCustomColor(root.opt("workspaceUrgentCustomColor"), root.opt("workspaceUnfocusedMonitorUrgentCustomColor")), Theme.error)

                readonly property color focusedBorderColor: colorFromMode(effectiveColorMode(root.opt("workspaceFocusedBorderColor"), root.opt("workspaceUnfocusedMonitorBorderColor")), Theme.primary, effectiveCustomColor(root.opt("workspaceFocusedBorderCustomColor"), root.opt("workspaceUnfocusedMonitorBorderCustomColor")), Theme.primary)

                readonly property bool focusedBorderEnabledForMonitor: root.useUnfocusedAppearance ? root.opt("workspaceUnfocusedMonitorBorderEnabled") : root.opt("workspaceFocusedBorderEnabled")
                readonly property int focusedBorderThicknessForMonitor: root.useUnfocusedAppearance ? root.opt("workspaceUnfocusedMonitorBorderThickness") : root.opt("workspaceFocusedBorderThickness")

                function getContrastingIconColor(bgColor) {
                    return Theme.isLightColor(bgColor, 0.4) ? Qt.rgba(0.15, 0.15, 0.15, 1) : Qt.rgba(0.8, 0.8, 0.8, 1);
                }

                readonly property color quickshellIconActiveColor: getContrastingIconColor(activeColor)
                readonly property color quickshellIconInactiveColor: getContrastingIconColor(unfocusedColor)

                readonly property color requestedColor: isActive ? activeColor : isUrgent ? urgentColor : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.withAlpha(unfocusedColor, root.hoverFadeAlpha) : isOccupied ? occupiedColor : unfocusedColor

                property bool colorAnimationReady: false

                readonly property color displayColor: pillColor.value

                DankColorAnimation {
                    id: pillColor
                    to: delegateRoot.requestedColor
                    animated: delegateRoot.colorAnimationReady
                }

                Item {
                    id: dragHandler
                    anchors.fill: parent
                    property bool dragging: false
                    property point dragStartPos: Qt.point(0, 0)
                    property real dragAxisOffset: 0
                    readonly property var rootWorkspaceList: root.workspaceList

                    onRootWorkspaceListChanged: {
                        if (!dragging)
                            return;
                        dragging = false;
                        dragAxisOffset = 0;
                        mouseArea.mousePressed = false;
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : (dragHandler.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor)
                    enabled: !isPlaceholder
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    property bool mousePressed: false

                    onPressed: mouse => {
                        if (mouse.button === Qt.LeftButton && CompositorService.workspaceReorderSupported && root.opt("workspaceDragReorder") && !isPlaceholder) {
                            mousePressed = true;
                            dragHandler.dragStartPos = Qt.point(mouse.x, mouse.y);
                        }
                    }

                    onPositionChanged: mouse => {
                        if (!mousePressed || !CompositorService.workspaceReorderSupported || !root.opt("workspaceDragReorder") || isPlaceholder)
                            return;

                        if (!dragHandler.dragging) {
                            const distance = root.isVertical ? Math.abs(mouse.y - dragHandler.dragStartPos.y) : Math.abs(mouse.x - dragHandler.dragStartPos.x);
                            if (distance > 5) {
                                dragHandler.dragging = true;
                                root.dragSourceIndex = index;
                                root.dragTargetIndex = index;
                            }
                        }

                        if (!dragHandler.dragging)
                            return;

                        const rawAxisOffset = root.isVertical ? (mouse.y - dragHandler.dragStartPos.y) : (mouse.x - dragHandler.dragStartPos.x);

                        const itemSize = (root.isVertical ? delegateRoot.height : delegateRoot.width) + workspaceRow.spacing;
                        const maxOffsetPositive = (root.workspaceList.length - 1 - index) * itemSize;
                        const maxOffsetNegative = -index * itemSize;
                        const axisOffset = Math.max(maxOffsetNegative, Math.min(maxOffsetPositive, rawAxisOffset));
                        dragHandler.dragAxisOffset = axisOffset;

                        const slotOffset = Math.round(axisOffset / itemSize);
                        const newTargetIndex = Math.max(0, Math.min(root.workspaceList.length - 1, index + slotOffset));

                        if (newTargetIndex !== root.dragTargetIndex) {
                            root.dragTargetIndex = newTargetIndex;
                        }
                    }

                    onReleased: mouse => {
                        const wasDragging = dragHandler.dragging;
                        const didReorder = wasDragging && root.dragTargetIndex >= 0 && root.dragTargetIndex !== root.dragSourceIndex;

                        if (didReorder) {
                            const sourceWs = root.workspaceList[root.dragSourceIndex];
                            const targetWs = root.workspaceList[root.dragTargetIndex];

                            if (sourceWs && targetWs && sourceWs.id !== undefined && targetWs.idx !== undefined) {
                                root.suppressShiftAnimation = true;
                                CompositorService.moveWorkspace(sourceWs, targetWs);
                                Qt.callLater(() => root.suppressShiftAnimation = false);
                            }
                        }

                        mousePressed = false;
                        dragHandler.dragging = false;
                        dragHandler.dragAxisOffset = 0;
                        root.dragSourceIndex = -1;
                        root.dragTargetIndex = -1;

                        if (wasDragging || isPlaceholder)
                            return;

                        if (mouse.button === Qt.LeftButton) {
                            if (delegateRoot.focusWindowAt(mouse.x, mouse.y))
                                return;
                            root.switchToWorkspaceByModelData(modelData);
                        } else if (mouse.button === Qt.RightButton) {
                            CompositorService.workspaceSecondaryAction(record, root.effectiveScreenName);
                            root.toggleHyprlandOverview();
                        }
                    }
                }

                Timer {
                    id: dataUpdateTimer
                    interval: 50
                    onTriggered: {
                        if (isPlaceholder) {
                            delegateRoot.loadedIcons = [];
                            delegateRoot.loadedIsUrgent = false;
                            return;
                        }

                        delegateRoot.loadedIsUrgent = CompositorService.loadWorkspaceUrgent(delegateRoot.record);
                        delegateRoot.loadedIcons = root.opt("showWorkspaceApps") ? root.getWorkspaceIcons(delegateRoot.record) : [];
                    }
                }

                function updateAllData() {
                    dataUpdateTimer.restart();
                }

                function windowIdAt(x, y) {
                    const layout = appIconsLoader.item?.iconsLayout;
                    if (!layout)
                        return null;
                    const point = layout.mapFromItem(mouseArea, x, y);
                    const icon = layout.childAt(point.x, point.y);
                    if (root.useAqueous)
                        return icon?.windowId ? {
                            id: icon.windowId,
                            session: icon.windowSession
                        } : null;
                    return icon?.windowId ?? null;
                }

                function focusWindowAt(x, y) {
                    const winId = delegateRoot.windowIdAt(x, y);
                    if (!winId)
                        return false;
                    return CompositorService.focusWindow(winId);
                }

                width: root.isVertical ? root.widgetThickness : visualWidth
                height: root.isVertical ? visualHeight : root.widgetThickness

                readonly property real outlineWidth: dragHandler.dragging || isUrgent || isDropTarget ? Theme.outlineWidthFocused : 0
                readonly property color outlineColor: dragHandler.dragging ? Theme.primary : (isUrgent ? urgentColor : (isDropTarget ? Theme.primary : Theme.withAlpha(Theme.primary, 0)))

                Behavior on width {
                    enabled: !SettingsData.reduceMotion
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                    }
                }

                Behavior on height {
                    enabled: !SettingsData.reduceMotion
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                    }
                }

                Rectangle {
                    id: focusedBorderRing
                    x: root.isVertical ? (root.widgetThickness - width) / 2 + delegateRoot.underlineLineShift : (parent.width - width) / 2
                    y: root.isVertical ? (parent.height - height) / 2 : (root.widgetThickness - height) / 2 + delegateRoot.underlineLineShift
                    width: {
                        const borderWidth = (delegateRoot.focusedBorderEnabledForMonitor && isActive && !isPlaceholder) ? delegateRoot.focusedBorderThicknessForMonitor : 0;
                        return delegateRoot.visualWidth + borderWidth * 2;
                    }
                    height: {
                        const borderWidth = (delegateRoot.focusedBorderEnabledForMonitor && isActive && !isPlaceholder) ? delegateRoot.focusedBorderThicknessForMonitor : 0;
                        return delegateRoot.visualHeight + borderWidth * 2;
                    }
                    topLeftRadius: visualContent.topLeftRadius + border.width
                    topRightRadius: visualContent.topRightRadius + border.width
                    bottomLeftRadius: visualContent.bottomLeftRadius + border.width
                    bottomRightRadius: visualContent.bottomRightRadius + border.width
                    color: "transparent"
                    border.width: (delegateRoot.focusedBorderEnabledForMonitor && isActive && !isPlaceholder) ? delegateRoot.focusedBorderThicknessForMonitor : 0
                    border.color: (delegateRoot.focusedBorderEnabledForMonitor && isActive && !isPlaceholder) ? focusedBorderColor : Theme.withAlpha(focusedBorderColor, 0)

                    Behavior on width {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                        }
                    }

                    Behavior on height {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                        }
                    }

                    Behavior on border.width {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                        }
                    }

                    Behavior on border.color {
                        enabled: !SettingsData.reduceMotion
                        ColorAnimation {
                            duration: Theme.expressiveDurations.expressiveEffects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                        }
                    }
                }

                BarPillSurface {
                    id: visualContent
                    width: delegateRoot.visualWidth
                    height: delegateRoot.visualHeight
                    x: root.isVertical ? (root.widgetThickness - width) / 2 + delegateRoot.underlineLineShift : (parent.width - width) / 2
                    y: root.isVertical ? (parent.height - height) / 2 : (root.widgetThickness - height) / 2 + delegateRoot.underlineLineShift
                    thickness: Math.min(width, height)
                    style: BarMetrics.widgetStyle(root.barConfig)
                    vertical: root.isVertical
                    joinedStart: root.segmented && index > 0
                    joinedEnd: root.segmented && index < workspaceRepeater.count - 1
                    pressed: mouseArea.pressed
                    color: root.cardsStyle && !isActive ? "transparent" : delegateRoot.displayColor
                    radiusOverride: root.cardsStyle ? Math.min(Theme.cornerRadiusXS, thickness / 2) : -1
                    opacity: dragHandler.dragging ? root.dragOpacity : 1.0

                    border.width: root.cardsStyle && !isActive ? Math.max(Theme.outlineWidth, delegateRoot.outlineWidth) : delegateRoot.outlineWidth
                    border.color: delegateRoot.outlineWidth > 0 ? delegateRoot.outlineColor : delegateRoot.displayColor

                    // an empty frame is an empty desktop; a window block marks it occupied
                    Rectangle {
                        anchors.centerIn: parent
                        visible: root.cardsStyle && isOccupied && !isActive && !appIconsLoader.active
                        width: Math.round(parent.width * root.cardWindowRatio)
                        height: Math.round(parent.height * root.cardWindowRatio)
                        radius: Math.min(Theme.cornerRadiusXXS, height / 2)
                        color: delegateRoot.displayColor
                    }

                    transform: Translate {
                        x: root.isVertical ? 0 : (dragHandler.dragging ? dragHandler.dragAxisOffset : 0)
                        y: root.isVertical ? (dragHandler.dragging ? dragHandler.dragAxisOffset : 0) : 0
                    }

                    Behavior on opacity {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveEffects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                        }
                    }

                    Behavior on width {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                        }
                    }

                    Behavior on height {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                        }
                    }

                    Behavior on border.width {
                        enabled: !SettingsData.reduceMotion
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                        }
                    }

                    Behavior on border.color {
                        enabled: !SettingsData.reduceMotion
                        ColorAnimation {
                            duration: Theme.expressiveDurations.expressiveEffects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                        }
                    }
                }

                Loader {
                    id: appIconsLoader
                    anchors.fill: parent
                    active: root.opt("showWorkspaceApps") || root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName") || loadedHasIcon
                    opacity: visualContent.opacity
                    transform: Translate {
                        x: root.isVertical ? 0 : (dragHandler.dragging ? dragHandler.dragAxisOffset : 0)
                        y: root.isVertical ? (dragHandler.dragging ? dragHandler.dragAxisOffset : 0) : 0
                    }
                    sourceComponent: Item {
                        id: contentRoot
                        readonly property real contentWidth: contentRow.item?.implicitWidth ?? 0
                        readonly property real contentHeight: contentRow.item?.implicitHeight ?? 0
                        property alias iconsLayout: contentRow.item

                        Loader {
                            id: contentRow
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: root.isVertical ? delegateRoot.underlineContentShift : 0
                            anchors.verticalCenterOffset: root.isVertical ? 0 : delegateRoot.underlineContentShift
                            sourceComponent: root.isVertical ? columnLayout : rowLayout
                        }

                        Component {
                            id: rowLayout
                            Row {
                                spacing: Theme.spacingXS
                                visible: loadedIcons.length > 0 || root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName") || loadedHasIcon

                                Item {
                                    visible: loadedHasIcon && loadedIconData?.type === "icon"
                                    width: wsIcon.width
                                    height: root.appIconSize

                                    DankIcon {
                                        id: wsIcon
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: loadedIconData?.value ?? ""
                                        size: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                        color: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                        weight: (isActive && !isPlaceholder) ? 500 : 400
                                    }
                                }

                                Item {
                                    visible: loadedHasIcon && loadedIconData?.type === "text"
                                    width: wsText.implicitWidth
                                    height: root.appIconSize

                                    StyledText {
                                        id: wsText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: loadedIconData?.value ?? ""
                                        color: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                        font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                        font.weight: (isActive && !isPlaceholder) ? Theme.fontWeightMedium : Theme.fontWeight
                                    }
                                }

                                Item {
                                    visible: ((root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName")) && !loadedHasIcon) || (loadedHasIcon && root.opt("showWorkspaceName") && hasWorkspaceName)
                                    width: wsIndexText.implicitWidth
                                    height: root.appIconSize

                                    StyledText {
                                        id: wsIndexText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: loadedHasIcon ? (record?.name ?? "") : root.getWorkspaceIndex(record, index)
                                        color: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                        font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                        font.weight: (isActive && !isPlaceholder) ? Theme.fontWeightMedium : Theme.fontWeight
                                    }
                                }

                                Repeater {
                                    model: ScriptModel {
                                        values: loadedIcons.slice(0, root.opt("maxWorkspaceIcons"))
                                    }
                                    delegate: Item {
                                        width: root.appIconSize
                                        height: root.appIconSize
                                        readonly property var windowId: modelData.windowId
                                        readonly property string windowSession: modelData.windowSession || ""
                                        readonly property bool appHighlightActive: root.opt("workspaceActiveAppHighlightEnabled") && modelData.active
                                        readonly property color appBorderColor: appHighlightActive ? focusedBorderColor : Theme.primarySelected
                                        readonly property color appGlyphColor: appHighlightActive ? focusedBorderColor : Theme.primary
                                        readonly property real appOpacity: modelData.active ? 1.0 : rowAppHover.hovered ? 0.8 : 0.6

                                        IconImage {
                                            id: rowAppIcon
                                            anchors.fill: parent
                                            source: modelData.icon || ""
                                            opacity: modelData.active ? 1.0 : rowAppHover.hovered ? 0.8 : 0.6
                                            visible: !modelData.isQuickshell && !modelData.isSteamApp && status === Image.Ready
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !modelData.isQuickshell && !modelData.isSteamApp && rowAppIcon.status !== Image.Ready
                                            color: Theme.chipSurface
                                            radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                            border.width: Theme.outlineWidth
                                            border.color: appBorderColor
                                            opacity: appOpacity

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: (modelData.fallbackText || "?").charAt(0).toUpperCase()
                                                font.pixelSize: parent.width * 0.45
                                                color: appGlyphColor
                                                font.weight: Theme.fontWeightMedium
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !modelData.isQuickshell && modelData.isSteamApp && rowSteamIcon.status !== Image.Ready
                                            color: Theme.chipSurface
                                            radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                            border.width: Theme.outlineWidth
                                            border.color: appBorderColor
                                            opacity: appOpacity

                                            DankIcon {
                                                anchors.centerIn: parent
                                                size: parent.width * 0.7
                                                name: "sports_esports"
                                                color: appGlyphColor
                                            }
                                        }

                                        IconImage {
                                            anchors.fill: parent
                                            source: modelData.icon
                                            opacity: modelData.active ? 1.0 : rowAppHover.hovered ? 0.8 : 0.6
                                            visible: modelData.isQuickshell
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                saturation: 0
                                                colorization: 1
                                                colorizationColor: appHighlightActive ? focusedBorderColor : (isActive ? quickshellIconActiveColor : quickshellIconInactiveColor)
                                            }
                                        }

                                        IconImage {
                                            id: rowSteamIcon
                                            anchors.fill: parent
                                            source: modelData.icon
                                            opacity: modelData.active ? 1.0 : rowAppHover.hovered ? 0.8 : 0.6
                                            visible: modelData.isSteamApp && modelData.icon
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            size: root.appIconSize
                                            name: "sports_esports"
                                            color: appHighlightActive ? focusedBorderColor : Theme.widgetTextColor
                                            opacity: modelData.active ? 1.0 : rowAppHover.hovered ? 0.8 : 0.6
                                            visible: modelData.isSteamApp && !modelData.icon
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: (rowAppIcon.visible || rowSteamIcon.visible || modelData.isQuickshell) && appHighlightActive
                                            color: "transparent"
                                            radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                            border.width: Theme.outlineWidth
                                            border.color: focusedBorderColor
                                            z: 1
                                        }

                                        HoverHandler {
                                            id: rowAppHover
                                        }

                                        Rectangle {
                                            visible: modelData.count > 1 && !isActive
                                            width: root.appIconSize * 0.67
                                            height: root.appIconSize * 0.67
                                            radius: root.appIconSize * 0.33
                                            color: "black"
                                            border.color: "white"
                                            border.width: Theme.outlineWidth
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            z: 2

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: modelData.count
                                                font.pixelSize: root.appIconSize * 0.44
                                                color: "white"
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
                                visible: loadedIcons.length > 0 || root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName") || loadedHasIcon

                                DankIcon {
                                    visible: loadedHasIcon && loadedIconData?.type === "icon"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: loadedIconData?.value ?? ""
                                    size: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                    color: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                    weight: (isActive && !isPlaceholder) ? 500 : 400
                                }

                                StyledText {
                                    visible: loadedHasIcon && loadedIconData?.type === "text"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: loadedIconData?.value ?? ""
                                    color: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                    font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                    font.weight: (isActive && !isPlaceholder) ? Theme.fontWeightMedium : Theme.fontWeight
                                }

                                StyledText {
                                    visible: (root.opt("showWorkspaceIndex") || root.opt("showWorkspaceName")) && !loadedHasIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.getWorkspaceIndex(record, index)
                                    color: (isActive || isUrgent) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                    font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
                                    font.weight: (isActive && !isPlaceholder) ? Theme.fontWeightMedium : Theme.fontWeight
                                }

                                Repeater {
                                    model: ScriptModel {
                                        values: loadedIcons.slice(0, root.opt("maxWorkspaceIcons"))
                                    }
                                    delegate: Item {
                                        width: root.appIconSize
                                        height: root.appIconSize
                                        readonly property var windowId: modelData.windowId
                                        readonly property string windowSession: modelData.windowSession || ""
                                        readonly property bool appHighlightActive: root.opt("workspaceActiveAppHighlightEnabled") && modelData.active
                                        readonly property color appBorderColor: appHighlightActive ? focusedBorderColor : Theme.primarySelected
                                        readonly property color appGlyphColor: appHighlightActive ? focusedBorderColor : Theme.primary
                                        readonly property real appOpacity: modelData.active ? 1.0 : colAppHover.hovered ? 0.8 : 0.6

                                        IconImage {
                                            id: colAppIcon
                                            anchors.fill: parent
                                            source: modelData.icon || ""
                                            opacity: modelData.active ? 1.0 : colAppHover.hovered ? 0.8 : 0.6
                                            visible: !modelData.isQuickshell && !modelData.isSteamApp && status === Image.Ready
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !modelData.isQuickshell && !modelData.isSteamApp && colAppIcon.status !== Image.Ready
                                            color: Theme.chipSurface
                                            radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                            border.width: Theme.outlineWidth
                                            border.color: appBorderColor
                                            opacity: appOpacity

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: (modelData.fallbackText || "?").charAt(0).toUpperCase()
                                                font.pixelSize: parent.width * 0.45
                                                color: appGlyphColor
                                                font.weight: Theme.fontWeightMedium
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !modelData.isQuickshell && modelData.isSteamApp && colSteamIcon.status !== Image.Ready
                                            color: Theme.chipSurface
                                            radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                            border.width: Theme.outlineWidth
                                            border.color: appBorderColor
                                            opacity: appOpacity

                                            DankIcon {
                                                anchors.centerIn: parent
                                                size: parent.width * 0.7
                                                name: "sports_esports"
                                                color: appGlyphColor
                                            }
                                        }

                                        IconImage {
                                            anchors.fill: parent
                                            source: modelData.icon
                                            opacity: modelData.active ? 1.0 : colAppHover.hovered ? 0.8 : 0.6
                                            visible: modelData.isQuickshell
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                saturation: 0
                                                colorization: 1
                                                colorizationColor: appHighlightActive ? focusedBorderColor : (isActive ? quickshellIconActiveColor : quickshellIconInactiveColor)
                                            }
                                        }

                                        IconImage {
                                            id: colSteamIcon
                                            anchors.fill: parent
                                            source: modelData.icon
                                            opacity: modelData.active ? 1.0 : colAppHover.hovered ? 0.8 : 0.6
                                            visible: modelData.isSteamApp && modelData.icon
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            size: root.appIconSize
                                            name: "sports_esports"
                                            color: appHighlightActive ? focusedBorderColor : Theme.widgetTextColor
                                            opacity: modelData.active ? 1.0 : colAppHover.hovered ? 0.8 : 0.6
                                            visible: modelData.isSteamApp && !modelData.icon
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: (colAppIcon.visible || colSteamIcon.visible || modelData.isQuickshell) && appHighlightActive
                                            color: "transparent"
                                            radius: Math.min(Theme.cornerRadiusS, width / 2, height / 2)
                                            border.width: Theme.outlineWidth
                                            border.color: focusedBorderColor
                                            z: 1
                                        }

                                        HoverHandler {
                                            id: colAppHover
                                        }

                                        Rectangle {
                                            visible: modelData.count > 1 && !isActive
                                            width: root.appIconSize * 0.67
                                            height: root.appIconSize * 0.67
                                            radius: root.appIconSize * 0.33
                                            color: "black"
                                            border.color: "white"
                                            border.width: Theme.outlineWidth
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            z: 2

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: modelData.count
                                                font.pixelSize: root.appIconSize * 0.44
                                                color: "white"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    updateAllData();
                    delegateRoot.colorAnimationReady = true;
                }

                Connections {
                    target: CompositorService
                    function onSortedToplevelsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWorkspaceStateChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                readonly property var rootCurrentWorkspace: root.currentWorkspace
                onRootCurrentWorkspaceChanged: updateAllData()
                Connections {
                    target: SettingsData
                    function onBarConfigsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onWorkspaceNameIconsChanged() {
                        delegateRoot.updateAllData();
                    }
                    function onAppIdSubstitutionsChanged() {
                        delegateRoot.updateAllData();
                    }
                }
                property var _extWindowsetsTrigger: root.useExtWorkspace ? WindowManager.windowsets : null
                on_ExtWindowsetsTriggerChanged: {
                    if (root.useExtWorkspace)
                        delegateRoot.updateAllData();
                }
            }
        }
    }
}
