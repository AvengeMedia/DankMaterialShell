import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    Ref {
        service: DMSNetworkService
    }

    property bool isHovered: clickArea.containsMouse
    property bool isAutoHideBar: false

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            return barThickness + barSpacing;
        }

        return 0;
    }

    signal toggleVpnPopup

    content: Component {
        Item {
            implicitWidth: icon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: icon

                name: DMSNetworkService.connected ? "vpn_lock" : "vpn_key_off"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: DMSNetworkService.connected ? Theme.primary : Theme.widgetIconColor
                opacity: DMSNetworkService.isBusy ? 0.5 : 1.0
                anchors.centerIn: parent

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !DMSNetworkService.isBusy
        onPressed: event => {
            root.triggerRipple(this, event.x, event.y);
            switch (event.button) {
            case Qt.RightButton:
                DMSNetworkService.toggleVpn();
                return;
            case Qt.LeftButton:
                root.toggleVpnPopup();
                return;
            }
        }
        onEntered: {
            if (!root.parentScreen || (popoutTarget?.shouldBeVisible))
                return;
            tooltipLoader.active = true;
            if (!tooltipLoader.item)
                return;
            let tooltipText = "";
            if (!DMSNetworkService.connected) {
                tooltipText = "VPN Disconnected";
            } else {
                const names = DMSNetworkService.activeNames || [];
                if (names.length <= 1) {
                    const name = names[0] || "";
                    const maxLength = 25;
                    const displayName = name.length > maxLength ? name.substring(0, maxLength) + "..." : name;
                    tooltipText = "VPN Connected • " + displayName;
                } else {
                    const name = names[0];
                    const maxLength = 20;
                    const displayName = name.length > maxLength ? name.substring(0, maxLength) + "..." : name;
                    tooltipText = "VPN Connected • " + displayName + " +" + (names.length - 1);
                }
            }

            if (root.isVerticalOrientation) {
                const globalPos = mapToGlobal(width / 2, height / 2);
                const currentScreen = root.parentScreen || Screen;
                const screenX = currentScreen ? currentScreen.x : 0;
                const screenY = currentScreen ? currentScreen.y : 0;
                const relativeY = globalPos.y - screenY;
                const adjustedY = relativeY + root.minTooltipY;
                const tooltipX = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (currentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                const isLeft = root.axis?.edge === "left";
                tooltipLoader.item.show(tooltipText, screenX + tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
            } else {
                const isBottom = root.axis?.edge === "bottom";
                const globalPos = mapToGlobal(width / 2, 0);
                const currentScreen = root.parentScreen || Screen;

                let tooltipY;
                if (isBottom) {
                    const tooltipHeight = Theme.fontSizeSmall * 1.5 + Theme.spacingS * 2;
                    tooltipY = currentScreen.height - root.barThickness - root.barSpacing - Theme.spacingXS - tooltipHeight;
                } else {
                    tooltipY = root.barThickness + root.barSpacing + Theme.spacingXS;
                }

                tooltipLoader.item.show(tooltipText, globalPos.x, tooltipY, currentScreen, false, false);
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }
    }
}
