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
    property Toplevel activeWindow: null
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

    function updateActiveWindow() {
        const active = ToplevelManager.activeToplevel;

        if (!active) {
            if (activeWindow) {
                if (CompositorService.isNiri) {
                    if (NiriService.currentOutput === (parentScreen?.name ?? ""))
                        activeWindow = null;
                } else {
                    const alive = ToplevelManager.toplevels?.values;
                    if (alive && !Array.from(alive).some(t => t === activeWindow))
                        activeWindow = null;
                }
            }
            return;
        }

        if (!parentScreen || CompositorService.filterCurrentDisplay([active], parentScreen?.name)?.length > 0) {
            activeWindow = active;
        } else if (activeWindow) {
            const alive = ToplevelManager.toplevels?.values;
            if (alive && !Array.from(alive).some(t => t === activeWindow))
                activeWindow = null;
        }
    }

    Component.onCompleted: {
        updateActiveWindow();
        updateDesktopEntry();
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (!CompositorService.isNiri)
                root.updateActiveWindow();
        }
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            root.updateActiveWindow();
        }
    }

    Connections {
        target: CompositorService.isNiri ? NiriService : null
        function onWindowsChanged() {
            root.updateActiveWindow();
        }
        function onCurrentOutputChanged() {
            root.updateActiveWindow();
        }
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
            root.updateDesktopEntry();
        }
    }

    Connections {
        target: SettingsData
        function onAppIdSubstitutionsChanged() {
            root.updateDesktopEntry();
        }
    }

    function updateDesktopEntry() {
        if (activeWindow && activeWindow.appId) {
            const moddedId = Paths.moddedAppId(activeWindow.appId);
            activeDesktopEntry = DesktopEntries.heuristicLookup(moddedId);
        } else {
            activeDesktopEntry = null;
        }
    }
    readonly property bool hasWindowsOnCurrentWorkspace: {
        if (CompositorService.isNiri) {
            if (!activeWindow || !(activeWindow.title || activeWindow.appId))
                return false;
            if (NiriService.currentOutput !== (parentScreen?.name ?? ""))
                return true;
            const focusedWin = NiriService.windows.find(w => w.is_focused);
            if (!focusedWin)
                return false;
            const screenWsIds = new Set(
                NiriService.allWorkspaces.filter(ws => ws.output === parentScreen.name).map(ws => ws.id)
            );
            return screenWsIds.has(focusedWin.workspace_id);
        }

        if (CompositorService.isHyprland) {
            if (!Hyprland.focusedWorkspace || !activeWindow || !(activeWindow.title || activeWindow.appId)) {
                return false;
            }

            try {
                if (!Hyprland.toplevels)
                    return false;
                const hyprlandToplevels = Array.from(Hyprland.toplevels.values);
                const activeHyprToplevel = hyprlandToplevels.find(t => t?.wayland === activeWindow);

                if (!activeHyprToplevel || !activeHyprToplevel.workspace) {
                    return false;
                }

                return activeHyprToplevel.workspace.id === Hyprland.focusedWorkspace.id;
            } catch (e) {
                return false;
            }
        }

        return activeWindow && (activeWindow.title || activeWindow.appId);
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
                visible: root.isVerticalOrientation && activeWindow && status === Image.Ready
                source: {
                    if (!activeWindow || !activeWindow.appId)
                        return "";
                    return Paths.getAppIcon(activeWindow.appId, activeDesktopEntry);
                }
                smooth: true
                mipmap: true
                asynchronous: true
                layer.enabled: activeWindow && (activeWindow.appId === "org.quickshell" || activeWindow.appId === "com.danklinux.dms")
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
                visible: root.isVerticalOrientation && activeWindow && activeWindow.appId && appIcon.status !== Image.Ready && Paths.isSteamApp(activeWindow.appId)
            }

            Text {
                anchors.centerIn: parent
                visible: root.isVerticalOrientation && activeWindow && activeWindow.appId && appIcon.status !== Image.Ready && !Paths.isSteamApp(activeWindow.appId)
                text: {
                    if (!activeWindow || !activeWindow.appId)
                        return "?";
                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
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
                        if (!activeWindow || !activeWindow.appId)
                            return "";
                        return Paths.getAppName(activeWindow.appId, activeDesktopEntry);
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
                        const title = activeWindow && activeWindow.title ? activeWindow.title : "";
                        const appName = appText.text;

                        if (compactMode) {
                            if (!title || title === appName)
                                return title || appName;
                            if (title.endsWith(appName))
                                return title.substring(0, title.length - appName.length).replace(/ (-|—) $/, "") || appName;
                            return title;
                        }

                        if (!title || !appName)
                            return title;

                        if (title.endsWith(appName))
                            return title.substring(0, title.length - appName.length).replace(/ (-|—) $/, "");

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
            if (root.isVerticalOrientation && activeWindow && activeWindow.appId && root.parentScreen) {
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

                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    const title = activeWindow.title || "";
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
