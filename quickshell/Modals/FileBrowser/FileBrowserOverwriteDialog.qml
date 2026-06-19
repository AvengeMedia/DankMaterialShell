import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: overwriteDialog

    property bool showDialog: false
    property string pendingFilePath: ""

    signal confirmed(string filePath)
    signal cancelled

    visible: showDialog
    focus: showDialog

    Keys.onEscapePressed: {
        cancelled();
    }

    Keys.onReturnPressed: {
        confirmed(pendingFilePath);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.shadowStrong
        opacity: 0.8

        MouseArea {
            anchors.fill: parent
            onClicked: {
                cancelled();
            }
        }
    }

    StyledRect {
        anchors.centerIn: parent
        width: 400
        height: 160
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outlineMedium
        border.width: 1

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            StyledText {
                text: I18n.tr("File Already Exists")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: I18n.tr("A file with this name already exists. Do you want to overwrite it?")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceTextMedium
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                StyledRect {
                    width: 80
                    height: 36
                    radius: Theme.cornerRadius
                    color: cancelArea.containsMouse ? Qt.lighter(Theme.surfaceVariant, 1.2) : Theme.surfaceVariant
                    border.color: Theme.outline
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Cancel")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cancelled();
                        }
                    }
                }

                StyledRect {
                    width: 90
                    height: 36
                    radius: Theme.cornerRadius
                    color: overwriteArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Overwrite")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.background
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: overwriteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            confirmed(pendingFilePath);
                        }
                    }
                }
            }
        }
    }
}
