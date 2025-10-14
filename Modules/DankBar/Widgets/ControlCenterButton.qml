import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property var widgetData: null
    property bool showNetworkIcon: SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: SettingsData.controlCenterShowAudioIcon
    property real widgetThickness: 30
    property real barThickness: 48
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    width: isVertical ? widgetThickness : (controlIndicators.implicitWidth + horizontalPadding * 2)
    height: isVertical ? (controlColumn.implicitHeight + horizontalPadding * 2) : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = controlCenterArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Column {
        id: controlColumn
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: {
                if (NetworkService.wifiToggling) {
                    return "sync"
                }

                if (NetworkService.networkStatus === "ethernet") {
                    return "lan"
                }

                return NetworkService.wifiSignalIcon
            }
            size: Theme.barIconSize(barThickness)
            color: {
                if (NetworkService.wifiToggling) {
                    return Theme.primary
                }

                return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.outlineButton
            }
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showNetworkIcon && NetworkService.networkAvailable
        }

        DankIcon {
            name: "bluetooth"
            size: Theme.barIconSize(barThickness)
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
        }

        Rectangle {
            width: audioIconV.implicitWidth + 4
            height: audioIconV.implicitHeight + 4
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showAudioIcon

            DankIcon {
                id: audioIconV

                name: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0) {
                            return "volume_off"
                        } else if (AudioService.sink.audio.volume * 100 < 33) {
                            return "volume_down"
                        } else {
                            return "volume_up"
                        }
                    }
                    return "volume_up"
                }
                size: Theme.barIconSize(barThickness)
                color: Theme.surfaceText
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onWheel: function(wheelEvent) {
                    let delta = wheelEvent.angleDelta.y
                    let currentVolume = (AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.volume * 100) || 0
                    let newVolume
                    if (delta > 0) {
                        newVolume = Math.min(100, currentVolume + 5)
                    } else {
                        newVolume = Math.max(0, currentVolume - 5)
                    }
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = false
                        AudioService.sink.audio.volume = newVolume / 100
                    }
                    wheelEvent.accepted = true
                }
            }
        }

        DankIcon {
            name: "settings"
            size: Theme.barIconSize(barThickness)
            color: controlCenterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon
        }
    }

    Row {
        id: controlIndicators
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            id: networkIcon

            name: {
                if (NetworkService.wifiToggling) {
                    return "sync";
                }

                if (NetworkService.networkStatus === "ethernet") {
                    return "lan";
                }

                return NetworkService.wifiSignalIcon;
            }
            size: Theme.barIconSize(barThickness)
            color: {
                if (NetworkService.wifiToggling) {
                    return Theme.primary;
                }

                return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.outlineButton;
            }
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showNetworkIcon && NetworkService.networkAvailable


        }

        DankIcon {
            id: bluetoothIcon

            name: "bluetooth"
            size: Theme.barIconSize(barThickness)
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
        }

        Rectangle {
            width: audioIcon.implicitWidth + 4
            height: audioIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showAudioIcon

            DankIcon {
                id: audioIcon

                name: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0) {
                            return "volume_off";
                        } else if (AudioService.sink.audio.volume * 100 < 33) {
                            return "volume_down";
                        } else {
                            return "volume_up";
                        }
                    }
                    return "volume_up";
                }
                size: Theme.barIconSize(barThickness)
                color: Theme.surfaceText
                anchors.centerIn: parent
            }

            MouseArea {
                id: audioWheelArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onWheel: function(wheelEvent) {
                    let delta = wheelEvent.angleDelta.y;
                    let currentVolume = (AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.volume * 100) || 0;
                    let newVolume;
                    if (delta > 0) {
                        newVolume = Math.min(100, currentVolume + 5);
                    } else {
                        newVolume = Math.max(0, currentVolume - 5);
                    }
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = false;
                        AudioService.sink.audio.volume = newVolume / 100;
                    }
                    wheelEvent.accepted = true;
                }
            }

        }

        DankIcon {
            name: "mic"
            size: Theme.barIconSize(barThickness)
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            visible: false // TODO: Add mic detection
        }

        // Fallback settings icon when all other icons are hidden
        DankIcon {
            name: "settings"
            size: Theme.barIconSize(barThickness)
            color: controlCenterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon
        }

    }

    MouseArea {
        id: controlCenterArea

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
            root.clicked();
        }
    }


}
