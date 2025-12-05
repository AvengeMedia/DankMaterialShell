import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Notifications.Center

DankPopout {
    id: root

    layerNamespace: "dms:notification-center-popout"

    property bool notificationHistoryVisible: false
    property var triggerScreen: null

    NotificationKeyboardController {
        id: keyboardController
        listView: null
        isOpen: notificationHistoryVisible
        onClose: () => {
            notificationHistoryVisible = false;
        }
    }

    popupWidth: 400
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 400
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: notificationHistoryVisible

    function toggle() {
        notificationHistoryVisible = !notificationHistoryVisible;
    }

    onBackgroundClicked: {
        notificationHistoryVisible = false;
    }

    onNotificationHistoryVisibleChanged: {
        if (notificationHistoryVisible) {
            open();
        } else {
            close();
        }
    }

    function setupKeyboardNavigation() {
        if (!contentLoader.item)
            return;
        contentLoader.item.externalKeyboardController = keyboardController;

        const notificationList = findChild(contentLoader.item, "notificationList");
        const notificationHeader = findChild(contentLoader.item, "notificationHeader");

        if (notificationList) {
            keyboardController.listView = notificationList;
            notificationList.keyboardController = keyboardController;
        }
        if (notificationHeader) {
            notificationHeader.keyboardController = keyboardController;
        }

        keyboardController.reset();
        keyboardController.rebuildFlatNavigation();
    }

    Connections {
        target: contentLoader
        function onLoaded() {
            if (root.shouldBeVisible)
                Qt.callLater(root.setupKeyboardNavigation);
        }
    }

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            NotificationService.onOverlayOpen();
            if (contentLoader.item)
                Qt.callLater(setupKeyboardNavigation);
        } else {
            NotificationService.onOverlayClose();
            keyboardController.keyboardNavigationActive = false;
        }
    }

    function findChild(parent, objectName) {
        if (parent.objectName === objectName) {
            return parent;
        }
        for (let i = 0; i < parent.children.length; i++) {
            const child = parent.children[i];
            const result = findChild(child, objectName);
            if (result) {
                return result;
            }
        }
        return null;
    }

    content: Component {
        Rectangle {
            id: notificationContent

            property var externalKeyboardController: null
            property real cachedHeaderHeight: 32

            implicitHeight: {
                let baseHeight = Theme.spacingL * 2;
                baseHeight += cachedHeaderHeight;
                baseHeight += Theme.spacingM * 2;

                const settingsHeight = notificationSettings.expanded ? notificationSettings.contentHeight : 0;
                let listHeight = notificationList.listContentHeight;
                if (NotificationService.groupedNotifications.length === 0) {
                    listHeight = 200;
                }

                const maxContentArea = 600;
                const availableListSpace = Math.max(200, maxContentArea - settingsHeight);

                baseHeight += settingsHeight;
                baseHeight += Math.min(listHeight, availableListSpace);

                const maxHeight = root.screen ? root.screen.height * 0.8 : Screen.height * 0.8;
                return Math.max(300, Math.min(baseHeight, maxHeight));
            }

            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus();
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                } else if (externalKeyboardController) {
                    externalKeyboardController.handleKey(event);
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(() => {
                            notificationContent.forceActiveFocus();
                        });
                    } else {
                        notificationContent.focus = false;
                    }
                }
                target: root
            }

            FocusScope {
                id: contentColumn

                anchors.fill: parent
                anchors.margins: Theme.spacingL
                focus: true

                Column {
                    id: contentColumnInner
                    anchors.fill: parent
                    spacing: Theme.spacingM

                    NotificationHeader {
                        id: notificationHeader
                        objectName: "notificationHeader"
                        onHeightChanged: notificationContent.cachedHeaderHeight = height
                    }

                    NotificationSettings {
                        id: notificationSettings
                        expanded: notificationHeader.showSettings
                    }

                    KeyboardNavigatedNotificationList {
                        id: notificationList
                        objectName: "notificationList"

                        width: parent.width
                        height: parent.height - notificationContent.cachedHeaderHeight - notificationSettings.height - contentColumnInner.spacing * 2
                    }
                }
            }

            NotificationKeyboardHints {
                id: keyboardHints
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                showHints: (externalKeyboardController && externalKeyboardController.showKeyboardHints) || false
                z: 200
            }
        }
    }
}
