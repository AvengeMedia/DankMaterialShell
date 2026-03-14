import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: widgetData?.focusedWindowCompactMode !== undefined ? widgetData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode
    property int availableWidth: 400
    readonly property int maxNormalWidth: 456
    readonly property int maxCompactWidth: 288
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property Toplevel monitorActiveWindow: null
    property var activeDesktopEntry: null
    property bool isHovered: mouseArea.containsMouse
    property bool isAutoHideBar: false

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            return barThickness + (barSpacing || 4);
        }

        return 0;
    }

    Component.onCompleted: {
        updateDesktopEntry();
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.updateDesktopEntry();
        }
    }

    Connections {
        target: root
        function onActiveWindowChanged() {
            if (!activeWindow) {
                monitorActiveWindow = null;
            } else if (parentScreen && activeWindow.screens.length > 0 && activeWindow.screens[0].name === parentScreen.name) {
                monitorActiveWindow = activeWindow;
            }
        }
    }

    Connections {
        target: root
        function onMonitorActiveWindowChanged() {
            root.updateDesktopEntry();
        }
    }

    Connections {
        target: NiriService
        function onAllWorkspacesChanged() {
            root.validateMonitorActiveWindow();
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.validateMonitorActiveWindow();
        }
    }

    Connections {
        target: SettingsData
        function onAppIdSubstitutionsChanged() {
            root.updateDesktopEntry();
        }
    }

    function validateMonitorActiveWindow() {
        if (!monitorActiveWindow || !parentScreen)
            return;

        if (CompositorService.isNiri) {
            let currentWorkspaceId = null;
            for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
                const ws = NiriService.allWorkspaces[i];
                if (ws.output === parentScreen.name && ws.is_active) {
                    currentWorkspaceId = ws.id;
                    break;
                }
            }

            if (!currentWorkspaceId) {
                monitorActiveWindow = null;
                return;
            }

            const workspaceWindows = NiriService.windows.filter(w => w.workspace_id === currentWorkspaceId);
            if (workspaceWindows.length === 0) {
                monitorActiveWindow = null;
            }
        } else if (CompositorService.isHyprland) {
            if (!Hyprland.monitors || !Hyprland.toplevels)
                return;
            const monitor = Hyprland.monitors.values.find(m => m.name === parentScreen.name);
            if (!monitor || !monitor.activeWorkspace)
                return;
            const hyprlandToplevels = Array.from(Hyprland.toplevels.values);
            const toplevel = hyprlandToplevels.find(t => t?.wayland === monitorActiveWindow);
            if (!toplevel || !toplevel.workspace || toplevel.workspace.id !== monitor.activeWorkspace.id) {
                monitorActiveWindow = null;
            }
        }
    }

    function updateDesktopEntry() {
        if (monitorActiveWindow && monitorActiveWindow.appId) {
            const moddedId = Paths.moddedAppId(monitorActiveWindow.appId);
            activeDesktopEntry = DesktopEntries.heuristicLookup(moddedId);
        } else {
            activeDesktopEntry = null;
        }
    }
    readonly property bool hasWindowsOnCurrentWorkspace: {
        if (CompositorService.isNiri) {
            if (!parentScreen)
                return false;

            let currentWorkspaceId = null;
            for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
                const ws = NiriService.allWorkspaces[i];
                if (ws.output === parentScreen.name && ws.is_active) {
                    currentWorkspaceId = ws.id;
                    break;
                }
            }

            if (!currentWorkspaceId) {
                return false;
            }

            const workspaceWindows = NiriService.windows.filter(w => w.workspace_id === currentWorkspaceId);
            return workspaceWindows.length > 0 && monitorActiveWindow && monitorActiveWindow.title;
        }

        if (CompositorService.isHyprland) {
            if (!monitorActiveWindow || !monitorActiveWindow.title || !parentScreen) {
                return false;
            }

            try {
                if (!Hyprland.toplevels || !Hyprland.monitors)
                    return false;

                const monitor = Hyprland.monitors.values.find(m => m.name === parentScreen.name);
                if (!monitor || !monitor.activeWorkspace)
                    return false;

                const hyprlandToplevels = Array.from(Hyprland.toplevels.values);
                const activeHyprToplevel = hyprlandToplevels.find(t => t?.wayland === monitorActiveWindow);

                if (!activeHyprToplevel || !activeHyprToplevel.workspace) {
                    return false;
                }

                return activeHyprToplevel.workspace.id === monitor.activeWorkspace.id;
            } catch (e) {
                return false;
            }
        }

        return monitorActiveWindow && monitorActiveWindow.title;
    }

    width: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? barThickness : visualWidth) : 0
    height: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? visualHeight : barThickness) : 0
    visible: hasWindowsOnCurrentWorkspace

    content: Component {
        Item {
            implicitWidth: {
                if (!root.hasWindowsOnCurrentWorkspace)
                    return 0;
                if (root.isVerticalOrientation)
                    return root.widgetThickness - root.horizontalPadding * 2;
                const baseWidth = contentRow.implicitWidth;
                return compactMode ? Math.min(baseWidth, maxCompactWidth - root.horizontalPadding * 2) : Math.min(baseWidth, maxNormalWidth - root.horizontalPadding * 2);
            }
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2
            clip: false

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.isVerticalOrientation && monitorActiveWindow && status === Image.Ready
                source: {
                    if (!monitorActiveWindow || !monitorActiveWindow.appId)
                        return "";
                    return Paths.getAppIcon(monitorActiveWindow.appId, activeDesktopEntry);
                }
                smooth: true
                mipmap: true
                asynchronous: true
                layer.enabled: monitorActiveWindow && monitorActiveWindow.appId === "org.quickshell"
                layer.smooth: true
                layer.mipmap: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: Theme.primary
                }
            }

            DankIcon {
                anchors.centerIn: parent
                size: 18
                name: "sports_esports"
                color: Theme.widgetTextColor
                visible: root.isVerticalOrientation && monitorActiveWindow && monitorActiveWindow.appId && appIcon.status !== Image.Ready && Paths.isSteamApp(monitorActiveWindow.appId)
            }

            Text {
                anchors.centerIn: parent
                visible: root.isVerticalOrientation && monitorActiveWindow && monitorActiveWindow.appId && appIcon.status !== Image.Ready && !Paths.isSteamApp(monitorActiveWindow.appId)
                text: {
                    if (!monitorActiveWindow || !monitorActiveWindow.appId)
                        return "?";
                    const appName = Paths.getAppName(monitorActiveWindow.appId, activeDesktopEntry);
                    return appName.charAt(0).toUpperCase();
                }
                font.pixelSize: 10
                color: Theme.widgetTextColor
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !root.isVerticalOrientation

                StyledText {
                    id: appText
                    text: {
                        if (!monitorActiveWindow || !monitorActiveWindow.appId)
                            return "";
                        return Paths.getAppName(monitorActiveWindow.appId, activeDesktopEntry);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, compactMode ? 80 : 180)
                    visible: !compactMode && text.length > 0
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !compactMode && appText.text && titleText.text
                }

                StyledText {
                    id: titleText
                    text: {
                        const title = monitorActiveWindow && monitorActiveWindow.title ? monitorActiveWindow.title : "";
                        const appName = appText.text;

                        if (compactMode && title === appName) {
                            return title;
                        }

                        if (!title || !appName) {
                            return title;
                        }

                        if (title.endsWith(appName)) {
                            return title.substring(0, title.length - appName.length).replace(/ (-|—) $/, "");
                        }

                        return title;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, compactMode ? 280 : 250)
                    visible: text.length > 0
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.isVerticalOrientation
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (root.isVerticalOrientation && monitorActiveWindow && monitorActiveWindow.appId && root.parentScreen) {
                tooltipLoader.active = true;
                if (tooltipLoader.item) {
                    const globalPos = mapToGlobal(width / 2, height / 2);
                    const currentScreen = root.parentScreen;
                    const screenX = currentScreen ? currentScreen.x : 0;
                    const screenY = currentScreen ? currentScreen.y : 0;
                    const relativeY = globalPos.y - screenY;
                    // Add minTooltipY offset to account for top bar
                    const adjustedY = relativeY + root.minTooltipY;
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS);

                    const appName = Paths.getAppName(monitorActiveWindow.appId, activeDesktopEntry);
                    const title = monitorActiveWindow.title || "";
                    const tooltipText = appName + (title ? " • " + title : "");

                    const isLeft = root.axis?.edge === "left";
                    tooltipLoader.item.show(tooltipText, screenX + tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }
}
