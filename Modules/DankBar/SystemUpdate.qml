import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property bool hasUpdates: SystemUpdateService.updateCount > 0
    readonly property bool isChecking: SystemUpdateService.isChecking

    signal clicked()

    width: updaterIcon.width + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = updaterArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Row {
        id: updaterIcon

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            id: statusIcon

            anchors.verticalCenter: parent.verticalCenter
            name: {
                if (isChecking) return "refresh";
                if (SystemUpdateService.hasError) return "error";
                if (hasUpdates) return "system_update_alt";
                return "check_circle";
            }
            size: Theme.iconSize - 6
            color: {
                if (SystemUpdateService.hasError) return Theme.error;
                if (hasUpdates) return Theme.primary;
                return (updaterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText);
            }

            RotationAnimation {
                id: rotationAnimation
                target: statusIcon
                property: "rotation"
                from: 0
                to: 360
                duration: 1000
                running: isChecking
                loops: Animation.Infinite

                onRunningChanged: {
                    if (!running) {
                        statusIcon.rotation = 0
                    }
                }
            }
        }

        StyledText {
            id: countText

            anchors.verticalCenter: parent.verticalCenter
            text: SystemUpdateService.updateCount.toString()
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            visible: hasUpdates && !isChecking
        }
    }

    MouseArea {
        id: updaterArea

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