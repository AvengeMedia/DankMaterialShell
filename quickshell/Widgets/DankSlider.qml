import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

Item {
    id: slider

    property int value: 50
    property int minimum: 0
    property int maximum: 100
    property var reference: null
    property string leftIcon: ""
    property string rightIcon: ""
    property bool enabled: true
    property string unit: "%"
    property bool showValue: true
    property bool isDragging: false
    property bool wheelEnabled: true
    property real valueOverride: -1
    property bool alwaysShowValue: false
    readonly property bool containsMouse: loader.item ? loader.item.containsMouse : false

    property color thumbOutlineColor: Theme.surfaceContainer
    property color trackColor: enabled ? Theme.outline : Theme.outline

    signal sliderValueChanged(int newValue)
    signal sliderDragFinished(int finalValue)

    enum Orientation { Horizontal, Vertical }
    property int orientation: DankSlider.Horizontal
    enum TooltipPlacement { Before, After }
    property int tooltipPlacement: orientation === DankSlider.Horizontal ? DankSlider.Before : DankSlider.After

    height: orientation === DankSlider.Horizontal ? 48 : parent.height
    width: orientation === DankSlider.Horizontal ? parent.width : 48

    function updateValueFromPosition(pos, sliderHandle, sliderTrack) {
        let ratio
        if (orientation === DankSlider.Horizontal) {
            ratio = Math.max(0, Math.min(1, (pos - sliderHandle.width / 2) / (sliderTrack.width - sliderHandle.width)))
        } else {
            ratio = 1 - Math.max(0, Math.min(1, (pos - sliderHandle.height / 2) / (sliderTrack.height - sliderHandle.height)))
        }
        let newValue = Math.round(minimum + ratio * (maximum - minimum))
        if (newValue !== value) {
            value = newValue
            sliderValueChanged(newValue)
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: orientation === DankSlider.Horizontal ? horizontalLayout : verticalLayout
    }

    Component {
        id: horizontalLayout

        Row {
            anchors.centerIn: parent
            width: parent.width
            spacing: Theme.spacingM
            property bool containsMouse: sliderMouseArea.containsMouse

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
                        const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                        const travel = sliderTrack.width - sliderHandle.width
                        const center = (travel * ratio) + sliderHandle.width / 2
                        return Math.max(0, Math.min(sliderTrack.width, center))
                    }
                    color: slider.enabled ? Theme.primary : Theme.withAlpha(Theme.onSurface, 0.12)

                }

                StyledRect {
                    id: sliderReference
                    height: 24
                    width: 8
                    radius: Theme.cornerRadius
                    visible: slider.reference && slider.reference < slider.maximum && slider.reference > slider.minimum
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.withAlpha(Theme.onSurface, 0.12)
                    border.width: 3
                    border.color: slider.thumbOutlineColor
                    x: {
                        const ratio = (slider.reference - slider.minimum) / (slider.maximum - slider.minimum)
                        const travel = sliderTrack.width - width
                        return Math.max(0, Math.min(travel, travel * ratio))
                    }
                }

                StyledRect {
                    id: sliderHandle

                    width: 8
                    height: 24
                    radius: Theme.cornerRadius
                    x: {
                        const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                        const travel = sliderTrack.width - width
                        return Math.max(0, Math.min(travel, travel * ratio))
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
                            opacity = 0.16
                            width = 0
                            height = 0
                            rippleAnimation.start()
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
                                ripple.start()
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
                                         wheelEvent.accepted = false
                                         return
                                     }
                                     let step = Math.max(0.5, (maximum - minimum) / 100)
                                     let newValue = wheelEvent.angleDelta.y > 0 ? Math.min(maximum, value + step) : Math.max(minimum, value - step)
                                     newValue = Math.round(newValue)
                                     if (newValue !== value) {
                                         value = newValue
                                         sliderValueChanged(newValue)
                                     }
                                     wheelEvent.accepted = true
                                 }
                        onPressed: mouse => {
                                       if (slider.enabled) {
                                           slider.isDragging = true
                                           sliderMouseArea.isDragging = true
                                           updateValueFromPosition(mouse.x, sliderHandle, sliderTrack)
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
                                               if (pressed && slider.isDragging && slider.enabled) {
                                                   updateValueFromPosition(mouse.x, sliderHandle, sliderTrack)
                                               }
                                           }
                        onClicked: mouse => {
                                       if (slider.enabled && !slider.isDragging) {
                                           updateValueFromPosition(mouse.x, sliderHandle, sliderTrack)
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
                    anchors.bottom: slider.tooltipPlacement === DankSlider.Before ? parent.top : undefined
                    anchors.top: slider.tooltipPlacement === DankSlider.After ? parent.bottom : undefined
                    anchors.bottomMargin: Theme.spacingM
                    anchors.topMargin: Theme.spacingM
                    x: Math.max(0, Math.min(parent.width - width, sliderHandle.x + sliderHandle.width/2 - width/2))
                    visible: slider.alwaysShowValue ? slider.showValue : ((sliderMouseArea.containsMouse && slider.showValue) || (slider.isDragging && slider.showValue))
                    opacity: visible ? 1 : 0
                    z: 100

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

    Component {
        id: verticalLayout

        Column {
            anchors.centerIn: parent
            height: parent.height
            width: parent.width
            spacing: Theme.spacingM
            property bool containsMouse: sliderMouseArea.containsMouse

            DankIcon {
                name: slider.leftIcon
                size: Theme.iconSize
                color: slider.enabled ? Theme.surfaceText : Theme.onSurface_38
                anchors.horizontalCenter: parent.horizontalCenter
                visible: slider.leftIcon.length > 0
            }

            StyledRect {
                id: sliderTrack

                property int leftIconWidth: slider.leftIcon.length > 0 ? Theme.iconSize : 0
                property int rightIconWidth: slider.rightIcon.length > 0 ? Theme.iconSize : 0

                width: 12
                height: parent.height - (leftIconWidth + rightIconWidth + (slider.leftIcon.length > 0 ? Theme.spacingM : 0) + (slider.rightIcon.length > 0 ? Theme.spacingM : 0))
                radius: Theme.cornerRadius
                color: slider.trackColor
                anchors.horizontalCenter: parent.horizontalCenter
                clip: false

                StyledRect {
                    id: sliderFill
                    width: parent.width
                    radius: Theme.cornerRadius
                    height: {
                        const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                        const travel = sliderTrack.height - sliderHandle.height
                        const center = (travel * ratio) + sliderHandle.height / 2
                        return Math.max(0, Math.min(sliderTrack.height, center))
                    }
                    color: slider.enabled ? Theme.primary : Theme.withAlpha(Theme.onSurface, 0.12)
                    anchors.bottom: parent.bottom
                }

                StyledRect {
                    id: sliderReference
                    width: 24
                    height: 8
                    radius: Theme.cornerRadius
                    visible: slider.reference && slider.reference < slider.maximum && slider.reference > slider.minimum
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.withAlpha(Theme.onSurface, 0.12)
                    border.width: 3
                    border.color: slider.thumbOutlineColor
                    y: {
                        const ratio = 1 - ((slider.reference - slider.minimum) / (slider.maximum - slider.minimum))
                        const travel = sliderTrack.height - height
                        return Math.max(0, Math.min(travel, travel * ratio))
                    }
                }

                StyledRect {
                    id: sliderHandle

                    width: 24
                    height: 8
                    radius: Theme.cornerRadius
                    y: {
                        const ratio = 1 - (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                        const travel = sliderTrack.height - height
                        return Math.max(0, Math.min(travel, travel * ratio))
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
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
                            opacity = 0.16
                            width = 0
                            height = 0
                            rippleAnimation.start()
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
                                ripple.start()
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
                        anchors.leftMargin: -10
                        anchors.rightMargin: -10
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: slider.enabled
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton
                        onWheel: wheelEvent => {
                            if (!slider.wheelEnabled) {
                                wheelEvent.accepted = false
                                return
                            }
                            let step = Math.max(0.5, (maximum - minimum) / 100)
                            let newValue = wheelEvent.angleDelta.y > 0 ? Math.min(maximum, value + step) : Math.max(minimum, value - step)
                            newValue = Math.round(newValue)
                            if (newValue !== value) {
                                value = newValue
                                sliderValueChanged(newValue)
                            }
                            wheelEvent.accepted = true
                        }
                        onPressed: mouse => {
                            if (slider.enabled) {
                                slider.isDragging = true
                                sliderMouseArea.isDragging = true
                                updateValueFromPosition(mouse.y, sliderHandle, sliderTrack)
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
                            if (pressed && slider.isDragging && slider.enabled) {
                                updateValueFromPosition(mouse.y, sliderHandle, sliderTrack)
                            }
                        }
                        onClicked: mouse => {
                            if (slider.enabled && !slider.isDragging) {
                                updateValueFromPosition(mouse.y, sliderHandle, sliderTrack)
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
                    anchors.right: slider.tooltipPlacement === DankSlider.Before ? parent.left : undefined
                    anchors.left: slider.tooltipPlacement === DankSlider.After ? parent.right : undefined
                    anchors.rightMargin: Theme.spacingM
                    anchors.leftMargin: Theme.spacingM
                    y: Math.max(0, Math.min(parent.height - height, sliderHandle.y + sliderHandle.height/2 - height/2))
                    visible: slider.alwaysShowValue ? slider.showValue : ((sliderMouseArea.containsMouse && slider.showValue) || (slider.isDragging && slider.showValue))
                    opacity: visible ? 1 : 0
                    z: 100

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
                anchors.horizontalCenter: parent.horizontalCenter
                visible: slider.rightIcon.length > 0
            }
        }
    }
}
