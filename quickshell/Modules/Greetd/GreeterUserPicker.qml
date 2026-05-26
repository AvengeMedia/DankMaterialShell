import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool expanded: false

    signal userSelected(string username)
    signal toggleRequested()

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split("/").map(s => encodeURIComponent(s)).join("/");
    }

    function profileImageSource(username) {
        const path = GreeterUsersService.profileImagePath(username);
        if (path)
            return encodeFileUrl(path);
        return "";
    }

    implicitHeight: column.implicitHeight
    implicitWidth: parent ? parent.width : 320

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            visible: !root.expanded && !!GreeterState.username

            StyledText {
                Layout.fillWidth: true
                text: GreeterUsersService.optionLabel(GreeterState.username)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                elide: Text.ElideRight
            }

            DankIcon {
                name: "expand_more"
                size: 20
                color: Theme.surfaceVariantText
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRequested()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            visible: !root.expanded && !GreeterState.username

            DankIcon {
                anchors.centerIn: parent
                name: "expand_more"
                size: 20
                color: Theme.surfaceVariantText
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRequested()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS
            visible: root.expanded

            Repeater {
                model: GreeterUsersService.users

                delegate: Rectangle {
                    id: userRow

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: Theme.cornerRadius
                    color: userRowMouse.containsMouse ? Theme.surfacePressed : "transparent"
                    border.color: GreeterState.username === userRow.modelData.username ? Theme.primary : "transparent"
                    border.width: GreeterState.username === userRow.modelData.username ? 1 : 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingM

                        Item {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36

                            DankCircularImage {
                                anchors.fill: parent
                                imageSource: root.profileImageSource(userRow.modelData.username)
                                fallbackIcon: "person"
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: GreeterUsersService.optionLabel(userRow.modelData.username)
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: userRowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.userSelected(userRow.modelData.username)
                    }
                }
            }
        }
    }
}
