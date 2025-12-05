import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    property string outputName: ""
    property var position: undefined
    property var mode: undefined
    property var vrr: undefined
    property int countdown: 15

    shouldBeVisible: false
    allowStacking: true
    modalWidth: 420
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingM * 2 : 200

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.shouldBeVisible
        onTriggered: {
            countdown--;
            if (countdown <= 0) {
                revert();
            }
        }
    }

    onOpened: {
        countdown = 15;
        countdownTimer.start();
    }

    onClosed: {
        countdownTimer.stop();
    }

    onBackgroundClicked: revert

    content: Component {
        FocusScope {
            id: confirmContent

            anchors.fill: parent
            focus: true
            implicitHeight: mainColumn.implicitHeight

            Keys.onEscapePressed: event => {
                revert();
                event.accepted = true;
            }

            Keys.onReturnPressed: event => {
                confirm();
                event.accepted = true;
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                anchors.topMargin: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Confirm Display Changes")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: I18n.tr("Display settings for ") + outputName
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 80
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            text: I18n.tr("Reverting in:")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: countdown + "s"
                            font.pixelSize: Theme.fontSizeXLarge * 1.5
                            color: Theme.primary
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Changes:")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                    }

                    StyledText {
                        visible: position !== undefined && position !== null
                        text: I18n.tr("Position: ") + (position ? position.x + ", " + position.y : "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        visible: mode !== undefined && mode !== null && mode !== ""
                        text: I18n.tr("Mode: ") + (mode || "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        visible: vrr !== undefined && vrr !== null
                        text: I18n.tr("VRR: ") + (vrr ? I18n.tr("Enabled") : I18n.tr("Disabled"))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            width: Math.max(70, revertText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: revertArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                            border.color: Theme.surfaceVariantAlpha
                            border.width: 1

                            StyledText {
                                id: revertText

                                anchors.centerIn: parent
                                text: I18n.tr("Revert")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: revertArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: revert
                            }
                        }

                        Rectangle {
                            width: Math.max(80, confirmText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: confirmArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                            StyledText {
                                id: confirmText

                                anchors.centerIn: parent
                                text: I18n.tr("Keep Changes")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.background
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: confirmArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: confirm
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }

            DankActionButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                iconName: "close"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: revert
            }
        }
    }

    function confirm() {
        displaysTab.confirmChanges();
        close();
    }

    function revert() {
        displaysTab.revertChanges();
        close();
    }
}
