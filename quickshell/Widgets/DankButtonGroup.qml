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
    property bool userInteracted: false

    signal selectionChanged(int index, bool selected)
    signal animationCompleted

    spacing: Theme.spacingXS

    Timer {
        id: animationTimer
        interval: Theme.shortDuration
        onTriggered: {
            root.userInteracted = false;
            root.animationCompleted();
        }
    }

    function isSelected(index) {
        if (multiSelect) {
            return repeater.itemAt(index)?.selected || false;
        }
        return index === currentIndex;
    }

    function selectItem(index) {
        userInteracted = true;
        if (multiSelect) {
            const modelValue = model[index];
            let newSelection = [...currentSelection];
            const isCurrentlySelected = newSelection.includes(modelValue);

            if (isCurrentlySelected) {
                newSelection = newSelection.filter(item => item !== modelValue);
            } else {
                newSelection.push(modelValue);
            }

            currentSelection = newSelection;
            selectionChanged(index, !isCurrentlySelected);
            animationTimer.restart();
        } else {
            const oldIndex = currentIndex;
            selectionChanged(index, true);
            if (oldIndex !== index && oldIndex >= 0) {
                selectionChanged(oldIndex, false);
            }
            animationTimer.restart();
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
            property bool visualFirst: I18n.isRtl ? isLast : isFirst
            property bool visualLast: I18n.isRtl ? isFirst : isLast
            property bool prevSelected: index > 0 ? root.isSelected(index - 1) : false
            property bool nextSelected: index < repeater.count - 1 ? root.isSelected(index + 1) : false

            width: Math.max(contentItem.implicitWidth + root.buttonPadding * 2, root.minButtonWidth) + (selected ? 4 : 0)
            height: root.buttonHeight

            color: selected ? Theme.buttonBg : Theme.surfaceVariant
            border.color: "transparent"
            border.width: 0

            topLeftRadius: (visualFirst || selected) ? Theme.cornerRadius : Math.min(4, Theme.cornerRadius)
            bottomLeftRadius: (visualFirst || selected) ? Theme.cornerRadius : Math.min(4, Theme.cornerRadius)
            topRightRadius: (visualLast || selected) ? Theme.cornerRadius : Math.min(4, Theme.cornerRadius)
            bottomRightRadius: (visualLast || selected) ? Theme.cornerRadius : Math.min(4, Theme.cornerRadius)

            Behavior on width {
                enabled: root.userInteracted
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on topLeftRadius {
                enabled: root.userInteracted
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on topRightRadius {
                enabled: root.userInteracted
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on bottomLeftRadius {
                enabled: root.userInteracted
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on bottomRightRadius {
                enabled: root.userInteracted
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on color {
                enabled: root.userInteracted
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
                    if (pressed)
                        return selected ? Theme.buttonPressed : Theme.surfaceTextHover;
                    if (hovered)
                        return selected ? Theme.buttonHover : Theme.surfaceTextHover;
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
                id: segmentRipple
                cornerRadius: Theme.cornerRadius
                rippleColor: segment.selected ? Theme.buttonText : Theme.surfaceVariantText
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
                        color: segment.selected ? Theme.buttonText : Theme.surfaceVariantText
                        visible: root.checkEnabled && segment.selected
                        opacity: segment.selected ? 1 : 0
                        scale: segment.selected ? 1 : 0.6
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            enabled: root.userInteracted
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        Behavior on scale {
                            enabled: root.userInteracted
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
                        color: segment.selected ? Theme.buttonText : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => segmentRipple.trigger(mouse.x, mouse.y)
                onClicked: root.selectItem(index)
            }
        }
    }
}
