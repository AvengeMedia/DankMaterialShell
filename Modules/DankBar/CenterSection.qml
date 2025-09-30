import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var widgetsModel: null
    property var components: null
    property bool noBackground: false
    required property var axis

    readonly property bool isVertical: axis?.isVertical ?? false
    readonly property real spacing: noBackground ? 2 : Theme.spacingXS

    property var centerWidgets: []
    property int totalWidgets: 0
    property real totalSize: 0

    function updateLayout() {
        const containerSize = isVertical ? height : width
        if (containerSize <= 0 || !visible) {
            return
        }

        centerWidgets = []
        totalWidgets = 0
        totalSize = 0

        let configuredWidgets = 0
        for (var i = 0; i < centerRepeater.count; i++) {
            const item = centerRepeater.itemAt(i)
            if (item && getWidgetVisible(item.widgetId)) {
                configuredWidgets++
                if (item.active && item.item) {
                    centerWidgets.push(item.item)
                    totalWidgets++
                    totalSize += isVertical ? item.item.height : item.item.width
                }
            }
        }

        if (totalWidgets > 1) {
            totalSize += spacing * (totalWidgets - 1)
        }

        positionWidgets(configuredWidgets)
    }

    function positionWidgets(configuredWidgets) {
        if (totalWidgets === 0 || (isVertical ? height : width) <= 0) {
            return
        }

        const parentCenter = (isVertical ? height : width) / 2
        const isOdd = configuredWidgets % 2 === 1

        centerWidgets.forEach(widget => {
            if (isVertical) {
                widget.anchors.verticalCenter = undefined
            } else {
                widget.anchors.horizontalCenter = undefined
            }
        })

        if (isOdd) {
            const middleIndex = Math.floor(configuredWidgets / 2)
            let currentActiveIndex = 0
            let middleWidget = null

            for (var i = 0; i < centerRepeater.count; i++) {
                const item = centerRepeater.itemAt(i)
                if (item && getWidgetVisible(item.widgetId)) {
                    if (currentActiveIndex === middleIndex && item.active && item.item) {
                        middleWidget = item.item
                        break
                    }
                    currentActiveIndex++
                }
            }

            if (middleWidget) {
                const middleSize = isVertical ? middleWidget.height : middleWidget.width
                if (isVertical) {
                    middleWidget.y = parentCenter - (middleSize / 2)
                } else {
                    middleWidget.x = parentCenter - (middleSize / 2)
                }

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

                let currentPos = isVertical ? middleWidget.y : middleWidget.x
                for (var i = leftWidgets.length - 1; i >= 0; i--) {
                    const size = isVertical ? leftWidgets[i].height : leftWidgets[i].width
                    currentPos -= (spacing + size)
                    if (isVertical) {
                        leftWidgets[i].y = currentPos
                    } else {
                        leftWidgets[i].x = currentPos
                    }
                }

                currentPos = (isVertical ? middleWidget.y : middleWidget.x) + middleSize
                for (var i = 0; i < rightWidgets.length; i++) {
                    currentPos += spacing
                    if (isVertical) {
                        rightWidgets[i].y = currentPos
                    } else {
                        rightWidgets[i].x = currentPos
                    }
                    currentPos += isVertical ? rightWidgets[i].height : rightWidgets[i].width
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
                if (item && getWidgetVisible(item.widgetId)) {
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
                const leftSize = isVertical ? leftWidget.height : leftWidget.width
                if (isVertical) {
                    leftWidget.y = parentCenter - halfSpacing - leftSize
                    rightWidget.y = parentCenter + halfSpacing
                } else {
                    leftWidget.x = parentCenter - halfSpacing - leftSize
                    rightWidget.x = parentCenter + halfSpacing
                }

                let currentPos = isVertical ? leftWidget.y : leftWidget.x
                for (var i = leftWidgets.length - 1; i >= 0; i--) {
                    const size = isVertical ? leftWidgets[i].height : leftWidgets[i].width
                    currentPos -= (spacing + size)
                    if (isVertical) {
                        leftWidgets[i].y = currentPos
                    } else {
                        leftWidgets[i].x = currentPos
                    }
                }

                currentPos = (isVertical ? rightWidget.y + rightWidget.height : rightWidget.x + rightWidget.width)
                for (var i = 0; i < rightWidgets.length; i++) {
                    currentPos += spacing
                    if (isVertical) {
                        rightWidgets[i].y = currentPos
                    } else {
                        rightWidgets[i].x = currentPos
                    }
                    currentPos += isVertical ? rightWidgets[i].height : rightWidgets[i].width
                }
            } else if (leftWidget && !rightWidget) {
                const leftSize = isVertical ? leftWidget.height : leftWidget.width
                if (isVertical) {
                    leftWidget.y = parentCenter - halfSpacing - leftSize
                } else {
                    leftWidget.x = parentCenter - halfSpacing - leftSize
                }

                let currentPos = isVertical ? leftWidget.y : leftWidget.x
                for (var i = leftWidgets.length - 1; i >= 0; i--) {
                    const size = isVertical ? leftWidgets[i].height : leftWidgets[i].width
                    currentPos -= (spacing + size)
                    if (isVertical) {
                        leftWidgets[i].y = currentPos
                    } else {
                        leftWidgets[i].x = currentPos
                    }
                }

                currentPos = (isVertical ? leftWidget.y + leftWidget.height : leftWidget.x + leftWidget.width) + spacing
                for (var i = 0; i < rightWidgets.length; i++) {
                    currentPos += spacing
                    if (isVertical) {
                        rightWidgets[i].y = currentPos
                    } else {
                        rightWidgets[i].x = currentPos
                    }
                    currentPos += isVertical ? rightWidgets[i].height : rightWidgets[i].width
                }
            } else if (!leftWidget && rightWidget) {
                if (isVertical) {
                    rightWidget.y = parentCenter + halfSpacing
                } else {
                    rightWidget.x = parentCenter + halfSpacing
                }

                let currentPos = (isVertical ? rightWidget.y : rightWidget.x) - spacing
                for (var i = leftWidgets.length - 1; i >= 0; i--) {
                    const size = isVertical ? leftWidgets[i].height : leftWidgets[i].width
                    currentPos -= size
                    if (isVertical) {
                        leftWidgets[i].y = currentPos
                    } else {
                        leftWidgets[i].x = currentPos
                    }
                    currentPos -= spacing
                }

                currentPos = (isVertical ? rightWidget.y + rightWidget.height : rightWidget.x + rightWidget.width)
                for (var i = 0; i < rightWidgets.length; i++) {
                    currentPos += spacing
                    if (isVertical) {
                        rightWidgets[i].y = currentPos
                    } else {
                        rightWidgets[i].x = currentPos
                    }
                    currentPos += isVertical ? rightWidgets[i].height : rightWidgets[i].width
                }
            } else if (totalWidgets === 1 && centerWidgets[0]) {
                const size = isVertical ? centerWidgets[0].height : centerWidgets[0].width
                if (isVertical) {
                    centerWidgets[0].y = parentCenter - (size / 2)
                } else {
                    centerWidgets[0].x = parentCenter - (size / 2)
                }
            }
        }
    }

    function getWidgetVisible(widgetId) {
        const widgetVisibility = {
            "cpuUsage": DgopService.dgopAvailable,
            "memUsage": DgopService.dgopAvailable,
            "cpuTemp": DgopService.dgopAvailable,
            "gpuTemp": DgopService.dgopAvailable,
            "network_speed_monitor": DgopService.dgopAvailable
        }
        return widgetVisibility[widgetId] ?? true
    }

    function getWidgetComponent(widgetId) {
        // Build dynamic component map including plugins
        let baseMap = {
            "launcherButton": "launcherButtonComponent",
            "workspaceSwitcher": "workspaceSwitcherComponent",
            "focusedWindow": "focusedWindowComponent",
            "runningApps": "runningAppsComponent",
            "clock": "clockComponent",
            "music": "mediaComponent",
            "weather": "weatherComponent",
            "systemTray": "systemTrayComponent",
            "privacyIndicator": "privacyIndicatorComponent",
            "clipboard": "clipboardComponent",
            "cpuUsage": "cpuUsageComponent",
            "memUsage": "memUsageComponent",
            "diskUsage": "diskUsageComponent",
            "cpuTemp": "cpuTempComponent",
            "gpuTemp": "gpuTempComponent",
            "notificationButton": "notificationButtonComponent",
            "battery": "batteryComponent",
            "controlCenterButton": "controlCenterButtonComponent",
            "idleInhibitor": "idleInhibitorComponent",
            "spacer": "spacerComponent",
            "separator": "separatorComponent",
            "network_speed_monitor": "networkComponent",
            "keyboard_layout_name": "keyboardLayoutNameComponent",
            "vpn": "vpnComponent",
            "notepadButton": "notepadButtonComponent",
            "colorPicker": "colorPickerComponent",
            "systemUpdate": "systemUpdateComponent"
        }

        // For built-in components, get from components property
        const componentKey = baseMap[widgetId]
        if (componentKey && root.components[componentKey]) {
            return root.components[componentKey]
        }

        // For plugin components, get from PluginService
        let pluginMap = PluginService.getWidgetComponents()
        return pluginMap[widgetId] || null
    }

    height: parent.height
    width: parent.width
    anchors.centerIn: parent

    Timer {
        id: layoutTimer
        interval: 0
        repeat: false
        onTriggered: root.updateLayout()
    }

    Component.onCompleted: {
        layoutTimer.restart()
    }

    onWidthChanged: {
        if (width > 0) {
            layoutTimer.restart()
        }
    }

    onHeightChanged: {
        if (height > 0) {
            layoutTimer.restart()
        }
    }

    onVisibleChanged: {
        if (visible && (isVertical ? height : width) > 0) {
            layoutTimer.restart()
        }
    }

    Repeater {
        id: centerRepeater
        model: root.widgetsModel


        Loader {
            property string widgetId: model.widgetId
            property var widgetData: model
            property int spacerSize: model.size || 20

            anchors.verticalCenter: !root.isVertical ? parent.verticalCenter : undefined
            anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
            active: root.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
            sourceComponent: root.getWidgetComponent(model.widgetId)
            opacity: (model.enabled !== false) ? 1 : 0
            asynchronous: false

            onLoaded: {
                if (!item) {
                    return
                }
                item.widthChanged.connect(() => layoutTimer.restart())
                item.heightChanged.connect(() => layoutTimer.restart())
                if (model.widgetId === "spacer") {
                    item.spacerSize = Qt.binding(() => model.size || 20)
                }
                if (root.axis && "axis" in item) {
                    item.axis = root.axis
                }
                if (root.axis && "isVertical" in item) {
                    item.isVertical = root.axis.isVertical
                }

                // Inject PluginService for plugin widgets
                if (item.pluginService !== undefined) {
                    console.log("CenterSection: Injecting PluginService into plugin widget:", model.widgetId)
                    item.pluginService = PluginService
                    if (item.loadTimezones) {
                        console.log("CenterSection: Calling loadTimezones for widget:", model.widgetId)
                        item.loadTimezones()
                    }
                }

                layoutTimer.restart()
            }

            onActiveChanged: {
                layoutTimer.restart()
            }
        }
    }

    Connections {
        target: widgetsModel
        function onCountChanged() {
            layoutTimer.restart()
        }
    }

    // Listen for plugin changes and refresh components
    Connections {
        target: PluginService
        function onPluginLoaded(pluginId) {
            // Force refresh of component lookups
            for (var i = 0; i < centerRepeater.count; i++) {
                var item = centerRepeater.itemAt(i)
                if (item && item.widgetId === pluginId) {
                    item.sourceComponent = root.getWidgetComponent(pluginId)
                }
            }
        }
        function onPluginUnloaded(pluginId) {
            // Force refresh of component lookups
            for (var i = 0; i < centerRepeater.count; i++) {
                var item = centerRepeater.itemAt(i)
                if (item && item.widgetId === pluginId) {
                    item.sourceComponent = root.getWidgetComponent(pluginId)
                }
            }
        }
    }
}