import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: sidebar

    property var quickAccessLocations: []
    property string currentPath: ""
    signal locationSelected(string path)

    width: 200
    color: Theme.surface
    clip: true

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 4

        StyledText {
            text: "Quick Access"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            font.weight: Font.Medium
            leftPadding: Theme.spacingS
            bottomPadding: Theme.spacingXS
        }

        Repeater {
            model: quickAccessLocations

            StyledRect {
                width: parent?.width ?? 0
                height: 38
                radius: Theme.cornerRadius
                color: quickAccessMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : (currentPath === modelData?.path ? Theme.surfacePressed : "transparent")

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    DankIcon {
                        name: modelData?.icon ?? ""
                        size: Theme.iconSize - 2
                        color: currentPath === modelData?.path ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData?.name ?? ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: currentPath === modelData?.path ? Theme.primary : Theme.surfaceText
                        font.weight: currentPath === modelData?.path ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: quickAccessMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: locationSelected(modelData?.path ?? "")
                }
            }
        }
    }
}
