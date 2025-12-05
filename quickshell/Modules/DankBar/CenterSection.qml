import QtQuick
import qs.Common

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
    readonly property real widgetSpacing: {
        const baseSpacing = noBackground ? 2 : Theme.spacingXS;
        const outlineThickness = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
        return baseSpacing + (outlineThickness * 2);
    }

    property var centerWidgets: []
    property int totalWidgets: 0
    property real totalSize: 0

    function updateLayout() {
        if (SettingsData.centeringMode === "geometric") {
            applyGeometricLayout();
        } else {
            applyIndexLayout();
        }
    }

    function applyGeometricLayout() {
        if ((isVertical ? height : width) <= 0 || !visible)
            return;

        centerWidgets = [];
        totalWidgets = 0;
        totalSize = 0;

        for (var i = 0; i < centerRepeater.count; i++) {
            const loader = centerRepeater.itemAt(i);
            if (loader && loader.active && loader.item) {
                centerWidgets.push(loader.item);
                totalWidgets++;
                totalSize += isVertical ? loader.item.height : loader.item.width;
            }
        }

        if (totalWidgets === 0)
            return;

        if (totalWidgets > 1)
            totalSize += widgetSpacing * (totalWidgets - 1);

        positionWidgetsGeometric();
    }

    function positionWidgetsGeometric() {
        const parentLength = isVertical ? height : width;
        const parentCenter = parentLength / 2;
        let currentPos = parentCenter - (totalSize / 2);

        centerWidgets.forEach(widget => {
            if (isVertical) {
                widget.anchors.verticalCenter = undefined;
                widget.y = currentPos;
            } else {
                widget.anchors.horizontalCenter = undefined;
                widget.x = currentPos;
            }
            const widgetSize = isVertical ? widget.height : widget.width;
            currentPos += widgetSize + widgetSpacing;
        });
    }

    function applyIndexLayout() {
        if ((isVertical ? height : width) <= 0 || !visible)
            return;

        centerWidgets = [];
        totalWidgets = 0;
        totalSize = 0;

        let configuredMiddleWidget = null;
        let configuredLeftWidget = null;
        let configuredRightWidget = null;

        const configuredWidgets = centerRepeater.count;
        const isOddConfigured = configuredWidgets % 2 === 1;
        const configuredMiddlePos = Math.floor(configuredWidgets / 2);
        const configuredLeftPos = isOddConfigured ? -1 : ((configuredWidgets / 2) - 1);
        const configuredRightPos = isOddConfigured ? -1 : (configuredWidgets / 2);

        for (var i = 0; i < centerRepeater.count; i++) {
            const wrapper = centerRepeater.itemAt(i);
            if (!wrapper)
                continue;

            if (isOddConfigured && i === configuredMiddlePos && wrapper.active && wrapper.item)
                configuredMiddleWidget = wrapper.item;
            if (!isOddConfigured && i === configuredLeftPos && wrapper.active && wrapper.item)
                configuredLeftWidget = wrapper.item;
            if (!isOddConfigured && i === configuredRightPos && wrapper.active && wrapper.item)
                configuredRightWidget = wrapper.item;

            if (wrapper.active && wrapper.item) {
                centerWidgets.push(wrapper.item);
                totalWidgets++;
                totalSize += isVertical ? wrapper.item.height : wrapper.item.width;
            }
        }

        if (totalWidgets === 0)
            return;

        if (totalWidgets > 1)
            totalSize += widgetSpacing * (totalWidgets - 1);

        positionWidgetsByIndex(configuredWidgets, configuredMiddleWidget, configuredLeftWidget, configuredRightWidget);
    }

    function positionWidgetsByIndex(configuredWidgets, configuredMiddleWidget, configuredLeftWidget, configuredRightWidget) {
        const parentCenter = (isVertical ? height : width) / 2;
        const isOddConfigured = configuredWidgets % 2 === 1;

        centerWidgets.forEach(widget => {
            if (isVertical)
                widget.anchors.verticalCenter = undefined;
            else
                widget.anchors.horizontalCenter = undefined;
        });

        if (isOddConfigured && configuredMiddleWidget) {
            const middleWidget = configuredMiddleWidget;
            const middleIndex = centerWidgets.indexOf(middleWidget);
            const middleSize = isVertical ? middleWidget.height : middleWidget.width;

            if (isVertical)
                middleWidget.y = parentCenter - (middleSize / 2);
            else
                middleWidget.x = parentCenter - (middleSize / 2);

            let currentPos = isVertical ? middleWidget.y : middleWidget.x;
            for (var i = middleIndex - 1; i >= 0; i--) {
                const size = isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                currentPos -= (widgetSpacing + size);
                if (isVertical)
                    centerWidgets[i].y = currentPos;
                else
                    centerWidgets[i].x = currentPos;
            }

            currentPos = (isVertical ? middleWidget.y : middleWidget.x) + middleSize;
            for (var i = middleIndex + 1; i < totalWidgets; i++) {
                currentPos += widgetSpacing;
                if (isVertical)
                    centerWidgets[i].y = currentPos;
                else
                    centerWidgets[i].x = currentPos;
                currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
            }
            return;
        }

        if (totalWidgets === 1) {
            const widget = centerWidgets[0];
            const size = isVertical ? widget.height : widget.width;
            if (isVertical)
                widget.y = parentCenter - (size / 2);
            else
                widget.x = parentCenter - (size / 2);
            return;
        }

        if (!configuredLeftWidget || !configuredRightWidget) {
            if (totalWidgets % 2 === 1) {
                const middleIndex = Math.floor(totalWidgets / 2);
                const middleWidget = centerWidgets[middleIndex];

                if (!middleWidget)
                    return;

                const middleSize = isVertical ? middleWidget.height : middleWidget.width;

                if (isVertical)
                    middleWidget.y = parentCenter - (middleSize / 2);
                else
                    middleWidget.x = parentCenter - (middleSize / 2);

                let currentPos = isVertical ? middleWidget.y : middleWidget.x;
                for (var i = middleIndex - 1; i >= 0; i--) {
                    const size = isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                    currentPos -= (widgetSpacing + size);
                    if (isVertical)
                        centerWidgets[i].y = currentPos;
                    else
                        centerWidgets[i].x = currentPos;
                }

                currentPos = (isVertical ? middleWidget.y : middleWidget.x) + middleSize;
                for (var i = middleIndex + 1; i < totalWidgets; i++) {
                    currentPos += widgetSpacing;
                    if (isVertical)
                        centerWidgets[i].y = currentPos;
                    else
                        centerWidgets[i].x = currentPos;
                    currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                }
            } else {
                const leftIndex = (totalWidgets / 2) - 1;
                const rightIndex = totalWidgets / 2;
                const fallbackLeft = centerWidgets[leftIndex];
                const fallbackRight = centerWidgets[rightIndex];

                if (!fallbackLeft || !fallbackRight)
                    return;

                const halfSpacing = widgetSpacing / 2;
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
                    currentPos -= (widgetSpacing + size);
                    if (isVertical)
                        centerWidgets[i].y = currentPos;
                    else
                        centerWidgets[i].x = currentPos;
                }

                currentPos = (isVertical ? fallbackRight.y + fallbackRight.height : fallbackRight.x + fallbackRight.width);
                for (var i = rightIndex + 1; i < totalWidgets; i++) {
                    currentPos += widgetSpacing;
                    if (isVertical)
                        centerWidgets[i].y = currentPos;
                    else
                        centerWidgets[i].x = currentPos;
                    currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
                }
            }
            return;
        }

        const leftWidget = configuredLeftWidget;
        const rightWidget = configuredRightWidget;
        const leftIndex = centerWidgets.indexOf(leftWidget);
        const rightIndex = centerWidgets.indexOf(rightWidget);
        const halfSpacing = widgetSpacing / 2;
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
            currentPos -= (widgetSpacing + size);
            if (isVertical)
                centerWidgets[i].y = currentPos;
            else
                centerWidgets[i].x = currentPos;
        }

        currentPos = (isVertical ? rightWidget.y + rightWidget.height : rightWidget.x + rightWidget.width);
        for (var i = rightIndex + 1; i < totalWidgets; i++) {
            currentPos += widgetSpacing;
            if (isVertical)
                centerWidgets[i].y = currentPos;
            else
                centerWidgets[i].x = currentPos;
            currentPos += isVertical ? centerWidgets[i].height : centerWidgets[i].width;
        }
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

    Component.onCompleted: layoutTimer.restart()

    onWidthChanged: {
        if (width > 0)
            layoutTimer.restart();
    }

    onHeightChanged: {
        if (height > 0)
            layoutTimer.restart();
    }

    onVisibleChanged: {
        if (visible && (isVertical ? height : width) > 0)
            layoutTimer.restart();
    }

    Repeater {
        id: centerRepeater
        model: root.widgetsModel

        onCountChanged: layoutTimer.restart()

        Item {
            property var itemData: modelData
            readonly property real itemSpacing: root.widgetSpacing

            width: widgetLoader.item ? widgetLoader.item.width : 0
            height: widgetLoader.item ? widgetLoader.item.height : 0

            readonly property bool active: widgetLoader.active
            readonly property var item: widgetLoader.item

            WidgetHost {
                id: widgetLoader

                anchors.verticalCenter: !root.isVertical ? parent.verticalCenter : undefined
                anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined

                widgetId: itemData.widgetId
                widgetData: itemData
                spacerSize: itemData.size || 20
                components: root.components
                isInColumn: root.isVertical
                axis: root.axis
                section: "center"
                parentScreen: root.parentScreen
                widgetThickness: root.widgetThickness
                barThickness: root.barThickness
                barSpacing: root.barSpacing
                barConfig: root.barConfig
                isFirst: index === 0
                isLast: index === centerRepeater.count - 1
                sectionSpacing: parent.itemSpacing
                isLeftBarEdge: false
                isRightBarEdge: false
                isTopBarEdge: false
                isBottomBarEdge: false

                onContentItemReady: contentItem => {
                    contentItem.widthChanged.connect(() => layoutTimer.restart());
                    contentItem.heightChanged.connect(() => layoutTimer.restart());
                }

                onActiveChanged: layoutTimer.restart()
            }
        }
    }

    Connections {
        target: SettingsData
        function onCenteringModeChanged() {
            layoutTimer.restart();
        }
    }
}
