import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    property int _displayBrightness: 0

    function _syncBrightness() {
        _displayBrightness = DisplayService.brightnessLevel;
    }

    readonly property real osdValueReserve: SettingsData.osdAlwaysShowValue ? 48 : 0

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(216 + osdValueReserve, screenWidth - Theme.spacingM * 2)
    osdHeight: useVertical ? Math.min(260, screenHeight - Theme.spacingM * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    Connections {
        target: DisplayService
        function onBrightnessChanged(showOsd) {
            root._syncBrightness();
            if (showOsd && SettingsData.osdBrightnessEnabled)
                root.show();
        }
    }

    content: Loader {
        anchors.fill: parent
        sourceComponent: useVertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

        Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            OsdLevelRow {
                anchors.fill: parent
                iconName: DisplayService.brightnessIconName(DisplayService.getCurrentDeviceInfo())
                iconColor: Theme.primary
                value: root._displayBrightness
                minimum: DisplayService.brightnessMinimum(DisplayService.getCurrentDeviceInfo())
                maximum: DisplayService.brightnessMaximum(DisplayService.getCurrentDeviceInfo())
                unit: DisplayService.brightnessUnit(DisplayService.getCurrentDeviceInfo())
                sliderEnabled: DisplayService.brightnessAvailable
                onHoverChanged: hovered => setChildHovered(hovered)
                onSliderValueChanged: newValue => {
                    if (!DisplayService.brightnessAvailable)
                        return;
                    root._displayBrightness = newValue;
                    DisplayService.setBrightness(newValue, DisplayService.lastIpcDevice, true);
                    resetHideTimer();
                }
            }
        }
    }

    Component {
        id: verticalContent

        Item {
            anchors.fill: parent
            property int gap: Theme.spacingS

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap

                DankIcon {
                    anchors.centerIn: parent
                    name: DisplayService.brightnessIconName(DisplayService.getCurrentDeviceInfo())
                    size: Theme.iconSize
                    color: Theme.primary
                }
            }

            Item {
                id: vertSlider
                width: 12
                height: parent.height - Theme.iconSize - gap * 3 - (SettingsData.osdAlwaysShowValue ? 24 : 0)
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap * 2 + Theme.iconSize

                property bool dragging: false
                property int value: 50

                Binding on value {
                    value: root._displayBrightness
                    when: !vertSlider.dragging
                }

                readonly property int minimum: DisplayService.brightnessMinimum(DisplayService.getCurrentDeviceInfo())
                readonly property int maximum: DisplayService.brightnessMaximum(DisplayService.getCurrentDeviceInfo())

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

                    onContainsMouseChanged: setChildHovered(containsMouse)

                    onPressed: mouse => {
                        vertSlider.dragging = true;
                        updateBrightness(mouse);
                    }

                    onReleased: vertSlider.dragging = false

                    onPositionChanged: mouse => {
                        if (pressed)
                            updateBrightness(mouse);
                    }

                    onClicked: mouse => updateBrightness(mouse)

                    function updateBrightness(mouse) {
                        if (!DisplayService.brightnessAvailable)
                            return;
                        const ratio = 1.0 - (mouse.y / height);
                        const newValue = Math.max(vertSlider.minimum, Math.min(vertSlider.maximum, Math.round(vertSlider.minimum + ratio * (vertSlider.maximum - vertSlider.minimum))));
                        vertSlider.value = newValue;
                        root._displayBrightness = newValue;
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
