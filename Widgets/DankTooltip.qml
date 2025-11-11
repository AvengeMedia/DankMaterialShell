import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

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
        if (screen) {
            targetScreen = screen;
            const screenX = screen.x || 0;
            targetX = x - screenX;
        } else {
            targetScreen = null;
            targetX = x;
        }
        targetY = y;
        alignLeft = leftAlign ?? false;
        alignRight = rightAlign ?? false;
        visible = true;
    }

    function hide() {
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
        left: {
            if (alignLeft) return Math.round(Math.max(Theme.spacingS, Math.min((targetScreen?.width ?? Screen.width) - implicitWidth - Theme.spacingS, targetX)))
            if (alignRight) return Math.round(Math.max(Theme.spacingS, Math.min((targetScreen?.width ?? Screen.width) - implicitWidth - Theme.spacingS, targetX - implicitWidth)))
            return Math.round(Math.max(Theme.spacingS, Math.min((targetScreen?.width ?? Screen.width) - implicitWidth - Theme.spacingS, targetX - implicitWidth / 2)))
        }
        top: {
            if (alignLeft || alignRight) return Math.round(Math.max(Theme.spacingS, Math.min((targetScreen?.height ?? Screen.height) - implicitHeight - Theme.spacingS, targetY - implicitHeight / 2)))
            return Math.round(Math.max(Theme.spacingS, Math.min((targetScreen?.height ?? Screen.height) - implicitHeight - Theme.spacingS, targetY)))
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.width: 1
        border.color: Theme.outlineMedium

        Text {
            id: textContent

            anchors.centerIn: parent
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 300 - Theme.spacingM * 2)
        }
    }
}