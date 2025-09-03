import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    property int selectedIndex: 0
    property int optionCount: 4

    signal powerActionRequested(string action, string title, string message)

    function selectOption() {
        close();
        const actions = [{
            "action": "logout",
            "title": "Log Out",
            "message": "Are you sure you want to log out?"
        }, {
            "action": "suspend",
            "title": "Suspend",
            "message": "Are you sure you want to suspend the system?"
        }, {
            "action": "reboot",
            "title": "Reboot",
            "message": "Are you sure you want to reboot the system?"
        }, {
            "action": "poweroff",
            "title": "Power Off",
            "message": "Are you sure you want to power off the system?"
        }];
        const selected = actions[selectedIndex];
        if (selected) {
            root.powerActionRequested(selected.action, selected.title, selected.message);
        }

    }

    shouldBeVisible: false
    width: 320
    height: 300
    enableShadow: true
    onBackgroundClicked: () => {
        return close();
    }
    onOpened: () => {
        selectedIndex = 0;
        modalFocusScope.forceActiveFocus();
    }
    modalFocusScope.Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
            selectedIndex = (selectedIndex - 1 + optionCount) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Down:
            selectedIndex = (selectedIndex + 1) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Tab:
            selectedIndex = (selectedIndex + 1) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            selectOption();
            event.accepted = true;
            break;
        }
    }

    content: Component {
        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width

                    StyledText {
                        text: "Power Options"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - 150
                        height: 1
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        hoverColor: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                        onClicked: () => {
                            return close();
                        }
                    }

                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            if (selectedIndex === 0) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (logoutArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === 0 ? Theme.primary : "transparent"
                        border.width: selectedIndex === 0 ? 1 : 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "logout"
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Log Out"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: logoutArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                selectedIndex = 0;
                                selectOption();
                            }
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            if (selectedIndex === 1) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (suspendArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === 1 ? Theme.primary : "transparent"
                        border.width: selectedIndex === 1 ? 1 : 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "bedtime"
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Suspend"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: suspendArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                selectedIndex = 1;
                                selectOption();
                            }
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            if (selectedIndex === 2) {
                                return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12);
                            } else if (rebootArea.containsMouse) {
                                return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === 2 ? Theme.warning : "transparent"
                        border.width: selectedIndex === 2 ? 1 : 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "restart_alt"
                                size: Theme.iconSize
                                color: rebootArea.containsMouse ? Theme.warning : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Reboot"
                                font.pixelSize: Theme.fontSizeMedium
                                color: rebootArea.containsMouse ? Theme.warning : Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: rebootArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                selectedIndex = 2;
                                selectOption();
                            }
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            if (selectedIndex === 3) {
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12);
                            } else if (powerOffArea.containsMouse) {
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === 3 ? Theme.error : "transparent"
                        border.width: selectedIndex === 3 ? 1 : 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "power_settings_new"
                                size: Theme.iconSize
                                color: powerOffArea.containsMouse ? Theme.error : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Power Off"
                                font.pixelSize: Theme.fontSizeMedium
                                color: powerOffArea.containsMouse ? Theme.error : Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: powerOffArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                selectedIndex = 3;
                                selectOption();
                            }
                        }

                    }

                }

                Item {
                    height: Theme.spacingS
                }

                StyledText {
                    text: "↑↓ Navigate • Tab Cycle • Enter Select • Esc Close"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.7
                }

            }

        }

    }

}
