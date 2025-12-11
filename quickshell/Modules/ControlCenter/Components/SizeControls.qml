import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Row {
    id: root

    property int currentSize: 50
    property bool isSlider: false
    property int widgetIndex: -1

    signal sizeChanged(int newSize)

    readonly property var availableSizes: isSlider ? [50, 75, 100] : [25, 50, 75, 100]

    spacing: 2

    Repeater {
        model: root.availableSizes

        Rectangle {
            width: 16
            height: 16
            radius: 3
            color: modelData === root.currentSize ? Theme.primary : Theme.surfaceContainer
            border.color: modelData === root.currentSize ? Theme.primary : Theme.outline
            border.width: 1

            StyledText {
                anchors.centerIn: parent
                text: modelData.toString()
                font.pixelSize: 8
                font.weight: Font.Medium
                color: modelData === root.currentSize ? Theme.primaryText : Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentSize = modelData
                    root.sizeChanged(modelData)
                }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.shortDuration }
            }
        }
    }
}
