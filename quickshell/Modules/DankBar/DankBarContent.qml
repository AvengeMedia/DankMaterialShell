import QtQuick
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.Common
import qs.Modules.DankBar.Widgets
import qs.Services

Item {
    id: topBarContent

    required property var barWindow
    required property var rootWindow
    required property var barConfig

    readonly property var blurBarWindow: barWindow

    property var leftWidgetsModel
    property var centerWidgetsModel
    property var rightWidgetsModel
    property bool _animateFrameInsets: false

    readonly property real innerPadding: barConfig?.innerPadding ?? 4
    readonly property real outlineThickness: (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0
    readonly property real _edgeBaseMargin: Math.max(Theme.spacingXS, innerPadding * 0.8)
    readonly property bool _hasBarWindow: barWindow !== undefined && barWindow !== null
    readonly property bool _usesFrameBarChrome: _hasBarWindow && (barWindow.usesFrameBarChrome ?? false)
    readonly property real _frameEdgeFloorInset: (SettingsData.frameEnabled && _usesFrameBarChrome) ? Math.max(0, SettingsData.frameThickness - _edgeBaseMargin) : 0
    readonly property bool _barIsVertical: _hasBarWindow ? barWindow.isVertical : false
    readonly property string _barScreenName: _hasBarWindow ? (barWindow.screenName || "") : ""
    readonly property bool hasAdjacentTopBarLive: _hasBarWindow && barWindow.hasAdjacentTopBar
    readonly property bool hasAdjacentBottomBarLive: _hasBarWindow && barWindow.hasAdjacentBottomBar
    readonly property bool hasAdjacentLeftBarLive: _hasBarWindow && barWindow.hasAdjacentLeftBar
    readonly property bool hasAdjacentRightBarLive: _hasBarWindow && barWindow.hasAdjacentRightBar
    property bool _hadAdjacentTopBar: false
    property bool _hadAdjacentBottomBar: false
    property bool _hadAdjacentLeftBar: false
    property bool _hadAdjacentRightBar: false

    onHasAdjacentTopBarLiveChanged: if (hasAdjacentTopBarLive)
        _hadAdjacentTopBar = true
    onHasAdjacentBottomBarLiveChanged: if (hasAdjacentBottomBarLive)
        _hadAdjacentBottomBar = true
    onHasAdjacentLeftBarLiveChanged: if (hasAdjacentLeftBarLive)
        _hadAdjacentLeftBar = true
    onHasAdjacentRightBarLiveChanged: if (hasAdjacentRightBarLive)
        _hadAdjacentRightBar = true

    readonly property real _frameLeftInset: {
        if (!_hasBarWindow || !SettingsData.frameEnabled || !_usesFrameBarChrome || _barIsVertical)
            return 0;
        return hasAdjacentLeftBarLive ? SettingsData.frameBarSize : (_hadAdjacentLeftBar ? _frameEdgeFloorInset : 0);
    }
    readonly property real _frameRightInset: {
        if (!_hasBarWindow || !SettingsData.frameEnabled || !_usesFrameBarChrome || _barIsVertical)
            return 0;
        return hasAdjacentRightBarLive ? SettingsData.frameBarSize : (_hadAdjacentRightBar ? _frameEdgeFloorInset : 0);
    }
    readonly property real _frameTopInset: {
        if (!_hasBarWindow || !SettingsData.frameEnabled || !_usesFrameBarChrome || !_barIsVertical)
            return 0;
        return hasAdjacentTopBarLive ? SettingsData.frameThickness : (_hadAdjacentTopBar ? _frameEdgeFloorInset : 0);
    }
    readonly property real _frameBottomInset: {
        if (!_hasBarWindow || !SettingsData.frameEnabled || !_usesFrameBarChrome || !_barIsVertical)
            return 0;
        return hasAdjacentBottomBarLive ? SettingsData.frameThickness : (_hadAdjacentBottomBar ? _frameEdgeFloorInset : 0);
    }

    property alias hLeftSection: hLeftSection
    property alias hCenterSection: hCenterSection
    property alias hRightSection: hRightSection
    property alias vLeftSection: vLeftSection
    property alias vCenterSection: vCenterSection
    property alias vRightSection: vRightSection

    anchors.fill: parent
    anchors.leftMargin: _edgeBaseMargin + _frameLeftInset
    anchors.rightMargin: _edgeBaseMargin + _frameRightInset
    anchors.topMargin: (_barIsVertical ? (hasAdjacentTopBarLive ? outlineThickness : Theme.spacingXS) : 0) + _frameTopInset
    anchors.bottomMargin: (_barIsVertical ? (hasAdjacentBottomBarLive ? outlineThickness : Theme.spacingXS) : 0) + _frameBottomInset
    clip: false

    DeferredAction {
        id: enableFrameInsetAnimation
        onTriggered: topBarContent._animateFrameInsets = true
    }

    Component.onCompleted: {
        _hadAdjacentTopBar = hasAdjacentTopBarLive;
        _hadAdjacentBottomBar = hasAdjacentBottomBarLive;
        _hadAdjacentLeftBar = hasAdjacentLeftBarLive;
        _hadAdjacentRightBar = hasAdjacentRightBarLive;
        enableFrameInsetAnimation.schedule();
    }

    Behavior on anchors.leftMargin {
        enabled: _animateFrameInsets && _usesFrameBarChrome
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on anchors.rightMargin {
        enabled: _animateFrameInsets && _usesFrameBarChrome
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on anchors.topMargin {
        enabled: _animateFrameInsets && _usesFrameBarChrome
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on anchors.bottomMargin {
        enabled: _animateFrameInsets && _usesFrameBarChrome
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    property int componentMapRevision: 0

    function updateComponentMap() {
        componentMapRevision++;
    }

    readonly property var sortedToplevels: {
        if (!_hasBarWindow) {
            return [];
        }
        return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, _barScreenName);
    }

    function getRealWorkspaces() {
        const screenName = _barScreenName;
        if (CompositorService.isNiri) {
            const fallbackWorkspaces = [
                {
                    "id": 1,
                    "idx": 0,
                    "name": ""
                },
                {
                    "id": 2,
                    "idx": 1,
                    "name": ""
                }
            ];
            if (!screenName || SettingsData.workspaceFollowFocus) {
                const currentWorkspaces = NiriService.getCurrentOutputWorkspaces();
                return currentWorkspaces.length > 0 ? currentWorkspaces : fallbackWorkspaces;
            }
            const workspaces = NiriService.allWorkspaces.filter(ws => ws.output === screenName);
            return workspaces.length > 0 ? workspaces : fallbackWorkspaces;
        } else if (CompositorService.isHyprland) {
            const workspaces = Hyprland.workspaces?.values || [];

            if (!screenName || SettingsData.workspaceFollowFocus) {
                const sorted = workspaces.slice().sort((a, b) => a.id - b.id);
                const filtered = sorted.filter(ws => ws.id > -1);
                return filtered.length > 0 ? filtered : [
                    {
                        "id": 1,
                        "name": "1"
                    }
                ];
            }

            const monitorWorkspaces = workspaces.filter(ws => {
                return ws.lastIpcObject && ws.lastIpcObject.monitor === screenName && ws.id > -1;
            });

            if (monitorWorkspaces.length === 0) {
                return [
                    {
                        "id": 1,
                        "name": "1"
                    }
                ];
            }

            return monitorWorkspaces.sort((a, b) => a.id - b.id);
        } else if (CompositorService.isMango) {
            if (!MangoService.available) {
                return [0];
            }
            if (SettingsData.dwlShowAllTags) {
                return Array.from({
                    length: MangoService.tagCount
                }, (_, i) => i);
            }
            return MangoService.getVisibleTags(screenName);
        } else if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
            const workspaces = I3.workspaces?.values || [];
            if (workspaces.length === 0)
                return [
                    {
                        "num": 1
                    }
                ];

            if (!screenName || SettingsData.workspaceFollowFocus) {
                return workspaces.slice().sort((a, b) => a.num - b.num);
            }

            const monitorWorkspaces = workspaces.filter(ws => ws.monitor?.name === screenName);
            return monitorWorkspaces.length > 0 ? monitorWorkspaces.sort((a, b) => a.num - b.num) : [
                {
                    "num": 1
                }
            ];
        }
        return [1];
    }

    function getCurrentWorkspace() {
        const screenName = _barScreenName;
        if (CompositorService.isNiri) {
            if (!screenName || SettingsData.workspaceFollowFocus) {
                return NiriService.getCurrentWorkspaceNumber();
            }
            const activeWs = NiriService.allWorkspaces.find(ws => ws.output === screenName && ws.is_active);
            return activeWs ? activeWs.idx : 1;
        } else if (CompositorService.isHyprland) {
            const monitors = Hyprland.monitors?.values || [];
            const currentMonitor = monitors.find(monitor => monitor.name === screenName);
            return currentMonitor?.activeWorkspace?.id ?? 1;
        } else if (CompositorService.isMango) {
            if (!MangoService.available)
                return 0;
            const outputState = MangoService.getOutputState(screenName);
            if (!outputState || !outputState.tags)
                return 0;
            const activeTags = MangoService.getActiveTags(screenName);
            return activeTags.length > 0 ? activeTags[0] : 0;
        } else if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
            if (!screenName || SettingsData.workspaceFollowFocus) {
                const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
                return focusedWs ? focusedWs.num : 1;
            }

            const focusedWs = I3.workspaces?.values?.find(ws => ws.monitor?.name === screenName && ws.focused === true);
            return focusedWs ? focusedWs.num : 1;
        }
        return 1;
    }

    function switchWorkspace(direction) {
        const realWorkspaces = getRealWorkspaces();
        if (realWorkspaces.length < 2) {
            return;
        }

        if (CompositorService.isNiri) {
            const currentWs = getCurrentWorkspace();
            const currentIndex = realWorkspaces.findIndex(ws => ws && ws.idx === currentWs);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                const nextWorkspace = realWorkspaces[nextIndex];
                if (!nextWorkspace || nextWorkspace.id === undefined) {
                    return;
                }
                NiriService.switchToWorkspace(nextWorkspace.id);
            }
        } else if (CompositorService.isHyprland) {
            const currentWs = getCurrentWorkspace();
            const currentIndex = realWorkspaces.findIndex(ws => ws.id === currentWs);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                HyprlandService.focusWorkspace(realWorkspaces[nextIndex].id);
            }
        } else if (CompositorService.isMango) {
            const currentTag = getCurrentWorkspace();
            const currentIndex = realWorkspaces.findIndex(tag => tag === currentTag);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                MangoService.switchToTag(_barScreenName, realWorkspaces[nextIndex]);
            }
        } else if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
            const currentWs = getCurrentWorkspace();
            const currentIndex = realWorkspaces.findIndex(ws => ws.num === currentWs);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                try {
                    I3.dispatch(`workspace number ${realWorkspaces[nextIndex].num}`);
                } catch (_) {}
            }
        }
    }

    function switchApp(deltaY) {
        const windows = sortedToplevels;
        if (windows.length < 2) {
            return;
        }
        let currentIndex = -1;
        for (let i = 0; i < windows.length; i++) {
            if (windows[i].activated) {
                currentIndex = i;
                break;
            }
        }
        let nextIndex;
        if (deltaY < 0) {
            if (currentIndex === -1) {
                nextIndex = 0;
            } else {
                nextIndex = currentIndex + 1;
            }
        } else {
            if (currentIndex === -1) {
                nextIndex = windows.length - 1;
            } else {
                nextIndex = currentIndex - 1;
            }
        }
        const nextWindow = windows[nextIndex];
        if (nextWindow) {
            nextWindow.activate();
        }
    }

    readonly property int availableWidth: width
    readonly property int launcherButtonWidth: 40
    readonly property int workspaceSwitcherWidth: 120
    readonly property int focusedAppMaxWidth: 456
    readonly property int estimatedLeftSectionWidth: launcherButtonWidth + workspaceSwitcherWidth + focusedAppMaxWidth + (Theme.spacingXS * 2)
    readonly property int rightSectionWidth: 200
    readonly property int clockWidth: 120
    readonly property int mediaMaxWidth: 280
    readonly property int weatherWidth: 80
    readonly property bool validLayout: availableWidth > 100 && estimatedLeftSectionWidth > 0 && rightSectionWidth > 0
    readonly property int clockLeftEdge: (availableWidth - clockWidth) / 2
    readonly property int clockRightEdge: clockLeftEdge + clockWidth
    readonly property int leftSectionRightEdge: estimatedLeftSectionWidth
    readonly property int mediaLeftEdge: clockLeftEdge - mediaMaxWidth - Theme.spacingS
    readonly property int rightSectionLeftEdge: availableWidth - rightSectionWidth
    readonly property int leftToClockGap: Math.max(0, clockLeftEdge - leftSectionRightEdge)
    readonly property int leftToMediaGap: mediaMaxWidth > 0 ? Math.max(0, mediaLeftEdge - leftSectionRightEdge) : leftToClockGap
    readonly property int mediaToClockGap: mediaMaxWidth > 0 ? Theme.spacingS : 0
    readonly property int clockToRightGap: validLayout ? Math.max(0, rightSectionLeftEdge - clockRightEdge) : 1000
    readonly property bool spacingTight: !_barIsVertical && validLayout && (leftToMediaGap < 150 || clockToRightGap < 100)
    readonly property bool overlapping: !_barIsVertical && validLayout && (leftToMediaGap < 100 || clockToRightGap < 50)

    function getWidgetEnabled(enabled) {
        return enabled !== false;
    }

    function getWidgetSection(parentItem) {
        let current = parentItem;
        while (current) {
            if (current.objectName === "leftSection") {
                return "left";
            }
            if (current.objectName === "centerSection") {
                return "center";
            }
            if (current.objectName === "rightSection") {
                return "right";
            }
            current = current.parent;
        }
        return "left";
    }

    property string activeHoverTrigger: ""
    property real _lastHoverGlobalX: 0
    property real _lastHoverGlobalY: 0

    readonly property bool hoverPopoutsEnabled: barConfig?.hoverPopouts ?? false

    function getBarPosition() {
        return barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
    }

    function resolveWidgetTriggerGeometry(widgetItem, section, opts) {
        opts = opts || {};
        if (opts.useCenterSection && section === "center") {
            const centerSection = barWindow.isVertical ? vCenterSection : hCenterSection;
            if (centerSection) {
                if (barWindow.isVertical) {
                    const centerY = centerSection.height / 2;
                    return {
                        triggerPos: centerSection.mapToItem(null, 0, centerY),
                        triggerWidth: centerSection.height
                    };
                }
                return {
                    triggerPos: centerSection.mapToItem(null, 0, 0),
                    triggerWidth: centerSection.width
                };
            }
        }
        const ref = opts.visualItem || widgetItem.visualContent || widgetItem;
        const w = opts.triggerWidth !== undefined ? opts.triggerWidth : (widgetItem.visualWidth !== undefined ? widgetItem.visualWidth : widgetItem.width);
        return {
            triggerPos: ref.mapToItem(null, 0, 0),
            triggerWidth: w
        };
    }

    function openWidgetPopout(spec) {
        if (!spec?.loader)
            return false;
        spec.loader.active = true;

        let popout = _resolvePopoutFromLoader(spec.loader);
        if (!popout) {
            _queuePopoutLoaderOpen(spec);
            return false;
        }
        return _finishWidgetPopoutOpen(spec, popout);
    }

    function _resolvePopoutFromLoader(loader) {
        if (!loader)
            return null;
        if (loader.item)
            return loader.item;

        const pairs = [
            [PopoutService.appDrawerLoader, PopoutService.appDrawerPopout],
            [PopoutService.batteryPopoutLoader, PopoutService.batteryPopout],
            [PopoutService.clipboardHistoryPopoutLoader, PopoutService.clipboardHistoryPopout],
            [PopoutService.controlCenterLoader, PopoutService.controlCenterPopout],
            [PopoutService.dankDashPopoutLoader, PopoutService.dankDashPopout],
            [PopoutService.layoutPopoutLoader, PopoutService.layoutPopout],
            [PopoutService.notificationCenterLoader, PopoutService.notificationCenterPopout],
            [PopoutService.processListPopoutLoader, PopoutService.processListPopout],
            [PopoutService.systemUpdateLoader, PopoutService.systemUpdatePopout],
            [PopoutService.vpnPopoutLoader, PopoutService.vpnPopout]
        ];
        for (let i = 0; i < pairs.length; i++) {
            if (loader === pairs[i][0] && pairs[i][1])
                return pairs[i][1];
        }
        return null;
    }

    property var _pendingPopoutOpenSpec: null

    function _queuePopoutLoaderOpen(spec) {
        if (_pendingPopoutOpenSpec && _pendingPopoutOpenSpec.loader === spec.loader)
            return;
        _pendingPopoutOpenSpec = spec;
        const loader = spec.loader;
        const onLoaded = function () {
            if (!loader.item)
                return;
            if (loader.loaded)
                loader.loaded.disconnect(onLoaded);
            const pending = topBarContent._pendingPopoutOpenSpec;
            if (!pending || pending.loader !== loader)
                return;
            topBarContent._pendingPopoutOpenSpec = null;
            topBarContent._finishWidgetPopoutOpen(pending, loader.item);
            if (pending.mode === "hover")
                topBarContent.checkHoverPopout(topBarContent._lastHoverGlobalX, topBarContent._lastHoverGlobalY);
        };
        if (loader.item) {
            onLoaded();
            return;
        }
        if (loader.loaded)
            loader.loaded.connect(onLoaded);
    }

    function _finishWidgetPopoutOpen(spec, popout) {
        const effectiveBarConfig = barConfig;
        const barPosition = getBarPosition();
        const widgetSection = spec.section || "right";
        const mode = spec.mode || "click";

        if (popout.setBarContext)
            popout.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);

        if (spec.setTriggerScreen)
            popout.triggerScreen = barWindow.screen;

        if (popout.setTriggerPosition && spec.widgetItem) {
            const geom = resolveWidgetTriggerGeometry(spec.widgetItem, widgetSection, {
                useCenterSection: spec.useCenterSection,
                visualItem: spec.visualItem,
                triggerWidth: spec.triggerWidth
            });
            if (geom.triggerPos) {
                const pos = SettingsData.getPopupTriggerPosition(geom.triggerPos, barWindow.screen, barWindow.effectiveBarThickness, geom.triggerWidth, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                popout.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
            }
        }

        if (spec.prepare)
            spec.prepare(popout);

        const request = mode === "hover" ? PopoutManager.requestHoverPopout : PopoutManager.requestPopout;
        request(popout, spec.tabIndex, spec.triggerSource);
        return true;
    }

    function _getBarSections() {
        if (barWindow.isVertical) {
            return [
                {
                    section: vLeftSection,
                    name: "left"
                },
                {
                    section: vCenterSection,
                    name: "center"
                },
                {
                    section: vRightSection,
                    name: "right"
                }
            ];
        }
        return [
            {
                section: hLeftSection,
                name: "left"
            },
            {
                section: hCenterSection,
                name: "center"
            },
            {
                section: hRightSection,
                name: "right"
            }
        ];
    }

    function _findWidgetHostInWrapper(wrapper) {
        if (wrapper.widgetId !== undefined)
            return wrapper;
        const children = wrapper.children || [];
        for (let i = 0; i < children.length; i++) {
            if (children[i].widgetId !== undefined)
                return children[i];
        }
        return null;
    }

    function _collectSectionWrappers(section) {
        const layout = section.layoutLoader?.item;
        if (layout)
            return layout.children || [];
        const children = section.children || [];
        const wrappers = [];
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            if (!child || child === section.layoutLoader)
                continue;
            if (child.itemData !== undefined || child.widgetId !== undefined || _findWidgetHostInWrapper(child))
                wrappers.push(child);
        }
        return wrappers;
    }

    function _widgetSupportsHoverPopout(widgetId, widgetItem) {
        if (!widgetId || !widgetItem)
            return false;
        if (typeof widgetItem.triggerHoverPopout === "function")
            return true;
        if (widgetId === "systemTray" && typeof widgetItem.openHoverAtGlobalPoint === "function")
            return true;
        switch (widgetId) {
        case "launcherButton":
        case "clipboard":
        case "clock":
        case "music":
        case "weather":
        case "cpuUsage":
        case "memUsage":
        case "cpuTemp":
        case "gpuTemp":
        case "notificationButton":
        case "battery":
        case "layout":
        case "vpn":
        case "controlCenterButton":
        case "systemUpdate":
        case "notepadButton":
        case "systemTray":
            return true;
        default:
            return false;
        }
    }

    function _enumerateWidgetHosts() {
        const hosts = [];
        const sections = _getBarSections();
        for (let s = 0; s < sections.length; s++) {
            const sectionEntry = sections[s];
            const section = sectionEntry.section;
            if (!section)
                continue;
            const wrappers = _collectSectionWrappers(section);
            for (let i = 0; i < wrappers.length; i++) {
                const wrapper = wrappers[i];
                const host = _findWidgetHostInWrapper(wrapper);
                if (!host?.widgetId)
                    continue;
                hosts.push({
                    host,
                    wrapper,
                    section: sectionEntry.name
                });
            }
        }
        return hosts;
    }

    function _collectHoverCandidates() {
        const screenName = barWindow.screen?.name;
        const candidates = [];
        const seen = new Set();

        function addCandidate(widgetId, widgetItem, sectionHint) {
            if (!widgetId || !widgetItem || seen.has(widgetItem))
                return;
            if (!_widgetSupportsHoverPopout(widgetId, widgetItem))
                return;
            if (!getWidgetVisible(widgetId))
                return;
            seen.add(widgetItem);
            candidates.push({
                widgetId,
                widgetItem,
                section: widgetItem.section || sectionHint || "right",
                wrapper: null
            });
        }

        if (screenName) {
            const registry = BarWidgetService.widgetRegistry;
            if (registry && typeof registry === "object") {
                for (const widgetId in registry) {
                    const screenMap = registry[widgetId];
                    if (!screenMap || typeof screenMap !== "object")
                        continue;
                    const widgetItem = screenMap[screenName];
                    if (widgetItem)
                        addCandidate(widgetId, widgetItem, widgetItem.section);
                }
            }
        }

        const hosts = _enumerateWidgetHosts();
        for (let i = 0; i < hosts.length; i++) {
            const entry = hosts[i];
            if (!entry.host?.item)
                continue;
            const existing = candidates.find(c => c.widgetItem === entry.host.item);
            if (existing) {
                existing.wrapper = entry.wrapper;
                if (!existing.section)
                    existing.section = entry.section;
                continue;
            }
            candidates.push({
                widgetId: entry.host.widgetId,
                widgetItem: entry.host.item,
                section: entry.host.item.section || entry.section,
                wrapper: entry.wrapper
            });
        }

        return candidates;
    }

    function _globalItemBounds(item) {
        const topLeft = item.mapToItem(null, 0, 0);
        return {
            x: topLeft.x,
            y: topLeft.y,
            width: item.width,
            height: item.height
        };
    }

    function _hitBoundsForWidget(widgetItem, wrapper) {
        if (!widgetItem?.visible)
            return null;

        if (widgetItem.visualContent !== undefined) {
            const visual = widgetItem.visualContent;
            if (visual.width > 0 && visual.height > 0)
                return _globalItemBounds(visual);
        }

        if (widgetItem.width > 0 && widgetItem.height > 0)
            return _globalItemBounds(widgetItem);

        if (wrapper && wrapper.width > 0 && wrapper.height > 0)
            return _globalItemBounds(wrapper);

        return null;
    }

    function _pointInBounds(gx, gy, bounds) {
        return gx >= bounds.x && gx < bounds.x + bounds.width && gy >= bounds.y && gy < bounds.y + bounds.height;
    }

    function findWidgetAtGlobalPoint(gx, gy) {
        const candidates = _collectHoverCandidates();
        let best = null;
        let bestArea = Infinity;
        for (let i = 0; i < candidates.length; i++) {
            const entry = candidates[i];
            const bounds = _hitBoundsForWidget(entry.widgetItem, entry.wrapper);
            if (!bounds || bounds.width <= 0 || bounds.height <= 0)
                continue;
            if (!_pointInBounds(gx, gy, bounds))
                continue;
            const area = bounds.width * bounds.height;
            if (area < bestArea) {
                bestArea = area;
                best = {
                    widgetId: entry.widgetId,
                    widgetItem: entry.widgetItem,
                    section: entry.section
                };
            }
        }
        return best;
    }

    function _dashTriggerSource(section, tabIndex) {
        return (barConfig?.id ?? "default") + "-" + section + "-" + tabIndex;
    }

    function _notepadWidgetForScreen() {
        const screenName = barWindow?.screen?.name;
        const fromRegistry = screenName ? BarWidgetService.getWidget("notepadButton", screenName) : null;
        if (fromRegistry)
            return fromRegistry;
        const candidates = _collectHoverCandidates();
        for (let i = 0; i < candidates.length; i++) {
            if (candidates[i].widgetId === "notepadButton")
                return candidates[i].widgetItem;
        }
        return null;
    }

    function notepadContainsGlobalPoint(gx, gy) {
        const instance = _notepadWidgetForScreen()?.notepadInstance;
        if (!instance?.isVisible || typeof instance.containsGlobalPoint !== "function")
            return false;
        return instance.containsGlobalPoint(gx, gy);
    }

    function cursorOverHoverChain(gx, gy) {
        if (PopoutManager.cursorOverBar(gx, gy))
            return true;
        const popout = PopoutManager.getActivePopout(barWindow?.screen);
        if (popout?.containsGlobalPoint?.(gx, gy))
            return true;
        if (notepadContainsGlobalPoint(gx, gy))
            return true;
        const screenName = barWindow.screen?.name;
        if (screenName && TrayMenuManager.activeTrayMenus[screenName])
            return true;
        return false;
    }

    function _closeHoverNotepad() {
        if (activeHoverTrigger !== "notepadButton")
            return;
        const instance = _notepadWidgetForScreen()?.notepadInstance;
        if (!instance)
            return;
        if (instance.hoverDismissEnabled !== undefined)
            instance.hoverDismissEnabled = false;
        if (typeof instance.hideFromHoverDismiss === "function")
            instance.hideFromHoverDismiss();
        else if (typeof instance.hide === "function")
            instance.hide();
    }

    function closeHoverSurfaces() {
        _closeHoverNotepad();
        activeHoverTrigger = "";
        PopoutManager.closePopoutForScreen(barWindow?.screen);
        TrayMenuManager.closeAllMenus();
    }

    function openNotepadHover(widgetItem) {
        const instance = widgetItem.prepareNotepadInstance?.(widgetItem.notepadInstance) ?? widgetItem.notepadInstance;
        if (!instance || typeof instance.show !== "function")
            return false;
        if (instance.hoverDismissEnabled !== undefined)
            instance.hoverDismissEnabled = true;
        instance.show();
        return true;
    }

    function _syncHoverTriggerState() {
        if (activeHoverTrigger === "notepadButton") {
            const inst = _notepadWidgetForScreen()?.notepadInstance;
            if (!inst?.isVisible)
                activeHoverTrigger = "";
            return;
        }
        if (activeHoverTrigger === "")
            return;
        if (!hasOpenHoverSurface())
            activeHoverTrigger = "";
    }

    function hasOpenHoverSurface() {
        if (activeHoverTrigger === "")
            return false;
        if (activeHoverTrigger === "notepadButton") {
            const inst = _notepadWidgetForScreen()?.notepadInstance;
            return inst?.isVisible ?? false;
        }
        const popout = PopoutManager.getActivePopout(barWindow?.screen);
        if (!popout)
            return false;
        if (popout.dashVisible !== undefined)
            return !!popout.dashVisible || !!popout.isClosing;
        if (popout.notificationHistoryVisible !== undefined)
            return !!popout.notificationHistoryVisible || !!popout.isClosing;
        return !!(popout.shouldBeVisible || popout.isClosing);
    }

    function openHoverPopoutForHit(hit) {
        if (!hit?.widgetItem)
            return false;

        const widgetId = hit.widgetId;
        const widgetItem = hit.widgetItem;
        const section = hit.section;
        const mode = "hover";
        const base = {
            widgetItem,
            section,
            mode
        };

        if (widgetId === "systemTray") {
            if (typeof widgetItem.openHoverAtGlobalPoint !== "function")
                return false;
            return !!widgetItem.openHoverAtGlobalPoint(hit.globalX, hit.globalY);
        }

        if (typeof widgetItem.triggerHoverPopout === "function") {
            widgetItem.triggerHoverPopout(hit.widgetId);
            return true;
        }

        switch (widgetId) {
        case "launcherButton":
            return openWidgetPopout(Object.assign({}, base, {
                loader: appDrawerLoader,
                triggerSource: "appDrawer",
                visualItem: widgetItem
            }));
        case "clipboard":
            return openWidgetPopout(Object.assign({}, base, {
                loader: clipboardHistoryPopoutLoader,
                triggerSource: "clipboard",
                prepare: popout => {
                    popout.activeTab = "recents";
                }
            }));
        case "clock":
            return openWidgetPopout(Object.assign({}, base, {
                loader: dankDashPopoutLoader,
                tabIndex: 0,
                triggerSource: _dashTriggerSource(section, 0),
                useCenterSection: true,
                setTriggerScreen: true
            }));
        case "music":
            return openWidgetPopout(Object.assign({}, base, {
                loader: dankDashPopoutLoader,
                tabIndex: 1,
                triggerSource: _dashTriggerSource(section, 1),
                useCenterSection: true,
                setTriggerScreen: true
            }));
        case "weather":
            return openWidgetPopout(Object.assign({}, base, {
                loader: dankDashPopoutLoader,
                tabIndex: 3,
                triggerSource: _dashTriggerSource(section, 3),
                useCenterSection: true,
                setTriggerScreen: true
            }));
        case "cpuUsage":
            return openWidgetPopout(Object.assign({}, base, {
                loader: processListPopoutLoader,
                triggerSource: "cpu"
            }));
        case "memUsage":
            return openWidgetPopout(Object.assign({}, base, {
                loader: processListPopoutLoader,
                triggerSource: "memory"
            }));
        case "cpuTemp":
            return openWidgetPopout(Object.assign({}, base, {
                loader: processListPopoutLoader,
                triggerSource: "cpu_temp"
            }));
        case "gpuTemp":
            return openWidgetPopout(Object.assign({}, base, {
                loader: processListPopoutLoader,
                triggerSource: "gpu_temp"
            }));
        case "notificationButton":
            return openWidgetPopout(Object.assign({}, base, {
                loader: notificationCenterLoader,
                triggerSource: "notifications",
                setTriggerScreen: true
            }));
        case "battery":
            return openWidgetPopout(Object.assign({}, base, {
                loader: batteryPopoutLoader,
                triggerSource: "battery"
            }));
        case "layout":
            return openWidgetPopout(Object.assign({}, base, {
                loader: layoutPopoutLoader,
                triggerSource: "layout"
            }));
        case "vpn":
            return openWidgetPopout(Object.assign({}, base, {
                loader: vpnPopoutLoader,
                triggerSource: "vpn"
            }));
        case "controlCenterButton":
            if (openWidgetPopout(Object.assign({}, base, {
                loader: controlCenterLoader,
                triggerSource: "controlCenter",
                setTriggerScreen: true
            }))) {
                if (controlCenterLoader.item?.shouldBeVisible && NetworkService.wifiEnabled)
                    NetworkService.scanWifi();
                return true;
            }
            return false;
        case "systemUpdate":
            return openWidgetPopout(Object.assign({}, base, {
                loader: systemUpdateLoader,
                triggerSource: "systemUpdate",
                visualItem: widgetItem
            }));
        case "notepadButton":
            return openNotepadHover(widgetItem);
        default:
            return false;
        }
    }

    function checkHoverPopout(gx, gy) {
        if (!hoverPopoutsEnabled)
            return;

        _lastHoverGlobalX = gx;
        _lastHoverGlobalY = gy;
        PopoutManager.updateHoverCursor(gx, gy);
        _syncHoverTriggerState();

        const hit = findWidgetAtGlobalPoint(gx, gy);
        if (!hit) {
            if (!cursorOverHoverChain(gx, gy))
                closeHoverSurfaces();
            return;
        }

        hit.globalX = gx;
        hit.globalY = gy;

        let triggerKey = hit.widgetId;
        if (hit.widgetId === "systemTray")
            triggerKey = hit.widgetItem.hoverTriggerAtGlobalPoint?.(gx, gy) || "";
        else if (hit.widgetId === "clock")
            triggerKey = _dashTriggerSource(hit.section, 0);
        else if (hit.widgetId === "music")
            triggerKey = _dashTriggerSource(hit.section, 1);
        else if (hit.widgetId === "weather")
            triggerKey = _dashTriggerSource(hit.section, 3);

        if (!triggerKey) {
            if (!cursorOverHoverChain(gx, gy))
                closeHoverSurfaces();
            return;
        }

        if (triggerKey === activeHoverTrigger && hasOpenHoverSurface())
            return;

        if (triggerKey !== activeHoverTrigger && activeHoverTrigger !== "")
            closeHoverSurfaces();

        if (!openHoverPopoutForHit(hit)) {
            if (activeHoverTrigger !== "")
                closeHoverSurfaces();
            return;
        }

        activeHoverTrigger = triggerKey;
    }

    readonly property var widgetVisibility: ({
            "cpuUsage": DgopService.dgopAvailable,
            "memUsage": DgopService.dgopAvailable,
            "cpuTemp": DgopService.dgopAvailable,
            "gpuTemp": DgopService.dgopAvailable,
            "network_speed_monitor": DgopService.dgopAvailable
        })

    function getWidgetVisible(widgetId) {
        return widgetVisibility[widgetId] ?? true;
    }

    readonly property var componentMap: {
        componentMapRevision;

        let baseMap = {
            "launcherButton": launcherButtonComponent,
            "workspaceSwitcher": workspaceSwitcherComponent,
            "focusedWindow": focusedWindowComponent,
            "runningApps": runningAppsComponent,
            "appsDock": appsDockComponent,
            "clock": clockComponent,
            "music": mediaComponent,
            "weather": weatherComponent,
            "systemTray": systemTrayComponent,
            "privacyIndicator": privacyIndicatorComponent,
            "clipboard": clipboardComponent,
            "cpuUsage": cpuUsageComponent,
            "memUsage": memUsageComponent,
            "diskUsage": diskUsageComponent,
            "cpuTemp": cpuTempComponent,
            "gpuTemp": gpuTempComponent,
            "notificationButton": notificationButtonComponent,
            "battery": batteryComponent,
            "layout": layoutComponent,
            "controlCenterButton": controlCenterButtonComponent,
            "capsLockIndicator": capsLockIndicatorComponent,
            "idleInhibitor": idleInhibitorComponent,
            "spacer": spacerComponent,
            "separator": separatorComponent,
            "network_speed_monitor": networkComponent,
            "keyboard_layout_name": keyboardLayoutNameComponent,
            "vpn": vpnComponent,
            "notepadButton": notepadButtonComponent,
            "colorPicker": colorPickerComponent,
            "systemUpdate": systemUpdateComponent,
            "powerMenuButton": powerMenuButtonComponent
        };

        let pluginMap = PluginService.getWidgetComponents();
        return Object.assign(baseMap, pluginMap);
    }

    function getWidgetComponent(widgetId) {
        return componentMap[widgetId] || null;
    }

    readonly property var allComponents: ({
            "launcherButtonComponent": launcherButtonComponent,
            "workspaceSwitcherComponent": workspaceSwitcherComponent,
            "focusedWindowComponent": focusedWindowComponent,
            "runningAppsComponent": runningAppsComponent,
            "appsDockComponent": appsDockComponent,
            "clockComponent": clockComponent,
            "mediaComponent": mediaComponent,
            "weatherComponent": weatherComponent,
            "systemTrayComponent": systemTrayComponent,
            "privacyIndicatorComponent": privacyIndicatorComponent,
            "clipboardComponent": clipboardComponent,
            "cpuUsageComponent": cpuUsageComponent,
            "memUsageComponent": memUsageComponent,
            "diskUsageComponent": diskUsageComponent,
            "cpuTempComponent": cpuTempComponent,
            "gpuTempComponent": gpuTempComponent,
            "notificationButtonComponent": notificationButtonComponent,
            "batteryComponent": batteryComponent,
            "layoutComponent": layoutComponent,
            "controlCenterButtonComponent": controlCenterButtonComponent,
            "capsLockIndicatorComponent": capsLockIndicatorComponent,
            "idleInhibitorComponent": idleInhibitorComponent,
            "spacerComponent": spacerComponent,
            "separatorComponent": separatorComponent,
            "networkComponent": networkComponent,
            "keyboardLayoutNameComponent": keyboardLayoutNameComponent,
            "vpnComponent": vpnComponent,
            "notepadButtonComponent": notepadButtonComponent,
            "colorPickerComponent": colorPickerComponent,
            "systemUpdateComponent": systemUpdateComponent,
            "powerMenuButtonComponent": powerMenuButtonComponent
        })

    Item {
        id: stackContainer
        anchors.fill: parent

        Item {
            id: horizontalStack
            anchors.fill: parent
            visible: !barWindow.axis.isVertical

            LeftSection {
                id: hLeftSection
                objectName: "leftSection"
                overrideAxisLayout: true
                forceVerticalLayout: false
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                axis: barWindow.axis
                widgetsModel: topBarContent.leftWidgetsModel
                components: topBarContent.allComponents
                noBackground: barConfig?.noBackground ?? false
                parentScreen: barWindow.screen
                widgetThickness: barWindow.widgetThickness
                barThickness: barWindow.effectiveBarThickness
                barSpacing: barConfig?.spacing ?? 4
            }

            Binding {
                target: hLeftSection
                property: "barConfig"
                value: topBarContent.barConfig
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: hLeftSection
                property: "blurBarWindow"
                value: topBarContent.blurBarWindow
                restoreMode: Binding.RestoreNone
            }

            RightSection {
                id: hRightSection
                objectName: "rightSection"
                overrideAxisLayout: true
                forceVerticalLayout: false
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                axis: barWindow.axis
                widgetsModel: topBarContent.rightWidgetsModel
                components: topBarContent.allComponents
                noBackground: barConfig?.noBackground ?? false
                parentScreen: barWindow.screen
                widgetThickness: barWindow.widgetThickness
                barThickness: barWindow.effectiveBarThickness
                barSpacing: barConfig?.spacing ?? 4
            }

            Binding {
                target: hRightSection
                property: "barConfig"
                value: topBarContent.barConfig
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: hRightSection
                property: "blurBarWindow"
                value: topBarContent.blurBarWindow
                restoreMode: Binding.RestoreNone
            }

            CenterSection {
                id: hCenterSection
                objectName: "centerSection"
                overrideAxisLayout: true
                forceVerticalLayout: false
                anchors {
                    verticalCenter: parent.verticalCenter
                    horizontalCenter: parent.horizontalCenter
                }
                axis: barWindow.axis
                widgetsModel: topBarContent.centerWidgetsModel
                components: topBarContent.allComponents
                noBackground: barConfig?.noBackground ?? false
                parentScreen: barWindow.screen
                widgetThickness: barWindow.widgetThickness
                barThickness: barWindow.effectiveBarThickness
                barSpacing: barConfig?.spacing ?? 4
            }

            Binding {
                target: hCenterSection
                property: "barConfig"
                value: topBarContent.barConfig
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: hCenterSection
                property: "blurBarWindow"
                value: topBarContent.blurBarWindow
                restoreMode: Binding.RestoreNone
            }
        }

        Item {
            id: verticalStack
            anchors.fill: parent
            visible: barWindow.axis.isVertical

            LeftSection {
                id: vLeftSection
                objectName: "leftSection"
                overrideAxisLayout: true
                forceVerticalLayout: true
                width: parent.width
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }
                axis: barWindow.axis
                widgetsModel: topBarContent.leftWidgetsModel
                components: topBarContent.allComponents
                noBackground: barConfig?.noBackground ?? false
                parentScreen: barWindow.screen
                widgetThickness: barWindow.widgetThickness
                barThickness: barWindow.effectiveBarThickness
                barSpacing: barConfig?.spacing ?? 4
            }

            Binding {
                target: vLeftSection
                property: "barConfig"
                value: topBarContent.barConfig
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: vLeftSection
                property: "blurBarWindow"
                value: topBarContent.blurBarWindow
                restoreMode: Binding.RestoreNone
            }

            CenterSection {
                id: vCenterSection
                objectName: "centerSection"
                overrideAxisLayout: true
                forceVerticalLayout: true
                width: parent.width
                anchors {
                    verticalCenter: parent.verticalCenter
                    horizontalCenter: parent.horizontalCenter
                }
                axis: barWindow.axis
                widgetsModel: topBarContent.centerWidgetsModel
                components: topBarContent.allComponents
                noBackground: barConfig?.noBackground ?? false
                parentScreen: barWindow.screen
                widgetThickness: barWindow.widgetThickness
                barThickness: barWindow.effectiveBarThickness
                barSpacing: barConfig?.spacing ?? 4
            }

            Binding {
                target: vCenterSection
                property: "barConfig"
                value: topBarContent.barConfig
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: vCenterSection
                property: "blurBarWindow"
                value: topBarContent.blurBarWindow
                restoreMode: Binding.RestoreNone
            }

            RightSection {
                id: vRightSection
                objectName: "rightSection"
                overrideAxisLayout: true
                forceVerticalLayout: true
                width: parent.width
                height: implicitHeight
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                axis: barWindow.axis
                widgetsModel: topBarContent.rightWidgetsModel
                components: topBarContent.allComponents
                noBackground: barConfig?.noBackground ?? false
                parentScreen: barWindow.screen
                widgetThickness: barWindow.widgetThickness
                barThickness: barWindow.effectiveBarThickness
                barSpacing: barConfig?.spacing ?? 4
            }

            Binding {
                target: vRightSection
                property: "barConfig"
                value: topBarContent.barConfig
                restoreMode: Binding.RestoreNone
            }
            Binding {
                target: vRightSection
                property: "blurBarWindow"
                value: topBarContent.blurBarWindow
                restoreMode: Binding.RestoreNone
            }
        }
    }

    Component {
        id: clipboardComponent

        ClipboardButton {
            id: clipboardWidget
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent)
            parentScreen: barWindow.screen
            popoutTarget: clipboardHistoryPopoutLoader.item ?? null

            function openClipboardPopout(initialTab, mode) {
                openWidgetPopout({
                    loader: clipboardHistoryPopoutLoader,
                    widgetItem: clipboardWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "clipboard",
                    mode: mode || "click",
                    prepare: popout => {
                        if (initialTab)
                            popout.activeTab = initialTab;
                    }
                });
            }

            onClipboardClicked: openClipboardPopout("recents")

            onShowSavedItemsRequested: openClipboardPopout("saved")

            onClearAllRequested: {
                clipboardHistoryPopoutLoader.active = true;
                const popout = clipboardHistoryPopoutLoader.item;
                if (!popout?.confirmDialog) {
                    return;
                }
                const hasPinned = popout.pinnedCount > 0;
                const message = hasPinned ? I18n.tr("This will delete all unpinned entries. %1 pinned entries will be kept.").arg(popout.pinnedCount) : I18n.tr("This will permanently delete all clipboard history.");
                popout.confirmDialog.show(I18n.tr("Clear History?"), message, function () {
                    if (popout && typeof popout.clearAll === "function") {
                        popout.clearAll();
                    }
                }, function () {});
            }
        }
    }

    Component {
        id: powerMenuButtonComponent

        PowerMenuButton {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent)
            parentScreen: barWindow.screen
            onClicked: {
                if (powerMenuModalLoader) {
                    powerMenuModalLoader.active = true;
                    if (powerMenuModalLoader.item) {
                        powerMenuModalLoader.item.openCentered();
                    }
                }
            }
        }
    }

    Component {
        id: launcherButtonComponent

        LauncherButton {
            id: launcherButton
            isActive: false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            section: topBarContent.getWidgetSection(parent)
            popoutTarget: appDrawerLoader.item
            parentScreen: barWindow.screen
            hyprlandOverviewLoader: barWindow ? barWindow.hyprlandOverviewLoader : null

            function _preparePopout() {
                appDrawerLoader.active = true;
                if (!appDrawerLoader.item)
                    return false;
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (appDrawerLoader.item.setBarContext)
                    appDrawerLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                if (appDrawerLoader.item.setTriggerPosition) {
                    const globalPos = launcherButton.visualContent.mapToItem(null, 0, 0);
                    const currentScreen = barWindow.screen;
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barWindow.effectiveBarThickness, launcherButton.visualWidth, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    appDrawerLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, launcherButton.section, currentScreen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                return true;
            }

            function openWithMode(mode) {
                if (!_preparePopout())
                    return;
                appDrawerLoader.item.openWithMode(mode);
            }

            function toggleWithMode(mode) {
                if (!_preparePopout())
                    return;
                appDrawerLoader.item.toggleWithMode(mode);
            }

            function openWithQuery(query) {
                if (!_preparePopout())
                    return;
                appDrawerLoader.item.openWithQuery(query);
            }

            function toggleWithQuery(query) {
                if (!_preparePopout())
                    return;
                appDrawerLoader.item.toggleWithQuery(query);
            }

            onClicked: {
                topBarContent.openWidgetPopout({
                    loader: appDrawerLoader,
                    widgetItem: launcherButton,
                    section: launcherButton.section,
                    triggerSource: "appDrawer",
                    mode: "click",
                    visualItem: launcherButton
                });
            }
        }
    }

    Component {
        id: workspaceSwitcherComponent

        WorkspaceSwitcher {
            axis: barWindow.axis
            screenName: _barScreenName
            widgetHeight: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            parentScreen: barWindow.screen
            hyprlandOverviewLoader: barWindow ? barWindow.hyprlandOverviewLoader : null
        }
    }

    Component {
        id: focusedWindowComponent

        FocusedApp {
            axis: barWindow.axis
            availableWidth: topBarContent.leftToMediaGap
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            barSpacing: barConfig?.spacing ?? 4
            barConfig: topBarContent.barConfig
            isAutoHideBar: topBarContent.barConfig?.autoHide ?? false
            parentScreen: barWindow.screen
        }
    }

    Component {
        id: runningAppsComponent

        RunningApps {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            barSpacing: barConfig?.spacing ?? 4
            section: topBarContent.getWidgetSection(parent)
            parentScreen: barWindow.screen
            topBar: topBarContent
            barConfig: topBarContent.barConfig
            isAutoHideBar: topBarContent.barConfig?.autoHide ?? false
        }
    }

    Component {
        id: appsDockComponent

        AppsDock {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            barSpacing: barConfig?.spacing ?? 4
            section: topBarContent.getWidgetSection(parent)
            parentScreen: barWindow.screen
            topBar: topBarContent
            barConfig: topBarContent.barConfig
            isAutoHideBar: topBarContent.barConfig?.autoHide ?? false
        }
    }

    Component {
        id: clockComponent

        Clock {
            id: clockWidget
            axis: barWindow.axis
            compactMode: topBarContent.overlapping
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: dankDashPopoutLoader.item ?? null
            parentScreen: barWindow.screen

            Component.onCompleted: {
                barWindow.clockButtonRef = this;
            }

            Component.onDestruction: {
                if (barWindow.clockButtonRef === this) {
                    barWindow.clockButtonRef = null;
                }
            }

            onClockClicked: {
                const section = topBarContent.getWidgetSection(parent) || "center";
                topBarContent.openWidgetPopout({
                    loader: dankDashPopoutLoader,
                    widgetItem: clockWidget,
                    section,
                    tabIndex: 0,
                    triggerSource: topBarContent._dashTriggerSource(section, 0),
                    mode: "click",
                    useCenterSection: true,
                    setTriggerScreen: true
                });
            }
        }
    }

    Component {
        id: mediaComponent

        Media {
            id: mediaWidget
            axis: barWindow.axis
            compactMode: topBarContent.spacingTight || topBarContent.overlapping
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: dankDashPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            onClicked: {
                const section = topBarContent.getWidgetSection(parent) || "center";
                topBarContent.openWidgetPopout({
                    loader: dankDashPopoutLoader,
                    widgetItem: mediaWidget,
                    section,
                    tabIndex: 1,
                    triggerSource: topBarContent._dashTriggerSource(section, 1),
                    mode: "click",
                    useCenterSection: true,
                    setTriggerScreen: true
                });
            }
        }
    }

    Component {
        id: weatherComponent

        Weather {
            id: weatherWidget
            axis: barWindow.axis
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: dankDashPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            onClicked: {
                const section = topBarContent.getWidgetSection(parent) || "center";
                topBarContent.openWidgetPopout({
                    loader: dankDashPopoutLoader,
                    widgetItem: weatherWidget,
                    section,
                    tabIndex: 3,
                    triggerSource: topBarContent._dashTriggerSource(section, 3),
                    mode: "click",
                    useCenterSection: true,
                    setTriggerScreen: true
                });
            }
        }
    }

    Component {
        id: systemTrayComponent

        SystemTrayBar {
            parentWindow: barWindow
            parentScreen: barWindow.screen
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            barSpacing: barConfig?.spacing ?? 4
            barConfig: topBarContent.barConfig
            widgetData: parent.widgetData
            isAutoHideBar: topBarContent.barConfig?.autoHide ?? false
            isAtBottom: barWindow.axis?.edge === "bottom"
            visible: SettingsData.getFilteredScreens("systemTray").includes(barWindow.screen) && SystemTray.items.values.length > 0
        }
    }

    Component {
        id: privacyIndicatorComponent

        PrivacyIndicator {
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "right"
            parentScreen: barWindow.screen
        }
    }

    Component {
        id: cpuUsageComponent

        CpuMonitor {
            id: cpuWidget
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: processListPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onCpuClicked: {
                topBarContent.openWidgetPopout({
                    loader: processListPopoutLoader,
                    widgetItem: cpuWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "cpu",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: memUsageComponent

        RamMonitor {
            id: ramWidget
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: processListPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onRamClicked: {
                topBarContent.openWidgetPopout({
                    loader: processListPopoutLoader,
                    widgetItem: ramWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "memory",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: diskUsageComponent

        DiskUsage {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            widgetData: parent.widgetData
            parentScreen: barWindow.screen
            barConfig: topBarContent.barConfig
            isAutoHideBar: topBarContent.barConfig?.autoHide ?? false
        }
    }

    Component {
        id: cpuTempComponent

        CpuTemperature {
            id: cpuTempWidget
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: processListPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onCpuTempClicked: {
                topBarContent.openWidgetPopout({
                    loader: processListPopoutLoader,
                    widgetItem: cpuTempWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "cpu_temp",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: gpuTempComponent

        GpuTemperature {
            id: gpuTempWidget
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: processListPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onGpuTempClicked: {
                topBarContent.openWidgetPopout({
                    loader: processListPopoutLoader,
                    widgetItem: gpuTempWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "gpu_temp",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: networkComponent

        NetworkMonitor {}
    }

    Component {
        id: notificationButtonComponent

        NotificationCenterButton {
            id: notificationButton
            hasUnread: barWindow.notificationCount > 0
            isActive: notificationCenterLoader.item ? notificationCenterLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: notificationCenterLoader.item ?? null
            parentScreen: barWindow.screen
            onClicked: {
                topBarContent.openWidgetPopout({
                    loader: notificationCenterLoader,
                    widgetItem: notificationButton,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "notifications",
                    mode: "click",
                    setTriggerScreen: true
                });
            }
        }
    }

    Component {
        id: batteryComponent

        Battery {
            id: batteryWidget
            batteryPopupVisible: batteryPopoutLoader.item ? batteryPopoutLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            barSpacing: barConfig?.spacing ?? 4
            barConfig: topBarContent.barConfig
            popoutTarget: batteryPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            onToggleBatteryPopup: {
                topBarContent.openWidgetPopout({
                    loader: batteryPopoutLoader,
                    widgetItem: batteryWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "battery",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: layoutComponent

        DWLLayout {
            id: layoutWidget
            layoutPopupVisible: layoutPopoutLoader.item ? layoutPopoutLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: layoutPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            onToggleLayoutPopup: {
                topBarContent.openWidgetPopout({
                    loader: layoutPopoutLoader,
                    widgetItem: layoutWidget,
                    section: topBarContent.getWidgetSection(parent) || "center",
                    triggerSource: "layout",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: vpnComponent

        Vpn {
            id: vpnWidget
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            barSpacing: barConfig?.spacing ?? 4
            barConfig: topBarContent.barConfig
            isAutoHideBar: topBarContent.barConfig?.autoHide ?? false
            popoutTarget: vpnPopoutLoader.item ?? null
            parentScreen: barWindow.screen
            onToggleVpnPopup: {
                topBarContent.openWidgetPopout({
                    loader: vpnPopoutLoader,
                    widgetItem: vpnWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "vpn",
                    mode: "click"
                });
            }
        }
    }

    Component {
        id: controlCenterButtonComponent

        ControlCenterButton {
            id: controlCenterButton
            isActive: controlCenterLoader.item ? controlCenterLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: controlCenterLoader.item ?? null
            parentScreen: barWindow.screen
            screenName: barWindow.screen?.name || ""
            screenModel: barWindow.screen?.model || ""
            widgetData: parent.widgetData

            Component.onCompleted: {
                barWindow.controlCenterButtonRef = this;
            }

            Component.onDestruction: {
                if (barWindow.controlCenterButtonRef === this) {
                    barWindow.controlCenterButtonRef = null;
                }
            }

            onClicked: {
                topBarContent.openWidgetPopout({
                    loader: controlCenterLoader,
                    widgetItem: controlCenterButton,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "controlCenter",
                    mode: "click",
                    setTriggerScreen: true
                });
                if (controlCenterLoader.item?.shouldBeVisible && NetworkService.wifiEnabled)
                    NetworkService.scanWifi();
            }
        }
    }

    Component {
        id: capsLockIndicatorComponent

        CapsLockIndicator {
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "right"
            parentScreen: barWindow.screen
        }
    }

    Component {
        id: idleInhibitorComponent

        IdleInhibitor {
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "right"
            parentScreen: barWindow.screen
        }
    }

    Component {
        id: spacerComponent

        Item {
            width: _barIsVertical ? barWindow.widgetThickness : (parent.spacerSize || 20)
            height: _barIsVertical ? (parent.spacerSize || 20) : barWindow.widgetThickness
            implicitWidth: width
            implicitHeight: height

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                border.width: 1
                radius: 2
                visible: false

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                    cursorShape: Qt.ArrowCursor
                    onEntered: parent.visible = true
                    onExited: parent.visible = false
                }
            }
        }
    }

    Component {
        id: separatorComponent

        Item {
            width: _barIsVertical ? parent.barThickness : 1
            height: _barIsVertical ? 1 : parent.barThickness
            implicitWidth: width
            implicitHeight: height

            Rectangle {
                width: _barIsVertical ? parent.width * 0.6 : 1
                height: _barIsVertical ? 1 : parent.height * 0.6
                anchors.centerIn: parent
                color: Theme.outline
                opacity: 0.3
            }
        }
    }

    Component {
        id: keyboardLayoutNameComponent

        KeyboardLayoutName {}
    }

    Component {
        id: notepadButtonComponent

        NotepadButton {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            parentScreen: barWindow.screen
        }
    }

    Component {
        id: colorPickerComponent

        ColorPicker {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            section: topBarContent.getWidgetSection(parent) || "right"
            parentScreen: barWindow.screen
            onColorPickerRequested: {
                barWindow.colorPickerRequested();
            }
        }
    }

    Component {
        id: systemUpdateComponent

        SystemUpdate {
            id: systemUpdateWidget
            isActive: systemUpdateLoader.item ? systemUpdateLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: systemUpdateLoader.item ?? null
            parentScreen: barWindow.screen

            Component.onCompleted: {
                barWindow.systemUpdateButtonRef = this;
            }

            Component.onDestruction: {
                if (barWindow.systemUpdateButtonRef === this)
                    barWindow.systemUpdateButtonRef = null;
            }

            onClicked: {
                topBarContent.openWidgetPopout({
                    loader: systemUpdateLoader,
                    widgetItem: systemUpdateWidget,
                    section: topBarContent.getWidgetSection(parent) || "right",
                    triggerSource: "systemUpdate",
                    mode: "click",
                    visualItem: systemUpdateWidget
                });
            }
        }
    }
}
