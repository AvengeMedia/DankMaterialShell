import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: navigation

    property string currentPath: ""
    property string homeDir: ""
    property bool backButtonFocused: false
    property bool keyboardNavigationActive: false
    property bool showSidebar: true
    property bool pathEditMode: false
    property bool pathInputHasFocus: false

    signal navigateUp()
    signal navigateTo(string path)
    signal pathInputFocusChanged(bool hasFocus)

    height: 40
    leftPadding: Theme.spacingM
    rightPadding: Theme.spacingM
    spacing: Theme.spacingS

    StyledRect {
        width: 32
        height: 32
        radius: Theme.cornerRadius
        color: (backButtonMouseArea.containsMouse || (backButtonFocused && keyboardNavigationActive)) && currentPath !== homeDir ? Theme.surfaceVariant : "transparent"
        opacity: currentPath !== homeDir ? 1 : 0
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            anchors.centerIn: parent
            name: "arrow_back"
            size: Theme.iconSizeSmall
            color: Theme.surfaceText
        }

        MouseArea {
            id: backButtonMouseArea

            anchors.fill: parent
            hoverEnabled: currentPath !== homeDir
            cursorShape: currentPath !== homeDir ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: currentPath !== homeDir
            onClicked: navigation.navigateUp()
        }
    }

    Item {
        width: Math.max(0, (parent?.width ?? 0) - 40 - Theme.spacingS - (showSidebar ? 0 : 80))
        height: 32
        anchors.verticalCenter: parent.verticalCenter

        StyledRect {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: pathEditMode ? Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency) : "transparent"
            border.color: pathEditMode ? Theme.primary : "transparent"
            border.width: pathEditMode ? 1 : 0
            visible: !pathEditMode

            StyledText {
                id: pathDisplay
                text: currentPath.replace("file://", "")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                elide: Text.ElideMiddle
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    pathEditMode = true
                    pathInput.text = currentPath.replace("file://", "")
                    Qt.callLater(() => pathInput.forceActiveFocus())
                }
            }
        }

        DankTextField {
            id: pathInput
            anchors.fill: parent
            visible: pathEditMode
            topPadding: Theme.spacingXS
            bottomPadding: Theme.spacingXS
            onAccepted: {
                const newPath = text.trim()
                if (newPath !== "") {
                    navigation.navigateTo(newPath)
                }
                pathEditMode = false
            }
            Keys.onEscapePressed: {
                pathEditMode = false
            }
            Keys.onDownPressed: {
                pathEditMode = false
            }
            onActiveFocusChanged: {
                navigation.pathInputFocusChanged(activeFocus)
                if (!activeFocus && pathEditMode) {
                    pathEditMode = false
                }
            }
        }
    }

    Row {
        spacing: Theme.spacingXS
        visible: !showSidebar
        anchors.verticalCenter: parent.verticalCenter

        DankActionButton {
            circular: false
            iconName: "sort"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceText
        }
    }
}
