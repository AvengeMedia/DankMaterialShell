import QtQuick
import qs.Common
import qs.Widgets

Flow {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool multiSelect: false
    property var selectedValues: []
    property int chipHeight: 32
    property int chipPadding: Theme.spacingM
    property bool showCheck: true
    property bool showCounts: true

    signal selectionChanged(int index)
    signal selectionToggled(int index, bool selected)

    spacing: Theme.spacingS
    width: parent ? parent.width : 400

    Repeater {
        model: root.model

        Rectangle {
            id: chip
            required property var modelData
            required property int index

            property var value: typeof modelData === "string" ? modelData : (modelData.value !== undefined ? modelData.value : (modelData.label || ""))
            property bool selected: root.multiSelect ? root.selectedValues.includes(value) : (index === root.currentIndex)
            property bool hovered: mouseArea.containsMouse
            property bool pressed: mouseArea.pressed
            property string label: typeof modelData === "string" ? modelData : (modelData.label || "")
            property int count: typeof modelData === "object" ? (modelData.count || 0) : 0
            property bool showCount: root.showCounts && count > 0

            width: contentRow.implicitWidth + root.chipPadding * 2
            height: root.chipHeight
            radius: height / 2

            color: selected ? Theme.primary : Theme.surfaceVariant

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: {
                    if (pressed)
                        return chip.selected ? Theme.primaryPressed : Theme.surfaceTextHover;
                    if (hovered)
                        return chip.selected ? Theme.primaryHover : Theme.surfaceTextHover;
                    return "transparent";
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shorterDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            DankRipple {
                id: chipRipple
                cornerRadius: chip.radius
                rippleColor: chip.selected ? Theme.primaryText : Theme.surfaceVariantText
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "check"
                    size: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.primaryText
                    visible: root.showCheck && chip.selected
                }

                StyledText {
                    text: chip.label + (chip.showCount ? " (" + chip.count + ")" : "")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: chip.selected ? Font.Medium : Font.Normal
                    color: chip.selected ? Theme.primaryText : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => chipRipple.trigger(mouse.x, mouse.y)
                onClicked: {
                    if (root.multiSelect) {
                        root.selectionToggled(chip.index, !chip.selected);
                        return;
                    }
                    root.currentIndex = chip.index;
                    root.selectionChanged(chip.index);
                }
            }
        }
    }
}
