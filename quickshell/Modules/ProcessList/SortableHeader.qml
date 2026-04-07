import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: headerItem

    property string text: ""
    property string sortKey: ""
    property string currentSort: ""
    property bool sortAscending: false
    property int alignment: Text.AlignHCenter

    signal clicked

    readonly property bool isActive: sortKey === currentSort

    height: 36

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.cornerRadius
        color: headerItem.isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (headerMouseArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06) : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        spacing: 4

        Item {
            Layout.fillWidth: headerItem.alignment === Text.AlignLeft
            visible: headerItem.alignment !== Text.AlignLeft
        }

        StyledText {
            text: headerItem.text
            font.pixelSize: Theme.fontSizeSmall
            font.family: SettingsData.monoFontFamily
            font.weight: headerItem.isActive ? Font.Bold : Font.Medium
            color: headerItem.isActive ? Theme.primary : Theme.surfaceText
            opacity: headerItem.isActive ? 1 : 0.8
        }

        DankIcon {
            name: headerItem.sortAscending ? "arrow_upward" : "arrow_downward"
            size: Theme.fontSizeSmall
            color: Theme.primary
            visible: headerItem.isActive
        }

        Item {
            Layout.fillWidth: headerItem.alignment !== Text.AlignLeft
            visible: headerItem.alignment === Text.AlignLeft
        }
    }

    MouseArea {
        id: headerMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: headerItem.clicked()
    }
}
