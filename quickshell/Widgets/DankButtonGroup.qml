import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Flow {
    id: root

    property var model: []
    property int currentIndex: -1
    property string selectionMode: "single"
    property bool multiSelect: selectionMode === "multi"
    property var initialSelection: []
    property var currentSelection: initialSelection
    property bool checkEnabled: true
    property int buttonHeight: 40
    property int minButtonWidth: 64
    property int buttonPadding: Theme.spacingL
    property int checkIconSize: Theme.iconSizeSmall
    property int textSize: Theme.fontSizeMedium

    signal selectionChanged(int index, bool selected)
    signal animationCompleted()

    spacing: Theme.spacingXS

    Timer {
        id: animationTimer
        interval: Theme.shortDuration
        onTriggered: root.animationCompleted()
    }

    function isSelected(index) {
        if (multiSelect) {
            return repeater.itemAt(index)?.selected || false
        }
        return index === currentIndex
    }

    function selectItem(index) {
        if (multiSelect) {
            const modelValue = model[index]
            let newSelection = [...currentSelection]
            const isCurrentlySelected = newSelection.includes(modelValue)

            if (isCurrentlySelected) {
                newSelection = newSelection.filter(item => item !== modelValue)
            } else {
                newSelection.push(modelValue)
            }

            currentSelection = newSelection
            selectionChanged(index, !isCurrentlySelected)
            animationTimer.restart()
        } else {
            const oldIndex = currentIndex
            currentIndex = index
            selectionChanged(index, true)
            if (oldIndex !== index && oldIndex >= 0) {
                selectionChanged(oldIndex, false)
            }
            animationTimer.restart()
        }
    }

    Repeater {
        id: repeater
        model: ScriptModel {
            values: root.model
        }

        delegate: Rectangle {
            id: segment

            property bool selected: multiSelect ? root.currentSelection.includes(modelData) : (index === root.currentIndex)
            property bool hovered: mouseArea.containsMouse
            property bool pressed: mouseArea.pressed
            property bool isFirst: index === 0
            property bool isLast: index === repeater.count - 1
            property bool prevSelected: index > 0 ? root.isSelected(index - 1) : false
            property bool nextSelected: index < repeater.count - 1 ? root.isSelected(index + 1) : false

            width: Math.max(contentItem.implicitWidth + root.buttonPadding * 2, root.minButtonWidth) + (selected ? 4 : 0)
            height: root.buttonHeight

            color: selected ? Theme.primary : Theme.surfaceVariant
            border.color: "transparent"
            border.width: 0

            topLeftRadius: (isFirst || selected) ? Theme.cornerRadius : 4
            bottomLeftRadius: (isFirst || selected) ? Theme.cornerRadius : 4
            topRightRadius: (isLast || selected) ? Theme.cornerRadius : 4
            bottomRightRadius: (isLast || selected) ? Theme.cornerRadius : 4

            Behavior on width {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on topLeftRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on topRightRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on bottomLeftRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on bottomRightRadius {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                id: stateLayer
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                bottomLeftRadius: parent.bottomLeftRadius
                topRightRadius: parent.topRightRadius
                bottomRightRadius: parent.bottomRightRadius
                color: {
                    if (pressed) return selected ? Theme.primaryPressed : Theme.surfaceTextHover
                    if (hovered) return selected ? Theme.primaryHover : Theme.surfaceTextHover
                    return "transparent"
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shorterDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Item {
                id: contentItem
                anchors.centerIn: parent
                implicitWidth: contentRow.implicitWidth
                implicitHeight: contentRow.implicitHeight

                Row {
                    id: contentRow
                    spacing: Theme.spacingS

                    DankIcon {
                        id: checkIcon
                        name: "check"
                        size: root.checkIconSize
                        color: segment.selected ? Theme.primaryText : Theme.surfaceVariantText
                        visible: root.checkEnabled && segment.selected
                        opacity: segment.selected ? 1 : 0
                        scale: segment.selected ? 1 : 0.6
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }

                    StyledText {
                        id: buttonText
                        text: typeof modelData === "string" ? modelData : modelData.text || ""
                        font.pixelSize: root.textSize
                        font.weight: segment.selected ? Font.Medium : Font.Normal
                        color: segment.selected ? Theme.primaryText : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectItem(index)
            }
        }
    }
}
