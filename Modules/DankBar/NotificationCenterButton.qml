import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool hasUnread: false
    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    width: notificationIcon.width + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = notificationArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    DankIcon {
        id: notificationIcon

        anchors.centerIn: parent
        name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
        size: Theme.iconSize - 6
        color: SessionData.doNotDisturb ? Theme.error : (notificationArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText)
    }

    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: Theme.error
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: SettingsData.dankBarNoBackground ? 0 : 6
        anchors.topMargin: SettingsData.dankBarNoBackground ? 0 : 6
        visible: root.hasUnread
    }

    MouseArea {
        id: notificationArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                const screenX = currentScreen.x || 0;
                const relativeX = globalPos.x - screenX;
                popupTarget.setTriggerPosition(relativeX, SettingsData.getPopupYPosition(barHeight), width, section, currentScreen);
            }
            root.clicked();
        }
    }


}
