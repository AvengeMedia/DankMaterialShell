import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowCompactMode")
    property bool showIcon: SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowShowIcon")
    readonly property int maxWidth: {
        const size = SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowSize");
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
    property var activeWindow: null
    property var activeDesktopEntry: null
    property bool isHovered: mouseArea.containsMouse

    readonly property string screenName: parentScreen?.name ?? ""
    readonly property bool popoutVisible: focusedWindowPopoutLoader.item?.shouldBeVisible ?? false

    function updateActiveWindow() {
        activeWindow = CompositorService.activeWindowForScreen(parentScreen ? parentScreen.name : null, activeWindow, popoutVisible);
    }

    Component.onCompleted: {
        updateActiveWindow();
        updateDesktopEntry();
    }

    readonly property Toplevel managerActiveToplevel: ToplevelManager.activeToplevel

    onManagerActiveToplevelChanged: updateActiveWindow()

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            root.updateActiveWindow();
        }
        function onWorkspaceStateChanged() {
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
        popout.processId = CompositorService.windowPid(activeWindow);
        const globalPos = root.visualContent.mapToItem(null, 0, 0);
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const position = SettingsData.getPopupTriggerPosition(globalPos, root.parentScreen, root.barThickness, root.visualWidth, root.barSpacing, barPosition, root.barConfig);
        popout.setTriggerPosition(position.x, position.y, position.width, root.section, root.parentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
    }

    onActiveWindowChanged: {
        updateDesktopEntry();
        if (focusedWindowPopoutLoader.item?.shouldBeVisible) {
            if (activeWindow) {
                syncPopoutState();
                Qt.callLater(() => root.syncPopoutState());
            } else {
                focusedWindowPopoutLoader.item.close();
            }
        }
    }

    readonly property var settingsAppIdSubstitutions: SettingsData.appIdSubstitutions

    onSettingsAppIdSubstitutionsChanged: updateDesktopEntry()

    function updateDesktopEntry() {
        if (activeWindow && activeWindow.appId) {
            const moddedId = Paths.moddedAppId(activeWindow.appId);
            activeDesktopEntry = DesktopEntries.heuristicLookup(moddedId);
        } else {
            activeDesktopEntry = null;
        }
    }
    readonly property bool hasWindowsOnCurrentWorkspace: {
        CompositorService.windowStateRevision;
        if (!activeWindow || !(activeWindow.title || activeWindow.appId))
            return false;
        return CompositorService.windowOnActiveWorkspace(screenName, activeWindow, popoutVisible);
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
                    return root.contentThickness;
                return Math.min(contentRow.implicitWidth, root.effectiveHorizontalInnerWidth);
            }
            width: root.isVerticalOrientation ? root.contentThickness : Math.min(implicitWidth, root.effectiveHorizontalInnerWidth)
            implicitHeight: root.contentThickness
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
                color: root.contentColor
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
                color: root.contentColor
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
                        color: root.contentColor
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
                        color: root.contentColor
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
                        color: root.contentColor
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
        sourceComponent: FocusedWindowContextMenu {
            onPopoutClosed: root.updateActiveWindow()
        }
    }

    onPopoutVisibleChanged: {
        if (!popoutVisible)
            updateActiveWindow();
    }
}
