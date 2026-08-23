import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var keyboardController: null
    property int currentTab: 0
    property bool showDndMenu: false
    property var transientSurfaceTracker: null
    property bool tapToClose: false

    signal headerTapped

    signal settingsRequested

    onShowDndMenuChanged: transientSurfaceTracker?.setActive(root, showDndMenu, null)
    Component.onDestruction: transientSurfaceTracker?.unregister(root)

    Connections {
        target: root.transientSurfaceTracker
        ignoreUnknownSignals: true

        function onCloseRequested() {
            root.showDndMenu = false;
        }
    }

    onCurrentTabChanged: {
        if (currentTab === 1 && !SettingsData.notificationHistoryEnabled)
            currentTab = 0;
    }

    Connections {
        target: SettingsData
        function onNotificationHistoryEnabledChanged() {
            if (!SettingsData.notificationHistoryEnabled)
                root.currentTab = 0;
        }
    }

    width: parent.width
    height: headerColumn.implicitHeight

    DankTooltipV2 {
        id: sharedTooltip
    }

    Column {
        id: headerColumn
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: Math.max(titleRow.implicitHeight, actionsRow.implicitHeight)

            MouseArea {
                anchors.fill: parent
                enabled: root.tapToClose
                acceptedButtons: Qt.LeftButton
                onClicked: root.headerTapped()
            }

            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Notifications")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankActionButton {
                    id: doNotDisturbButton
                    iconName: SessionData.doNotDisturb ? "notifications_off" : "notifications"
                    iconColor: SessionData.doNotDisturb ? Theme.error : Theme.surfaceText
                    buttonSize: Theme.iconSize + Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        if (SessionData.doNotDisturb) {
                            SessionData.setDoNotDisturb(false);
                            return;
                        }
                        root.showDndMenu = !root.showDndMenu;
                    }
                    onEntered: sharedTooltip.show(SessionData.doNotDisturb ? I18n.tr("Turn off Do Not Disturb") : I18n.tr("Do Not Disturb"), doNotDisturbButton, 0, 0, "bottom")
                    onExited: sharedTooltip.hide()
                }

                DankActionButton {
                    id: dndScheduleButton
                    iconName: root.showDndMenu ? "expand_less" : "schedule"
                    iconColor: root.showDndMenu ? Theme.primary : Theme.surfaceText
                    buttonSize: Theme.iconSize + Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.showDndMenu = !root.showDndMenu
                    onEntered: sharedTooltip.show(I18n.tr("Silence for a while"), dndScheduleButton, 0, 0, "bottom")
                    onExited: sharedTooltip.hide()
                }
            }

            Row {
                id: actionsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DankActionButton {
                    id: helpButton
                    iconName: "info"
                    iconColor: (keyboardController && keyboardController.showKeyboardHints) ? Theme.primary : Theme.surfaceText
                    buttonSize: Theme.iconSize + Theme.spacingS
                    visible: keyboardController !== null
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        if (keyboardController)
                            keyboardController.showKeyboardHints = !keyboardController.showKeyboardHints;
                    }
                }

                DankActionButton {
                    id: settingsButton
                    iconName: "settings"
                    buttonSize: Theme.iconSize + Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.settingsRequested()
                }

                Rectangle {
                    id: clearAllButton
                    width: clearButtonContent.implicitWidth + Theme.spacingM * 2
                    height: Theme.iconSize + Theme.spacingS
                    radius: Theme.cornerRadius
                    visible: root.currentTab === 0 ? NotificationService.notifications.length > 0 : NotificationService.historyList.length > 0
                    color: clearArea.containsMouse ? Theme.primaryHoverLight : Theme.nestedSurface
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth

                    Row {
                        id: clearButtonContent
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "delete_sweep"
                            size: Theme.iconSizeSmall
                            color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Clear")
                            font.pixelSize: Theme.fontSizeSmall
                            color: clearArea.containsMouse ? Theme.primary : Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentTab === 0) {
                                NotificationService.clearAllNotifications();
                            } else {
                                NotificationService.clearHistory();
                            }
                        }
                    }
                }
            }
        }

        DndDurationMenu {
            id: dndMenu
            width: parent.width
            visible: root.showDndMenu
            onDismissed: root.showDndMenu = false
        }

        DankButtonGroup {
            id: tabGroup
            width: parent.width
            currentIndex: root.currentTab
            buttonHeight: 32
            buttonPadding: Theme.spacingM
            checkEnabled: false
            textSize: Theme.fontSizeSmall
            visible: SettingsData.notificationHistoryEnabled
            model: [I18n.tr("Current", "notification center tab") + " (" + NotificationService.notifications.length + ")", I18n.tr("History", "notification center tab") + " (" + NotificationService.historyList.length + ")"]
            onSelectionChanged: (index, selected) => {
                if (selected)
                    root.currentTab = index;
            }
        }
    }
}
