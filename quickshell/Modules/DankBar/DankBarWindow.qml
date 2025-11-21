import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.DankBar.Widgets
import qs.Modules.DankBar.Popouts
import qs.Services
import qs.Widgets

PanelWindow {
    id: barWindow

    required property var rootWindow
    property var modelData: item
    property var hyprlandOverviewLoader: rootWindow ? rootWindow.hyprlandOverviewLoader : null

    property var controlCenterButtonRef: null
    property var clockButtonRef: null

    function triggerControlCenter() {
        controlCenterLoader.active = true
        if (!controlCenterLoader.item) {
            return
        }

        if (controlCenterButtonRef && controlCenterLoader.item.setTriggerPosition) {
            const globalPos = controlCenterButtonRef.mapToGlobal(0, 0)
            const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, controlCenterButtonRef.width)
            const section = controlCenterButtonRef.section || "right"
            controlCenterLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen)
        } else {
            controlCenterLoader.item.triggerScreen = barWindow.screen
        }

        controlCenterLoader.item.toggle()
        if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
            NetworkService.scanWifi()
        }
    }

    function triggerWallpaperBrowser() {
        dankDashPopoutLoader.active = true
        if (!dankDashPopoutLoader.item) {
            return
        }

        if (clockButtonRef && clockButtonRef.visualContent && dankDashPopoutLoader.item.setTriggerPosition) {
            const globalPos = clockButtonRef.visualContent.mapToGlobal(0, 0)
            const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, clockButtonRef.visualWidth)
            const section = clockButtonRef.section || "center"
            dankDashPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen)
        } else {
            dankDashPopoutLoader.item.triggerScreen = barWindow.screen
        }

        PopoutManager.requestPopout(dankDashPopoutLoader.item, 2)
    }

    readonly property var dBarLayer: {
        switch (Quickshell.env("DMS_DANKBAR_LAYER")) {
        case "bottom":
            return WlrLayer.Bottom
        case "overlay":
            return WlrLayer.Overlay
        case "background":
            return WlrLayer.background
        default:
            return WlrLayer.Top
        }
    }

    WlrLayershell.layer: dBarLayer
    WlrLayershell.namespace: "dms:bar"

    signal colorPickerRequested

    onColorPickerRequested: rootWindow.colorPickerRequested()

    property alias axis: axis

    AxisContext {
        id: axis
        edge: {
            switch (SettingsData.dankBarPosition) {
            case SettingsData.Position.Top:
                return "top"
            case SettingsData.Position.Bottom:
                return "bottom"
            case SettingsData.Position.Left:
                return "left"
            case SettingsData.Position.Right:
                return "right"
            default:
                return "top"
            }
        }
    }

    readonly property bool isVertical: axis.isVertical

    property bool gothCornersEnabled: SettingsData.dankBarGothCornersEnabled
    property real wingtipsRadius: SettingsData.dankBarGothCornerRadiusOverride ? SettingsData.dankBarGothCornerRadiusValue : Theme.cornerRadius
    readonly property real _wingR: Math.max(0, wingtipsRadius)
    readonly property color _surfaceContainer: Theme.surfaceContainer
    readonly property real _backgroundAlpha: topBarCore?.backgroundTransparency ?? SettingsData.dankBarTransparency
    readonly property color _bgColor: Theme.withAlpha(_surfaceContainer, _backgroundAlpha)
    readonly property real _dpr: CompositorService.getScreenScale(barWindow.screen)

    property string screenName: modelData.name
    readonly property int notificationCount: NotificationService.notifications.length
    readonly property real effectiveBarThickness: Math.max(barWindow.widgetThickness + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
    readonly property real widgetThickness: Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)

    screen: modelData
    implicitHeight: !isVertical ? Theme.px(effectiveBarThickness + SettingsData.dankBarSpacing + (SettingsData.dankBarGothCornersEnabled ? _wingR : 0), _dpr) : 0
    implicitWidth: isVertical ? Theme.px(effectiveBarThickness + SettingsData.dankBarSpacing + (SettingsData.dankBarGothCornersEnabled ? _wingR : 0), _dpr) : 0
    color: "transparent"

    property var nativeInhibitor: null

    Component.onCompleted: {
        if (SettingsData.forceStatusBarLayoutRefresh) {
            SettingsData.forceStatusBarLayoutRefresh.connect(() => {
                                                                 Qt.callLater(() => {
                                                                                  stackContainer.visible = false
                                                                                  Qt.callLater(() => {
                                                                                                   stackContainer.visible = true
                                                                                               })
                                                                              })
                                                             })
        }

        updateGpuTempConfig()

        inhibitorInitTimer.start()
    }

    Timer {
        id: inhibitorInitTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (SessionService.nativeInhibitorAvailable) {
                createNativeInhibitor()
            }
        }
    }

    Connections {
        target: PluginService
        function onPluginLoaded(pluginId) {
            console.info("DankBar: Plugin loaded:", pluginId)
            SettingsData.widgetDataChanged()
        }
        function onPluginUnloaded(pluginId) {
            console.info("DankBar: Plugin unloaded:", pluginId)
            SettingsData.widgetDataChanged()
        }
    }

    function updateGpuTempConfig() {
        const allWidgets = [...(SettingsData.dankBarLeftWidgets || []), ...(SettingsData.dankBarCenterWidgets || []), ...(SettingsData.dankBarRightWidgets || [])]

        const hasGpuTempWidget = allWidgets.some(widget => {
                                                     const widgetId = typeof widget === "string" ? widget : widget.id
                                                     const widgetEnabled = typeof widget === "string" ? true : (widget.enabled !== false)
                                                     return widgetId === "gpuTemp" && widgetEnabled
                                                 })

        DgopService.gpuTempEnabled = hasGpuTempWidget || SessionData.nvidiaGpuTempEnabled || SessionData.nonNvidiaGpuTempEnabled
        DgopService.nvidiaGpuTempEnabled = hasGpuTempWidget || SessionData.nvidiaGpuTempEnabled
        DgopService.nonNvidiaGpuTempEnabled = hasGpuTempWidget || SessionData.nonNvidiaGpuTempEnabled
    }

    function createNativeInhibitor() {
        if (!SessionService.nativeInhibitorAvailable) {
            return
        }

        try {
            const qmlString = `
            import QtQuick
            import Quickshell.Wayland

            IdleInhibitor {
            enabled: false
            }
            `

            nativeInhibitor = Qt.createQmlObject(qmlString, barWindow, "DankBar.NativeInhibitor")
            nativeInhibitor.window = barWindow
            nativeInhibitor.enabled = Qt.binding(() => SessionService.idleInhibited)
            nativeInhibitor.enabledChanged.connect(function () {
                console.log("DankBar: Native inhibitor enabled changed to:", nativeInhibitor.enabled)
                if (SessionService.idleInhibited !== nativeInhibitor.enabled) {
                    SessionService.idleInhibited = nativeInhibitor.enabled
                    SessionService.inhibitorChanged()
                }
            })
            console.log("DankBar: Created native Wayland IdleInhibitor for", barWindow.screenName)
        } catch (e) {
            console.warn("DankBar: Failed to create native IdleInhibitor:", e)
            nativeInhibitor = null
        }
    }

    Connections {
        function onDankBarLeftWidgetsChanged() {
            barWindow.updateGpuTempConfig()
        }

        function onDankBarCenterWidgetsChanged() {
            barWindow.updateGpuTempConfig()
        }

        function onDankBarRightWidgetsChanged() {
            barWindow.updateGpuTempConfig()
        }

        target: SettingsData
    }

    Connections {
        function onNvidiaGpuTempEnabledChanged() {
            barWindow.updateGpuTempConfig()
        }

        function onNonNvidiaGpuTempEnabledChanged() {
            barWindow.updateGpuTempConfig()
        }

        target: SessionData
    }

    Connections {
        target: barWindow.screen
        function onGeometryChanged() {
            Qt.callLater(forceWidgetRefresh)
        }
    }

    Timer {
        id: refreshTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: {
            forceWidgetRefresh()
        }
    }

    Connections {
        target: axis
        function onChanged() {
            Qt.application.active
            refreshTimer.restart()
        }
    }

    anchors.top: !isVertical ? (SettingsData.dankBarPosition === SettingsData.Position.Top) : true
    anchors.bottom: !isVertical ? (SettingsData.dankBarPosition === SettingsData.Position.Bottom) : true
    anchors.left: !isVertical ? true : (SettingsData.dankBarPosition === SettingsData.Position.Left)
    anchors.right: !isVertical ? true : (SettingsData.dankBarPosition === SettingsData.Position.Right)

    exclusiveZone: (!SettingsData.dankBarVisible || topBarCore.autoHide) ? -1 : (barWindow.effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap)

    Item {
        id: inputMask

        readonly property int barThickness: Theme.px(barWindow.effectiveBarThickness + SettingsData.dankBarSpacing, barWindow._dpr)

        readonly property bool inOverviewWithShow: CompositorService.isNiri && NiriService.inOverview && SettingsData.dankBarOpenOnOverview
        readonly property bool effectiveVisible: SettingsData.dankBarVisible || inOverviewWithShow
        readonly property bool showing: effectiveVisible && (topBarCore.reveal || inOverviewWithShow || !topBarCore.autoHide)

        readonly property int maskThickness: showing ? barThickness : 1

        x: {
            if (!axis.isVertical) {
                return 0
            } else {
                switch (SettingsData.dankBarPosition) {
                case SettingsData.Position.Left:
                    return 0
                case SettingsData.Position.Right:
                    return parent.width - maskThickness
                default:
                    return 0
                }
            }
        }
        y: {
            if (axis.isVertical) {
                return 0
            } else {
                switch (SettingsData.dankBarPosition) {
                case SettingsData.Position.Top:
                    return 0
                case SettingsData.Position.Bottom:
                    return parent.height - maskThickness
                default:
                    return 0
                }
            }
        }
        width: axis.isVertical ? maskThickness : parent.width
        height: axis.isVertical ? parent.height : maskThickness
    }

    mask: Region {
        item: inputMask
    }

    Item {
        id: topBarCore
        anchors.fill: parent
        layer.enabled: true

        property real backgroundTransparency: SettingsData.dankBarTransparency
        property bool autoHide: SettingsData.dankBarAutoHide
        property bool revealSticky: false

        Timer {
            id: revealHold
            interval: SettingsData.dankBarAutoHideDelay
            repeat: false
            onTriggered: topBarCore.revealSticky = false
        }

        property bool reveal: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return SettingsData.dankBarOpenOnOverview || topBarMouseArea.containsMouse || hasActivePopout || revealSticky
            }
            return SettingsData.dankBarVisible && (!autoHide || topBarMouseArea.containsMouse || hasActivePopout || revealSticky)
        }

        readonly property bool hasActivePopout: {
            const loaders = [{
                                 "loader": appDrawerLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": dankDashPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": processListPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": notificationCenterLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": batteryPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": layoutPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": vpnPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": controlCenterLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": clipboardHistoryModalPopup,
                                 "prop": "visible"
                             }, {
                                 "loader": systemUpdateLoader,
                                 "prop": "shouldBeVisible"
                             }]
            return loaders.some(item => {
                                    if (item.loader && item.loader.item) {
                                        return item.loader.item[item.prop]
                                    }
                                    return false
                                }) || rootWindow.systemTrayMenuOpen
        }

        Connections {
            function onDankBarTransparencyChanged() {
                topBarCore.backgroundTransparency = SettingsData.dankBarTransparency
            }

            target: SettingsData
        }

        Connections {
            target: topBarMouseArea
            function onContainsMouseChanged() {
                if (topBarMouseArea.containsMouse) {
                    topBarCore.revealSticky = true
                    revealHold.stop()
                } else {
                    if (topBarCore.autoHide && !topBarCore.hasActivePopout) {
                        revealHold.restart()
                    }
                }
            }
        }

        onHasActivePopoutChanged: {
            if (hasActivePopout) {
                revealSticky = true
                revealHold.stop()
            } else if (autoHide && !topBarMouseArea.containsMouse) {
                revealSticky = true
                revealHold.restart()
            }
        }

        MouseArea {
            id: topBarMouseArea
            y: !barWindow.isVertical ? (SettingsData.dankBarPosition === SettingsData.Position.Bottom ? parent.height - height : 0) : 0
            x: barWindow.isVertical ? (SettingsData.dankBarPosition === SettingsData.Position.Right ? parent.width - width : 0) : 0
            height: !barWindow.isVertical ? Theme.px(barWindow.effectiveBarThickness + SettingsData.dankBarSpacing, barWindow._dpr) : undefined
            width: barWindow.isVertical ? Theme.px(barWindow.effectiveBarThickness + SettingsData.dankBarSpacing, barWindow._dpr) : undefined
            anchors {
                left: !barWindow.isVertical ? parent.left : (SettingsData.dankBarPosition === SettingsData.Position.Left ? parent.left : undefined)
                right: !barWindow.isVertical ? parent.right : (SettingsData.dankBarPosition === SettingsData.Position.Right ? parent.right : undefined)
                top: barWindow.isVertical ? parent.top : undefined
                bottom: barWindow.isVertical ? parent.bottom : undefined
            }
            readonly property bool inOverview: CompositorService.isNiri && NiriService.inOverview && SettingsData.dankBarOpenOnOverview
            hoverEnabled: SettingsData.dankBarAutoHide && !inOverview
            acceptedButtons: Qt.NoButton
            enabled: SettingsData.dankBarAutoHide && !inOverview

            Item {
                id: topBarContainer
                anchors.fill: parent

                transform: Translate {
                    id: topBarSlide
                    x: barWindow.isVertical ? Theme.snap(topBarCore.reveal ? 0 : (SettingsData.dankBarPosition === SettingsData.Position.Right ? barWindow.implicitWidth : -barWindow.implicitWidth), barWindow._dpr) : 0
                    y: !barWindow.isVertical ? Theme.snap(topBarCore.reveal ? 0 : (SettingsData.dankBarPosition === SettingsData.Position.Bottom ? barWindow.implicitHeight : -barWindow.implicitHeight), barWindow._dpr) : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    id: barUnitInset
                    anchors.fill: parent
                    anchors.leftMargin: !barWindow.isVertical ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : (axis.edge === "left" ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : 0)
                    anchors.rightMargin: !barWindow.isVertical ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : (axis.edge === "right" ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : 0)
                    anchors.topMargin: barWindow.isVertical ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : (axis.outerVisualEdge() === "bottom" ? 0 : Theme.px(SettingsData.dankBarSpacing, barWindow._dpr))
                    anchors.bottomMargin: barWindow.isVertical ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : (axis.outerVisualEdge() === "bottom" ? Theme.px(SettingsData.dankBarSpacing, barWindow._dpr) : 0)

                    BarCanvas {
                        id: barBackground
                        barWindow: barWindow
                        axis: axis
                    }

                    MouseArea {
                        id: scrollArea
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        z: -1

                        property real scrollAccumulator: 0
                        property real touchpadThreshold: 500
                        property bool actionInProgress: false

                        Timer {
                            id: cooldownTimer
                            interval: 100
                            onTriggered: parent.actionInProgress = false
                        }

                        onWheel: wheel => {
                            if (actionInProgress) {
                                wheel.accepted = false
                                return
                            }

                            const deltaY = wheel.angleDelta.y
                            const deltaX = wheel.angleDelta.x

                            if (CompositorService.isNiri && Math.abs(deltaX) > Math.abs(deltaY)) {
                                topBarContent.switchApp(deltaX)
                                wheel.accepted = false
                                return
                            }

                            const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0
                            const direction = deltaY < 0 ? 1 : -1

                            if (isMouseWheel) {
                                topBarContent.switchWorkspace(direction)
                                actionInProgress = true
                                cooldownTimer.restart()
                            } else {
                                scrollAccumulator += deltaY

                                if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                                    const touchDirection = scrollAccumulator < 0 ? 1 : -1
                                    topBarContent.switchWorkspace(touchDirection)
                                    scrollAccumulator = 0
                                    actionInProgress = true
                                    cooldownTimer.restart()
                                }
                            }

                            wheel.accepted = false
                        }
                    }

                    DankBarContent {
                        id: topBarContent
                        barWindow: barWindow
                        rootWindow: rootWindow
                    }
                }
            }
        }
    }
}
