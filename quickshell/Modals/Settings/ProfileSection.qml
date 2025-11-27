import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var parentModal: null

    width: parent.width - Theme.spacingS * 2
    height: 110
    radius: Theme.cornerRadius
    color: "transparent"
    border.width: 0

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        Item {
            id: profileImageContainer

            width: 80
            height: 80
            anchors.verticalCenter: parent.verticalCenter

            DankCircularImage {
                id: profileImage

                anchors.fill: parent
                imageSource: {
                    if (PortalService.profileImage === "") {
                        return "";
                    }
                    if (PortalService.profileImage.startsWith("/")) {
                        return "file://" + PortalService.profileImage;
                    }
                    return PortalService.profileImage;
                }
                fallbackIcon: "person"
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.7)
                visible: profileMouseArea.containsMouse

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Qt.rgba(255, 255, 255, 0.9)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "edit"
                            size: 16
                            color: "black"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                if (root.parentModal) {
                                    root.parentModal.allowFocusOverride = true;
                                    root.parentModal.shouldHaveFocus = false;
                                    if (root.parentModal.profileBrowser) {
                                        root.parentModal.profileBrowser.open();
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Qt.rgba(255, 255, 255, 0.9)
                        visible: profileImage.hasImage

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            color: "black"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                return PortalService.setProfileImage("");
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: profileMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: true
                acceptedButtons: Qt.NoButton
            }
        }

        Column {
            width: 120
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: UserInfoService.fullName || "User"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                width: parent.width
            }

            StyledText {
                text: DgopService.hostname || "DMS"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
