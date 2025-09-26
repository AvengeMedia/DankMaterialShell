import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    property string tooltipText: ""
    property real targetX: 0
    property real targetY: 0
    property var targetScreen: null

    function showTooltip(text, x, y, screen) {
        tooltipText = text;
        targetScreen = screen;
        const screenX = screen ? screen.x : 0;
        targetX = x - screenX;
        targetY = y;
        visible = true;
    }

    function hideTooltip() {
        visible = false;
    }

    screen: targetScreen
    implicitWidth: Math.min(300, Math.max(120, textContent.implicitWidth + Theme.spacingM * 2))
    implicitHeight: textContent.implicitHeight + Theme.spacingS * 2
    color: "transparent"
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1

    anchors {
        top: true
        left: true
    }

    margins {
        left: Math.round(targetX - implicitWidth / 2)
        top: Math.round(targetY)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceContainerHigh
        radius: Theme.cornerRadius
        border.width: 1
        border.color: Theme.outlineMedium

        Text {
            id: textContent

            anchors.centerIn: parent
            text: root.tooltipText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
            width: parent.width - Theme.spacingM * 2
        }

    }

}
