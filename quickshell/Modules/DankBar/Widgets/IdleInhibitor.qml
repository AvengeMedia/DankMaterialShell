import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property color idleColor: Theme.widgetTextColor
    property color inhibitColor: Theme.primary

    content: Component {
        Item {
            implicitWidth: icon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: SessionService.idleInhibited ? inhibitColor : idleColor
            }
        }
    }

    onClicked: SessionService.toggleIdleInhibit()

    onRightClicked: {
        const screen = root.parentScreen || Screen;
        if (!screen)
            return;

        const isVertical = root.axis?.isVertical ?? false;
        const edge = root.axis?.edge ?? "top";
        const gap = Math.max(Theme.spacingXS, root.barSpacing ?? Theme.spacingXS);
        const barOffset = root.barThickness + root.barSpacing + gap;
        const localPos = root.visualContent.mapToItem(null, root.visualContent.width / 2, root.visualContent.height / 2);

        let anchorX;
        let anchorY;
        if (isVertical) {
            anchorX = edge === "left" ? barOffset : screen.width - barOffset;
            anchorY = localPos.y;
        } else {
            anchorX = localPos.x;
            anchorY = edge === "bottom" ? screen.height - barOffset : barOffset;
        }

        durationPopupLoader.active = true;
        const popup = durationPopupLoader.item;
        if (!popup)
            return;

        popup.showAt(anchorX, anchorY, isVertical, edge, screen);
    }

    Loader {
        id: durationPopupLoader
        active: false
        sourceComponent: IdleInhibitDurationPopup {}
    }
}
