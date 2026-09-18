import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "dms:tooltip"

    property string text: ""
    property real targetX: 0
    property real targetY: 0
    property var targetScreen: null
    property bool alignLeft: false
    property bool alignRight: false

    function show(text, x, y, screen, leftAlign, rightAlign) {
        root.text = text;
        targetScreen = screen ?? null;
        targetX = x;
        targetY = y;
        alignLeft = leftAlign ?? false;
        alignRight = rightAlign ?? false;
        visible = true;
    }

    function hide() {
        visible = false;
    }

    screen: targetScreen
    implicitWidth: Math.min(Theme.tooltipMaxWidth, textContent.implicitWidth) + Theme.spacingM * 2
    implicitHeight: textContent.implicitHeight + Theme.spacingS * 2
    color: "transparent"
    mask: Region {}
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1

    anchors {
        top: true
        left: true
    }

    margins {
        left: {
            const screenWidth = targetScreen?.width ?? Screen.width;
            if (alignLeft) {
                return Math.round(Math.max(Theme.spacingS, Math.min(screenWidth - implicitWidth - Theme.spacingS, targetX)));
            } else if (alignRight) {
                return Math.round(Math.max(Theme.spacingS, Math.min(screenWidth - implicitWidth - Theme.spacingS, targetX - implicitWidth)));
            } else {
                return Math.round(Math.max(Theme.spacingS, Math.min(screenWidth - implicitWidth - Theme.spacingS, targetX - implicitWidth / 2)));
            }
        }
        top: {
            const screenHeight = targetScreen?.height ?? Screen.height;
            if (alignLeft || alignRight) {
                return Math.round(Math.max(Theme.spacingS, Math.min(screenHeight - implicitHeight - Theme.spacingS, targetY - implicitHeight / 2)));
            } else {
                return Math.round(Math.max(Theme.spacingS, Math.min(screenHeight - implicitHeight - Theme.spacingS, targetY)));
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.inverseSurface
        radius: Theme.cornerRadiusXS

        StyledText {
            id: textContent

            anchors.centerIn: parent
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.inverseOnSurface
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Theme.tooltipMaxWidth)
        }
    }
}
