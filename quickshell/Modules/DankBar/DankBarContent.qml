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

    property var leftWidgetsModel
    property var centerWidgetsModel
    property var rightWidgetsModel

    readonly property real innerPadding: barConfig?.innerPadding ?? 4

    anchors.fill: parent
    anchors.leftMargin: Math.max(Theme.spacingXS, innerPadding * 0.8)
    anchors.rightMargin: Math.max(Theme.spacingXS, innerPadding * 0.8)
    anchors.topMargin: barWindow.isVertical ? (barWindow.hasAdjacentTopBar ? 0 : Theme.spacingXS) : 0
    anchors.bottomMargin: barWindow.isVertical ? (barWindow.hasAdjacentBottomBar ? 0 : Theme.spacingXS) : 0
    clip: false

    property int componentMapRevision: 0

    function updateComponentMap() {
        componentMapRevision++;
    }

    readonly property var sortedToplevels: {
        return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, barWindow.screenName);
    }

    function getRealWorkspaces() {
        if (CompositorService.isNiri) {
            if (!barWindow.screenName || !SettingsData.workspacesPerMonitor) {
                return NiriService.getCurrentOutputWorkspaceNumbers();
            }
            const workspaces = NiriService.allWorkspaces.filter(ws => ws.output === barWindow.screenName).map(ws => ws.idx + 1);
            return workspaces.length > 0 ? workspaces : [1, 2];
        } else if (CompositorService.isHyprland) {
            const workspaces = Hyprland.workspaces?.values || [];

            if (!barWindow.screenName || !SettingsData.workspacesPerMonitor) {
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
                return ws.lastIpcObject && ws.lastIpcObject.monitor === barWindow.screenName && ws.id > -1;
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
        } else if (CompositorService.isDwl) {
            if (!DwlService.dwlAvailable) {
                return [0];
            }
            if (SettingsData.dwlShowAllTags) {
                return Array.from({
                    length: DwlService.tagCount
                }, (_, i) => i);
            }
            return DwlService.getVisibleTags(barWindow.screenName);
        } else if (CompositorService.isSway) {
            const workspaces = I3.workspaces?.values || [];
            if (workspaces.length === 0)
                return [
                    {
                        "num": 1
                    }
                ];

            if (!barWindow.screenName || !SettingsData.workspacesPerMonitor) {
                return workspaces.slice().sort((a, b) => a.num - b.num);
            }

            const monitorWorkspaces = workspaces.filter(ws => ws.monitor?.name === barWindow.screenName);
            return monitorWorkspaces.length > 0 ? monitorWorkspaces.sort((a, b) => a.num - b.num) : [
                {
                    "num": 1
                }
            ];
        }
        return [1];
    }

    function getCurrentWorkspace() {
        if (CompositorService.isNiri) {
            if (!barWindow.screenName || !SettingsData.workspacesPerMonitor) {
                return NiriService.getCurrentWorkspaceNumber();
            }
            const activeWs = NiriService.allWorkspaces.find(ws => ws.output === barWindow.screenName && ws.is_active);
            return activeWs ? activeWs.idx + 1 : 1;
        } else if (CompositorService.isHyprland) {
            const monitors = Hyprland.monitors?.values || [];
            const currentMonitor = monitors.find(monitor => monitor.name === barWindow.screenName);
            return currentMonitor?.activeWorkspace?.id ?? 1;
        } else if (CompositorService.isDwl) {
            if (!DwlService.dwlAvailable)
                return 0;
            const outputState = DwlService.getOutputState(barWindow.screenName);
            if (!outputState || !outputState.tags)
                return 0;
            const activeTags = DwlService.getActiveTags(barWindow.screenName);
            return activeTags.length > 0 ? activeTags[0] : 0;
        } else if (CompositorService.isSway) {
            if (!barWindow.screenName || !SettingsData.workspacesPerMonitor) {
                const focusedWs = I3.workspaces?.values?.find(ws => ws.focused === true);
                return focusedWs ? focusedWs.num : 1;
            }

            const focusedWs = I3.workspaces?.values?.find(ws => ws.monitor?.name === barWindow.screenName && ws.focused === true);
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
            const currentIndex = realWorkspaces.findIndex(ws => ws === currentWs);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1);
            }
        } else if (CompositorService.isHyprland) {
            const currentWs = getCurrentWorkspace();
            const currentIndex = realWorkspaces.findIndex(ws => ws.id === currentWs);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                Hyprland.dispatch(`workspace ${realWorkspaces[nextIndex].id}`);
            }
        } else if (CompositorService.isDwl) {
            const currentTag = getCurrentWorkspace();
            const currentIndex = realWorkspaces.findIndex(tag => tag === currentTag);
            const validIndex = currentIndex === -1 ? 0 : currentIndex;
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0);

            if (nextIndex !== validIndex) {
                DwlService.switchToTag(barWindow.screenName, realWorkspaces[nextIndex]);
            }
        } else if (CompositorService.isSway) {
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
    readonly property bool spacingTight: !barWindow.isVertical && validLayout && (leftToMediaGap < 150 || clockToRightGap < 100)
    readonly property bool overlapping: !barWindow.isVertical && validLayout && (leftToMediaGap < 100 || clockToRightGap < 50)

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
        }
    }

    Component {
        id: clipboardComponent

        ClipboardButton {
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent)
            parentScreen: barWindow.screen
            onClicked: {
                clipboardHistoryModalPopup.toggle()
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
                    powerMenuModalLoader.active = true
                    if (powerMenuModalLoader.item) {
                        powerMenuModalLoader.item.openCentered()
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
            onClicked: {
                appDrawerLoader.active = true;
                // Use topBarContent.barConfig directly since widget barConfig binding doesn't work in Components
                const effectiveBarConfig = topBarContent.barConfig;
                // Calculate barPosition from axis.edge
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (appDrawerLoader.item && appDrawerLoader.item.setBarContext) {
                    appDrawerLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (appDrawerLoader.item && appDrawerLoader.item.setTriggerPosition) {
                    const globalPos = launcherButton.visualContent.mapToGlobal(0, 0);
                    const currentScreen = barWindow.screen;
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barWindow.effectiveBarThickness, launcherButton.visualWidth, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    appDrawerLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, launcherButton.section, currentScreen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                if (appDrawerLoader.item) {
                    PopoutManager.requestPopout(appDrawerLoader.item, undefined, "appDrawer");
                }
            }
        }
    }

    Component {
        id: workspaceSwitcherComponent

        WorkspaceSwitcher {
            axis: barWindow.axis
            screenName: barWindow.screenName
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
        id: clockComponent

        Clock {
            axis: barWindow.axis
            compactMode: topBarContent.overlapping
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: {
                dankDashPopoutLoader.active = true;
                return dankDashPopoutLoader.item;
            }
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
                dankDashPopoutLoader.active = true;
                if (dankDashPopoutLoader.item) {
                    const effectiveBarConfig = topBarContent.barConfig;
                    const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                    if (dankDashPopoutLoader.item.setBarContext) {
                        dankDashPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                    }
                    if (dankDashPopoutLoader.item.setTriggerPosition) {
                        let triggerPos, triggerWidth;
                        if (section === "center") {
                            const centerSection = barWindow.isVertical ? (barWindow.axis?.edge === "left" ? vCenterSection : vCenterSection) : hCenterSection;
                            if (centerSection) {
                                if (barWindow.isVertical) {
                                    const centerY = centerSection.height / 2;
                                    const centerGlobalPos = centerSection.mapToGlobal(0, centerY);
                                    triggerPos = centerGlobalPos;
                                    triggerWidth = centerSection.height;
                                } else {
                                    const centerGlobalPos = centerSection.mapToGlobal(0, 0);
                                    triggerPos = centerGlobalPos;
                                    triggerWidth = centerSection.width;
                                }
                            } else {
                                triggerPos = visualContent.mapToGlobal(0, 0);
                                triggerWidth = visualWidth;
                            }
                        } else {
                            triggerPos = visualContent.mapToGlobal(0, 0);
                            triggerWidth = visualWidth;
                        }
                        const pos = SettingsData.getPopupTriggerPosition(triggerPos, barWindow.screen, barWindow.effectiveBarThickness, triggerWidth, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                        dankDashPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                    } else {
                        dankDashPopoutLoader.item.triggerScreen = barWindow.screen;
                    }
                    PopoutManager.requestPopout(dankDashPopoutLoader.item, 0, (effectiveBarConfig?.id ?? "default") + "-0");
                }
            }
        }
    }

    Component {
        id: mediaComponent

        Media {
            axis: barWindow.axis
            compactMode: topBarContent.spacingTight || topBarContent.overlapping
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: {
                dankDashPopoutLoader.active = true;
                return dankDashPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            onClicked: {
                dankDashPopoutLoader.active = true;
                if (dankDashPopoutLoader.item) {
                    const effectiveBarConfig = topBarContent.barConfig;
                    const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                    if (dankDashPopoutLoader.item.setBarContext) {
                        dankDashPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                    }
                    if (dankDashPopoutLoader.item.setTriggerPosition) {
                        let triggerPos, triggerWidth;
                        if (section === "center") {
                            const centerSection = barWindow.isVertical ? (barWindow.axis?.edge === "left" ? vCenterSection : vCenterSection) : hCenterSection;
                            if (centerSection) {
                                if (barWindow.isVertical) {
                                    const centerY = centerSection.height / 2;
                                    const centerGlobalPos = centerSection.mapToGlobal(0, centerY);
                                    triggerPos = centerGlobalPos;
                                    triggerWidth = centerSection.height;
                                } else {
                                    const centerGlobalPos = centerSection.mapToGlobal(0, 0);
                                    triggerPos = centerGlobalPos;
                                    triggerWidth = centerSection.width;
                                }
                            } else {
                                triggerPos = visualContent.mapToGlobal(0, 0);
                                triggerWidth = visualWidth;
                            }
                        } else {
                            triggerPos = visualContent.mapToGlobal(0, 0);
                            triggerWidth = visualWidth;
                        }
                        const pos = SettingsData.getPopupTriggerPosition(triggerPos, barWindow.screen, barWindow.effectiveBarThickness, triggerWidth, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                        dankDashPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                    } else {
                        dankDashPopoutLoader.item.triggerScreen = barWindow.screen;
                    }
                    PopoutManager.requestPopout(dankDashPopoutLoader.item, 1, (effectiveBarConfig?.id ?? "default") + "-1");
                }
            }
        }
    }

    Component {
        id: weatherComponent

        Weather {
            axis: barWindow.axis
            barThickness: barWindow.effectiveBarThickness
            widgetThickness: barWindow.widgetThickness
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: {
                dankDashPopoutLoader.active = true;
                return dankDashPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            onClicked: {
                dankDashPopoutLoader.active = true;
                if (dankDashPopoutLoader.item) {
                    const effectiveBarConfig = topBarContent.barConfig;
                    // Calculate barPosition from axis.edge
                    const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                    if (dankDashPopoutLoader.item.setBarContext) {
                        dankDashPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                    }
                    if (dankDashPopoutLoader.item.setTriggerPosition) {
                        // For center section widgets, use center section bounds for DankDash centering
                        let triggerPos, triggerWidth;
                        if (section === "center") {
                            const centerSection = barWindow.isVertical ? (barWindow.axis?.edge === "left" ? vCenterSection : vCenterSection) : hCenterSection;
                            if (centerSection) {
                                // For vertical bars, use center Y of section; for horizontal, use left edge
                                if (barWindow.isVertical) {
                                    const centerY = centerSection.height / 2;
                                    const centerGlobalPos = centerSection.mapToGlobal(0, centerY);
                                    triggerPos = centerGlobalPos;
                                    triggerWidth = centerSection.height;
                                } else {
                                    // For horizontal bars, use left edge (DankPopout will center it)
                                    const centerGlobalPos = centerSection.mapToGlobal(0, 0);
                                    triggerPos = centerGlobalPos;
                                    triggerWidth = centerSection.width;
                                }
                            } else {
                                triggerPos = visualContent.mapToGlobal(0, 0);
                                triggerWidth = visualWidth;
                            }
                        } else {
                            triggerPos = visualContent.mapToGlobal(0, 0);
                            triggerWidth = visualWidth;
                        }
                        const pos = SettingsData.getPopupTriggerPosition(triggerPos, barWindow.screen, barWindow.effectiveBarThickness, triggerWidth, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                        dankDashPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                    } else {
                        dankDashPopoutLoader.item.triggerScreen = barWindow.screen;
                    }
                    PopoutManager.requestPopout(dankDashPopoutLoader.item, 3, (effectiveBarConfig?.id ?? "default") + "-3");
                }
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
            popoutTarget: {
                processListPopoutLoader.active = true;
                return processListPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onCpuClicked: {
                processListPopoutLoader.active = true;
                if (!processListPopoutLoader.item) {
                    return;
                }
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (processListPopoutLoader.item.setBarContext) {
                    processListPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (processListPopoutLoader.item.setTriggerPosition) {
                    const globalPos = cpuWidget.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, cpuWidget.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    processListPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(processListPopoutLoader.item, undefined, "cpu");
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
            popoutTarget: {
                processListPopoutLoader.active = true;
                return processListPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onRamClicked: {
                processListPopoutLoader.active = true;
                if (!processListPopoutLoader.item) {
                    return;
                }
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (processListPopoutLoader.item.setBarContext) {
                    processListPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (processListPopoutLoader.item.setTriggerPosition) {
                    const globalPos = ramWidget.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, ramWidget.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    processListPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(processListPopoutLoader.item, undefined, "memory");
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
            popoutTarget: {
                processListPopoutLoader.active = true;
                return processListPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onCpuTempClicked: {
                processListPopoutLoader.active = true;
                if (!processListPopoutLoader.item) {
                    return;
                }
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (processListPopoutLoader.item.setBarContext) {
                    processListPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (processListPopoutLoader.item.setTriggerPosition) {
                    const globalPos = cpuTempWidget.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, cpuTempWidget.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    processListPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(processListPopoutLoader.item, undefined, "cpu_temp");
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
            popoutTarget: {
                processListPopoutLoader.active = true;
                return processListPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            widgetData: parent.widgetData
            onGpuTempClicked: {
                processListPopoutLoader.active = true;
                if (!processListPopoutLoader.item) {
                    return;
                }
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (processListPopoutLoader.item.setBarContext) {
                    processListPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (processListPopoutLoader.item.setTriggerPosition) {
                    const globalPos = gpuTempWidget.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, gpuTempWidget.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    processListPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(processListPopoutLoader.item, undefined, "gpu_temp");
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
            popoutTarget: {
                notificationCenterLoader.active = true;
                return notificationCenterLoader.item;
            }
            parentScreen: barWindow.screen
            onClicked: {
                notificationCenterLoader.active = true;
                if (!notificationCenterLoader.item) {
                    return;
                }
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (notificationCenterLoader.item.setBarContext) {
                    notificationCenterLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (notificationCenterLoader.item.setTriggerPosition) {
                    const globalPos = notificationButton.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, notificationButton.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    notificationCenterLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(notificationCenterLoader.item, undefined, "notifications");
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
            popoutTarget: {
                batteryPopoutLoader.active = true;
                return batteryPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            onToggleBatteryPopup: {
                batteryPopoutLoader.active = true;
                if (!batteryPopoutLoader.item) {
                    return;
                }
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (batteryPopoutLoader.item.setBarContext) {
                    batteryPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (batteryPopoutLoader.item.setTriggerPosition) {
                    const globalPos = batteryWidget.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, batteryWidget.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    batteryPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(batteryPopoutLoader.item, undefined, "battery");
            }
        }
    }

    Component {
        id: layoutComponent

        DWLLayout {
            layoutPopupVisible: layoutPopoutLoader.item ? layoutPopoutLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "center"
            popoutTarget: {
                layoutPopoutLoader.active = true;
                return layoutPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            onToggleLayoutPopup: {
                layoutPopoutLoader.active = true;
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (layoutPopoutLoader.item && layoutPopoutLoader.item.setBarContext) {
                    layoutPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                if (layoutPopoutLoader.item) {
                    PopoutManager.requestPopout(layoutPopoutLoader.item, undefined, "layout");
                }
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
            popoutTarget: {
                vpnPopoutLoader.active = true;
                return vpnPopoutLoader.item;
            }
            parentScreen: barWindow.screen
            onToggleVpnPopup: {
                vpnPopoutLoader.active = true;
                if (!vpnPopoutLoader.item)
                    return;
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));

                if (vpnPopoutLoader.item.setBarContext) {
                    vpnPopoutLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }

                if (vpnPopoutLoader.item.setTriggerPosition) {
                    const globalPos = vpnWidget.mapToGlobal(0, 0);
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, vpnWidget.width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const widgetSection = topBarContent.getWidgetSection(parent) || "right";
                    vpnPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, widgetSection, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }

                PopoutManager.requestPopout(vpnPopoutLoader.item, undefined, "vpn");
            }
        }
    }

    Component {
        id: controlCenterButtonComponent

        ControlCenterButton {
            isActive: controlCenterLoader.item ? controlCenterLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: {
                controlCenterLoader.active = true;
                return controlCenterLoader.item;
            }
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
                controlCenterLoader.active = true;
                if (!controlCenterLoader.item) {
                    return;
                }
                controlCenterLoader.item.triggerScreen = barWindow.screen;
                if (controlCenterLoader.item.setTriggerPosition) {
                    const globalPos = mapToGlobal(0, 0);
                    // Use topBarContent.barConfig directly
                    const effectiveBarConfig = topBarContent.barConfig;
                    // Calculate barPosition from axis.edge like Battery widget does
                    const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, width, effectiveBarConfig?.spacing ?? 4, barPosition, effectiveBarConfig);
                    const section = topBarContent.getWidgetSection(parent) || "right";
                    controlCenterLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, effectiveBarConfig?.spacing ?? 4, effectiveBarConfig);
                }
                PopoutManager.requestPopout(controlCenterLoader.item, undefined, "controlCenter");
                if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
                    NetworkService.scanWifi();
                }
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
            width: barWindow.isVertical ? barWindow.widgetThickness : (parent.spacerSize || 20)
            height: barWindow.isVertical ? (parent.spacerSize || 20) : barWindow.widgetThickness
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
            width: barWindow.isVertical ? parent.barThickness : 1
            height: barWindow.isVertical ? 1 : parent.barThickness
            implicitWidth: width
            implicitHeight: height

            Rectangle {
                width: barWindow.isVertical ? parent.width * 0.6 : 1
                height: barWindow.isVertical ? 1 : parent.height * 0.6
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
            isActive: systemUpdateLoader.item ? systemUpdateLoader.item.shouldBeVisible : false
            widgetThickness: barWindow.widgetThickness
            barThickness: barWindow.effectiveBarThickness
            axis: barWindow.axis
            section: topBarContent.getWidgetSection(parent) || "right"
            popoutTarget: {
                systemUpdateLoader.active = true;
                return systemUpdateLoader.item;
            }
            parentScreen: barWindow.screen
            onClicked: {
                systemUpdateLoader.active = true;
                const effectiveBarConfig = topBarContent.barConfig;
                const barPosition = barWindow.axis?.edge === "left" ? 2 : (barWindow.axis?.edge === "right" ? 3 : (barWindow.axis?.edge === "top" ? 0 : 1));
                if (systemUpdateLoader.item && systemUpdateLoader.item.setBarContext) {
                    systemUpdateLoader.item.setBarContext(barPosition, effectiveBarConfig?.bottomGap ?? 0);
                }
                systemUpdateLoader.item?.toggle();
            }
        }
    }
}
