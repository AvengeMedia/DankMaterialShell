import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var widgetsModel: null
    property var components: null
    property bool noBackground: false
    required property var axis
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property bool overrideAxisLayout: false
    property bool forceVerticalLayout: false

    readonly property bool isVertical: overrideAxisLayout ? forceVerticalLayout : (axis?.isVertical ?? false)
    readonly property real spacing: noBackground ? 2 : Theme.spacingXS

    property var centerWidgets: []
    property int totalWidgets: 0
    property real totalSize: 0

    function updateLayout() {
        if ((isVertical ? height : width) <= 0 || !visible) {
            return;
        }

        centerWidgets = [];
        totalWidgets = 0;
        totalSize = 0;

        let configuredWidgets = 0;
        let configuredMiddleWidget = null;
        let configuredLeftWidget = null;
        let configuredRightWidget = null;

        for (var i = 0; i < centerRepeater.count; i++) {
            const item = centerRepeater.itemAt(i);
            if (item && getWidgetVisible(item.widgetId)) {
                configuredWidgets++;
            }
        }

        const isOddConfigured = configuredWidgets % 2 === 1;
        const configuredMiddlePos = Math.floor(configuredWidgets / 2);
        const configuredLeftPos = isOddConfigured ? -1 : ((configuredWidgets / 2) - 1);
        const configuredRightPos = isOddConfigured ? -1 : (configuredWidgets / 2);
        let currentConfigIndex = 0;

        for (var i = 0; i < centerRepeater.count; i++) {
            const item = centerRepeater.itemAt(i);
            if (item && getWidgetVisible(item.widgetId)) {
                if (isOddConfigured && currentConfigIndex === configuredMiddlePos && item.active && item.item) {
                    configuredMiddleWidget = item.item;
                }
                if (!isOddConfigured && currentConfigIndex === configuredLeftPos && item.active && item.item) {
                    configuredLeftWidget = item.item;
                }
                if (!isOddConfigured && currentConfigIndex === configuredRightPos && item.active && item.item) {
                    configuredRightWidget = item.item;
                }
                if (item.active && item.item) {
                    centerWidgets.push(item.item);
                    totalWidgets++;
                    totalSize += isVertical ? item.item.height : item.item.width;
                }
                currentConfigIndex++;
            }
        }

        if (totalWidgets === 0) {
            return;
        }

        if (totalWidgets > 1) {
            totalSize += spacing * (totalWidgets - 1);
        }

        positionWidgets(configuredWidgets, configuredMiddleWidget, configuredLeftWidget, configuredRightWidget);
    }

    function positionWidgets(configuredWidgets, configuredMiddleWidget, configuredLeftWidget, configuredRightWidget) {
        const parentCenter = (isVertical ? height : width) / 2;
        const isOddConfigured = configuredWidgets % 2 === 1;

        centerWidgets.forEach(widget => {
            if (isVertical) {
                widget.anchors.verticalCenter = undefined;
            } else {
                widget.anchors.horizontalCenter = undefined;
            }
        });

        if (isOddConfigured && configuredMiddleWidget) {
            const middleWidget = configuredMiddleWidget;
            const middleIndex = centerWidgets.indexOf(middleWidget);
            const middleSize = isVertical ? middleWidget.height : middleWidget.width;

            if (isVertical) {
                middleWidget.y = parentCenter - (middleSize / 2);
            } else {
                middleWidget.x = parentCenter - (middleSize / 2);
            }

            let currentPos = isVertical ? middleWidget.y : middleWidget.x;
            for (var i = middleIndex - 1; i >= 0; i--) {
                const size = isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                currentPos -= (spacing + size);
                if (isVertical) {
                    centerWidgets[i].y = currentPos;
                } else {
                    centerWidgets[i].x = currentPos;
                }
            }

            currentPos = (isVertical ? middleWidget.y : middleWidget.x) + middleSize;
            for (var i = middleIndex + 1; i < totalWidgets; i++) {
                currentPos += spacing;
                if (isVertical) {
                    centerWidgets[i].y = currentPos;
                } else {
                    centerWidgets[i].x = currentPos;
                }
                currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
            }
        } else {
            if (totalWidgets === 1) {
                const widget = centerWidgets[0];
                const size = isVertical ? widget.height : widget.width;
                if (isVertical) {
                    widget.y = parentCenter - (size / 2);
                } else {
                    widget.x = parentCenter - (size / 2);
                }
                return;
            }

            if (!configuredLeftWidget || !configuredRightWidget) {
                if (totalWidgets % 2 === 1) {
                    const middleIndex = Math.floor(totalWidgets / 2);
                    const middleWidget = centerWidgets[middleIndex];

                    if (!middleWidget) {
                        return;
                    }

                    const middleSize = isVertical ? middleWidget.height : middleWidget.width;

                    if (isVertical) {
                        middleWidget.y = parentCenter - (middleSize / 2);
                    } else {
                        middleWidget.x = parentCenter - (middleSize / 2);
                    }

                    let currentPos = isVertical ? middleWidget.y : middleWidget.x;
                    for (var i = middleIndex - 1; i >= 0; i--) {
                        const size = isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                        currentPos -= (spacing + size);
                        if (isVertical) {
                            centerWidgets[i].y = currentPos;
                        } else {
                            centerWidgets[i].x = currentPos;
                        }
                    }

                    currentPos = (isVertical ? middleWidget.y : middleWidget.x) + middleSize;
                    for (var i = middleIndex + 1; i < totalWidgets; i++) {
                        currentPos += spacing;
                        if (isVertical) {
                            centerWidgets[i].y = currentPos;
                        } else {
                            centerWidgets[i].x = currentPos;
                        }
                        currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                    }
                } else {
                    const leftIndex = (totalWidgets / 2) - 1;
                    const rightIndex = totalWidgets / 2;
                    const fallbackLeft = centerWidgets[leftIndex];
                    const fallbackRight = centerWidgets[rightIndex];

                    if (!fallbackLeft || !fallbackRight) {
                        return;
                    }

                    const halfSpacing = spacing / 2;
                    const leftSize = isVertical ? fallbackLeft.height : fallbackLeft.width;

                    if (isVertical) {
                        fallbackLeft.y = parentCenter - halfSpacing - leftSize;
                        fallbackRight.y = parentCenter + halfSpacing;
                    } else {
                        fallbackLeft.x = parentCenter - halfSpacing - leftSize;
                        fallbackRight.x = parentCenter + halfSpacing;
                    }

                    let currentPos = isVertical ? fallbackLeft.y : fallbackLeft.x;
                    for (var i = leftIndex - 1; i >= 0; i--) {
                        const size = isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                        currentPos -= (spacing + size);
                        if (isVertical) {
                            centerWidgets[i].y = currentPos;
                        } else {
                            centerWidgets[i].x = currentPos;
                        }
                    }

                    currentPos = (isVertical ? fallbackRight.y + fallbackRight.height : fallbackRight.x + fallbackRight.width);
                    for (var i = rightIndex + 1; i < totalWidgets; i++) {
                        currentPos += spacing;
                        if (isVertical) {
                            centerWidgets[i].y = currentPos;
                        } else {
                            centerWidgets[i].x = currentPos;
                        }
                        currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                    }
                }
                return;
            }

            const leftWidget = configuredLeftWidget;
            const rightWidget = configuredRightWidget;
            const leftIndex = centerWidgets.indexOf(leftWidget);
            const rightIndex = centerWidgets.indexOf(rightWidget);
            const halfSpacing = spacing / 2;
            const leftSize = isVertical ? leftWidget.height : leftWidget.width;

            if (isVertical) {
                leftWidget.y = parentCenter - halfSpacing - leftSize;
                rightWidget.y = parentCenter + halfSpacing;
            } else {
                leftWidget.x = parentCenter - halfSpacing - leftSize;
                rightWidget.x = parentCenter + halfSpacing;
            }

            let currentPos = isVertical ? leftWidget.y : leftWidget.x;
            for (var i = leftIndex - 1; i >= 0; i--) {
                const size = isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                currentPos -= (spacing + size);
                if (isVertical) {
                    centerWidgets[i].y = currentPos;
                } else {
                    centerWidgets[i].x = currentPos;
                }
            }

            currentPos = (isVertical ? rightWidget.y + rightWidget.height : rightWidget.x + rightWidget.width);
            for (var i = rightIndex + 1; i < totalWidgets; i++) {
                currentPos += spacing;
                if (isVertical) {
                    centerWidgets[i].y = currentPos;
                } else {
                    centerWidgets[i].x = currentPos;
                }
                currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
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
        };
        return widgetVisibility[widgetId] ?? true;
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
        };

        // For built-in components, get from components property
        const componentKey = baseMap[widgetId];
        if (componentKey && root.components[componentKey]) {
            return root.components[componentKey];
        }

        // For plugin components, get from PluginService
        var parts = widgetId.split(":");
        var pluginId = parts[0];
        let pluginComponents = PluginService.getWidgetComponents();
        return pluginComponents[pluginId] || null;
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
        layoutTimer.restart();
    }

    onWidthChanged: {
        if (width > 0) {
            layoutTimer.restart();
        }
    }

    onHeightChanged: {
        if (height > 0) {
            layoutTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible && (isVertical ? height : width) > 0) {
            layoutTimer.restart();
        }
    }

    Repeater {
        id: centerRepeater
        model: root.widgetsModel

        Loader {
            property var itemData: modelData
            property string widgetId: itemData.widgetId
            property var widgetData: itemData
            property int spacerSize: itemData.size || 20

            anchors.verticalCenter: !root.isVertical ? parent.verticalCenter : undefined
            anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
            active: root.getWidgetVisible(itemData.widgetId) && (itemData.widgetId !== "music" || MprisController.activePlayer !== null)
            sourceComponent: root.getWidgetComponent(itemData.widgetId)
            opacity: (itemData.enabled !== false) ? 1 : 0
            asynchronous: false

            onLoaded: {
                if (!item) {
                    return;
                }
                item.widthChanged.connect(() => {
                    if (layoutTimer)
                        layoutTimer.restart();
                });
                item.heightChanged.connect(() => {
                    if (layoutTimer)
                        layoutTimer.restart();
                });
                if (root.axis && "axis" in item) {
                    item.axis = Qt.binding(() => root.axis);
                }
                if (root.axis && "isVertical" in item) {
                    try {
                        item.isVertical = Qt.binding(() => root.axis.isVertical);
                    } catch (e) {}
                }

                // Inject properties for plugin widgets
                if ("section" in item) {
                    item.section = root.section;
                }
                if ("parentScreen" in item) {
                    item.parentScreen = Qt.binding(() => root.parentScreen);
                }
                if ("widgetThickness" in item) {
                    item.widgetThickness = Qt.binding(() => root.widgetThickness);
                }
                if ("barThickness" in item) {
                    item.barThickness = Qt.binding(() => root.barThickness);
                }
                if ("barSpacing" in item) {
                    item.barSpacing = Qt.binding(() => root.barSpacing);
                }
                if ("barConfig" in item) {
                    item.barConfig = Qt.binding(() => root.barConfig);
                }
                if ("sectionSpacing" in item) {
                    item.sectionSpacing = Qt.binding(() => root.spacing);
                }

                if ("isFirst" in item) {
                    item.isFirst = Qt.binding(() => {
                        for (var i = 0; i < centerRepeater.count; i++) {
                            const checkItem = centerRepeater.itemAt(i);
                            if (checkItem && checkItem.active && checkItem.item) {
                                return checkItem.item === item;
                            }
                        }
                        return false;
                    });
                }

                if ("isLast" in item) {
                    item.isLast = Qt.binding(() => {
                        for (var i = centerRepeater.count - 1; i >= 0; i--) {
                            const checkItem = centerRepeater.itemAt(i);
                            if (checkItem && checkItem.active && checkItem.item) {
                                return checkItem.item === item;
                            }
                        }
                        return false;
                    });
                }

                if ("isLeftBarEdge" in item) {
                    item.isLeftBarEdge = false;
                }
                if ("isRightBarEdge" in item) {
                    item.isRightBarEdge = false;
                }
                if ("isTopBarEdge" in item) {
                    item.isTopBarEdge = false;
                }
                if ("isBottomBarEdge" in item) {
                    item.isBottomBarEdge = false;
                }

                if (item.pluginService !== undefined) {
                    var parts = model.widgetId.split(":");
                    var pluginId = parts[0];
                    var variantId = parts.length > 1 ? parts[1] : null;

                    if (item.pluginId !== undefined) {
                        item.pluginId = pluginId;
                    }
                    if (item.variantId !== undefined) {
                        item.variantId = variantId;
                    }
                    if (item.variantData !== undefined && variantId) {
                        item.variantData = PluginService.getPluginVariantData(pluginId, variantId);
                    }
                    item.pluginService = PluginService;
                }

                if (item.popoutService !== undefined) {
                    item.popoutService = PopoutService;
                }

                layoutTimer.restart();
            }

            onActiveChanged: {
                layoutTimer.restart();
            }
        }
    }

    Connections {
        target: PluginService
        function onPluginLoaded(pluginId) {
            // Force refresh of component lookups
            for (var i = 0; i < centerRepeater.count; i++) {
                var item = centerRepeater.itemAt(i);
                if (item && item.widgetId.startsWith(pluginId)) {
                    item.sourceComponent = root.getWidgetComponent(item.widgetId);
                }
            }
        }
        function onPluginUnloaded(pluginId) {
            // Force refresh of component lookups
            for (var i = 0; i < centerRepeater.count; i++) {
                var item = centerRepeater.itemAt(i);
                if (item && item.widgetId.startsWith(pluginId)) {
                    item.sourceComponent = root.getWidgetComponent(item.widgetId);
                }
            }
        }
    }
}
