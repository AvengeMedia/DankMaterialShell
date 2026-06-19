import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property int widgetIndex: -1
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 0
    property real anchorHeight: 0

    readonly property var widgetData: {
        if (widgetIndex < 0)
            return null;
        const widgets = SettingsData.controlCenterWidgets || [];
        return widgets[widgetIndex] || null;
    }

    visible: widgetIndex >= 0
    z: 10000

    function open(index, data, anchorItem) {
        const pos = anchorItem.mapToItem(root, 0, 0);
        anchorX = pos.x;
        anchorY = pos.y;
        anchorWidth = anchorItem.width;
        anchorHeight = anchorItem.height;
        widgetIndex = index;
    }

    function close() {
        widgetIndex = -1;
    }

    function persistShowMountPath(show) {
        const widgets = (SettingsData.controlCenterWidgets || []).slice();
        if (root.widgetIndex < 0 || root.widgetIndex >= widgets.length)
            return;
        const updated = Object.assign({}, widgets[root.widgetIndex]);
        updated.showMountPath = show;
        widgets[root.widgetIndex] = updated;
        SettingsData.set("controlCenterWidgets", widgets);
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        onClicked: root.close()
    }

    DiskUsageWidgetConfigMenu {
        id: diskMenu
        visible: root.visible && root.widgetData?.id === "diskUsage"
        widgetData: root.widgetData

        x: {
            let nx = root.anchorX + root.anchorWidth - width;
            const maxX = root.width - width - Theme.spacingS;
            const minX = Theme.spacingS;
            if (nx < minX)
                nx = minX;
            if (nx > maxX)
                nx = maxX;
            return nx;
        }
        y: {
            let ny = root.anchorY - height - Theme.spacingS;
            if (ny < Theme.spacingS)
                ny = root.anchorY + root.anchorHeight + Theme.spacingS;
            return ny;
        }

        onShowMountPathChanged: show => root.persistShowMountPath(show)
    }
}
