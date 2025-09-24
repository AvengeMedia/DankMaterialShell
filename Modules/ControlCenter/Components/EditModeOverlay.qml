import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool editMode: false
    property var widgetData: null
    property int widgetIndex: -1
    property bool showSizeControls: true
    property bool isSlider: false

    signal removeWidget(int index)
    signal toggleWidgetSize(int index)

    // Delete button in top-right
    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Theme.error
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -4
        visible: editMode
        z: 10

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 12
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.removeWidget(widgetIndex)
        }
    }

    // Circular size control indicator in bottom-right
    Rectangle {
        width: 24
        height: 24
        radius: 12
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: -8
        visible: editMode && showSizeControls
        z: 1000
        color: Theme.surfaceContainer
        border.color: Theme.primary
        border.width: 2

        property real currentWidth: widgetData?.width || 50
        property real fillPercentage: {
            if (isSlider) {
                // For sliders: 50% = 0.5, 100% = 1.0
                return currentWidth === 50 ? 0.5 : 1.0
            } else {
                // For regular widgets: 25% = 0.25, 50% = 0.5, 75% = 0.75, 100% = 1.0
                return currentWidth / 100
            }
        }

        // Background circle
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.outline
            border.width: 1
            opacity: 0.6
        }

        // Progress fill using a pie chart approach
        Canvas {
            id: progressCanvas
            anchors.fill: parent

            property real targetFillPercentage: parent.fillPercentage

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var centerX = width / 2
                var centerY = height / 2
                var radius = Math.min(width, height) / 2 - 2
                var fillAngle = targetFillPercentage * 2 * Math.PI

                if (fillAngle > 0) {
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + fillAngle)
                    ctx.closePath()
                    ctx.fillStyle = Theme.primary
                    ctx.fill()
                }
            }

            onTargetFillPercentageChanged: {
                requestPaint()
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            z: 10000
            propagateComposedEvents: false
            preventStealing: true
            visible: editMode

            onPressed: function (mouse) {
                mouse.accepted = true
            }

            onClicked: function (mouse) {
                mouse.accepted = true

                var widgets = SettingsData.controlCenterWidgets.slice()

                if (widgetIndex < 0 || widgetIndex >= widgets.length) {
                    return
                }

                var currentSize = widgets[widgetIndex].width || 50
                var newSize

                if (isSlider) {
                    newSize = currentSize === 50 ? 100 : 50
                } else {
                    switch (currentSize) {
                    case 25:
                        newSize = 50
                        break
                    case 50:
                        newSize = 75
                        break
                    case 75:
                        newSize = 100
                        break
                    case 100:
                        newSize = 25
                        break
                    default:
                        newSize = 50
                        break
                    }
                }

                widgets[widgetIndex].width = newSize
                SettingsData.setControlCenterWidgets(widgets)
            }
        }

        // Smooth transition for fill changes
        Behavior on fillPercentage {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // Drag handle indicator in top-left
    Rectangle {
        width: 20
        height: 12
        radius: 6
        color: Theme.surfaceContainer
        border.color: Theme.outline
        border.width: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 4
        visible: editMode
        z: 20
        opacity: 0.8

        Column {
            anchors.centerIn: parent
            spacing: 1

            Rectangle {
                width: 12
                height: 2
                radius: 1
                color: Theme.surfaceText
            }
            Rectangle {
                width: 12
                height: 2
                radius: 1
                color: Theme.surfaceText
            }
        }
    }

    // Border highlight
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
        radius: Theme.cornerRadius
        border.color: Theme.primary
        border.width: editMode ? 1 : 0
        visible: editMode
        z: -1

        Behavior on border.width {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }
}
