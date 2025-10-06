import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real barThickness: 48
    property real widgetThickness: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    width: isVertical ? widgetThickness : (cpuTempContent.implicitWidth + horizontalPadding * 2)
    height: isVertical ? (cpuTempColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = cpuTempArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }

    MouseArea {
        id: cpuTempArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, width)
                popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            DgopService.setSortBy("cpu");
            if (root.toggleProcessList) {
                root.toggleProcessList();
            }

        }
    }

    Column {
        id: cpuTempColumn
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 1

        DankIcon {
            name: "device_thermostat"
            size: Theme.iconSize - 8
            color: {
                if (DgopService.cpuTemperature > 85) {
                    return Theme.tempDanger;
                }

                if (DgopService.cpuTemperature > 69) {
                    return Theme.tempWarning;
                }

                return Theme.surfaceText;
            }
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: {
                if (DgopService.cpuTemperature === undefined || DgopService.cpuTemperature === null || DgopService.cpuTemperature < 0) {
                    return "--";
                }

                return Math.round(DgopService.cpuTemperature).toString();
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Row {
        id: cpuTempContent
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "device_thermostat"
            size: Theme.iconSize - 8
            color: {
                if (DgopService.cpuTemperature > 85) {
                    return Theme.tempDanger;
                }

                if (DgopService.cpuTemperature > 69) {
                    return Theme.tempWarning;
                }

                return Theme.surfaceText;
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (DgopService.cpuTemperature === undefined || DgopService.cpuTemperature === null || DgopService.cpuTemperature < 0) {
                    return "--°";
                }

                return Math.round(DgopService.cpuTemperature) + "°";
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone

            StyledTextMetrics {
                id: tempBaseline
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                text: "100°"
            }

            width: Math.max(tempBaseline.width, paintedWidth)

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

    }


}
