import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modules.Notifications.Center
import qs.Services

DankModal {
    id: notificationModal

    layerNamespace: "dms:notification-center-modal"

    HyprlandFocusGrab {
        windows: [notificationModal.contentWindow]
        active: notificationModal.useHyprlandFocusGrab && notificationModal.shouldHaveFocus
    }

    property bool notificationModalOpen: false
    property var notificationListRef: null

    function show() {
        notificationModalOpen = true;
        NotificationService.onOverlayOpen();
        open();
        modalKeyboardController.reset();
        if (modalKeyboardController && notificationListRef) {
            modalKeyboardController.listView = notificationListRef;
            modalKeyboardController.rebuildFlatNavigation();

            Qt.callLater(() => {
                modalKeyboardController.keyboardNavigationActive = true;
                modalKeyboardController.selectedFlatIndex = 0;
                modalKeyboardController.updateSelectedIdFromIndex();
                if (notificationListRef) {
                    notificationListRef.keyboardActive = true;
                    notificationListRef.currentIndex = 0;
                }
                modalKeyboardController.selectionVersion++;
                modalKeyboardController.ensureVisible();
            });
        }
    }

    function hide() {
        notificationModalOpen = false;
        NotificationService.onOverlayClose();
        close();
        modalKeyboardController.reset();
    }

    function toggle() {
        if (shouldBeVisible) {
            hide();
        } else {
            show();
        }
    }

    function clearAll() {
        NotificationService.clearAllNotifications();
    }

    function dismissAllPopups () {
        NotificationService.dismissAllPopups();
    }

    modalWidth: 500
    modalHeight: 700
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    visible: false
    onBackgroundClicked: hide()
    onOpened: () => {
        Qt.callLater(() => modalFocusScope.forceActiveFocus());
    }
    onShouldBeVisibleChanged: shouldBeVisible => {
        if (!shouldBeVisible) {
            notificationModalOpen = false;
            modalKeyboardController.reset();
            NotificationService.onOverlayClose();
        }
    }
    modalFocusScope.Keys.onPressed: event => modalKeyboardController.handleKey(event)

    NotificationKeyboardController {
        id: modalKeyboardController

        listView: null
        isOpen: notificationModal.notificationModalOpen
        onClose: () => notificationModal.hide()
    }

    IpcHandler {
        function open(): string {
            notificationModal.show();
            return "NOTIFICATION_MODAL_OPEN_SUCCESS";
        }

        function close(): string {
            notificationModal.hide();
            return "NOTIFICATION_MODAL_CLOSE_SUCCESS";
        }

        function toggle(): string {
            notificationModal.toggle();
            return "NOTIFICATION_MODAL_TOGGLE_SUCCESS";
        }

        function toggleDoNotDisturb(): string {
            SessionData.setDoNotDisturb(!SessionData.doNotDisturb);

            return "NOTIFICATION_MODAL_TOGGLE_DND_SUCCESS";
        }

        function getDoNotDisturb(): bool {
            return SessionData.doNotDisturb;
        }

        function clearAll(): string {
            notificationModal.clearAll();
            return "NOTIFICATION_MODAL_CLEAR_ALL_SUCCESS";
        }

        function dismissAllPopups(): string {
            notificationModal.dismissAllPopups();
            return "NOTIFICATION_MODAL_DISMISS_ALL_POPUPS_SUCCESS";
        }

        target: "notifications"
    }

    content: Component {
        Item {
            id: notificationKeyHandler

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                NotificationHeader {
                    id: notificationHeader

                    keyboardController: modalKeyboardController
                }

                NotificationSettings {
                    id: notificationSettings

                    expanded: notificationHeader.showSettings
                }

                KeyboardNavigatedNotificationList {
                    id: notificationList

                    width: parent.width
                    height: parent.height - y
                    keyboardController: modalKeyboardController
                    Component.onCompleted: {
                        notificationModal.notificationListRef = notificationList;
                        if (modalKeyboardController) {
                            modalKeyboardController.listView = notificationList;
                            modalKeyboardController.rebuildFlatNavigation();
                        }
                    }
                }
            }

            NotificationKeyboardHints {
                id: keyboardHints

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                showHints: modalKeyboardController.showKeyboardHints
            }
        }
    }
}
