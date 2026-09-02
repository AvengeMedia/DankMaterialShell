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
    property bool showIcon: widgetData?.focusedWindowShowIcon !== undefined ? widgetData.focusedWindowShowIcon : SettingsData.focusedWindowShowIcon
    readonly property int maxWidth: {
        const size = widgetData?.focusedWindowSize !== undefined ? widgetData.focusedWindowSize : SettingsData.focusedWindowSize;
        switch (size) {
        case 0:
            return 288;
        case 2:
            return 656;
        case 3:
            return 856;
        default:
            return 456;
        }
    }
    property int availableWidth: maxWidth
    readonly property real effectiveHorizontalWidth: Math.max(0, Math.min(maxWidth, availableWidth))
    readonly property real effectiveHorizontalInnerWidth: Math.max(0, effectiveHorizontalWidth - horizontalPadding * 2)
    property Toplevel activeWindow: null
    property var activeDesktopEntry: null
    property bool isHovered: mouseArea.containsMouse
    property bool isAutoHideBar: false

    function resolveSortedWindow() {
        const sortedWindows = CompositorService.sortedToplevels || [];
        const exactMatch = sortedWindows.find(window => window === activeWindow || window.wayland === activeWindow || window.sourceToplevel === activeWindow);
        if (exactMatch)
            return exactMatch;

        const titleMatches = sortedWindows.filter(window => window.appId === activeWindow.appId && window.title === activeWindow.title);
        return titleMatches.length === 1 ? titleMatches[0] : null;
    }

    function resolveActiveWindowPid() {
        if (!activeWindow)
            return 0;
        if (CompositorService.isNiri) {
            const sortedWindow = resolveSortedWindow();
            return sortedWindow?.niriWindowId !== undefined ? NiriService.windows.find(w => w.id === sortedWindow.niriWindowId)?.pid || 0 : 0;
        }
        if (CompositorService.isHyprland) {
            const hyprWindow = Array.from(Hyprland.toplevels?.values || []).find(t => t.wayland === activeWindow);
            return hyprWindow?.lastIpcObject?.pid || 0;
        }
        if (CompositorService.isMango) {
            const sortedWindow = resolveSortedWindow();
            return sortedWindow?.mangoWindowId !== undefined ? MangoService.windows.find(w => w.id === sortedWindow.mangoWindowId)?.pid || 0 : 0;
        }
        return activeWindow.pid || 0;
    }

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

    function isWindowAlive(win) {
        if (!win)
            return false;
        const alive = ToplevelManager.toplevels?.values;
        return !!alive && Array.from(alive).some(t => t === win);
    }

    function getNiriFocusedWindow() {
        if (!CompositorService.isNiri)
            return null;
        const focused = NiriService.windows.find(w => w.is_focused);
        if (focused)
            return focused;
        if (!focusedWindowPopoutLoader.item?.shouldBeVisible || NiriService.lastFocusedWindowId === null)
            return null;
        return NiriService.windows.find(w => w.id === NiriService.lastFocusedWindowId) || null;
    }

    function updateActiveWindow() {
        let active = ToplevelManager.activeToplevel;

        if (!active && CompositorService.isNiri) {
            const focusedWin = getNiriFocusedWindow();
            if (focusedWin) {
                const screenWsIds = new Set(NiriService.allWorkspaces.filter(ws => ws.output === (parentScreen?.name ?? "")).map(ws => ws.id));
                if (screenWsIds.has(focusedWin.workspace_id)) {
                    const sortedMatch = (CompositorService.sortedToplevels || []).find(st => st.niriWindowId === focusedWin.id);
                    active = sortedMatch?.sourceToplevel || (Array.from(ToplevelManager.toplevels?.values || []).find(t => t.appId === focusedWin.app_id && (!focusedWin.title || t.title === focusedWin.title)) || null);
                }
            }
        }

        if (!active) {
            if (activeWindow) {
                if (CompositorService.isNiri) {
                    const currentWs = NiriService.allWorkspaces.find(ws => ws.output === (parentScreen?.name ?? "") && ws.is_active);
                    const wsWindows = currentWs ? NiriService.windows.filter(w => w.workspace_id === currentWs.id) : [];
                    if (!isWindowAlive(activeWindow) || wsWindows.length === 0)
                        activeWindow = null;
                } else if (!isWindowAlive(activeWindow)) {
                    activeWindow = null;
                }
            }
            return;
        }

        if (!parentScreen || CompositorService.filterCurrentDisplay([active], parentScreen?.name)?.length > 0) {
            activeWindow = active;
        } else if (!isWindowAlive(activeWindow)) {
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
        function onAllWorkspacesChanged() {
            root.updateActiveWindow();
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.updateDesktopEntry();
        }
    }

    function syncPopoutState() {
        const popout = focusedWindowPopoutLoader.item;
        if (!popout || !activeWindow || !root.parentScreen)
            return;
        popout.currentWindow = activeWindow;
        popout.processId = root.resolveActiveWindowPid();
        const globalPos = root.visualContent.mapToItem(null, 0, 0);
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const position = SettingsData.getPopupTriggerPosition(globalPos, root.parentScreen, root.barThickness, root.visualWidth, root.barSpacing, barPosition, root.barConfig);
        popout.setTriggerPosition(position.x, position.y, position.width, root.section, root.parentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
    }

    Connections {
        target: root
        function onActiveWindowChanged() {
            root.updateDesktopEntry();
            if (focusedWindowPopoutLoader.item?.shouldBeVisible) {
                if (root.activeWindow) {
                    root.syncPopoutState();
                    Qt.callLater(() => root.syncPopoutState());
                } else {
                    focusedWindowPopoutLoader.item.close();
                }
            }
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
            const focusedWin = getNiriFocusedWindow();
            if (!focusedWin) {
                const currentWs = NiriService.allWorkspaces.find(ws => ws.output === (parentScreen?.name ?? "") && ws.is_active);
                return !!currentWs && NiriService.windows.some(w => w.workspace_id === currentWs.id);
            }
            const screenWsIds = new Set(NiriService.allWorkspaces.filter(ws => ws.output === (parentScreen?.name ?? "")).map(ws => ws.id));
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

    width: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? barThickness : (effectiveHorizontalInnerWidth > 0 ? visualWidth : 0)) : 0
    height: hasWindowsOnCurrentWorkspace ? (isVerticalOrientation ? visualHeight : barThickness) : 0
    visible: hasWindowsOnCurrentWorkspace && (isVerticalOrientation || effectiveHorizontalInnerWidth > 0)

    content: Component {
        Item {
            implicitWidth: {
                if (!root.hasWindowsOnCurrentWorkspace)
                    return 0;
                if (root.isVerticalOrientation)
                    return root.widgetThickness - root.horizontalPadding * 2;
                return Math.min(contentRow.implicitWidth, root.effectiveHorizontalInnerWidth);
            }
            width: root.isVerticalOrientation ? root.widgetThickness - root.horizontalPadding * 2 : Math.min(implicitWidth, root.effectiveHorizontalInnerWidth)
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

            StyledText {
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

            Item {
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root.barThickness

                Row {
                    id: contentRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    spacing: Theme.spacingS
                    visible: !root.isVerticalOrientation

                    readonly property real iconSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)

                    IconImage {
                        id: horizontalAppIcon
                        width: contentRow.iconSize
                        height: contentRow.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showIcon && activeWindow && status === Image.Ready
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
                        id: horizontalSteamIcon
                        width: contentRow.iconSize
                        size: contentRow.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        name: "sports_esports"
                        color: Theme.widgetTextColor
                        visible: root.showIcon && activeWindow && activeWindow.appId && horizontalAppIcon.status !== Image.Ready && Paths.isSteamApp(activeWindow.appId)
                    }

                    StyledText {
                        id: appText
                        text: {
                            if (compactMode || !activeWindow || !activeWindow.appId)
                                return "";
                            return Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: {
                            const sp = contentRow.spacing;
                            let used = 0;
                            if (horizontalAppIcon.visible)
                                used += horizontalAppIcon.width + sp;
                            else if (horizontalSteamIcon.visible)
                                used += horizontalSteamIcon.width + sp;
                            const budget = Math.max(0, root.effectiveHorizontalInnerWidth - used);
                            return Math.min(implicitWidth, compactMode ? 80 : 180, budget);
                        }
                        visible: text.length > 0
                    }

                    StyledText {
                        id: appSeparator
                        text: compactMode ? "" : "•"
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
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: {
                            const sp = contentRow.spacing;
                            let used = 0;
                            if (horizontalAppIcon.visible)
                                used += horizontalAppIcon.width + sp;
                            else if (horizontalSteamIcon.visible)
                                used += horizontalSteamIcon.width + sp;
                            if (appText.visible)
                                used += appText.width + sp;
                            if (appSeparator.visible)
                                used += appSeparator.width + sp;
                            const budget = root.effectiveHorizontalInnerWidth - used;
                            return Math.min(implicitWidth, Math.max(0, budget));
                        }
                        visible: text.length > 0
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        hoverEnabled: root.isVerticalOrientation
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (root.isVerticalOrientation && activeWindow && activeWindow.appId && root.parentScreen) {
                tooltipLoader.active = true;
                if (tooltipLoader.item) {
                    const localPos = mapToItem(null, width / 2, height / 2);
                    const currentScreen = root.parentScreen;
                    const adjustedY = localPos.y + root.minTooltipY;
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS);

                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    const title = activeWindow.title || "";
                    const tooltipText = appName + (title ? " • " + title : "");

                    const isLeft = root.axis?.edge === "left";
                    tooltipLoader.item.show(tooltipText, tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }

        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (!activeWindow || !root.parentScreen)
                return;
            if (tooltipLoader.item)
                tooltipLoader.item.hide();
            tooltipLoader.active = false;

            focusedWindowPopoutLoader.active = true;
            if (!focusedWindowPopoutLoader.item)
                return;

            root.syncPopoutState();
            focusedWindowPopoutLoader.item.toggle();
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: focusedWindowPopoutLoader
        active: false
        sourceComponent: FocusedWindowContextMenu {}
    }

    Connections {
        target: focusedWindowPopoutLoader.item
        function onShouldBeVisibleChanged() {
            if (!focusedWindowPopoutLoader.item?.shouldBeVisible)
                root.updateActiveWindow();
        }
        function onPopoutClosed() {
            root.updateActiveWindow();
        }
    }
}
