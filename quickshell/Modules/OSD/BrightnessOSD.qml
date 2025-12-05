import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    property int targetBrightness: {
        DisplayService.brightnessVersion;
        return DisplayService.brightnessLevel;
    }

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(260, Screen.width - Theme.spacingM * 2)
    osdHeight: useVertical ? Math.min(260, Screen.height - Theme.spacingM * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    Connections {
        target: DisplayService
        function onBrightnessChanged(showOsd) {
            if (showOsd && SettingsData.osdBrightnessEnabled) {
                root.show();
            }
        }
    }

    content: Loader {
        anchors.fill: parent
        sourceComponent: useVertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

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
                        const deviceInfo = DisplayService.getCurrentDeviceInfo();
                        if (!deviceInfo || deviceInfo.class === "backlight" || deviceInfo.class === "ddc") {
                            return "brightness_medium";
                        } else if (deviceInfo.name.includes("kbd")) {
                            return "keyboard";
                        } else {
                            return "lightbulb";
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
                    const deviceInfo = DisplayService.getCurrentDeviceInfo();
                    if (!deviceInfo)
                        return 1;
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id);
                    if (isExponential) {
                        return 1;
                    }
                    return (deviceInfo.class === "backlight" || deviceInfo.class === "ddc") ? 1 : 0;
                }
                maximum: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo();
                    if (!deviceInfo)
                        return 100;
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id);
                    if (isExponential) {
                        return 100;
                    }
                    return deviceInfo.displayMax || 100;
                }
                enabled: DisplayService.brightnessAvailable
                showValue: true
                unit: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo();
                    if (!deviceInfo)
                        return "%";
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id);
                    if (isExponential) {
                        return "%";
                    }
                    return deviceInfo.class === "ddc" ? "" : "%";
                }
                thumbOutlineColor: Theme.surfaceContainer
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                onSliderValueChanged: newValue => {
                    if (DisplayService.brightnessAvailable) {
                        DisplayService.setBrightness(newValue, DisplayService.lastIpcDevice, true);
                        resetHideTimer();
                    }
                }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse);
                }

                Binding on value {
                    value: root.targetBrightness
                    when: !brightnessSlider.isDragging
                }
            }
        }
    }

    Component {
        id: verticalContent

        Item {
            anchors.fill: parent
            property int gap: Theme.spacingS

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap

                DankIcon {
                    anchors.centerIn: parent
                    name: {
                        const deviceInfo = DisplayService.getCurrentDeviceInfo();
                        if (!deviceInfo || deviceInfo.class === "backlight" || deviceInfo.class === "ddc") {
                            return "brightness_medium";
                        } else if (deviceInfo.name.includes("kbd")) {
                            return "keyboard";
                        } else {
                            return "lightbulb";
                        }
                    }
                    size: Theme.iconSize
                    color: Theme.primary
                }
            }

            Item {
                id: vertSlider
                width: 12
                height: parent.height - Theme.iconSize - gap * 3 - 24
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap * 2 + Theme.iconSize

                property bool dragging: false
                property int value: 50

                Binding on value {
                    value: root.targetBrightness
                    when: !vertSlider.dragging
                }

                readonly property int minimum: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo();
                    if (!deviceInfo)
                        return 1;
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id);
                    if (isExponential)
                        return 1;
                    return (deviceInfo.class === "backlight" || deviceInfo.class === "ddc") ? 1 : 0;
                }

                readonly property int maximum: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo();
                    if (!deviceInfo)
                        return 100;
                    const isExponential = SessionData.getBrightnessExponential(deviceInfo.id);
                    if (isExponential)
                        return 100;
                    return deviceInfo.displayMax || 100;
                }

                Rectangle {
                    id: vertTrack
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    color: Theme.outline
                    radius: Theme.cornerRadius
                }

                Rectangle {
                    id: vertFill
                    width: parent.width
                    height: {
                        const ratio = (vertSlider.value - vertSlider.minimum) / (vertSlider.maximum - vertSlider.minimum);
                        return ratio * parent.height;
                    }
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    radius: Theme.cornerRadius
                }

                Rectangle {
                    id: vertHandle
                    width: 24
                    height: 8
                    radius: Theme.cornerRadius
                    y: {
                        const ratio = (vertSlider.value - vertSlider.minimum) / (vertSlider.maximum - vertSlider.minimum);
                        const travel = parent.height - height;
                        return Math.max(0, Math.min(travel, travel * (1 - ratio)));
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    border.width: 3
                    border.color: Theme.surfaceContainer
                }

                MouseArea {
                    id: vertSliderArea
                    anchors.fill: parent
                    anchors.margins: -12
                    enabled: DisplayService.brightnessAvailable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onContainsMouseChanged: {
                        setChildHovered(containsMouse);
                    }

                    onPressed: mouse => {
                        vertSlider.dragging = true;
                        updateBrightness(mouse);
                    }

                    onReleased: {
                        vertSlider.dragging = false;
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            updateBrightness(mouse);
                        }
                    }

                    onClicked: mouse => {
                        updateBrightness(mouse);
                    }

                    function updateBrightness(mouse) {
                        if (!DisplayService.brightnessAvailable) {
                            return;
                        }
                        const ratio = 1.0 - (mouse.y / height);
                        const newValue = Math.round(vertSlider.minimum + ratio * (vertSlider.maximum - vertSlider.minimum));
                        vertSlider.value = newValue;
                        DisplayService.setBrightness(newValue, DisplayService.lastIpcDevice, true);
                        resetHideTimer();
                    }
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: gap
                text: {
                    const deviceInfo = DisplayService.getCurrentDeviceInfo();
                    const isExponential = deviceInfo ? SessionData.getBrightnessExponential(deviceInfo.id) : false;
                    const unit = (deviceInfo && deviceInfo.class === "ddc" && !isExponential) ? "" : "%";
                    return vertSlider.value + unit;
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                visible: SettingsData.osdAlwaysShowValue
            }
        }
    }
}
