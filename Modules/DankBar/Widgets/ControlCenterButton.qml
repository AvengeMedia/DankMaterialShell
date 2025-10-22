import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    property var popoutTarget: null
    property var widgetData: null
    property bool showNetworkIcon: SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: SettingsData.controlCenterShowAudioIcon

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : controlIndicators.implicitWidth
            implicitHeight: root.isVerticalOrientation ? controlColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: controlColumn
                visible: root.isVerticalOrientation
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
                    size: Theme.barIconSize(root.barThickness)
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
                    size: Theme.barIconSize(root.barThickness)
                    color: BluetoothService.connected ? Theme.primary : Theme.outlineButton
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
                        size: Theme.barIconSize(root.barThickness)
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
                    size: Theme.barIconSize(root.barThickness)
                    color: root.isActive ? Theme.primary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon
                }
            }

            Row {
                id: controlIndicators
                visible: !root.isVerticalOrientation
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
                    size: Theme.barIconSize(root.barThickness)
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
                    size: Theme.barIconSize(root.barThickness)
                    color: BluetoothService.connected ? Theme.primary : Theme.outlineButton
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
                        size: Theme.barIconSize(root.barThickness)
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
                    size: Theme.barIconSize(root.barThickness)
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    visible: false
                }

                DankIcon {
                    name: "settings"
                    size: Theme.barIconSize(root.barThickness)
                    color: root.isActive ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (popoutTarget && popoutTarget.setTriggerPosition) {
                const globalPos = root.visualContent.mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, root.visualWidth)
                popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            root.clicked()
        }
    }
}
