pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    required property var barContent
    required property var barWindow
    required property var barConfig
    required property var hLeftSection
    required property var hCenterSection
    required property var hRightSection
    required property var vLeftSection
    required property var vCenterSection
    required property var vRightSection

    property var leftWidgetsModel
    property var centerWidgetsModel
    property var rightWidgetsModel

    property string activeHoverTrigger: ""
    readonly property bool hoverPopoutsEnabled: barConfig?.hoverPopouts ?? false
    readonly property int hoverPopoutDelay: Math.max(0, barConfig?.hoverPopoutDelay ?? 150)

    property real _lastHoverGlobalX: 0
    property real _lastHoverGlobalY: 0
    property bool _hitTestPending: false
    property bool _barHovered: false
    property bool _barExitPending: false
    property var _pendingHoverHit: null
    property string _pendingHoverTrigger: ""

    property bool _candidateCacheValid: false
    property var _candidateCache: []
    property var _candidateWatchers: []
    property bool _lastLookupWasMiss: false

    width: 0
    height: 0

    onLeftWidgetsModelChanged: invalidateCandidateCache()
    onCenterWidgetsModelChanged: invalidateCandidateCache()
    onRightWidgetsModelChanged: invalidateCandidateCache()

    onHoverPopoutsEnabledChanged: {
        if (hoverPopoutsEnabled)
            return;
        cancelQueuedHitTest();
        _cancelPendingHover();
        _hoverCloseTimer.stop();
        if (hasOpenHoverSurface() && !isActiveHoverSurfacePinned())
            closeHoverSurfaces();
        activeHoverTrigger = "";
    }

    Component.onDestruction: _disconnectCandidateWatchers()

    Connections {
        target: root.barContent

        function onWidthChanged() {
            root.invalidateCandidateCache();
        }

        function onHeightChanged() {
            root.invalidateCandidateCache();
        }
    }

    Connections {
        target: root.barWindow

        function onScreenChanged() {
            root.invalidateCandidateCache();
        }
    }

    Connections {
        target: BarWidgetService

        function onWidgetRegistered(_widgetId, screenName) {
            if (screenName === root.barWindow?.screen?.name)
                root.invalidateCandidateCache();
        }

        function onWidgetUnregistered(_widgetId, screenName) {
            if (screenName === root.barWindow?.screen?.name)
                root.invalidateCandidateCache();
        }
    }

    FrameAnimation {
        running: root._hitTestPending
        onTriggered: {
            root._hitTestPending = false;
            root.checkHoverPopout(root._lastHoverGlobalX, root._lastHoverGlobalY);
        }
    }

    Timer {
        id: _hoverIntentTimer
        interval: root.hoverPopoutDelay
        repeat: false
        onTriggered: root._commitPendingHover()
    }

    // Grace timer to prevent flicker when crossing gaps.
    Timer {
        id: _hoverCloseTimer
        interval: 120
        repeat: false
        onTriggered: root._commitHoverClose()
    }

    function queueHoverPoint(gx, gy) {
        _lastHoverGlobalX = gx;
        _lastHoverGlobalY = gy;
        _barHovered = true;
        _barExitPending = false;
        PopoutManager.updateHoverCursor(gx, gy);
        if (hoverPopoutsEnabled)
            _hitTestPending = true;
    }

    function updateBarHovered(hovered) {
        _barHovered = hovered;
        if (hovered) {
            _barExitPending = false;
            _hoverCloseTimer.stop();
            return;
        }

        cancelQueuedHitTest();
        _cancelPendingHover();
        if (!hoverPopoutsEnabled || isActiveHoverSurfacePinned())
            return;
        _barExitPending = true;
        _hoverCloseTimer.restart();
    }

    function cancelQueuedHitTest() {
        _hitTestPending = false;
    }

    function recheckLatestPoint() {
        checkHoverPopout(_lastHoverGlobalX, _lastHoverGlobalY);
    }

    function resetForBarGeometryChange() {
        invalidateCandidateCache();
        cancelQueuedHitTest();
        _cancelPendingHover();
        _hoverCloseTimer.stop();
        barContent._pendingPopoutOpenSpec = null;

        const activePopout = PopoutManager.getActivePopout(barWindow?.screen);
        const hasTransientSurface = activeHoverTrigger !== "" || activePopout?.hoverDismissEnabled === true;
        if (hasTransientSurface && !isActiveHoverSurfacePinned())
            closeHoverSurfaces();
        else
            activeHoverTrigger = "";
    }

    function invalidateCandidateCache() {
        _candidateCacheValid = false;
        _candidateCache = [];
        _lastLookupWasMiss = false;
        _disconnectCandidateWatchers();
    }

    function _disconnectCandidateWatchers() {
        const watchers = _candidateWatchers;
        _candidateWatchers = [];
        for (let i = 0; i < watchers.length; i++) {
            const watcher = watchers[i];
            try {
                const signal = watcher.object?.[watcher.signalName];
                if (signal && typeof signal.disconnect === "function")
                    signal.disconnect(watcher.callback);
            } catch (e) {}
        }
    }

    function _watchCandidateObject(object) {
        if (!object)
            return;
        for (let i = 0; i < _candidateWatchers.length; i++) {
            if (_candidateWatchers[i].object === object)
                return;
        }

        const signalNames = ["xChanged", "yChanged", "widthChanged", "heightChanged", "visibleChanged", "parentChanged", "childrenChanged", "itemChanged", "activeChanged", "destroyed"];
        for (let i = 0; i < signalNames.length; i++) {
            const signalName = signalNames[i];
            try {
                const signal = object[signalName];
                if (!signal || typeof signal.connect !== "function")
                    continue;
                const callback = function () {
                    root.invalidateCandidateCache();
                };
                signal.connect(callback);
                _candidateWatchers.push({
                    object,
                    signalName,
                    callback
                });
            } catch (e) {}
        }
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

    // The widget registry is keyed by (widgetId, screenName)
    function _itemBelongsToThisBar(item) {
        const owner = barContent;
        if (!owner || !item)
            return true;
        let node = item;
        let guard = 0;
        while (node && guard < 100) {
            if (node === owner)
                return true;
            node = node.parent;
            guard++;
        }
        return false;
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
        _watchCandidateObject(section);
        const layoutLoader = section.widgetLayoutLoader;
        _watchCandidateObject(layoutLoader);
        const layout = layoutLoader?.item;
        if (layout) {
            _watchCandidateObject(layout);
            return layout.children || [];
        }
        const children = section.children || [];
        const wrappers = [];
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            if (!child || child === layoutLoader)
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
                _watchCandidateObject(wrapper);
                _watchCandidateObject(host);
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
            if (!root._itemBelongsToThisBar(widgetItem))
                return;
            if (!root._widgetSupportsHoverPopout(widgetId, widgetItem))
                return;
            if (!root.barContent.getWidgetVisible(widgetId))
                return;
            seen.add(widgetItem);
            candidates.push({
                widgetId,
                widgetItem,
                section: widgetItem.section || sectionHint || "right",
                wrapper: null,
                host: null
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
            const existing = candidates.find(candidate => candidate.widgetItem === entry.host.item);
            if (existing) {
                existing.wrapper = entry.wrapper;
                existing.host = entry.host;
                if (!existing.section)
                    existing.section = entry.section;
                continue;
            }
            if (!_widgetSupportsHoverPopout(entry.host.widgetId, entry.host.item))
                continue;
            candidates.push({
                widgetId: entry.host.widgetId,
                widgetItem: entry.host.item,
                section: entry.host.item.section || entry.section,
                wrapper: entry.wrapper,
                host: entry.host
            });
        }

        return candidates;
    }

    function _globalItemBounds(item) {
        try {
            const topLeft = item.mapToItem(null, 0, 0);
            return {
                x: topLeft.x,
                y: topLeft.y,
                width: item.width,
                height: item.height
            };
        } catch (e) {
            return null;
        }
    }

    function _hitBoundsForWidget(widgetItem, wrapper) {
        try {
            if (!widgetItem?.visible)
                return null;

            if (widgetItem.visualContent !== undefined) {
                const visual = widgetItem.visualContent;
                if (visual && visual.width > 0 && visual.height > 0)
                    return _globalItemBounds(visual);
            }

            if (widgetItem.width > 0 && widgetItem.height > 0)
                return _globalItemBounds(widgetItem);

            if (wrapper && wrapper.width > 0 && wrapper.height > 0)
                return _globalItemBounds(wrapper);
        } catch (e) {}
        return null;
    }

    function _pointInBounds(gx, gy, bounds) {
        return gx >= bounds.x && gx < bounds.x + bounds.width && gy >= bounds.y && gy < bounds.y + bounds.height;
    }

    function _sameBounds(a, b) {
        return !!a && !!b && a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }

    function _buildCandidateCache() {
        _disconnectCandidateWatchers();
        const candidates = _collectHoverCandidates();
        const cache = [];
        for (let i = 0; i < candidates.length; i++) {
            const entry = candidates[i];
            const bounds = _hitBoundsForWidget(entry.widgetItem, entry.wrapper);
            _watchCandidateObject(entry.widgetItem);
            _watchCandidateObject(entry.wrapper);
            _watchCandidateObject(entry.host);
            try {
                _watchCandidateObject(entry.widgetItem?.visualContent);
            } catch (e) {}
            if (!bounds || bounds.width <= 0 || bounds.height <= 0)
                continue;
            cache.push({
                widgetId: entry.widgetId,
                widgetItem: entry.widgetItem,
                section: entry.section,
                wrapper: entry.wrapper,
                bounds
            });
        }
        _candidateCache = cache;
        _candidateCacheValid = true;
        _lastLookupWasMiss = false;
    }

    function _scanCandidateCache(gx, gy) {
        let best = null;
        let bestArea = Infinity;
        for (let i = 0; i < _candidateCache.length; i++) {
            const entry = _candidateCache[i];
            const bounds = entry.bounds;
            if (!_pointInBounds(gx, gy, bounds))
                continue;
            const area = bounds.width * bounds.height;
            if (area < bestArea) {
                bestArea = area;
                best = entry;
            }
        }
        return best;
    }

    function _validatedHit(entry, gx, gy) {
        if (!entry)
            return null;
        const liveBounds = _hitBoundsForWidget(entry.widgetItem, entry.wrapper);
        if (!liveBounds || !_pointInBounds(gx, gy, liveBounds))
            return null;
        if (!_sameBounds(entry.bounds, liveBounds))
            return null;
        return {
            widgetId: entry.widgetId,
            widgetItem: entry.widgetItem,
            section: entry.section
        };
    }

    function findWidgetAtGlobalPoint(gx, gy) {
        if (!_candidateCacheValid)
            _buildCandidateCache();

        let entry = _scanCandidateCache(gx, gy);
        let hit = _validatedHit(entry, gx, gy);
        if (entry && !hit) {
            invalidateCandidateCache();
            _buildCandidateCache();
            entry = _scanCandidateCache(gx, gy);
            hit = _validatedHit(entry, gx, gy);
        } else if (!entry && !_lastLookupWasMiss) {
            // One live rebuild on entry into an empty gap covers layout changes whose
            // source did not expose a QML geometry signal without rescanning every frame.
            invalidateCandidateCache();
            _buildCandidateCache();
            entry = _scanCandidateCache(gx, gy);
            hit = _validatedHit(entry, gx, gy);
        }

        _lastLookupWasMiss = !hit;
        return hit;
    }

    function dashTriggerSource(section, tabIndex) {
        return (barConfig?.id ?? "default") + "-" + section + "-" + tabIndex;
    }

    function _notepadWidgetForScreen() {
        // Prefer this bar's own enumerated candidates; the registry is screen-keyed and a
        // sibling bar on the same screen can shadow it.
        if (!_candidateCacheValid)
            _buildCandidateCache();
        for (let i = 0; i < _candidateCache.length; i++) {
            if (_candidateCache[i].widgetId === "notepadButton")
                return _candidateCache[i].widgetItem;
        }
        const screenName = barWindow?.screen?.name;
        const fromRegistry = screenName ? BarWidgetService.getWidget("notepadButton", screenName) : null;
        if (fromRegistry && _itemBelongsToThisBar(fromRegistry))
            return fromRegistry;
        return null;
    }

    function notepadContainsGlobalPoint(gx, gy) {
        const instance = _notepadWidgetForScreen()?.notepadInstance;
        if (!instance?.isVisible || typeof instance.containsGlobalPoint !== "function")
            return false;
        return instance.containsGlobalPoint(gx, gy);
    }

    function isActiveHoverSurfacePinned() {
        if (activeHoverTrigger === "notepadButton") {
            const instance = _notepadWidgetForScreen()?.notepadInstance;
            if (instance?.hoverDismissSuspended === true)
                return true;
        }
        return PopoutManager.isActivePopoutPinned(barWindow?.screen);
    }

    function cursorOverHoverChain(gx, gy, excludedBarWindow) {
        if (PopoutManager.cursorOverBar(gx, gy, undefined, excludedBarWindow))
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

    function _beginSupersededCloseForActive() {
        const popout = PopoutManager.getActivePopout(barWindow?.screen);
        if (popout && typeof popout.beginSupersededClose === "function")
            popout.beginSupersededClose();
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
            const instance = _notepadWidgetForScreen()?.notepadInstance;
            if (!instance?.isVisible)
                activeHoverTrigger = "";
            return;
        }
        if (activeHoverTrigger !== "" && !hasOpenHoverSurface())
            activeHoverTrigger = "";
    }

    function hasOpenHoverSurface() {
        if (activeHoverTrigger === "")
            return false;
        if (activeHoverTrigger === "notepadButton") {
            const instance = _notepadWidgetForScreen()?.notepadInstance;
            return instance?.isVisible ?? false;
        }
        if (activeHoverTrigger.startsWith("tray-")) {
            const screenName = barWindow.screen?.name;
            return !!(screenName && TrayMenuManager.activeTrayMenus[screenName]);
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

    function _loaderForWidgetId(widgetId) {
        switch (widgetId) {
        case "launcherButton":
            return PopoutService.appDrawerLoader;
        case "clipboard":
            return PopoutService.clipboardHistoryPopoutLoader;
        case "clock":
        case "music":
        case "weather":
            return PopoutService.dankDashPopoutLoader;
        case "cpuUsage":
        case "memUsage":
        case "cpuTemp":
        case "gpuTemp":
            return PopoutService.processListPopoutLoader;
        case "notificationButton":
            return PopoutService.notificationCenterLoader;
        case "battery":
            return PopoutService.batteryPopoutLoader;
        case "layout":
            return PopoutService.layoutPopoutLoader;
        case "vpn":
            return PopoutService.vpnPopoutLoader;
        case "controlCenterButton":
            return PopoutService.controlCenterLoader;
        case "systemUpdate":
            return PopoutService.systemUpdateLoader;
        default:
            return null;
        }
    }

    function openHoverPopoutForHit(hit) {
        if (!hit?.widgetItem)
            return false;

        const widgetId = hit.widgetId;
        const widgetItem = hit.widgetItem;
        const section = hit.section;
        const base = {
            widgetItem,
            section,
            mode: "hover"
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

        const loader = _loaderForWidgetId(widgetId);
        switch (widgetId) {
        case "launcherButton":
            return barContent.openWidgetPopout(Object.assign({}, base, {
                loader,
                triggerSource: "appDrawer",
                visualItem: widgetItem
            }));
        case "clipboard":
            return barContent.openWidgetPopout(Object.assign({}, base, {
                loader,
                triggerSource: "clipboard",
                prepare: popout => {
                    popout.activeTab = "recents";
                }
            }));
        case "clock":
        case "music":
        case "weather":
            {
                const tabIndex = widgetId === "clock" ? 0 : (widgetId === "music" ? 1 : 3);
                return barContent.openWidgetPopout(Object.assign({}, base, {
                    loader,
                    tabIndex,
                    triggerSource: dashTriggerSource(section, tabIndex),
                    useCenterSection: true,
                    setTriggerScreen: true
                }));
            }
        case "cpuUsage":
        case "memUsage":
        case "cpuTemp":
        case "gpuTemp":
            {
                const triggerSources = {
                    cpuUsage: "cpu",
                    memUsage: "memory",
                    cpuTemp: "cpu_temp",
                    gpuTemp: "gpu_temp"
                };
                return barContent.openWidgetPopout(Object.assign({}, base, {
                    loader,
                    triggerSource: triggerSources[widgetId]
                }));
            }
        case "notificationButton":
            return barContent.openWidgetPopout(Object.assign({}, base, {
                loader,
                triggerSource: "notifications",
                setTriggerScreen: true
            }));
        case "battery":
        case "layout":
        case "vpn":
            {
                const triggerSources = {
                    battery: "battery",
                    layout: "layout",
                    vpn: "vpn"
                };
                return barContent.openWidgetPopout(Object.assign({}, base, {
                    loader,
                    triggerSource: triggerSources[widgetId]
                }));
            }
        case "controlCenterButton":
            if (barContent.openWidgetPopout(Object.assign({}, base, {
                loader,
                triggerSource: "controlCenter",
                setTriggerScreen: true
            }))) {
                if (loader.item?.shouldBeVisible && NetworkService.wifiEnabled)
                    NetworkService.scanWifi();
                return true;
            }
            return false;
        case "systemUpdate":
            return barContent.openWidgetPopout(Object.assign({}, base, {
                loader,
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

        if (isActiveHoverSurfacePinned())
            return;

        const hit = findWidgetAtGlobalPoint(gx, gy);
        if (!hit) {
            _cancelPendingHover();
            scheduleHoverClose(gx, gy);
            return;
        }

        hit.globalX = gx;
        hit.globalY = gy;

        let triggerKey = hit.widgetId;
        if (hit.widgetId === "systemTray")
            triggerKey = hit.widgetItem.hoverTriggerAtGlobalPoint?.(gx, gy) || "";
        else if (hit.widgetId === "clock")
            triggerKey = dashTriggerSource(hit.section, 0);
        else if (hit.widgetId === "music")
            triggerKey = dashTriggerSource(hit.section, 1);
        else if (hit.widgetId === "weather")
            triggerKey = dashTriggerSource(hit.section, 3);

        if (!triggerKey) {
            _cancelPendingHover();
            scheduleHoverClose(gx, gy);
            return;
        }

        _hoverCloseTimer.stop();

        if (triggerKey === activeHoverTrigger && hasOpenHoverSurface()) {
            _cancelPendingHover();
            return;
        }

        _pendingHoverHit = hit;
        if (_pendingHoverTrigger !== triggerKey) {
            _pendingHoverTrigger = triggerKey;
            if (hoverPopoutDelay <= 0)
                _commitPendingHover();
            else
                _hoverIntentTimer.restart();
        }
    }

    function _cancelPendingHover() {
        _hoverIntentTimer.stop();
        _pendingHoverHit = null;
        _pendingHoverTrigger = "";
    }

    function _hitTargetsActivePopout(hit) {
        const active = PopoutManager.getActivePopout(barWindow?.screen);
        if (!active || !hit)
            return false;
        const loader = _loaderForWidgetId(hit.widgetId);
        if (!loader)
            return false;
        return barContent._resolvePopoutFromLoader(loader) === active;
    }

    function _commitPendingHover() {
        const hit = _pendingHoverHit;
        const triggerKey = _pendingHoverTrigger;
        _pendingHoverHit = null;
        _pendingHoverTrigger = "";
        if (!hit || !hoverPopoutsEnabled)
            return;
        if (isActiveHoverSurfacePinned())
            return;
        if (!PopoutManager.cursorOverBar(_lastHoverGlobalX, _lastHoverGlobalY))
            return;

        const activePopout = PopoutManager.getActivePopout(barWindow?.screen);
        const targetLoader = _loaderForWidgetId(hit.widgetId);
        const targetPopout = barContent._resolvePopoutFromLoader(targetLoader);
        const managerOwnsTransition = !!(activePopout && targetPopout);

        if (triggerKey !== activeHoverTrigger && activeHoverTrigger !== "" && !_hitTargetsActivePopout(hit)) {
            if (!managerOwnsTransition) {
                _beginSupersededCloseForActive();
                closeHoverSurfaces();
            }
        }

        if (!openHoverPopoutForHit(hit)) {
            if (activeHoverTrigger !== "")
                closeHoverSurfaces();
            return;
        }

        activeHoverTrigger = triggerKey;
    }

    function scheduleHoverClose(gx, gy) {
        cancelQueuedHitTest();
        _cancelPendingHover();
        _barExitPending = false;
        if (!hoverPopoutsEnabled)
            return;
        if (isActiveHoverSurfacePinned())
            return;
        if (cursorOverHoverChain(gx, gy))
            return;
        _hoverCloseTimer.restart();
    }

    function _commitHoverClose() {
        const gx = PopoutManager.hoverCursorGlobalX;
        const gy = PopoutManager.hoverCursorGlobalY;
        if (isActiveHoverSurfacePinned())
            return;
        if (_barHovered)
            return;
        const excludedBar = _barExitPending ? barWindow : null;
        if (cursorOverHoverChain(gx, gy, excludedBar))
            return;
        _barExitPending = false;
        closeHoverSurfaces();
    }
}
