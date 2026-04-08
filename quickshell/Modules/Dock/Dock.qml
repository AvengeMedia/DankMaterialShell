pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Variants {
    id: dockVariants
    model: SettingsData.getFilteredScreens("dock")

    property var contextMenu

    delegate: PanelWindow {
        id: dock

        WindowBlur {
            targetWindow: dock
            blurEnabled: dock.effectiveBlurEnabled && !SettingsData.connectedFrameModeActive
            blurX: dockBackground.x + dockContainer.x + dockMouseArea.x + dockCore.x + dockSlide.x
            blurY: dockBackground.y + dockContainer.y + dockMouseArea.y + dockCore.y + dockSlide.y
            blurWidth: dock.hasApps && dock.reveal ? dockBackground.width : 0
            blurHeight: dock.hasApps && dock.reveal ? dockBackground.height : 0
            blurRadius: Theme.isConnectedEffect ? Theme.connectedCornerRadius : dock.surfaceRadius
        }

        WlrLayershell.namespace: "dms:dock"

        readonly property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right

        anchors {
            top: !isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top) : true
            bottom: !isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom) : true
            left: !isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Left)
            right: !isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Right)
        }

        property var modelData: item
        property bool autoHide: SettingsData.dockAutoHide || SettingsData.dockSmartAutoHide
        property real backgroundTransparency: SettingsData.dockTransparency
        property bool groupByApp: SettingsData.dockGroupByApp
        readonly property int borderThickness: SettingsData.dockBorderEnabled ? SettingsData.dockBorderThickness : 0
        readonly property string connectedBarSide: SettingsData.dockPosition === SettingsData.Position.Top ? "top" : SettingsData.dockPosition === SettingsData.Position.Bottom ? "bottom" : SettingsData.dockPosition === SettingsData.Position.Left ? "left" : "right"
        readonly property bool connectedBarActiveOnEdge: Theme.isConnectedEffect && !!(dock.screen || modelData) && SettingsData.getActiveBarEdgesForScreen(dock.screen || modelData).includes(connectedBarSide)
        readonly property real connectedJoinInset: {
            if (!Theme.isConnectedEffect)
                return 0;
            return connectedBarActiveOnEdge ? SettingsData.frameBarSize : SettingsData.frameThickness;
        }
        readonly property real surfaceRadius: Theme.connectedSurfaceRadius
        readonly property color surfaceColor: Theme.isConnectedEffect ? Theme.connectedSurfaceColor : Theme.withAlpha(Theme.surfaceContainer, backgroundTransparency)
        readonly property color surfaceBorderColor: Theme.isConnectedEffect ? "transparent" : BlurService.borderColor
        readonly property real surfaceBorderWidth: Theme.isConnectedEffect ? 0 : BlurService.borderWidth
        readonly property real surfaceTopLeftRadius: Theme.isConnectedEffect && (SettingsData.dockPosition === SettingsData.Position.Top || SettingsData.dockPosition === SettingsData.Position.Left) ? 0 : surfaceRadius
        readonly property real surfaceTopRightRadius: Theme.isConnectedEffect && (SettingsData.dockPosition === SettingsData.Position.Top || SettingsData.dockPosition === SettingsData.Position.Right) ? 0 : surfaceRadius
        readonly property real surfaceBottomLeftRadius: Theme.isConnectedEffect && (SettingsData.dockPosition === SettingsData.Position.Bottom || SettingsData.dockPosition === SettingsData.Position.Left) ? 0 : surfaceRadius
        readonly property real surfaceBottomRightRadius: Theme.isConnectedEffect && (SettingsData.dockPosition === SettingsData.Position.Bottom || SettingsData.dockPosition === SettingsData.Position.Right) ? 0 : surfaceRadius
        readonly property real horizontalConnectorExtent: Theme.isConnectedEffect && !isVertical ? Theme.connectedCornerRadius : 0
        readonly property real verticalConnectorExtent: Theme.isConnectedEffect && isVertical ? Theme.connectedCornerRadius : 0

        readonly property int hasApps: dockApps.implicitWidth > 0 || dockApps.implicitHeight > 0

        readonly property real widgetHeight: SettingsData.dockIconSize
        readonly property real effectiveBarHeight: widgetHeight + SettingsData.dockSpacing * 2 + 10 + borderThickness * 2
        function getBarHeight(barConfig) {
            if (!barConfig)
                return 0;
            const innerPadding = barConfig.innerPadding ?? 4;
            const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
            const barThickness = Math.max(widgetThickness + innerPadding + 4, Theme.barHeight - 4 - (8 - innerPadding));
            const spacing = barConfig.spacing ?? 4;
            const bottomGap = barConfig.bottomGap ?? 0;
            return barThickness + spacing + bottomGap;
        }

        readonly property real barSpacing: {
            const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
            if (!defaultBar)
                return 0;

            const barPos = defaultBar.position ?? SettingsData.Position.Top;
            const barIsHorizontal = (barPos === SettingsData.Position.Top || barPos === SettingsData.Position.Bottom);
            const barIsVertical = (barPos === SettingsData.Position.Left || barPos === SettingsData.Position.Right);
            const samePosition = (SettingsData.dockPosition === barPos);
            const dockIsHorizontal = !isVertical;
            const dockIsVertical = isVertical;

            if (!(defaultBar.visible ?? true))
                return 0;
            const spacing = defaultBar.spacing ?? 4;
            const bottomGap = defaultBar.bottomGap ?? 0;
            if (dockIsHorizontal && barIsHorizontal && samePosition) {
                return spacing + effectiveBarHeight + bottomGap;
            }
            if (dockIsVertical && barIsVertical && samePosition) {
                return spacing + effectiveBarHeight + bottomGap;
            }
            return 0;
        }

        readonly property real adjacentTopBarHeight: {
            if (!isVertical || autoHide)
                return 0;
            const screenName = dock.modelData?.name ?? "";
            const topBar = SettingsData.barConfigs.find(bc => {
                if (!bc.enabled || bc.autoHide || !(bc.visible ?? true))
                    return false;
                if (bc.position !== SettingsData.Position.Top && bc.position !== 0)
                    return false;
                const onThisScreen = bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all") || bc.screenPreferences.includes(screenName);
                return onThisScreen;
            });
            return getBarHeight(topBar);
        }

        readonly property real adjacentLeftBarWidth: {
            if (isVertical || autoHide)
                return 0;
            const screenName = dock.modelData?.name ?? "";
            const leftBar = SettingsData.barConfigs.find(bc => {
                if (!bc.enabled || bc.autoHide || !(bc.visible ?? true))
                    return false;
                if (bc.position !== SettingsData.Position.Left && bc.position !== 2)
                    return false;
                const onThisScreen = bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all") || bc.screenPreferences.includes(screenName);
                return onThisScreen;
            });
            return getBarHeight(leftBar);
        }

        readonly property real dockMargin: SettingsData.dockMargin
        readonly property bool effectiveBlurEnabled: Theme.connectedSurfaceBlurEnabled
        readonly property real effectiveDockBottomGap: Theme.isConnectedEffect ? 0 : SettingsData.dockBottomGap
        readonly property real effectiveDockMargin: Theme.isConnectedEffect ? 0 : SettingsData.dockMargin
        readonly property real positionSpacing: barSpacing + effectiveDockBottomGap + effectiveDockMargin
        readonly property real joinedEdgeMargin: Theme.isConnectedEffect ? 0 : (barSpacing + effectiveDockMargin + 1 + dock.borderThickness)
        readonly property real _dpr: (dock.screen && dock.screen.devicePixelRatio) ? dock.screen.devicePixelRatio : 1
        function px(v) {
            return Math.round(v * _dpr) / _dpr;
        }

        function connectorWidth(spacing) {
            return dock.isVertical ? (spacing + Theme.connectedCornerRadius) : Theme.connectedCornerRadius;
        }

        function connectorHeight(spacing) {
            return dock.isVertical ? Theme.connectedCornerRadius : (spacing + Theme.connectedCornerRadius);
        }

        function connectorSeamX(baseX, bodyWidth, placement) {
            if (!dock.isVertical)
                return placement === "left" ? baseX : baseX + bodyWidth;
            return SettingsData.dockPosition === SettingsData.Position.Left ? baseX : baseX + bodyWidth;
        }

        function connectorSeamY(baseY, bodyHeight, placement) {
            if (SettingsData.dockPosition === SettingsData.Position.Top)
                return baseY;
            if (SettingsData.dockPosition === SettingsData.Position.Bottom)
                return baseY + bodyHeight;
            return placement === "left" ? baseY : baseY + bodyHeight;
        }

        function connectorX(baseX, bodyWidth, placement, spacing) {
            const seamX = connectorSeamX(baseX, bodyWidth, placement);
            const width = connectorWidth(spacing);
            if (!dock.isVertical)
                return placement === "left" ? seamX - width : seamX;
            return SettingsData.dockPosition === SettingsData.Position.Left ? seamX : seamX - width;
        }

        function connectorY(baseY, bodyHeight, placement, spacing) {
            const seamY = connectorSeamY(baseY, bodyHeight, placement);
            const height = connectorHeight(spacing);
            if (SettingsData.dockPosition === SettingsData.Position.Top)
                return seamY;
            if (SettingsData.dockPosition === SettingsData.Position.Bottom)
                return seamY - height;
            return placement === "left" ? seamY - height : seamY;
        }

        // ─── ConnectedModeState sync ────────────────────────────────────────
        // Dock window origin in screen-relative coordinates (FrameWindow space).
        function _dockWindowOriginX() {
            if (!dock.isVertical)
                return 0;
            if (SettingsData.dockPosition === SettingsData.Position.Right)
                return (dock.screen ? dock.screen.width : 0) - dock.width;
            return 0;
        }
        function _dockWindowOriginY() {
            if (dock.isVertical)
                return 0;
            if (SettingsData.dockPosition === SettingsData.Position.Bottom)
                return (dock.screen ? dock.screen.height : 0) - dock.height;
            return 0;
        }

        readonly property string _dockScreenName: dock.modelData ? dock.modelData.name : (dock.screen ? dock.screen.name : "")

        function _syncDockChromeState() {
            if (!dock._dockScreenName)
                return;
            if (!SettingsData.connectedFrameModeActive) {
                ConnectedModeState.clearDockState(dock._dockScreenName);
                return;
            }

            ConnectedModeState.setDockState(dock._dockScreenName, {
                "reveal": dock.visible && (dock.reveal || slideXAnimation.running || slideYAnimation.running) && dock.hasApps,
                "barSide": dock.connectedBarSide,
                "bodyX": dock._dockWindowOriginX() + dockBackground.x + dockContainer.x + dockMouseArea.x + dockCore.x,
                "bodyY": dock._dockWindowOriginY() + dockBackground.y + dockContainer.y + dockMouseArea.y + dockCore.y,
                "bodyW": dock.hasApps ? dockBackground.width : 0,
                "bodyH": dock.hasApps ? dockBackground.height : 0,
                "slideX": dockSlide.x,
                "slideY": dockSlide.y
            });
        }

        function _syncDockSlide() {
            if (!dock._dockScreenName || !SettingsData.connectedFrameModeActive)
                return;
            ConnectedModeState.setDockSlide(dock._dockScreenName, dockSlide.x, dockSlide.y);
        }

        property bool contextMenuOpen: (dockVariants.contextMenu && dockVariants.contextMenu.visible && dockVariants.contextMenu.screen === modelData)
        property bool revealSticky: false

        readonly property bool shouldHideForWindows: {
            if (!SettingsData.dockSmartAutoHide)
                return false;
            if (!CompositorService.isNiri && !CompositorService.isHyprland)
                return false;

            const screenName = dock.modelData?.name ?? "";
            const dockThickness = dock.connectedJoinInset + effectiveBarHeight + SettingsData.dockSpacing + dock.effectiveDockBottomGap + dock.effectiveDockMargin;
            const screenWidth = dock.screen?.width ?? 0;
            const screenHeight = dock.screen?.height ?? 0;

            if (CompositorService.isNiri) {
                NiriService.windows;

                let currentWorkspaceId = null;
                for (let i = 0; i < NiriService.allWorkspaces.length; i++) {
                    const ws = NiriService.allWorkspaces[i];
                    if (ws.output === screenName && ws.is_active) {
                        currentWorkspaceId = ws.id;
                        break;
                    }
                }

                if (currentWorkspaceId === null)
                    return false;

                for (let i = 0; i < NiriService.windows.length; i++) {
                    const win = NiriService.windows[i];
                    if (win.workspace_id !== currentWorkspaceId)
                        continue;

                    // Get window position and size from layout data
                    const tilePos = win.layout?.tile_pos_in_workspace_view;
                    const winSize = win.layout?.window_size || win.layout?.tile_size;

                    if (tilePos && winSize) {
                        const winX = tilePos[0];
                        const winY = tilePos[1];
                        const winW = winSize[0];
                        const winH = winSize[1];

                        switch (SettingsData.dockPosition) {
                        case SettingsData.Position.Top:
                            if (winY < dockThickness)
                                return true;
                            break;
                        case SettingsData.Position.Bottom:
                            if (winY + winH > screenHeight - dockThickness)
                                return true;
                            break;
                        case SettingsData.Position.Left:
                            if (winX < dockThickness)
                                return true;
                            break;
                        case SettingsData.Position.Right:
                            if (winX + winW > screenWidth - dockThickness)
                                return true;
                            break;
                        }
                    } else if (!win.is_floating) {
                        return true;
                    }
                }

                return false;
            }

            // Hyprland implementation
            Hyprland.focusedWorkspace;
            const filtered = CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);

            if (filtered.length === 0)
                return false;

            for (let i = 0; i < filtered.length; i++) {
                const toplevel = filtered[i];

                let hyprToplevel = null;
                if (Hyprland.toplevels) {
                    const hyprToplevels = Array.from(Hyprland.toplevels.values);
                    for (let j = 0; j < hyprToplevels.length; j++) {
                        if (hyprToplevels[j].wayland === toplevel) {
                            hyprToplevel = hyprToplevels[j];
                            break;
                        }
                    }
                }

                if (!hyprToplevel?.lastIpcObject)
                    continue;

                const ipc = hyprToplevel.lastIpcObject;
                const at = ipc.at;
                const size = ipc.size;
                if (!at || !size)
                    continue;

                const monX = hyprToplevel.monitor?.x ?? 0;
                const monY = hyprToplevel.monitor?.y ?? 0;

                const winX = at[0] - monX;
                const winY = at[1] - monY;
                const winW = size[0];
                const winH = size[1];

                switch (SettingsData.dockPosition) {
                case SettingsData.Position.Top:
                    if (winY < dockThickness)
                        return true;
                    break;
                case SettingsData.Position.Bottom:
                    if (winY + winH > screenHeight - dockThickness)
                        return true;
                    break;
                case SettingsData.Position.Left:
                    if (winX < dockThickness)
                        return true;
                    break;
                case SettingsData.Position.Right:
                    if (winX + winW > screenWidth - dockThickness)
                        return true;
                    break;
                }
            }

            return false;
        }

        Timer {
            id: revealHold
            interval: 250
            repeat: false
            onTriggered: dock.revealSticky = false
        }

        property bool reveal: {
            if (CompositorService.isNiri && NiriService.inOverview && SettingsData.dockOpenOnOverview) {
                return true;
            }

            // Smart auto-hide: show dock when no windows overlap, hide when they do
            if (SettingsData.dockSmartAutoHide) {
                if (shouldHideForWindows)
                    return dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky;
                return true;  // No overlapping windows - show dock
            }

            // Regular auto-hide: always hide unless hovering
            return !autoHide || dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky;
        }

        onContextMenuOpenChanged: {
            if (!contextMenuOpen && autoHide && !dockMouseArea.containsMouse) {
                revealSticky = true;
                revealHold.restart();
            }
        }

        Component.onCompleted: Qt.callLater(() => dock._syncDockChromeState())
        Component.onDestruction: ConnectedModeState.clearDockState(dock._dockScreenName)

        onRevealChanged: dock._syncDockChromeState()
        onWidthChanged: dock._syncDockChromeState()
        onHeightChanged: dock._syncDockChromeState()
        onVisibleChanged: dock._syncDockChromeState()
        onHasAppsChanged: dock._syncDockChromeState()
        onConnectedBarSideChanged: dock._syncDockChromeState()

        Connections {
            target: SettingsData
            function onConnectedFrameModeActiveChanged() {
                dock._syncDockChromeState();
            }
        }

        Connections {
            target: SettingsData
            function onDockTransparencyChanged() {
                dock.backgroundTransparency = SettingsData.dockTransparency;
            }
        }

        screen: modelData
        visible: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return SettingsData.dockOpenOnOverview;
            }
            return SettingsData.showDock;
        }
        color: "transparent"

        exclusiveZone: {
            if (!SettingsData.showDock || autoHide)
                return -1;
            if (barSpacing > 0)
                return -1;
            return px(connectedJoinInset + effectiveBarHeight + SettingsData.dockSpacing + effectiveDockBottomGap + effectiveDockMargin);
        }

        property real animationHeadroom: Math.ceil(SettingsData.dockIconSize * 0.35)

        implicitWidth: isVertical ? (px(connectedJoinInset + effectiveBarHeight + SettingsData.dockSpacing + effectiveDockMargin + SettingsData.dockIconSize * 0.3) + animationHeadroom) : 0
        implicitHeight: !isVertical ? (px(connectedJoinInset + effectiveBarHeight + SettingsData.dockSpacing + effectiveDockMargin + SettingsData.dockIconSize * 0.3) + animationHeadroom) : 0

        Item {
            id: maskItem
            parent: dock.contentItem
            visible: false
            readonly property bool expanded: dock.reveal
            x: {
                const baseX = dockCore.x + dockMouseArea.x;
                if (isVertical && SettingsData.dockPosition === SettingsData.Position.Right)
                    return baseX - (expanded ? animationHeadroom + borderThickness + dock.horizontalConnectorExtent : 0);
                return baseX - (expanded ? borderThickness + dock.horizontalConnectorExtent : 0);
            }
            y: {
                const baseY = dockCore.y + dockMouseArea.y;
                if (!isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom)
                    return baseY - (expanded ? animationHeadroom + borderThickness + dock.verticalConnectorExtent : 0);
                return baseY - (expanded ? borderThickness + dock.verticalConnectorExtent : 0);
            }
            width: dockMouseArea.width + (isVertical && expanded ? animationHeadroom : 0) + (expanded ? borderThickness * 2 + dock.horizontalConnectorExtent * 2 : 0)
            height: dockMouseArea.height + (!isVertical && expanded ? animationHeadroom : 0) + (expanded ? borderThickness * 2 + dock.verticalConnectorExtent * 2 : 0)
        }

        mask: Region {
            item: maskItem
        }

        property var hoveredButton: {
            if (!dockApps.children[0]) {
                return null;
            }
            const layoutItem = dockApps.children[0];
            const flowLayout = layoutItem.children[0];
            let repeater = null;
            for (var i = 0; i < flowLayout.children.length; i++) {
                const child = flowLayout.children[i];
                if (child && typeof child.count !== "undefined" && typeof child.itemAt === "function") {
                    repeater = child;
                    break;
                }
            }
            if (!repeater || !repeater.itemAt) {
                return null;
            }
            for (var i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.dockButton && item.dockButton.showTooltip) {
                    return item.dockButton;
                }
            }
            return null;
        }

        DankTooltip {
            id: dockTooltip
            targetScreen: dock.screen
        }

        Timer {
            id: tooltipRevealDelay
            interval: 250
            repeat: false
            onTriggered: dock.showTooltipForHoveredButton()
        }

        function showTooltipForHoveredButton() {
            dockTooltip.hide();
            if (!dock.hoveredButton || !dock.reveal || slideXAnimation.running || slideYAnimation.running)
                return;

            const buttonGlobalPos = dock.hoveredButton.mapToGlobal(0, 0);
            const tooltipText = dock.hoveredButton.tooltipText || "";
            if (!tooltipText)
                return;

            const screenX = dock.screen ? (dock.screen.x || 0) : 0;
            const screenY = dock.screen ? (dock.screen.y || 0) : 0;
            const screenHeight = dock.screen ? dock.screen.height : 0;

            const gap = Theme.spacingS;
            const bgMargin = dock.joinedEdgeMargin + dock.connectedJoinInset;
            const btnW = dock.hoveredButton.width;
            const btnH = dock.hoveredButton.height;

            if (!dock.isVertical) {
                const isBottom = SettingsData.dockPosition === SettingsData.Position.Bottom;
                const globalX = buttonGlobalPos.x + btnW / 2 + adjacentLeftBarWidth;
                const tooltipHeight = 32;
                const totalFromEdge = bgMargin + dockBackground.height + dock.borderThickness + gap;
                const screenRelativeY = isBottom ? (screenHeight - totalFromEdge - tooltipHeight) : totalFromEdge;
                dockTooltip.show(tooltipText, globalX, screenRelativeY, dock.screen, false, false);
                return;
            }

            const isLeft = SettingsData.dockPosition === SettingsData.Position.Left;
            const screenWidth = dock.screen ? dock.screen.width : 0;
            const totalFromEdge = bgMargin + dockBackground.width + dock.borderThickness + gap;
            const tooltipX = isLeft ? (screenX + totalFromEdge) : (screenX + screenWidth - totalFromEdge);
            const screenRelativeY = buttonGlobalPos.y - screenY + btnH / 2 + adjacentTopBarHeight;
            dockTooltip.show(tooltipText, tooltipX, screenRelativeY, dock.screen, isLeft, !isLeft);
        }

        Connections {
            target: dock
            function onRevealChanged() {
                if (!dock.reveal) {
                    tooltipRevealDelay.stop();
                    dockTooltip.hide();
                } else {
                    tooltipRevealDelay.restart();
                }
            }

            function onHoveredButtonChanged() {
                dock.showTooltipForHoveredButton();
            }
        }

        Item {
            id: dockCore
            anchors.fill: parent
            x: isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? animationHeadroom : 0
            y: !isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom ? animationHeadroom : 0

            Connections {
                target: dockMouseArea
                function onContainsMouseChanged() {
                    if (dockMouseArea.containsMouse) {
                        dock.revealSticky = true;
                        revealHold.stop();
                    } else {
                        if (dock.autoHide && !dock.contextMenuOpen) {
                            revealHold.restart();
                        }
                    }
                }
            }

            MouseArea {
                id: dockMouseArea
                property real currentScreen: modelData ? modelData : dock.screen
                property real screenWidth: currentScreen ? currentScreen.geometry.width : 1920
                property real screenHeight: currentScreen ? currentScreen.geometry.height : 1080
                property real maxDockWidth: screenWidth * 0.98
                property real maxDockHeight: screenHeight * 0.98

                height: {
                    if (dock.isVertical) {
                        // Keep the taller hit area regardless of the reveal state to prevent shrinking loop
                        return Math.min(Math.max(dockBackground.height + 64, 200), maxDockHeight);
                    }
                    return dock.reveal ? px(dock.connectedJoinInset + dock.effectiveBarHeight + SettingsData.dockSpacing + dock.effectiveDockBottomGap + dock.effectiveDockMargin) : 1;
                }
                width: {
                    if (dock.isVertical) {
                        return dock.reveal ? px(dock.connectedJoinInset + dock.effectiveBarHeight + SettingsData.dockSpacing + dock.effectiveDockBottomGap + dock.effectiveDockMargin) : 1;
                    }
                    // Keep the wider hit area regardless of the reveal state to prevent shrinking loop
                    return Math.min(dockBackground.width + 8 + dock.borderThickness, maxDockWidth);
                }
                anchors {
                    top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? undefined : parent.top) : undefined
                    bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                    horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                    left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? undefined : parent.left) : undefined
                    right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                    verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                }
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: dockContainer
                    anchors.fill: parent
                    clip: false

                    transform: Translate {
                        id: dockSlide
                        x: {
                            if (!dock.isVertical)
                                return 0;
                            if (dock.reveal)
                                return 0;
                            if (Theme.isConnectedEffect) {
                                const retractDist = dockBackground.width + SettingsData.dockSpacing + 10;
                                return SettingsData.dockPosition === SettingsData.Position.Right ? retractDist : -retractDist;
                            }
                            const hideDistance = dock.connectedJoinInset + dock.effectiveBarHeight + SettingsData.dockSpacing + dock.effectiveDockBottomGap + dock.effectiveDockMargin + 10;
                            if (SettingsData.dockPosition === SettingsData.Position.Right) {
                                return hideDistance;
                            } else {
                                return -hideDistance;
                            }
                        }
                        y: {
                            if (dock.isVertical)
                                return 0;
                            if (dock.reveal)
                                return 0;
                            if (Theme.isConnectedEffect) {
                                const retractDist = dockBackground.height + SettingsData.dockSpacing + 10;
                                return SettingsData.dockPosition === SettingsData.Position.Bottom ? retractDist : -retractDist;
                            }
                            const hideDistance = dock.connectedJoinInset + dock.effectiveBarHeight + SettingsData.dockSpacing + dock.effectiveDockBottomGap + dock.effectiveDockMargin + 10;
                            if (SettingsData.dockPosition === SettingsData.Position.Bottom) {
                                return hideDistance;
                            } else {
                                return -hideDistance;
                            }
                        }

                        Behavior on x {
                            NumberAnimation {
                                id: slideXAnimation
                                duration: Theme.isConnectedEffect ? Theme.variantDuration(Theme.popoutAnimationDuration, dock.reveal) : Theme.shortDuration
                                easing.type: Theme.isConnectedEffect ? Easing.BezierSpline : Easing.OutCubic
                                easing.bezierCurve: Theme.isConnectedEffect ? (dock.reveal ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve) : []
                                onRunningChanged: if (!running) dock._syncDockChromeState()
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                id: slideYAnimation
                                duration: Theme.isConnectedEffect ? Theme.variantDuration(Theme.popoutAnimationDuration, dock.reveal) : Theme.shortDuration
                                easing.type: Theme.isConnectedEffect ? Easing.BezierSpline : Easing.OutCubic
                                easing.bezierCurve: Theme.isConnectedEffect ? (dock.reveal ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve) : []
                                onRunningChanged: if (!running) dock._syncDockChromeState()
                            }
                        }

                        onXChanged: {
                            dock._syncDockSlide();
                        }
                        onYChanged: {
                            dock._syncDockSlide();
                        }
                    }

                    Item {
                        id: dockBackground
                        objectName: "dockBackground"
                        anchors {
                            top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top ? parent.top : undefined) : undefined
                            bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                            horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                            left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined) : undefined
                            right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                            verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                        }
                        anchors.topMargin: !dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Top ? (dock.connectedJoinInset + dock.joinedEdgeMargin) : 0
                        anchors.bottomMargin: !dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom ? (dock.connectedJoinInset + dock.joinedEdgeMargin) : 0
                        anchors.leftMargin: dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Left ? (dock.connectedJoinInset + dock.joinedEdgeMargin) : 0
                        anchors.rightMargin: dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? (dock.connectedJoinInset + dock.joinedEdgeMargin) : 0

                        implicitWidth: dock.isVertical ? (dockApps.implicitHeight + SettingsData.dockSpacing * 2) : (dockApps.implicitWidth + SettingsData.dockSpacing * 2)
                        implicitHeight: dock.isVertical ? (dockApps.implicitWidth + SettingsData.dockSpacing * 2) : (dockApps.implicitHeight + SettingsData.dockSpacing * 2)
                        width: implicitWidth
                        height: implicitHeight

                        // Avoid an offscreen texture seam where the connected dock meets the frame.
                        layer.enabled: !Theme.isConnectedEffect
                        clip: false

                        Rectangle {
                            anchors.fill: parent
                            visible: !SettingsData.connectedFrameModeActive
                            color: dock.surfaceColor
                            topLeftRadius: dock.surfaceTopLeftRadius
                            topRightRadius: dock.surfaceTopRightRadius
                            bottomLeftRadius: dock.surfaceBottomLeftRadius
                            bottomRightRadius: dock.surfaceBottomRightRadius
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !SettingsData.connectedFrameModeActive
                            color: "transparent"
                            topLeftRadius: dock.surfaceTopLeftRadius
                            topRightRadius: dock.surfaceTopRightRadius
                            bottomLeftRadius: dock.surfaceBottomLeftRadius
                            bottomRightRadius: dock.surfaceBottomRightRadius
                            border.color: dock.surfaceBorderColor
                            border.width: dock.surfaceBorderWidth
                            z: 100
                        }

                        // Sync dockBackground geometry to ConnectedModeState
                        onXChanged: dock._syncDockChromeState()
                        onYChanged: dock._syncDockChromeState()
                        onWidthChanged: dock._syncDockChromeState()
                        onHeightChanged: dock._syncDockChromeState()
                    }

                    ConnectedCorner {
                        visible: Theme.isConnectedEffect && dock.reveal && !SettingsData.connectedFrameModeActive
                        barSide: dock.connectedBarSide
                        placement: "left"
                        spacing: 0
                        connectorRadius: Theme.connectedCornerRadius
                        color: dock.surfaceColor
                        dpr: dock._dpr
                        x: Theme.snap(dock.connectorX(dockBackground.x, dockBackground.width, placement, spacing), dock._dpr)
                        y: Theme.snap(dock.connectorY(dockBackground.y, dockBackground.height, placement, spacing), dock._dpr)
                    }

                    ConnectedCorner {
                        visible: Theme.isConnectedEffect && dock.reveal && !SettingsData.connectedFrameModeActive
                        barSide: dock.connectedBarSide
                        placement: "right"
                        spacing: 0
                        connectorRadius: Theme.connectedCornerRadius
                        color: dock.surfaceColor
                        dpr: dock._dpr
                        x: Theme.snap(dock.connectorX(dockBackground.x, dockBackground.width, placement, spacing), dock._dpr)
                        y: Theme.snap(dock.connectorY(dockBackground.y, dockBackground.height, placement, spacing), dock._dpr)
                    }

                    Shape {
                        id: dockBorderShape
                        x: dockBackground.x - borderThickness
                        y: dockBackground.y - borderThickness
                        width: dockBackground.width + borderThickness * 2
                        height: dockBackground.height + borderThickness * 2
                        visible: SettingsData.dockBorderEnabled && dock.hasApps && !Theme.isConnectedEffect
                        preferredRendererType: Shape.CurveRenderer

                        readonly property real borderThickness: Math.max(1, dock.borderThickness)
                        readonly property real i: borderThickness / 2
                        readonly property real cr: dock.surfaceRadius
                        readonly property real w: dockBackground.width
                        readonly property real h: dockBackground.height

                        readonly property color borderColor: {
                            const opacity = SettingsData.dockBorderOpacity;
                            switch (SettingsData.dockBorderColor) {
                            case "secondary":
                                return Theme.withAlpha(Theme.secondary, opacity);
                            case "primary":
                                return Theme.withAlpha(Theme.primary, opacity);
                            default:
                                return Theme.withAlpha(Theme.surfaceText, opacity);
                            }
                        }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: dockBorderShape.borderColor
                            strokeWidth: dockBorderShape.borderThickness
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.FlatCap

                            PathSvg {
                                path: {
                                    const bt = dockBorderShape.borderThickness;
                                    const i = dockBorderShape.i;
                                    const cr = dockBorderShape.cr + bt - i;
                                    const w = dockBorderShape.w;
                                    const h = dockBorderShape.h;

                                    let d = `M ${i + cr} ${i}`;
                                    d += ` L ${i + w + 2 * (bt - i) - cr} ${i}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i + w + 2 * (bt - i)} ${i + cr}`;
                                    d += ` L ${i + w + 2 * (bt - i)} ${i + h + 2 * (bt - i) - cr}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i + w + 2 * (bt - i) - cr} ${i + h + 2 * (bt - i)}`;
                                    d += ` L ${i + cr} ${i + h + 2 * (bt - i)}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i} ${i + h + 2 * (bt - i) - cr}`;
                                    d += ` L ${i} ${i + cr}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i + cr} ${i}`;
                                    d += " Z";
                                    return d;
                                }
                            }
                        }
                    }

                    DockApps {
                        id: dockApps

                        anchors.top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top ? dockBackground.top : undefined) : undefined
                        anchors.bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? dockBackground.bottom : undefined) : undefined
                        anchors.horizontalCenter: !dock.isVertical ? dockBackground.horizontalCenter : undefined
                        anchors.left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Left ? dockBackground.left : undefined) : undefined
                        anchors.right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? dockBackground.right : undefined) : undefined
                        anchors.verticalCenter: dock.isVertical ? dockBackground.verticalCenter : undefined
                        anchors.topMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.bottomMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.leftMargin: dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.rightMargin: dock.isVertical ? SettingsData.dockSpacing : 0

                        contextMenu: dockVariants.contextMenu
                        groupByApp: dock.groupByApp
                        isVertical: dock.isVertical
                        dockScreen: dock.screen
                        iconSize: dock.widgetHeight
                    }
                }
            }
        }
    }
}
