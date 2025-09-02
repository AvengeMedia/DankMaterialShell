import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: slider

    property int value: 50
    property int minimum: 0
    property int maximum: 100
    property string leftIcon: ""
    property string rightIcon: ""
    property bool enabled: true
    property string unit: "%"
    property bool showValue: true
    property bool isDragging: false
    property bool wheelEnabled: true
    readonly property bool containsMouse: sliderMouseArea.containsMouse

    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)

    height: 40

    Row {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacingM

        DankIcon {
            name: slider.leftIcon
            size: Theme.iconSize
            color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            visible: slider.leftIcon.length > 0
        }

        StyledRect {
            id: sliderTrack

            property int leftIconWidth: slider.leftIcon.length > 0 ? Theme.iconSize : 0
            property int rightIconWidth: slider.rightIcon.length > 0 ? Theme.iconSize : 0

            width: parent.width - (leftIconWidth + rightIconWidth
                                   + (slider.leftIcon.length > 0 ? Theme.spacingM : 0)
                                   + (slider.rightIcon.length > 0 ? Theme.spacingM : 0))
            height: 6
            radius: 3
            color: slider.enabled ? Theme.surfaceVariantAlpha : Theme.surfaceLight
            anchors.verticalCenter: parent.verticalCenter

            StyledRect {
                id: sliderFill

                width: (parent.width - sliderHandle.width) * (
                    (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                ) + sliderHandle.width
                height: parent.height
                radius: parent.radius
                color: slider.enabled ? Theme.primary : Theme.surfaceVariantText

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            StyledRect {
                id: sliderHandle

                width: 18
                height: 18
                radius: 9
                color: slider.enabled ? Theme.primary : Theme.surfaceVariantText
                border.color: slider.enabled ? Qt.lighter(Theme.primary,
                                                          1.3) : Qt.lighter(
                                                   Theme.surfaceVariantText,
                                                   1.3)
                border.width: 2
                x: sliderFill.width - width
                anchors.verticalCenter: parent.verticalCenter
                scale: sliderMouseArea.containsMouse
                       || sliderMouseArea.pressed ? 1.2 : 1

                StyledRect {
                    anchors.centerIn: parent
                    width: parent.width + 4
                    height: parent.height + 4
                    radius: width / 2
                    color: "transparent"
                    border.color: Theme.primarySelected
                    border.width: 2
                    visible: sliderMouseArea.containsMouse && slider.enabled
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
                    anchors.bottomMargin: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: (sliderMouseArea.containsMouse && slider.showValue)
                             || (slider.isDragging && slider.showValue)
                    opacity: visible ? 1 : 0

                    StyledText {
                        id: tooltipText

                        text: slider.value + slider.unit
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
                    property real scrollAccumulator: 0
                    property real touchpadThreshold: 20

                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
                    hoverEnabled: true
                    cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: slider.enabled
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    onWheel: (wheelEvent) => {
                        if (!slider.enabled || !slider.wheelEnabled) {
                            wheelEvent.accepted = false
                            return
                        }
                        
                        const deltaY = wheelEvent.angleDelta.y
                        const isMouseWheel = Math.abs(deltaY) >= 120
                            && (Math.abs(deltaY) % 120) === 0
                        
                        let currentValue = slider.value
                        
                        if (isMouseWheel) {
                            // Direct mouse wheel action - 5% steps
                            let step = Math.max(1, (slider.maximum - slider.minimum) / 20)
                            let newValue
                            if (deltaY > 0)
                                newValue = Math.min(slider.maximum, currentValue + step)
                            else
                                newValue = Math.max(slider.minimum, currentValue - step)
                            newValue = Math.round(newValue)
                            if (newValue !== slider.value) {
                                slider.value = newValue
                                slider.sliderValueChanged(newValue)
                            }
                        } else {
                            // Touchpad - accumulate then apply 1% steps
                            scrollAccumulator += deltaY
                            
                            if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                                let step = Math.max(0.5, (slider.maximum - slider.minimum) / 100)
                                let newValue
                                if (scrollAccumulator > 0)
                                    newValue = Math.min(slider.maximum, currentValue + step)
                                else
                                    newValue = Math.max(slider.minimum, currentValue - step)
                                newValue = Math.round(newValue)
                                if (newValue !== slider.value) {
                                    slider.value = newValue
                                    slider.sliderValueChanged(newValue)
                                }
                                scrollAccumulator = 0
                            }
                        }
                        wheelEvent.accepted = true
                    }
                    onPressed: mouse => {
                                   if (slider.enabled) {
                                       slider.isDragging = true
                                       sliderMouseArea.isDragging = true
                                       let ratio = Math.max(
                                           0, Math.min(1, (
                                               mouse.x - sliderHandle.width / 2) / (
                                                   width - sliderHandle.width)))
                                       let newValue = Math.round(
                                           slider.minimum + ratio
                                           * (slider.maximum - slider.minimum))
                                       slider.value = newValue
                                       slider.sliderValueChanged(newValue)
                                   }
                               }
                    onReleased: {
                        if (slider.enabled) {
                            slider.isDragging = false
                            sliderMouseArea.isDragging = false
                            slider.sliderDragFinished(slider.value)
                        }
                    }
                    onPositionChanged: mouse => {
                                           if (pressed && slider.isDragging
                                               && slider.enabled) {
                                               let ratio = Math.max(
                                                   0, Math.min(1, (
                                                       mouse.x - sliderHandle.width / 2) / (
                                                           width - sliderHandle.width)))
                                               let newValue = Math.round(
                                                   slider.minimum + ratio
                                                   * (slider.maximum - slider.minimum))
                                               slider.value = newValue
                                               slider.sliderValueChanged(
                                                   newValue)
                                           }
                                       }
                    onClicked: mouse => {
                                   if (slider.enabled && !slider.isDragging) {
                                       let ratio = Math.max(
                                           0, Math.min(1, (
                                               mouse.x - sliderHandle.width / 2) / (
                                                   width - sliderHandle.width)))
                                       let newValue = Math.round(
                                           slider.minimum + ratio
                                           * (slider.maximum - slider.minimum))
                                       slider.value = newValue
                                       slider.sliderValueChanged(newValue)
                                   }
                               }
                }

                MouseArea {
                    id: sliderGlobalMouseArea

                    anchors.fill: sliderContainer
                    enabled: slider.isDragging
                    visible: false
                    preventStealing: true
                    onPositionChanged: mouse => {
                                           if (slider.isDragging
                                               && slider.enabled) {
                                               let globalPos = mapToItem(
                                                   sliderTrack,
                                                   mouse.x, mouse.y)
                                               let ratio = Math.max(
                                                   0, Math.min(
                                                       1,
                                                       globalPos.x / sliderTrack.width))
                                               let newValue = Math.round(
                                                   slider.minimum + ratio
                                                   * (slider.maximum - slider.minimum))
                                               slider.value = newValue
                                               slider.sliderValueChanged(
                                                   newValue)
                                           }
                                       }
                    onReleased: {
                        if (slider.isDragging && slider.enabled) {
                            slider.isDragging = false
                            sliderMouseArea.isDragging = false
                            slider.sliderDragFinished(slider.value)
                        }
                    }
                }
            }
        }

        DankIcon {
            name: slider.rightIcon
            size: Theme.iconSize
            color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            visible: slider.rightIcon.length > 0
        }
    }
}
