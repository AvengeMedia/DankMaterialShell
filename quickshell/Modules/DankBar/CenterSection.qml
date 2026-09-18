import QtQuick
import qs.Common
import "CenterLayout.js" as CenterLayout

BarSection {
    id: root

    property var centerWidgets: []
    property int totalWidgets: 0
    property real totalSize: 0
    property real contentStart: 0
    property real contentSize: 0

    function updateLayout() {
        positionWidgets();
        updateContentExtent();
        refreshBlur();
    }

    function updateContentExtent() {
        if (centerWidgets.length === 0) {
            contentStart = 0;
            contentSize = 0;
            return;
        }
        let start = Infinity;
        let end = -Infinity;
        for (const widget of centerWidgets) {
            const pos = isVertical ? widget.y : widget.x;
            const size = isVertical ? widget.height : widget.width;
            start = Math.min(start, pos);
            end = Math.max(end, pos + size);
        }
        contentStart = start;
        contentSize = end - start;
    }

    function positionWidgets() {
        const length = isVertical ? height : width;
        if (length <= 0 || !visible)
            return;

        const widgets = [];
        const sizes = [];
        const entries = [];
        const participating = [];
        for (let index = 0; index < centerRepeater.count; index++) {
            const wrapper = centerRepeater.itemAt(index);
            const widget = wrapper?.active && wrapper.item?.visible ? wrapper.item : null;
            widgets.push(widget);
            sizes.push(widget ? (isVertical ? widget.height : widget.width) : null);
            entries.push(wrapper?.itemData ?? null);
            participating.push(participation(wrapper, widget !== null, widget));
        }
        applyRoles(entries, participating);

        const layout = CenterLayout.resolve(sizes, length, widgetSpacing, SettingsData.centeringMode);
        for (let index = 0; index < widgets.length; index++) {
            const widget = widgets[index];
            if (!widget)
                continue;
            if (isVertical) {
                widget.anchors.verticalCenter = undefined;
                widget.y = layout.positions[index];
                continue;
            }
            widget.anchors.horizontalCenter = undefined;
            widget.x = layout.positions[index];
        }
        centerWidgets = widgets.filter(widget => widget !== null);
        totalWidgets = centerWidgets.length;
        totalSize = layout.totalSize;
    }

    height: parent.height
    width: parent.width
    anchors.centerIn: parent

    implicitWidth: isVertical ? widgetThickness : totalSize
    implicitHeight: isVertical ? totalSize : widgetThickness

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

    onSegmentedChanged: layoutTimer.restart()

    Repeater {
        id: centerRepeater
        model: root.widgetsModel

        onCountChanged: layoutTimer.restart()

        Item {
            property var itemData: modelData

            width: root.isVertical ? root.width : (widgetLoader.item ? widgetLoader.item.width : 0)
            height: widgetLoader.item ? widgetLoader.item.height : 0

            readonly property bool active: widgetLoader.active
            readonly property var item: widgetLoader.item
            readonly property bool itemVisible: widgetLoader.item?.visible ?? false
            readonly property real itemWidth: widgetLoader.item?.width ?? 0
            readonly property real itemHeight: widgetLoader.item?.height ?? 0

            onItemVisibleChanged: layoutTimer.restart()
            onItemWidthChanged: layoutTimer.restart()
            onItemHeightChanged: layoutTimer.restart()

            SectionWidget {
                id: widgetLoader

                anchors.verticalCenter: !root.isVertical ? parent.verticalCenter : undefined
                anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined

                occurrenceOrder: index
                sectionContext: root
                widgetData: itemData
                isFirst: index === 0
                isLast: index === centerRepeater.count - 1
                onContentItemReady: layoutTimer.restart()

                onActiveChanged: layoutTimer.restart()
            }
        }
    }

    readonly property string settingsCenteringMode: SettingsData.centeringMode

    onSettingsCenteringModeChanged: layoutTimer.restart()
}
