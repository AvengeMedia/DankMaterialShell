import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: slider

    property int value: 50
    property int minimum: 0
    property int maximum: 100
    property int step: 1
    property string leftIcon: ""
    property string rightIcon: ""
    property bool enabled: true
    property string unit: "%"
    property bool showValue: true
    property bool isDragging: false
    property bool wheelEnabled: true
    property real valueOverride: -1
    property bool alwaysShowValue: false
    readonly property bool containsMouse: sliderMouseArea.containsMouse

    property color thumbOutlineColor: Theme.surfaceContainer
    property color trackColor: enabled ? Theme.outline : Theme.outline

    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)

    height: 48

    function updateValueFromPosition(x) {
        let ratio = Math.max(0, Math.min(1, (x - sliderHandle.width / 2) / (sliderTrack.width - sliderHandle.width)));
        let rawValue = minimum + ratio * (maximum - minimum);
        let newValue = step > 1 ? Math.round(rawValue / step) * step : Math.round(rawValue);
        newValue = Math.max(minimum, Math.min(maximum, newValue));
        if (newValue !== value) {
            value = newValue;
            sliderValueChanged(newValue);
        }
    }

    Row {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacingM

        DankIcon {
            name: slider.leftIcon
            size: Theme.iconSize
            color: slider.enabled ? Theme.surfaceText : Theme.onSurface_38
            anchors.verticalCenter: parent.verticalCenter
            visible: slider.leftIcon.length > 0
        }

        StyledRect {
            id: sliderTrack

            property int leftIconWidth: slider.leftIcon.length > 0 ? Theme.iconSize : 0
            property int rightIconWidth: slider.rightIcon.length > 0 ? Theme.iconSize : 0

            width: parent.width - (leftIconWidth + rightIconWidth + (slider.leftIcon.length > 0 ? Theme.spacingM : 0) + (slider.rightIcon.length > 0 ? Theme.spacingM : 0))
            height: 12
            radius: Theme.cornerRadius
            color: slider.trackColor
            anchors.verticalCenter: parent.verticalCenter
            clip: false

            StyledRect {
                id: sliderFill
                height: parent.height
                radius: Theme.cornerRadius
                width: {
                    const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum);
                    const travel = sliderTrack.width - sliderHandle.width;
                    const center = (travel * ratio) + sliderHandle.width / 2;
                    return Math.max(0, Math.min(sliderTrack.width, center));
                }
                color: slider.enabled ? Theme.primary : Theme.withAlpha(Theme.onSurface, 0.12)
            }

            StyledRect {
                id: sliderHandle

                property bool active: sliderMouseArea.containsMouse || sliderMouseArea.pressed || slider.isDragging

                width: 8
                height: 24
                radius: Theme.cornerRadius
                x: {
                    const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum);
                    const travel = sliderTrack.width - width;
                    return Math.max(0, Math.min(travel, travel * ratio));
                }
                anchors.verticalCenter: parent.verticalCenter
                color: slider.enabled ? Theme.primary : Theme.withAlpha(Theme.onSurface, 0.12)
                border.width: 3
                border.color: slider.thumbOutlineColor

                StyledRect {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Theme.onPrimary
                    opacity: slider.enabled ? (sliderMouseArea.pressed ? 0.16 : (sliderMouseArea.containsMouse ? 0.08 : 0)) : 0
                    visible: opacity > 0
                }

                StyledRect {
                    anchors.centerIn: parent
                    width: parent.width + 20
                    height: parent.height + 20
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    opacity: slider.enabled && slider.focus ? 0.3 : 0
                    visible: opacity > 0
                }

                Rectangle {
                    id: ripple
                    anchors.centerIn: parent
                    width: 0
                    height: 0
                    radius: width / 2
                    color: Theme.onPrimary
                    opacity: 0

                    function start() {
                        opacity = 0.16;
                        width = 0;
                        height = 0;
                        rippleAnimation.start();
                    }

                    SequentialAnimation {
                        id: rippleAnimation
                        NumberAnimation {
                            target: ripple
                            properties: "width,height"
                            to: 28
                            duration: 180
                        }
                        NumberAnimation {
                            target: ripple
                            property: "opacity"
                            to: 0
                            duration: 150
                        }
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onPressedChanged: {
                        if (pressed && slider.enabled) {
                            ripple.start();
                        }
                    }
                }

                scale: active ? 1.05 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Item {
                id: sliderContainer

                anchors.fill: parent

                MouseArea {
                    id: sliderMouseArea

                    property bool isDragging: false

                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: slider.enabled
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    onWheel: wheelEvent => {
                        if (!slider.wheelEnabled) {
                            wheelEvent.accepted = false;
                            return;
                        }
                        let wheelStep = slider.step > 1 ? slider.step : Math.max(1, (maximum - minimum) / 100);
                        let newValue = wheelEvent.angleDelta.y > 0 ? Math.min(maximum, value + wheelStep) : Math.max(minimum, value - wheelStep);
                        if (slider.step > 1)
                            newValue = Math.round(newValue / slider.step) * slider.step;
                        newValue = Math.round(newValue);
                        if (newValue !== value) {
                            value = newValue;
                            sliderValueChanged(newValue);
                        }
                        wheelEvent.accepted = true;
                    }
                    onPressed: mouse => {
                        if (slider.enabled) {
                            slider.isDragging = true;
                            sliderMouseArea.isDragging = true;
                            updateValueFromPosition(mouse.x);
                        }
                    }
                    onReleased: {
                        if (slider.enabled) {
                            slider.isDragging = false;
                            sliderMouseArea.isDragging = false;
                            slider.sliderDragFinished(slider.value);
                        }
                    }
                    onPositionChanged: mouse => {
                        if (pressed && slider.isDragging && slider.enabled) {
                            updateValueFromPosition(mouse.x);
                        }
                    }
                    onClicked: mouse => {
                        if (slider.enabled && !slider.isDragging) {
                            updateValueFromPosition(mouse.x);
                        }
                    }
                }
            }

            StyledRect {
                id: valueTooltip

                width: tooltipText.contentWidth + Theme.spacingS * 2
                height: tooltipText.contentHeight + Theme.spacingXS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                border.color: Theme.outline
                border.width: 1
                anchors.bottom: parent.top
                anchors.bottomMargin: Theme.spacingM
                x: Math.max(0, Math.min(parent.width - width, sliderHandle.x + sliderHandle.width / 2 - width / 2))
                visible: slider.alwaysShowValue ? slider.showValue : ((sliderMouseArea.containsMouse && slider.showValue) || (slider.isDragging && slider.showValue))
                opacity: visible ? 1 : 0

                StyledText {
                    id: tooltipText

                    text: (slider.valueOverride >= 0 ? Math.round(slider.valueOverride) : slider.value) + slider.unit
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.centerIn: parent
                    font.hintingPreference: Font.PreferFullHinting
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }

        DankIcon {
            name: slider.rightIcon
            size: Theme.iconSize
            color: slider.enabled ? Theme.surfaceText : Theme.onSurface_38
            anchors.verticalCenter: parent.verticalCenter
            visible: slider.rightIcon.length > 0
        }
    }
}
