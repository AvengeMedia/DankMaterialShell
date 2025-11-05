import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:power-menu"

    property int selectedIndex: 0
    property int optionCount: SessionService.hibernateSupported ? 5 : 4
    property rect parentBounds: Qt.rect(0, 0, 0, 0)
    property var parentScreen: null

    signal powerActionRequested(string action, string title, string message)

    function openCentered() {
        parentBounds = Qt.rect(0, 0, 0, 0)
        parentScreen = null
        backgroundOpacity = 0.5
        open()
    }

    function openFromControlCenter(bounds, targetScreen) {
        parentBounds = bounds
        parentScreen = targetScreen
        backgroundOpacity = 0
        open()
    }

    function selectOption(action) {
        close();
        const actions = {
            "logout": {
                "title": I18n.tr("Log Out"),
                "message": I18n.tr("Are you sure you want to log out?")
            },
            "suspend": {
                "title": I18n.tr("Suspend"),
                "message": I18n.tr("Are you sure you want to suspend the system?")
            },
            "hibernate": {
                "title": I18n.tr("Hibernate"),
                "message": I18n.tr("Are you sure you want to hibernate the system?")
            },
            "reboot": {
                "title": I18n.tr("Reboot"),
                "message": I18n.tr("Are you sure you want to reboot the system?")
            },
            "poweroff": {
                "title": I18n.tr("Power Off"),
                "message": I18n.tr("Are you sure you want to power off the system?")
            }
        }
        const selected = actions[action]
        if (selected) {
            root.powerActionRequested(action, selected.title, selected.message);
        }

    }

    shouldBeVisible: false
    width: 320
    height: contentLoader.item ? contentLoader.item.implicitHeight : 300
    enableShadow: true
    screen: parentScreen
    positioning: parentBounds.width > 0 ? "custom" : "center"
    customPosition: {
        if (parentBounds.width > 0) {
            const centerX = parentBounds.x + (parentBounds.width - width) / 2
            const centerY = parentBounds.y + (parentBounds.height - height) / 2
            return Qt.point(centerX, centerY)
        }
        return Qt.point(0, 0)
    }
    onBackgroundClicked: () => {
        return close();
    }
    onOpened: () => {
        selectedIndex = 0;
        Qt.callLater(() => modalFocusScope.forceActiveFocus());
    }
    modalFocusScope.Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selectedIndex = (selectedIndex - 1 + optionCount) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selectedIndex = (selectedIndex + 1) % optionCount;
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            const actions = ["logout", "suspend"];
            if (SessionService.hibernateSupported) actions.push("hibernate");
            actions.push("reboot", "poweroff");
            if (selectedIndex < actions.length) {
                selectOption(actions[selectedIndex]);
            }
            event.accepted = true;
            break;
        case Qt.Key_N:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex + 1) % optionCount;
                event.accepted = true;
            }
            break;
        case Qt.Key_P:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex - 1 + optionCount) % optionCount;
                event.accepted = true;
            }
            break;
        case Qt.Key_J:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex + 1) % optionCount;
                event.accepted = true;
            }
            break;
        case Qt.Key_K:
            if (event.modifiers & Qt.ControlModifier) {
                selectedIndex = (selectedIndex - 1 + optionCount) % optionCount;
                event.accepted = true;
            }
            break;
        }
    }

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: mainColumn.implicitHeight + Theme.spacingL * 2

            Column {
                id: mainColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width

                    StyledText {
                        text: I18n.tr("Power Options")
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
                                text: I18n.tr("Log Out")
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
                                selectOption("logout");
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
                                text: I18n.tr("Suspend")
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
                                selectOption("suspend");
                            }
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            if (selectedIndex === 2) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (hibernateArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === 2 ? Theme.primary : "transparent"
                        border.width: selectedIndex === 2 ? 1 : 0
                        visible: SessionService.hibernateSupported

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "ac_unit"
                                size: Theme.iconSize
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Hibernate")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        MouseArea {
                            id: hibernateArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: () => {
                                selectedIndex = 2;
                                selectOption("hibernate");
                            }
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            const rebootIndex = SessionService.hibernateSupported ? 3 : 2;
                            if (selectedIndex === rebootIndex) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (rebootArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === (SessionService.hibernateSupported ? 3 : 2) ? Theme.primary : "transparent"
                        border.width: selectedIndex === (SessionService.hibernateSupported ? 3 : 2) ? 1 : 0

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
                                text: I18n.tr("Reboot")
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
                                selectedIndex = SessionService.hibernateSupported ? 3 : 2;
                                selectOption("reboot");
                            }
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            const powerOffIndex = SessionService.hibernateSupported ? 4 : 3;
                            if (selectedIndex === powerOffIndex) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                            } else if (powerOffArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                            }
                        }
                        border.color: selectedIndex === (SessionService.hibernateSupported ? 4 : 3) ? Theme.primary : "transparent"
                        border.width: selectedIndex === (SessionService.hibernateSupported ? 4 : 3) ? 1 : 0

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
                                text: I18n.tr("Power Off")
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
                                selectedIndex = SessionService.hibernateSupported ? 4 : 3;
                                selectOption("poweroff");
                            }
                        }

                    }

                }

                Item {
                    height: Theme.spacingS
                }

            }

        }

    }

}
