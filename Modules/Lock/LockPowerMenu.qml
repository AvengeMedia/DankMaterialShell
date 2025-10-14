pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVisible: false
    property bool showLogout: true
    property int selectedIndex: 0
    property int optionCount: {
        let count = 0
        if (showLogout) count++
        count++
        if (SessionService.hibernateSupported) count++
        count += 2
        return count
    }

    signal closed()

    function show() {
        isVisible = true
        selectedIndex = 0
        Qt.callLater(() => {
            if (powerMenuFocusScope && powerMenuFocusScope.forceActiveFocus) {
                powerMenuFocusScope.forceActiveFocus()
            }
        })
    }

    function hide() {
        isVisible = false
        closed()
    }

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    visible: isVisible
    z: 1000

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    FocusScope {
        id: powerMenuFocusScope
        anchors.fill: parent
        focus: root.isVisible

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(() => forceActiveFocus())
            }
        }

        Keys.onEscapePressed: {
            root.hide()
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                selectedIndex = (selectedIndex - 1 + optionCount) % optionCount
                event.accepted = true
                break
            case Qt.Key_Down:
            case Qt.Key_Tab:
                selectedIndex = (selectedIndex + 1) % optionCount
                event.accepted = true
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                const actions = []
                if (showLogout) actions.push("logout")
                actions.push("suspend")
                if (SessionService.hibernateSupported) actions.push("hibernate")
                actions.push("reboot", "poweroff")
                if (selectedIndex < actions.length) {
                    const action = actions[selectedIndex]
                    hide()
                    switch (action) {
                    case "logout":
                        SessionService.logout()
                        break
                    case "suspend":
                        SessionService.suspend()
                        break
                    case "hibernate":
                        SessionService.hibernate()
                        break
                    case "reboot":
                        SessionService.reboot()
                        break
                    case "poweroff":
                        SessionService.poweroff()
                        break
                    }
                }
                event.accepted = true
                break
            case Qt.Key_N:
                if (event.modifiers & Qt.ControlModifier) {
                    selectedIndex = (selectedIndex + 1) % optionCount
                    event.accepted = true
                }
                break
            case Qt.Key_P:
                if (event.modifiers & Qt.ControlModifier) {
                    selectedIndex = (selectedIndex - 1 + optionCount) % optionCount
                    event.accepted = true
                }
                break
            case Qt.Key_J:
                if (event.modifiers & Qt.ControlModifier) {
                    selectedIndex = (selectedIndex + 1) % optionCount
                    event.accepted = true
                }
                break
            case Qt.Key_K:
                if (event.modifiers & Qt.ControlModifier) {
                    selectedIndex = (selectedIndex - 1 + optionCount) % optionCount
                    event.accepted = true
                }
                break
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 320
            implicitHeight: mainColumn.implicitHeight + Theme.spacingL * 2
            height: implicitHeight
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outlineMedium
            border.width: 1

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
                        onClicked: root.hide()
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        visible: showLogout
                        color: {
                            if (selectedIndex === 0) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            } else if (logoutArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
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
                            onClicked: {
                                root.hide()
                                SessionService.logout()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            const suspendIdx = showLogout ? 1 : 0
                            if (selectedIndex === suspendIdx) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            } else if (suspendArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                            }
                        }
                        border.color: selectedIndex === (showLogout ? 1 : 0) ? Theme.primary : "transparent"
                        border.width: selectedIndex === (showLogout ? 1 : 0) ? 1 : 0

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
                            onClicked: {
                                root.hide()
                                SessionService.suspend()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            const hibernateIdx = showLogout ? 2 : 1
                            if (selectedIndex === hibernateIdx) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            } else if (hibernateArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                            }
                        }
                        border.color: selectedIndex === (showLogout ? 2 : 1) ? Theme.primary : "transparent"
                        border.width: selectedIndex === (showLogout ? 2 : 1) ? 1 : 0
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
                            onClicked: {
                                root.hide()
                                SessionService.hibernate()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            let rebootIdx = showLogout ? 3 : 2
                            if (!SessionService.hibernateSupported) rebootIdx--
                            if (selectedIndex === rebootIdx) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            } else if (rebootArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                            }
                        }
                        border.color: {
                            let rebootIdx = showLogout ? 3 : 2
                            if (!SessionService.hibernateSupported) rebootIdx--
                            return selectedIndex === rebootIdx ? Theme.primary : "transparent"
                        }
                        border.width: {
                            let rebootIdx = showLogout ? 3 : 2
                            if (!SessionService.hibernateSupported) rebootIdx--
                            return selectedIndex === rebootIdx ? 1 : 0
                        }

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
                            onClicked: {
                                root.hide()
                                SessionService.reboot()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: {
                            let powerOffIdx = showLogout ? 4 : 3
                            if (!SessionService.hibernateSupported) powerOffIdx--
                            if (selectedIndex === powerOffIdx) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            } else if (powerOffArea.containsMouse) {
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            } else {
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                            }
                        }
                        border.color: {
                            let powerOffIdx = showLogout ? 4 : 3
                            if (!SessionService.hibernateSupported) powerOffIdx--
                            return selectedIndex === powerOffIdx ? Theme.primary : "transparent"
                        }
                        border.width: {
                            let powerOffIdx = showLogout ? 4 : 3
                            if (!SessionService.hibernateSupported) powerOffIdx--
                            return selectedIndex === powerOffIdx ? 1 : 0
                        }

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
                            onClicked: {
                                root.hide()
                                SessionService.poweroff()
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
