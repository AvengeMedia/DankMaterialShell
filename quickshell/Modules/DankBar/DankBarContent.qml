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
    readonly property bool _barIsVertical: _hasBarWindow ? barWindow.isVertical : false
    readonly property string _barScreenName: _hasBarWindow ? (barWindow.screenName || "") : ""
    readonly property bool hasAdjacentTopBarLive: _hasBarWindow && barWindow.hasAdjacentTopBar
    readonly property bool hasAdjacentBottomBarLive: _hasBarWindow && barWindow.hasAdjacentBottomBar
    readonly property bool hasAdjacentLeftBarLive: _hasBarWindow && barWindow.hasAdjacentLeftBar
    readonly property bool hasAdjacentRightBarLive: _hasBarWindow && barWindow.hasAdjacentRightBar

    // Standalone/separate Bar Inset Padding (per-bar, optionally synced): absolute gap at BOTH ends.
    // Stored value < 0 (default -1) means "auto" — fall back to the natural edge margin so the look is unchanged.
    readonly property real _barInsetPaddingRaw: SettingsData.barInsetPaddingSyncAll ? SettingsData.barInsetPaddingShared : (barConfig?.barInsetPadding ?? -1)
    readonly property real _barInsetPaddingAuto: _barIsVertical ? Theme.spacingXS : _edgeBaseMargin
    readonly property real _barInsetPadding: _barInsetPaddingRaw < 0 ? _barInsetPaddingAuto : _barInsetPaddingRaw
    // Connected-frame Bar Inset Padding: absolute free-end inset (auto < 0 = frameThickness, 0 = edge-to-edge).
    // Any amount beyond the frameThickness baseline is also added at the bar-clearance ends (all ends).
    readonly property real _frameInsetResolved: SettingsData.frameBarInsetPadding < 0 ? SettingsData.frameThickness : SettingsData.frameBarInsetPadding
    readonly property real _frameInsetExtra: Math.max(0, _frameInsetResolved - SettingsData.frameThickness)

    readonly property real _leftMargin: {
        if (_barIsVertical)
            return _edgeBaseMargin;
        if (_usesFrameBarChrome)
            return hasAdjacentLeftBarLive ? (_edgeBaseMargin + SettingsData.frameBarSize + _frameInsetExtra) : Math.max(0, _frameInsetResolved);
        return Math.max(0, _barInsetPadding);
    }
    readonly property real _rightMargin: {
        if (_barIsVertical)
            return _edgeBaseMargin;
        if (_usesFrameBarChrome)
            return hasAdjacentRightBarLive ? (_edgeBaseMargin + SettingsData.frameBarSize + _frameInsetExtra) : Math.max(0, _frameInsetResolved);
        return Math.max(0, _barInsetPadding);
    }
    readonly property real _topMargin: {
        if (!_barIsVertical)
            return 0;
        if (_usesFrameBarChrome)
            return hasAdjacentTopBarLive ? (outlineThickness + SettingsData.frameThickness + _frameInsetExtra) : Math.max(0, _frameInsetResolved);
        return Math.max(0, _barInsetPadding);
    }
    readonly property real _bottomMargin: {
        if (!_barIsVertical)
            return 0;
        if (_usesFrameBarChrome)
            return hasAdjacentBottomBarLive ? (outlineThickness + SettingsData.frameThickness + _frameInsetExtra) : Math.max(0, _frameInsetResolved);
        return Math.max(0, _barInsetPadding);
    }

    property alias hLeftSection: hLeftSection
    property alias hCenterSection: hCenterSection
    property alias hRightSection: hRightSection
    property alias vLeftSection: vLeftSection
    property alias vCenterSection: vCenterSection
    property alias vRightSection: vRightSection

    anchors.fill: parent
    anchors.leftMargin: _leftMargin
    anchors.rightMargin: _rightMargin
    anchors.topMargin: _topMargin
    anchors.bottomMargin: _bottomMargin
    clip: false

    DeferredAction {
        id: enableFrameInsetAnimation
        onTriggered: topBarContent._animateFrameInsets = true
    }

    Component.onCompleted: {
        enableFrameInsetAnimation.schedule();
    }

    Connections {
        target: topBarContent._hasBarWindow ? topBarContent.barWindow.axis : null

        function onEdgeChanged() {
            topBarContent.resetHoverForBarGeometryChange();
        }
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

    DankBarHoverController {
        id: hoverController
        barContent: topBarContent
        barWindow: topBarContent.barWindow
        barConfig: topBarContent.barConfig
        hLeftSection: topBarContent.hLeftSection
        hCenterSection: topBarContent.hCenterSection
        hRightSection: topBarContent.hRightSection
        vLeftSection: topBarContent.vLeftSection
        vCenterSection: topBarContent.vCenterSection
        vRightSection: topBarContent.vRightSection
        leftWidgetsModel: topBarContent.leftWidgetsModel
        centerWidgetsModel: topBarContent.centerWidgetsModel
        rightWidgetsModel: topBarContent.rightWidgetsModel
    }

    readonly property string activeHoverTrigger: hoverController.activeHoverTrigger
    readonly property bool hoverPopoutsEnabled: hoverController.hoverPopoutsEnabled

    function queueHoverPopout(gx, gy) {
        hoverController.queueHoverPoint(gx, gy);
    }

    function checkHoverPopout(gx, gy) {
        hoverController.checkHoverPopout(gx, gy);
    }

    function findWidgetAtGlobalPoint(gx, gy) {
        return hoverController.findWidgetAtGlobalPoint(gx, gy);
    }

    function scheduleHoverClose(gx, gy) {
        hoverController.scheduleHoverClose(gx, gy);
    }

    function updateHoverBarHovered(hovered) {
        hoverController.updateBarHovered(hovered);
    }

    function resetHoverForBarGeometryChange() {
        hoverController.resetForBarGeometryChange();
    }

    function _dashTriggerSource(section, tabIndex) {
        return hoverController.dashTriggerSource(section, tabIndex);
    }

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

        const pairs = [[PopoutService.appDrawerLoader, PopoutService.appDrawerPopout], [PopoutService.batteryPopoutLoader, PopoutService.batteryPopout], [PopoutService.clipboardHistoryPopoutLoader, PopoutService.clipboardHistoryPopout], [PopoutService.controlCenterLoader, PopoutService.controlCenterPopout], [PopoutService.dankDashPopoutLoader, PopoutService.dankDashPopout], [PopoutService.layoutPopoutLoader, PopoutService.layoutPopout], [PopoutService.notificationCenterLoader, PopoutService.notificationCenterPopout], [PopoutService.processListPopoutLoader, PopoutService.processListPopout], [PopoutService.systemUpdateLoader, PopoutService.systemUpdatePopout], [PopoutService.vpnPopoutLoader, PopoutService.vpnPopout]];
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
                hoverController.recheckLatestPoint();
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

        if (typeof popout.prepareForTrigger === "function")
            popout.prepareForTrigger(spec.triggerSource, mode);

        if (spec.prepare)
            spec.prepare(popout);

        const request = mode === "hover" ? PopoutManager.requestHoverPopout : PopoutManager.requestPopout;
        request(popout, spec.tabIndex, spec.triggerSource);
        return true;
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
                sectionAvailablePrimarySize: Math.max(1, hCenterSection.x > 0 ? hCenterSection.x : parent.width / 3)
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
                sectionAvailablePrimarySize: Math.max(1, hCenterSection.x > 0 ? parent.width - (hCenterSection.x + hCenterSection.width) : parent.width / 3)
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
                sectionAvailablePrimarySize: Math.max(1, hRightSection.x > 0 ? hRightSection.x - (hLeftSection.x + hLeftSection.width) : parent.width / 3)
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
                sectionAvailablePrimarySize: Math.max(1, vCenterSection.y > 0 ? vCenterSection.y : parent.height / 3)
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
                sectionAvailablePrimarySize: Math.max(1, vRightSection.y > 0 ? vRightSection.y - (vLeftSection.y + vLeftSection.height) : parent.height / 3)
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
                sectionAvailablePrimarySize: Math.max(1, vCenterSection.y > 0 ? parent.height - (vCenterSection.y + vCenterSection.height) : parent.height / 3)
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
                border.color: Theme.outlineStrong
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
