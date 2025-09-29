import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.DankBar
import qs.Services
import qs.Widgets

Variants {
    id: dankBarVariants
    model: SettingsData.getFilteredScreens("dankBar")

    signal colorPickerRequested()

    function getNotepadInstanceForScreen() {
        if (typeof notepadSlideoutVariants === "undefined" || !notepadSlideoutVariants || !notepadSlideoutVariants.instances) {
            return null
        }

        for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
            var slideout = notepadSlideoutVariants.instances[i]
            if (slideout.modelData && slideout.modelData.name === root.screen?.name) {
                return slideout
            }
        }

        return notepadSlideoutVariants.instances.length > 0 ? notepadSlideoutVariants.instances[0] : null
    }

    delegate: PanelWindow {
        id: root

        WlrLayershell.namespace: "quickshell:bar"

        property var modelData: item

        property bool gothCornersEnabled: SettingsData.dankBarGothCornersEnabled
    property real wingtipsRadius: Theme.cornerRadius
    readonly property real _wingR: Math.max(0, wingtipsRadius)
    readonly property color _bgColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, topBarCore?.backgroundTransparency ?? SettingsData.dankBarTransparency)
    readonly property real _dpr: (root.screen && root.screen.devicePixelRatio) ? root.screen.devicePixelRatio : 1
    function px(v) { return Math.round(v * _dpr) / _dpr }
    property string screenName: modelData.name
    readonly property int notificationCount: NotificationService.notifications.length
    readonly property real effectiveBarHeight: Math.max(root.widgetHeight + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))
    readonly property real widgetHeight: Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)

    screen: modelData
    implicitHeight: px(effectiveBarHeight + SettingsData.dankBarSpacing + (SettingsData.dankBarGothCornersEnabled ? _wingR : 0))
    color: "transparent"
    Component.onCompleted: {
        const fonts = Qt.fontFamilies()
        if (fonts.indexOf("Material Symbols Rounded") === -1) {
            ToastService.showError("Please install Material Symbols Rounded and Restart your Shell. See README.md for instructions")
        }

        updateGpuTempConfig()
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

    Connections {
        function onDankBarLeftWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        function onDankBarCenterWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        function onDankBarRightWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        target: SettingsData
    }

    Connections {
        function onNvidiaGpuTempEnabledChanged() {
            root.updateGpuTempConfig()
        }

        function onNonNvidiaGpuTempEnabledChanged() {
            root.updateGpuTempConfig()
        }

        target: SessionData
    }

    Connections {
        target: root.screen
        function onGeometryChanged() {
            if (centerSection?.width > 0) {
                Qt.callLater(centerSection.updateLayout)
            }
        }
    }

    anchors {
        top: !SettingsData.dankBarAtBottom
        bottom: SettingsData.dankBarAtBottom
        left: true
        right: true
    }

    exclusiveZone: (!SettingsData.dankBarVisible || topBarCore.autoHide) ? -1 : (root.effectiveBarHeight + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap)

    Item {
        id: inputMask
        anchors {
            top: SettingsData.dankBarAtBottom ? undefined : parent.top
            bottom: SettingsData.dankBarAtBottom ? parent.bottom : undefined
            left: parent.left
            right: parent.right
        }
        height: {
            const base = px(root.effectiveBarHeight + SettingsData.dankBarSpacing)
            if (topBarCore.autoHide && !topBarCore.reveal) return 1
            if (CompositorService.isNiri && NiriService.inOverview && SettingsData.dankBarOpenOnOverview) return base
            return SettingsData.dankBarVisible ? base : 0
        }
    }

    mask: Region {
        item: inputMask
    }


    Item {
        id: topBarCore
        anchors.fill: parent

        property real backgroundTransparency: SettingsData.dankBarTransparency
        property bool autoHide: SettingsData.dankBarAutoHide
        property bool revealSticky: false

        Timer {
            id: revealHold
            interval: 250
            repeat: false
            onTriggered: topBarCore.revealSticky = false
        }

        property bool reveal: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return SettingsData.dankBarOpenOnOverview
            }
            return SettingsData.dankBarVisible && (!autoHide || topBarMouseArea.containsMouse || hasActivePopout || revealSticky)
        }

        property var notepadInstance: null
        property bool notepadInstanceVisible: notepadInstance?.isVisible ?? false
        
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
            return notepadInstanceVisible || loaders.some(item => {
                if (item.loader) {
                    return item.loader?.item?.[item.prop]
                }
                return false
            })
        }

        Component.onCompleted: {
            notepadInstance = dankBarVariants.getNotepadInstanceForScreen()
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
            if (!hasActivePopout && autoHide && !topBarMouseArea.containsMouse) {
                revealSticky = true
                revealHold.restart()
            }
        }

        MouseArea {
            id: topBarMouseArea
            y: SettingsData.dankBarAtBottom ? parent.height - height : 0
            height: px(root.effectiveBarHeight + SettingsData.dankBarSpacing)
            anchors {
                left: parent.left
                right: parent.right
            }
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: true

            Item {
                id: topBarContainer
                anchors.fill: parent

                transform: Translate {
                    id: topBarSlide
                    y: px(topBarCore.reveal ? 0 : (SettingsData.dankBarAtBottom ? root.implicitHeight : -root.implicitHeight))

                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    id: barUnitInset
                    anchors.fill: parent
                    anchors.leftMargin: px(SettingsData.dankBarSpacing)
                    anchors.rightMargin: px(SettingsData.dankBarSpacing)
                    anchors.topMargin: SettingsData.dankBarAtBottom ? 0 : px(SettingsData.dankBarSpacing)
                    anchors.bottomMargin: SettingsData.dankBarAtBottom ? px(SettingsData.dankBarSpacing) : 0

                    Item {
                        id: barBackground
                        anchors.fill: parent
                        anchors.bottomMargin: -(SettingsData.dankBarGothCornersEnabled && !SettingsData.dankBarAtBottom ? root._wingR : 0)
                        anchors.topMargin: -(SettingsData.dankBarGothCornersEnabled && SettingsData.dankBarAtBottom ? root._wingR : 0)

                    Canvas {
                            id: barShape
                            anchors.fill: parent
                            antialiasing: true
                            renderTarget: Canvas.Image
                            canvasSize: Qt.size(px(width), px(height))

                            property real wing: SettingsData.dankBarGothCornersEnabled ? root._wingR : 0
                            property real rt: SettingsData.dankBarSquareCorners ? 0 : Theme.cornerRadius
                            property real h: height
                            property real contentH: height - wing
                            property real y0: SettingsData.dankBarAtBottom ? wing : 0

                            onWingChanged: requestPaint()
                            onRtChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            Connections {
                                target: root
                                function on_BgColorChanged() { barShape.requestPaint() }
                                function on_DprChanged() { barShape.requestPaint() }
                            }

                            onPaint: {
                                const ctx = getContext("2d")
                                const scale = root._dpr
                                const W = px(width)
                                const H_raw = px(height)
                                const R = px(wing)
                                const RT = px(rt)
                                const H = H_raw - (R > 0 ? R : 0)
                                const isBottom = SettingsData.dankBarAtBottom

                                ctx.scale(scale, scale)

                                function drawTopPath() {
                                    ctx.beginPath()
                                    ctx.moveTo(RT, 0)
                                    ctx.lineTo(W - RT, 0)
                                    ctx.arcTo(W, 0, W, RT, RT)
                                    ctx.lineTo(W, H)

                                    if (R > 0) {
                                        ctx.lineTo(W, H + R)
                                        ctx.arc(W - R, H + R, R, 0, -Math.PI / 2, true)
                                        ctx.lineTo(R, H)
                                        ctx.arc(R, H + R, R, -Math.PI / 2, -Math.PI, true)
                                        ctx.lineTo(0, H + R)
                                    } else {
                                        ctx.lineTo(W, H - RT)
                                        ctx.arcTo(W, H, W - RT, H, RT)
                                        ctx.lineTo(RT, H)
                                        ctx.arcTo(0, H, 0, H - RT, RT)
                                    }

                                    ctx.lineTo(0, RT)
                                    ctx.arcTo(0, 0, RT, 0, RT)
                                    ctx.closePath()
                                }

                                ctx.reset()
                                ctx.clearRect(0, 0, W, H_raw)

                                if (isBottom) {
                                    ctx.save()
                                    ctx.translate(0, H_raw)
                                    ctx.scale(1, -1)
                                    drawTopPath()
                                    ctx.restore()
                                } else {
                                    drawTopPath()
                                }

                                ctx.fillStyle = root._bgColor
                                ctx.fill()

                            }

                        }

                        Canvas {
                            id: barTint
                            anchors.fill: parent
                            antialiasing: true
                            renderTarget: Canvas.Image
                            canvasSize: Qt.size(px(width), px(height))

                            property real wing: SettingsData.dankBarGothCornersEnabled ? root._wingR : 0
                            property real rt: SettingsData.dankBarSquareCorners ? 0 : Theme.cornerRadius
                            property real h: height
                            property real contentH: height - wing
                            property real y0: SettingsData.dankBarAtBottom ? wing : 0
                            property real alphaTint: (root._bgColor?.a ?? 1) < 0.99 ? (Theme.stateLayerOpacity ?? 0) : 0

                            onWingChanged: requestPaint()
                            onRtChanged: requestPaint()
                            onAlphaTintChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            Connections {
                                target: root
                                function on_BgColorChanged() { barTint.requestPaint() }
                                function on_DprChanged() { barTint.requestPaint() }
                            }

                            onPaint: {
                                const ctx = getContext("2d")
                                const scale = root._dpr
                                const W = px(width)
                                const H_raw = px(height)
                                const R = px(wing)
                                const RT = px(rt)
                                const H = H_raw - (R > 0 ? R : 0)
                                const isBottom = SettingsData.dankBarAtBottom

                                ctx.scale(scale, scale)

                                function drawTopPath() {
                                    ctx.beginPath()
                                    ctx.moveTo(RT, 0)
                                    ctx.lineTo(W - RT, 0)
                                    ctx.arcTo(W, 0, W, RT, RT)
                                    ctx.lineTo(W, H)

                                    if (R > 0) {
                                        ctx.lineTo(W, H + R)
                                        ctx.arc(W - R, H + R, R, 0, -Math.PI / 2, true)
                                        ctx.lineTo(R, H)
                                        ctx.arc(R, H + R, R, -Math.PI / 2, -Math.PI, true)
                                        ctx.lineTo(0, H + R)
                                    } else {
                                        ctx.lineTo(W, H - RT)
                                        ctx.arcTo(W, H, W - RT, H, RT)
                                        ctx.lineTo(RT, H)
                                        ctx.arcTo(0, H, 0, H - RT, RT)
                                    }

                                    ctx.lineTo(0, RT)
                                    ctx.arcTo(0, 0, RT, 0, RT)
                                    ctx.closePath()
                                }

                                ctx.reset()
                                ctx.clearRect(0, 0, W, H_raw)

                                if (isBottom) {
                                    ctx.save()
                                    ctx.translate(0, H_raw)
                                    ctx.scale(1, -1)
                                    drawTopPath()
                                    ctx.restore()
                                } else {
                                    drawTopPath()
                                }

                                ctx.fillStyle = Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, alphaTint)
                                ctx.fill()

                            }
                        }
                    }

                    Item {
                        id: topBarContent
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(Theme.spacingXS, SettingsData.dankBarInnerPadding * 0.8)
                        anchors.rightMargin: Math.max(Theme.spacingXS, SettingsData.dankBarInnerPadding * 0.8)
                        anchors.topMargin: SettingsData.dankBarInnerPadding / 2
                        anchors.bottomMargin: SettingsData.dankBarInnerPadding / 2
                        clip: true

                    readonly property int availableWidth: width
                        readonly property int launcherButtonWidth: 40
                        readonly property int workspaceSwitcherWidth: 120
                        readonly property int focusedAppMaxWidth: 456
                        readonly property int estimatedLeftSectionWidth: launcherButtonWidth + workspaceSwitcherWidth + focusedAppMaxWidth + (Theme.spacingXS * 2)
                        readonly property int rightSectionWidth: rightSection.width
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
                        readonly property bool spacingTight: validLayout && (leftToMediaGap < 150 || clockToRightGap < 100)
                        readonly property bool overlapping: validLayout && (leftToMediaGap < 100 || clockToRightGap < 50)

                        function getWidgetEnabled(enabled) {
                            return enabled !== false
                        }

                        function getWidgetSection(parentItem) {
                            if (!parentItem?.parent) {
                                return "left"
                            }
                            if (parentItem.parent === leftSection) {
                                return "left"
                            }
                            if (parentItem.parent === rightSection) {
                                return "right"
                            }
                            if (parentItem.parent === centerSection) {
                                return "center"
                            }
                            return "left"
                        }

                        readonly property var widgetVisibility: ({
                                                                     "cpuUsage": DgopService.dgopAvailable,
                                                                     "memUsage": DgopService.dgopAvailable,
                                                                     "cpuTemp": DgopService.dgopAvailable,
                                                                     "gpuTemp": DgopService.dgopAvailable,
                                                                     "network_speed_monitor": DgopService.dgopAvailable
                                                                 })

                        function getWidgetVisible(widgetId) {
                            return widgetVisibility[widgetId] ?? true
                        }

                        readonly property var componentMap: ({
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
                                                                 "controlCenterButton": controlCenterButtonComponent,
                                                                 "idleInhibitor": idleInhibitorComponent,
                                                                 "spacer": spacerComponent,
                                                                 "separator": separatorComponent,
                                                                 "network_speed_monitor": networkComponent,
                                                                 "keyboard_layout_name": keyboardLayoutNameComponent,
                                                                 "vpn": vpnComponent,
                                                                 "notepadButton": notepadButtonComponent,
                                                                 "colorPicker": colorPickerComponent,
                                                                 "systemUpdate": systemUpdateComponent
                                                             })

                        function getWidgetComponent(widgetId) {
                            return componentMap[widgetId] || null
                        }

                        Row {
                            id: leftSection

                            height: parent.height
                            spacing: SettingsData.dankBarNoBackground ? 2 : Theme.spacingXS
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: SettingsData.dankBarLeftWidgetsModel

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    active: topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false
                                }
                            }
                        }

                        Item {
                            id: centerSection

                            property var centerWidgets: []
                            property int totalWidgets: 0
                            property real totalWidth: 0
                            property real spacing: SettingsData.dankBarNoBackground ? 2 : Theme.spacingXS

                            function updateLayout() {
                                if (width <= 0 || height <= 0 || !visible) {
                                    Qt.callLater(updateLayout)
                                    return
                                }

                                centerWidgets = []
                                totalWidgets = 0
                                totalWidth = 0

                                let configuredWidgets = 0
                                for (var i = 0; i < centerRepeater.count; i++) {
                                    const item = centerRepeater.itemAt(i)
                                    if (item && topBarContent.getWidgetVisible(item.widgetId)) {
                                        configuredWidgets++
                                        if (item.active && item.item) {
                                            centerWidgets.push(item.item)
                                            totalWidgets++
                                            totalWidth += item.item.width
                                        }
                                    }
                                }

                                if (totalWidgets > 1) {
                                    totalWidth += spacing * (totalWidgets - 1)
                                }
                                positionWidgets(configuredWidgets)
                            }

                            function positionWidgets(configuredWidgets) {
                                if (totalWidgets === 0 || width <= 0) {
                                    return
                                }

                                const parentCenterX = width / 2
                                const isOdd = configuredWidgets % 2 === 1

                                centerWidgets.forEach(widget => widget.anchors.horizontalCenter = undefined)

                                if (isOdd) {
                                    const middleIndex = Math.floor(configuredWidgets / 2)
                                    let currentActiveIndex = 0
                                    let middleWidget = null

                                    for (var i = 0; i < centerRepeater.count; i++) {
                                        const item = centerRepeater.itemAt(i)
                                        if (item && topBarContent.getWidgetVisible(item.widgetId)) {
                                            if (currentActiveIndex === middleIndex && item.active && item.item) {
                                                middleWidget = item.item
                                                break
                                            }
                                            currentActiveIndex++
                                        }
                                    }

                                    if (middleWidget) {
                                        middleWidget.x = parentCenterX - (middleWidget.width / 2)

                                        let leftWidgets = []
                                        let rightWidgets = []
                                        let foundMiddle = false

                                        for (var i = 0; i < centerWidgets.length; i++) {
                                            if (centerWidgets[i] === middleWidget) {
                                                foundMiddle = true
                                                continue
                                            }
                                            if (!foundMiddle) {
                                                leftWidgets.push(centerWidgets[i])
                                            } else {
                                                rightWidgets.push(centerWidgets[i])
                                            }
                                        }

                                        let currentX = middleWidget.x
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= (spacing + leftWidgets[i].width)
                                            leftWidgets[i].x = currentX
                                        }

                                        currentX = middleWidget.x + middleWidget.width
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    }
                                } else {
                                    let configuredLeftIndex = (configuredWidgets / 2) - 1
                                    let configuredRightIndex = configuredWidgets / 2
                                    const halfSpacing = spacing / 2

                                    let leftWidget = null
                                    let rightWidget = null
                                    let leftWidgets = []
                                    let rightWidgets = []

                                    let currentConfigIndex = 0
                                    for (var i = 0; i < centerRepeater.count; i++) {
                                        const item = centerRepeater.itemAt(i)
                                        if (item && topBarContent.getWidgetVisible(item.widgetId)) {
                                            if (item.active && item.item) {
                                                if (currentConfigIndex < configuredLeftIndex) {
                                                    leftWidgets.push(item.item)
                                                } else if (currentConfigIndex === configuredLeftIndex) {
                                                    leftWidget = item.item
                                                } else if (currentConfigIndex === configuredRightIndex) {
                                                    rightWidget = item.item
                                                } else {
                                                    rightWidgets.push(item.item)
                                                }
                                            }
                                            currentConfigIndex++
                                        }
                                    }

                                    if (leftWidget && rightWidget) {
                                        leftWidget.x = parentCenterX - halfSpacing - leftWidget.width
                                        rightWidget.x = parentCenterX + halfSpacing

                                        let currentX = leftWidget.x
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= (spacing + leftWidgets[i].width)
                                            leftWidgets[i].x = currentX
                                        }

                                        currentX = rightWidget.x + rightWidget.width
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    } else if (leftWidget && !rightWidget) {
                                        leftWidget.x = parentCenterX - halfSpacing - leftWidget.width

                                        let currentX = leftWidget.x
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= (spacing + leftWidgets[i].width)
                                            leftWidgets[i].x = currentX
                                        }

                                        currentX = leftWidget.x + leftWidget.width + spacing
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    } else if (!leftWidget && rightWidget) {
                                        rightWidget.x = parentCenterX + halfSpacing

                                        let currentX = rightWidget.x - spacing
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= leftWidgets[i].width
                                            leftWidgets[i].x = currentX
                                            currentX -= spacing
                                        }

                                        currentX = rightWidget.x + rightWidget.width
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    } else if (totalWidgets === 1 && centerWidgets[0]) {
                                        centerWidgets[0].x = parentCenterX - (centerWidgets[0].width / 2)
                                    }
                                }
                            }

                            height: parent.height
                            width: parent.width
                            anchors.centerIn: parent
                            Component.onCompleted: {
                                Qt.callLater(() => {
                                                 Qt.callLater(updateLayout)
                                             })
                            }

                            onWidthChanged: {
                                if (width > 0) {
                                    Qt.callLater(updateLayout)
                                }
                            }

                            onVisibleChanged: {
                                if (visible && width > 0) {
                                    Qt.callLater(updateLayout)
                                }
                            }

                            Repeater {
                                id: centerRepeater

                                model: SettingsData.dankBarCenterWidgetsModel

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    active: topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false

                                    onLoaded: {
                                        if (!item) {
                                            return
                                        }
                                        item.onWidthChanged.connect(centerSection.updateLayout)
                                        if (model.widgetId === "spacer") {
                                            item.spacerSize = Qt.binding(() => model.size || 20)
                                        }
                                        Qt.callLater(centerSection.updateLayout)
                                    }
                                    onActiveChanged: {
                                        Qt.callLater(centerSection.updateLayout)
                                    }
                                }
                            }

                            Connections {
                                function onCountChanged() {
                                    Qt.callLater(centerSection.updateLayout)
                                }

                                target: SettingsData.dankBarCenterWidgetsModel
                            }
                        }

                        Row {
                            id: rightSection

                            height: parent.height
                            spacing: SettingsData.dankBarNoBackground ? 2 : Theme.spacingXS
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: SettingsData.dankBarRightWidgetsModel

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    active: topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false
                                }
                            }
                        }

                        Component {
                            id: clipboardComponent

                            Rectangle {
                                readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (root.widgetHeight / 30))
                                width: clipboardIcon.width + horizontalPadding * 2
                                height: root.widgetHeight
                                radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
                                color: {
                                    if (SettingsData.dankBarNoBackground) {
                                        return "transparent"
                                    }
                                    const baseColor = clipboardArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
                                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
                                }

                                DankIcon {
                                    id: clipboardIcon
                                    anchors.centerIn: parent
                                    name: "content_paste"
                                    size: Theme.iconSize - 6
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: clipboardArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        clipboardHistoryModalPopup.toggle()
                                    }
                                }

                            }
                        }

                        Component {
                            id: launcherButtonComponent

                            LauncherButton {
                                isActive: false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent)
                                popupTarget: appDrawerLoader.item
                                parentScreen: root.screen
                                onClicked: {
                                    appDrawerLoader.active = true
                                    appDrawerLoader.item?.toggle()
                                }
                            }
                        }

                        Component {
                            id: workspaceSwitcherComponent

                            WorkspaceSwitcher {
                                screenName: root.screenName
                                widgetHeight: root.widgetHeight
                            }
                        }

                        Component {
                            id: focusedWindowComponent

                            FocusedApp {
                                availableWidth: topBarContent.leftToMediaGap
                                widgetHeight: root.widgetHeight
                            }
                        }

                        Component {
                            id: runningAppsComponent

                            RunningApps {
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent)
                                parentScreen: root.screen
                                topBar: topBarContent
                            }
                        }

                        Component {
                            id: clockComponent

                            Clock {
                                compactMode: topBarContent.overlapping
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                popupTarget: {
                                    dankDashPopoutLoader.active = true
                                    return dankDashPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onClockClicked: {
                                    dankDashPopoutLoader.active = true
                                    if (dankDashPopoutLoader.item) {
                                        dankDashPopoutLoader.item.dashVisible = !dankDashPopoutLoader.item.dashVisible
                                        dankDashPopoutLoader.item.currentTabIndex = 0
                                    }
                                }
                            }
                        }

                        Component {
                            id: mediaComponent

                            Media {
                                compactMode: topBarContent.spacingTight || topBarContent.overlapping
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                popupTarget: {
                                    dankDashPopoutLoader.active = true
                                    return dankDashPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onClicked: {
                                    dankDashPopoutLoader.active = true
                                    if (dankDashPopoutLoader.item) {
                                        dankDashPopoutLoader.item.dashVisible = !dankDashPopoutLoader.item.dashVisible
                                        dankDashPopoutLoader.item.currentTabIndex = 1
                                    }
                                }
                            }
                        }

                        Component {
                            id: weatherComponent

                            Weather {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                popupTarget: {
                                    dankDashPopoutLoader.active = true
                                    return dankDashPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onClicked: {
                                    dankDashPopoutLoader.active = true
                                    if (dankDashPopoutLoader.item) {
                                        dankDashPopoutLoader.item.dashVisible = !dankDashPopoutLoader.item.dashVisible
                                        dankDashPopoutLoader.item.currentTabIndex = 2
                                    }
                                }
                            }
                        }

                        Component {
                            id: systemTrayComponent

                            SystemTrayBar {
                                parentWindow: root
                                parentScreen: root.screen
                                widgetHeight: root.widgetHeight
                                isAtBottom: SettingsData.dankBarAtBottom
                                visible: SettingsData.getFilteredScreens("systemTray").includes(root.screen)
                            }
                        }

                        Component {
                            id: privacyIndicatorComponent

                            PrivacyIndicator {
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: cpuUsageComponent

                            CpuMonitor {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
                                                   }
                            }
                        }

                        Component {
                            id: memUsageComponent

                            RamMonitor {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
                                                   }
                            }
                        }

                        Component {
                            id: diskUsageComponent

                            DiskUsage {
                                widgetHeight: root.widgetHeight
                                widgetData: parent.widgetData
                            }
                        }

                        Component {
                            id: cpuTempComponent

                            CpuTemperature {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
                                                   }
                            }
                        }

                        Component {
                            id: gpuTempComponent

                            GpuTemperature {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                widgetData: parent.widgetData
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
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
                                hasUnread: root.notificationCount > 0
                                isActive: notificationCenterLoader.item ? notificationCenterLoader.item.shouldBeVisible : false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    notificationCenterLoader.active = true
                                    return notificationCenterLoader.item
                                }
                                parentScreen: root.screen
                                onClicked: {
                                    notificationCenterLoader.active = true
                                    notificationCenterLoader.item?.toggle()
                                }
                            }
                        }

                        Component {
                            id: batteryComponent

                            Battery {
                                batteryPopupVisible: batteryPopoutLoader.item ? batteryPopoutLoader.item.shouldBeVisible : false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    batteryPopoutLoader.active = true
                                    return batteryPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onToggleBatteryPopup: {
                                    batteryPopoutLoader.active = true
                                    batteryPopoutLoader.item?.toggle()
                                }
                            }
                        }

                        Component {
                            id: vpnComponent

                            Vpn {
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    vpnPopoutLoader.active = true
                                    return vpnPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onToggleVpnPopup: {
                                    vpnPopoutLoader.active = true
                                    vpnPopoutLoader.item?.toggle()
                                }
                            }
                        }

                        Component {
                            id: controlCenterButtonComponent

                            ControlCenterButton {
                                isActive: controlCenterLoader.item ? controlCenterLoader.item.shouldBeVisible : false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    controlCenterLoader.active = true
                                    return controlCenterLoader.item
                                }
                                parentScreen: root.screen
                                widgetData: parent.widgetData
                                onClicked: {
                                    controlCenterLoader.active = true
                                    if (!controlCenterLoader.item) {
                                        return
                                    }
                                    controlCenterLoader.item.triggerScreen = root.screen
                                    controlCenterLoader.item.toggle()
                                    if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
                                        NetworkService.scanWifi()
                                    }
                                }
                            }
                        }

                        Component {
                            id: idleInhibitorComponent

                            IdleInhibitor {
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: spacerComponent

                            Item {
                                width: parent.spacerSize || 20
                                height: root.widgetHeight

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
                                        onEntered: parent.visible = true
                                        onExited: parent.visible = false
                                    }
                                }
                            }
                        }

                        Component {
                            id: separatorComponent

                            Rectangle {
                                width: 1
                                height: root.widgetHeight * 0.67
                                color: Theme.outline
                                opacity: 0.3
                            }
                        }

                        Component {
                            id: keyboardLayoutNameComponent

                            KeyboardLayoutName {}
                        }

                        Component {
                            id: notepadButtonComponent

                            NotepadButton {
                                property var notepadInstance: topBarCore.notepadInstance
                                isActive: notepadInstance?.isVisible ?? false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: notepadInstance
                                parentScreen: root.screen
                                onClicked: {
                                    if (notepadInstance) {
                                        notepadInstance.toggle()
                                    }
                                }
                            }
                        }

                        Component {
                            id: colorPickerComponent

                            ColorPicker {
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                                onColorPickerRequested: {
                                    dankBarVariants.colorPickerRequested()
                                }
                            }
                        }

                        Component {
                            id: systemUpdateComponent

                            SystemUpdate {
                                isActive: systemUpdateLoader.item ? systemUpdateLoader.item.shouldBeVisible : false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    systemUpdateLoader.active = true
                                    return systemUpdateLoader.item
                                }
                                parentScreen: root.screen
                                onClicked: {
                                    systemUpdateLoader.active = true
                                    systemUpdateLoader.item?.toggle()
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }
}