import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Math.min(260, Screen.width - Theme.spacingM * 2)
    osdHeight: 40 + Theme.spacingS * 2
    autoHideInterval: 3000
    enableMouseInteraction: true

    Connections {
        target: DisplayService
        function onBrightnessChanged(showOsd) {
            if (showOsd) {
                root.show()
            }
        }
    }

    content: Item {
        anchors.fill: parent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            width: parent.width - Theme.spacingS * 2
            height: 40

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: {
                        const deviceInfo = DisplayService.getCurrentDeviceInfo()
                        if (!deviceInfo || deviceInfo.class === "backlight" || deviceInfo.class === "ddc") {
                            return "brightness_medium"
                        } else if (deviceInfo.name.includes("kbd")) {
                            return "keyboard"
                        } else {
                            return "lightbulb"
                        }
                    }
                    size: Theme.iconSize
                    color: Theme.primary
                }
            }

            DankSlider {
                id: brightnessSlider

                width: parent.width - Theme.iconSize - parent.gap * 3
                height: 40
                x: parent.gap * 2 + Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                minimum: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo()
                    if (!deviceInfo) return 1
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id)
                    if (isExponential) {
                        return 1
                    }
                    return (deviceInfo.class === "backlight" || deviceInfo.class === "ddc") ? 1 : 0
                }
                maximum: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo()
                    if (!deviceInfo) return 100
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id)
                    if (isExponential) {
                        return 100
                    }
                    return deviceInfo.displayMax || 100
                }
                enabled: DisplayService.brightnessAvailable
                showValue: true
                unit: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo()
                    if (!deviceInfo) return "%"
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id)
                    if (isExponential) {
                        return "%"
                    }
                    return deviceInfo.class === "ddc" ? "" : "%"
                }
                thumbOutlineColor: Theme.surfaceContainer
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                Component.onCompleted: {
                    if (DisplayService.brightnessAvailable) {
                        value = DisplayService.brightnessLevel
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (DisplayService.brightnessAvailable) {
                                              DisplayService.setBrightness(newValue, DisplayService.lastIpcDevice, true)
                                              resetHideTimer()
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse)
                }

                onSliderDragFinished: finalValue => {
                                          if (DisplayService.brightnessAvailable) {
                                              DisplayService.setBrightness(finalValue, DisplayService.lastIpcDevice, true)
                                          }
                                      }

                Connections {
                    target: DisplayService

                    function onBrightnessChanged(showOsd) {
                        if (!brightnessSlider.pressed && brightnessSlider.value !== DisplayService.brightnessLevel) {
                            brightnessSlider.value = DisplayService.brightnessLevel
                        }
                    }

                    function onDeviceSwitched() {
                        if (!brightnessSlider.pressed && brightnessSlider.value !== DisplayService.brightnessLevel) {
                            brightnessSlider.value = DisplayService.brightnessLevel
                        }
                    }
                }
            }
        }
    }
}
