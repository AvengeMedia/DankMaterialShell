import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.TopBar
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property var modelData
    property string screenName: modelData.name
    property real backgroundTransparency: SettingsData.topBarTransparency
    readonly property int notificationCount: NotificationService.notifications.length
    property bool autoHide: SettingsData.topBarAutoHide
    property bool reveal: SettingsData.topBarVisible && (!autoHide || topBarMouseArea.containsMouse)
    readonly property real effectiveBarHeight: Math.max(root.widgetHeight + SettingsData.topBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.topBarInnerPadding))
    readonly property real widgetHeight: Math.max(20, 26 + SettingsData.topBarInnerPadding * 0.6)

    screen: modelData
    implicitHeight: effectiveBarHeight + SettingsData.topBarSpacing
    color: "transparent"
    Component.onCompleted: {
        let fonts = Qt.fontFamilies()
        if (fonts.indexOf("Material Symbols Rounded") === -1)
            ToastService.showError(
                        "Please install Material Symbols Rounded and Restart your Shell. See README.md for instructions")

        SettingsData.forceTopBarLayoutRefresh.connect(function () {
            Qt.callLater(() => {
                             leftSection.visible = false
                             centerSection.visible = false
                             rightSection.visible = false
                             Qt.callLater(() => {
                                              leftSection.visible = true
                                              centerSection.visible = true
                                              rightSection.visible = true
                                          })
                         })
        })

        // Configure GPU temperature monitoring based on widget configuration
        updateGpuTempConfig()

        // Force widget initialization after brief delay to ensure services are loaded
        Qt.callLater(() => {
                         Qt.callLater(() => {
                                          forceWidgetRefresh()
                                      })
                     })
    }

    function forceWidgetRefresh() {
        // Force reload of all widget sections to handle race condition on desktop hardware
        if (leftSection)
            leftSection.visible = false
        if (centerSection)
            centerSection.visible = false
        if (rightSection)
            rightSection.visible = false

        Qt.callLater(() => {
                         if (leftSection)
                         leftSection.visible = true
                         if (centerSection)
                         centerSection.visible = true
                         if (rightSection)
                         rightSection.visible = true
                     })
    }

    function updateGpuTempConfig() {
        const allWidgets = [...(SettingsData.topBarLeftWidgets
                                || []), ...(SettingsData.topBarCenterWidgets
                                            || []), ...(SettingsData.topBarRightWidgets
                                                        || [])]

        const hasGpuTempWidget = allWidgets.some(widget => {
                                                     const widgetId = typeof widget
                                                     === "string" ? widget : widget.id
                                                     const widgetEnabled = typeof widget === "string" ? true : (widget.enabled !== false)
                                                     return widgetId === "gpuTemp"
                                                     && widgetEnabled
                                                 })

        DgopService.gpuTempEnabled = hasGpuTempWidget
                || SessionData.nvidiaGpuTempEnabled
                || SessionData.nonNvidiaGpuTempEnabled
        DgopService.nvidiaGpuTempEnabled = hasGpuTempWidget
                || SessionData.nvidiaGpuTempEnabled
        DgopService.nonNvidiaGpuTempEnabled = hasGpuTempWidget
                || SessionData.nonNvidiaGpuTempEnabled
    }

    Connections {
        function onTopBarTransparencyChanged() {
            root.backgroundTransparency = SettingsData.topBarTransparency
        }

        function onTopBarLeftWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        function onTopBarCenterWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        function onTopBarRightWidgetsChanged() {
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
            // Re-layout center widgets when screen geometry changes
            if (centerSection && centerSection.width > 0) {
                Qt.callLater(centerSection.updateLayout)
            }
        }
    }

    QtObject {
        id: notificationHistory

        property int count: 0
    }

    anchors {
        top: true
        left: true
        right: true
    }

    exclusiveZone: !SettingsData.topBarVisible || autoHide ? -1 : root.effectiveBarHeight + SettingsData.topBarSpacing - 2 + SettingsData.topBarBottomGap

    mask: Region {
        item: topBarMouseArea
    }

    MouseArea {
        id: topBarMouseArea
        height: root.reveal ? effectiveBarHeight + SettingsData.topBarSpacing : 4
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        hoverEnabled: true

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: topBarContainer
            anchors.fill: parent

            transform: Translate {
                id: topBarSlide
                y: root.reveal ? 0 : -(effectiveBarHeight - 4)

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.topMargin: SettingsData.topBarSpacing
                anchors.bottomMargin: 0
                anchors.leftMargin: SettingsData.topBarSpacing
                anchors.rightMargin: SettingsData.topBarSpacing

                Rectangle {
                    anchors.fill: parent
                    radius: SettingsData.topBarSquareCorners ? 0 : Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r,
                                   Theme.surfaceContainer.g,
                                   Theme.surfaceContainer.b,
                                   root.backgroundTransparency)
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Theme.outlineMedium
                        border.width: 1
                        radius: parent.radius
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Theme.surfaceTint.r,
                                       Theme.surfaceTint.g,
                                       Theme.surfaceTint.b, 0.04)
                        radius: parent.radius

                        SequentialAnimation on opacity {
                            running: false
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.08
                                duration: Theme.extraLongDuration
                                easing.type: Theme.standardEasing
                            }

                            NumberAnimation {
                                to: 0.02
                                duration: Theme.extraLongDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 4
                        shadowBlur: 0.5 // radius/32, adjusted for visual match
                        shadowColor: Qt.rgba(0, 0, 0, 0.15)
                        shadowOpacity: 0.15
                    }
                }

                Item {
                    id: topBarContent

                    readonly property int availableWidth: width
                    readonly property int launcherButtonWidth: 40
                    readonly property int workspaceSwitcherWidth: 120 // Approximate
                    readonly property int focusedAppMaxWidth: 456 // Fixed width since we don't have focusedApp reference
                    readonly property int estimatedLeftSectionWidth: launcherButtonWidth + workspaceSwitcherWidth + focusedAppMaxWidth + (Theme.spacingXS * 2)
                    readonly property int rightSectionWidth: rightSection.width
                    readonly property int clockWidth: 120 // Approximate clock width
                    readonly property int mediaMaxWidth: 280 // Normal max width
                    readonly property int weatherWidth: 80 // Approximate weather width
                    readonly property bool validLayout: availableWidth > 100
                                                        && estimatedLeftSectionWidth > 0
                                                        && rightSectionWidth > 0
                    readonly property int clockLeftEdge: (availableWidth - clockWidth) / 2
                    readonly property int clockRightEdge: clockLeftEdge + clockWidth
                    readonly property int leftSectionRightEdge: estimatedLeftSectionWidth
                    readonly property int mediaLeftEdge: clockLeftEdge - mediaMaxWidth
                                                         - Theme.spacingS
                    readonly property int rightSectionLeftEdge: availableWidth - rightSectionWidth
                    readonly property int leftToClockGap: Math.max(
                                                              0,
                                                              clockLeftEdge - leftSectionRightEdge)
                    readonly property int leftToMediaGap: mediaMaxWidth > 0 ? Math.max(0, mediaLeftEdge - leftSectionRightEdge) : leftToClockGap
                    readonly property int mediaToClockGap: mediaMaxWidth > 0 ? Theme.spacingS : 0
                    readonly property int clockToRightGap: validLayout ? Math.max(
                                                                             0,
                                                                             rightSectionLeftEdge - clockRightEdge) : 1000
                    readonly property bool spacingTight: validLayout
                                                         && (leftToMediaGap < 150
                                                             || clockToRightGap < 100)
                    readonly property bool overlapping: validLayout
                                                        && (leftToMediaGap < 100
                                                            || clockToRightGap < 50)

                    function getWidgetEnabled(enabled) {
                        return enabled !== undefined ? enabled : true
                    }

                    function getWidgetVisible(widgetId) {
                        switch (widgetId) {
                        case "launcherButton":
                            return true
                        case "workspaceSwitcher":
                            return true
                        case "focusedWindow":
                            return true
                        case "runningApps":
                            return true
                        case "clock":
                            return true
                        case "music":
                            return true
                        case "weather":
                            return true
                        case "systemTray":
                            return true
                        case "privacyIndicator":
                            return true
                        case "clipboard":
                            return true
                        case "cpuUsage":
                            return DgopService.dgopAvailable
                        case "memUsage":
                            return DgopService.dgopAvailable
                        case "cpuTemp":
                            return DgopService.dgopAvailable
                        case "gpuTemp":
                            return DgopService.dgopAvailable
                        case "notificationButton":
                            return true
                        case "battery":
                            return true
                        case "controlCenterButton":
                            return true
                        case "idleInhibitor":
                            return true
                        case "spacer":
                            return true
                        case "separator":
                            return true
                        case "network_speed_monitor":
                            return DgopService.dgopAvailable
                        case "keyboard_layout_name":
                            return true
                        case "vpn":
                            return true
                        case "notepadButton":
                            return true
                        default:
                            return false
                        }
                    }

                    function getWidgetComponent(widgetId) {
                        switch (widgetId) {
                        case "launcherButton":
                            return launcherButtonComponent
                        case "workspaceSwitcher":
                            return workspaceSwitcherComponent
                        case "focusedWindow":
                            return focusedWindowComponent
                        case "runningApps":
                            return runningAppsComponent
                        case "clock":
                            return clockComponent
                        case "music":
                            return mediaComponent
                        case "weather":
                            return weatherComponent
                        case "systemTray":
                            return systemTrayComponent
                        case "privacyIndicator":
                            return privacyIndicatorComponent
                        case "clipboard":
                            return clipboardComponent
                        case "cpuUsage":
                            return cpuUsageComponent
                        case "memUsage":
                            return memUsageComponent
                        case "cpuTemp":
                            return cpuTempComponent
                        case "gpuTemp":
                            return gpuTempComponent
                        case "notificationButton":
                            return notificationButtonComponent
                        case "battery":
                            return batteryComponent
                        case "controlCenterButton":
                            return controlCenterButtonComponent
                        case "idleInhibitor":
                            return idleInhibitorComponent
                        case "spacer":
                            return spacerComponent
                        case "separator":
                            return separatorComponent
                        case "network_speed_monitor":
                            return networkComponent
                        case "keyboard_layout_name":
                            return keyboardLayoutNameComponent
                        case "vpn":
                            return vpnComponent
                        case "notepadButton":
                            return notepadButtonComponent
                        default:
                            return null
                        }
                    }

                    anchors.fill: parent
                    anchors.leftMargin: Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
                    anchors.rightMargin: Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
                    anchors.topMargin: SettingsData.topBarInnerPadding / 2
                    anchors.bottomMargin: SettingsData.topBarInnerPadding / 2
                    clip: true

                    Row {
                        id: leftSection

                        height: parent.height
                        spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: SettingsData.topBarLeftWidgetsModel

                            Loader {
                                property string widgetId: model.widgetId
                                property var widgetData: model
                                property int spacerSize: model.size || 20

                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                active: topBarContent.getWidgetVisible(
                                            model.widgetId)
                                sourceComponent: topBarContent.getWidgetComponent(
                                                     model.widgetId)
                                opacity: topBarContent.getWidgetEnabled(
                                             model.enabled) ? 1 : 0
                                asynchronous: false
                                
                            }
                        }
                    }

                    Item {
                        id: centerSection

                        property var centerWidgets: []
                        property int totalWidgets: 0
                        property real totalWidth: 0
                        property real spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingS

                        function updateLayout() {
                            // Defer layout if dimensions are invalid
                            if (width <= 0 || height <= 0 || !visible) {
                                Qt.callLater(updateLayout)
                                return
                            }

                            centerWidgets = []
                            totalWidgets = 0
                            totalWidth = 0
                            for (var i = 0; i < centerRepeater.count; i++) {
                                let item = centerRepeater.itemAt(i)
                                if (item && item.active && item.item) {
                                    centerWidgets.push(item.item)
                                    totalWidgets++
                                    totalWidth += item.item.width
                                }
                            }
                            if (totalWidgets > 1)
                                totalWidth += spacing * (totalWidgets - 1)

                            positionWidgets()
                        }

                        function positionWidgets() {
                            if (totalWidgets === 0 || width <= 0)
                                return

                            let parentCenterX = width / 2
                            if (totalWidgets % 2 === 1) {
                                let middleIndex = Math.floor(totalWidgets / 2)
                                let currentX = parentCenterX
                                    - (centerWidgets[middleIndex].width / 2)
                                centerWidgets[middleIndex].x = currentX
                                centerWidgets[middleIndex].anchors.horizontalCenter = undefined
                                currentX = centerWidgets[middleIndex].x
                                for (var i = middleIndex - 1; i >= 0; i--) {
                                    currentX -= (spacing + centerWidgets[i].width)
                                    centerWidgets[i].x = currentX
                                    centerWidgets[i].anchors.horizontalCenter = undefined
                                }
                                currentX = centerWidgets[middleIndex].x
                                        + centerWidgets[middleIndex].width
                                for (var i = middleIndex + 1; i < totalWidgets; i++) {
                                    currentX += spacing
                                    centerWidgets[i].x = currentX
                                    centerWidgets[i].anchors.horizontalCenter = undefined
                                    currentX += centerWidgets[i].width
                                }
                            } else {
                                let leftMiddleIndex = (totalWidgets / 2) - 1
                                let rightMiddleIndex = totalWidgets / 2
                                let gapCenter = parentCenterX
                                let halfSpacing = spacing / 2
                                centerWidgets[leftMiddleIndex].x = gapCenter - halfSpacing
                                        - centerWidgets[leftMiddleIndex].width
                                centerWidgets[leftMiddleIndex].anchors.horizontalCenter = undefined
                                centerWidgets[rightMiddleIndex].x = gapCenter + halfSpacing
                                centerWidgets[rightMiddleIndex].anchors.horizontalCenter = undefined
                                let currentX = centerWidgets[leftMiddleIndex].x
                                for (var i = leftMiddleIndex - 1; i >= 0; i--) {
                                    currentX -= (spacing + centerWidgets[i].width)
                                    centerWidgets[i].x = currentX
                                    centerWidgets[i].anchors.horizontalCenter = undefined
                                }
                                currentX = centerWidgets[rightMiddleIndex].x
                                        + centerWidgets[rightMiddleIndex].width
                                for (var i = rightMiddleIndex + 1; i < totalWidgets; i++) {
                                    currentX += spacing
                                    centerWidgets[i].x = currentX
                                    centerWidgets[i].anchors.horizontalCenter = undefined
                                    currentX += centerWidgets[i].width
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

                            model: SettingsData.topBarCenterWidgetsModel

                            Loader {
                                property string widgetId: model.widgetId
                                property var widgetData: model
                                property int spacerSize: model.size || 20

                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                active: topBarContent.getWidgetVisible(
                                            model.widgetId)
                                sourceComponent: topBarContent.getWidgetComponent(
                                                     model.widgetId)
                                opacity: topBarContent.getWidgetEnabled(
                                             model.enabled) ? 1 : 0
                                asynchronous: false

                                onLoaded: {
                                    if (item) {
                                        item.onWidthChanged.connect(
                                                    centerSection.updateLayout)
                                        if (model.widgetId === "spacer")
                                            item.spacerSize = Qt.binding(() => {
                                                                             return model.size
                                                                             || 20
                                                                         })
                                        Qt.callLater(centerSection.updateLayout)
                                    }
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

                            target: SettingsData.topBarCenterWidgetsModel
                        }
                    }

                    Row {
                        id: rightSection

                        height: parent.height
                        spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: SettingsData.topBarRightWidgetsModel

                            Loader {
                                property string widgetId: model.widgetId
                                property var widgetData: model
                                property int spacerSize: model.size || 20

                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                active: topBarContent.getWidgetVisible(
                                            model.widgetId)
                                sourceComponent: topBarContent.getWidgetComponent(
                                                     model.widgetId)
                                opacity: topBarContent.getWidgetEnabled(
                                             model.enabled) ? 1 : 0
                                asynchronous: false
                                
                            }
                        }
                    }

                    Component {
                        id: clipboardComponent

                        Rectangle {
                            readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (root.widgetHeight / 30))
                            width: clipboardIcon.width + horizontalPadding * 2
                            height: root.widgetHeight
                            radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
                            color: {
                                if (SettingsData.topBarNoBackground) return "transparent"
                                const baseColor = clipboardArea.containsMouse ? Theme.primaryHover : Theme.secondaryHover
                                return Qt.rgba(
                                            baseColor.r, baseColor.g,
                                            baseColor.b,
                                            baseColor.a * Theme.widgetTransparency)
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

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
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
                            section: {
                                if (parent && parent.parent) {
                                    if (parent.parent === leftSection)
                                        return "left"
                                    if (parent.parent === rightSection)
                                        return "right"
                                    if (parent.parent === centerSection)
                                        return "center"
                                }
                                return "left"
                            }
                            popupTarget: appDrawerLoader.item
                            parentScreen: root.screen
                            onClicked: {
                                appDrawerLoader.active = true
                                if (appDrawerLoader.item)
                                    appDrawerLoader.item.toggle()
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
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "left"
                            }
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
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "center"
                            }
                            popupTarget: {
                                centcomPopoutLoader.active = true
                                return centcomPopoutLoader.item
                            }
                            parentScreen: root.screen
                            onClockClicked: {
                                centcomPopoutLoader.active = true
                                if (centcomPopoutLoader.item) {
                                    centcomPopoutLoader.item.calendarVisible
                                            = !centcomPopoutLoader.item.calendarVisible
                                }
                            }
                        }
                    }

                    Component {
                        id: mediaComponent

                        Media {
                            compactMode: topBarContent.spacingTight
                                         || topBarContent.overlapping
                            barHeight: root.effectiveBarHeight
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "center"
                            }
                            popupTarget: {
                                centcomPopoutLoader.active = true
                                return centcomPopoutLoader.item
                            }
                            parentScreen: root.screen
                            onClicked: {
                                centcomPopoutLoader.active = true
                                if (centcomPopoutLoader.item) {
                                    centcomPopoutLoader.item.calendarVisible
                                            = !centcomPopoutLoader.item.calendarVisible
                                }
                            }
                        }
                    }

                    Component {
                        id: weatherComponent

                        Weather {
                            barHeight: root.effectiveBarHeight
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "center"
                            }
                            popupTarget: {
                                centcomPopoutLoader.active = true
                                return centcomPopoutLoader.item
                            }
                            parentScreen: root.screen
                            onClicked: {
                                centcomPopoutLoader.active = true
                                if (centcomPopoutLoader.item) {
                                    centcomPopoutLoader.item.calendarVisible
                                            = !centcomPopoutLoader.item.calendarVisible
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
                        }
                    }

                    Component {
                        id: privacyIndicatorComponent

                        PrivacyIndicator {
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            parentScreen: root.screen
                        }
                    }

                    Component {
                        id: cpuUsageComponent

                        CpuMonitor {
                            barHeight: root.effectiveBarHeight
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                processListPopoutLoader.active = true
                                return processListPopoutLoader.item
                            }
                            parentScreen: root.screen
                            toggleProcessList: () => {
                                                   processListPopoutLoader.active = true
                                                   if (processListPopoutLoader.item)
                                                   return processListPopoutLoader.item.toggle()
                                               }
                        }
                    }

                    Component {
                        id: memUsageComponent

                        RamMonitor {
                            barHeight: root.effectiveBarHeight
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                processListPopoutLoader.active = true
                                return processListPopoutLoader.item
                            }
                            parentScreen: root.screen
                            toggleProcessList: () => {
                                                   processListPopoutLoader.active = true
                                                   if (processListPopoutLoader.item)
                                                   return processListPopoutLoader.item.toggle()
                                               }
                        }
                    }

                    Component {
                        id: cpuTempComponent

                        CpuTemperature {
                            barHeight: root.effectiveBarHeight
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                processListPopoutLoader.active = true
                                return processListPopoutLoader.item
                            }
                            parentScreen: root.screen
                            toggleProcessList: () => {
                                                   processListPopoutLoader.active = true
                                                   if (processListPopoutLoader.item)
                                                   return processListPopoutLoader.item.toggle()
                                               }
                        }
                    }

                    Component {
                        id: gpuTempComponent

                        GpuTemperature {
                            barHeight: root.effectiveBarHeight
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                processListPopoutLoader.active = true
                                return processListPopoutLoader.item
                            }
                            parentScreen: root.screen
                            widgetData: parent.widgetData
                            toggleProcessList: () => {
                                                   processListPopoutLoader.active = true
                                                   if (processListPopoutLoader.item)
                                                   return processListPopoutLoader.item.toggle()
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
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                notificationCenterLoader.active = true
                                return notificationCenterLoader.item
                            }
                            parentScreen: root.screen
                            onClicked: {
                                notificationCenterLoader.active = true
                                if (notificationCenterLoader.item) {
                                    notificationCenterLoader.item.toggle()
                                }
                            }
                        }
                    }

                    Component {
                        id: batteryComponent

                        Battery {
                            batteryPopupVisible: batteryPopoutLoader.item ? batteryPopoutLoader.item.shouldBeVisible : false
                            widgetHeight: root.widgetHeight
                            barHeight: root.effectiveBarHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                batteryPopoutLoader.active = true
                                return batteryPopoutLoader.item
                            }
                            parentScreen: root.screen
                            onToggleBatteryPopup: {
                                batteryPopoutLoader.active = true
                                if (batteryPopoutLoader.item) {
                                    batteryPopoutLoader.item.toggle()
                                }
                            }
                        }
                    }

                    Component {
                        id: vpnComponent

                        Vpn {
                            widgetHeight: root.widgetHeight
                            barHeight: root.effectiveBarHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                vpnPopoutLoader.active = true
                                return vpnPopoutLoader.item
                            }
                            parentScreen: root.screen
                            onToggleVpnPopup: {
                                vpnPopoutLoader.active = true
                                if (vpnPopoutLoader.item) {
                                    vpnPopoutLoader.item.toggle()
                                }
                            }
                        }
                    }

                    Component {
                        id: controlCenterButtonComponent

                        ControlCenterButton {
                            isActive: controlCenterLoader.item ? controlCenterLoader.item.shouldBeVisible : false
                            widgetHeight: root.widgetHeight
                            barHeight: root.effectiveBarHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                controlCenterLoader.active = true
                                return controlCenterLoader.item
                            }
                            parentScreen: root.screen
                            widgetData: parent.widgetData
                            onClicked: {
                                controlCenterLoader.active = true
                                if (controlCenterLoader.item) {
                                    controlCenterLoader.item.triggerScreen = root.screen
                                    controlCenterLoader.item.toggle()
                                    if (controlCenterLoader.item.shouldBeVisible) {
                                        if (NetworkService.wifiEnabled)
                                            NetworkService.scanWifi()
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: idleInhibitorComponent

                        IdleInhibitor {
                            widgetHeight: root.widgetHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
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
                                border.color: Qt.rgba(Theme.outline.r,
                                                      Theme.outline.g,
                                                      Theme.outline.b, 0.1)
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
                            isActive: notepadModalLoader.item ? notepadModalLoader.item.visible : false
                            widgetHeight: root.widgetHeight
                            barHeight: root.effectiveBarHeight
                            section: {
                                if (parent && parent.parent === leftSection)
                                    return "left"
                                if (parent && parent.parent === rightSection)
                                    return "right"
                                if (parent && parent.parent === centerSection)
                                    return "center"
                                return "right"
                            }
                            popupTarget: {
                                notepadModalLoader.active = true
                                return notepadModalLoader.item
                            }
                            parentScreen: root.screen
                            onClicked: {
                                notepadModalLoader.active = true
                                if (notepadModalLoader.item) {
                                    notepadModalLoader.item.toggle()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
