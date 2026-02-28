import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:notification-center-popout"
    fullHeightSurface: true

    property bool notificationHistoryVisible: false
    property var triggerScreen: null
    property real stablePopupHeight: 400
    property real _lastAlignedContentHeight: -1
    property bool _pendingSizedOpen: false

    function updateStablePopupHeight() {
        const item = contentLoader.item;
        if (item && !root.shouldBeVisible) {
            const notificationList = findChild(item, "notificationList");
            if (notificationList && typeof notificationList.forceLayout === "function") {
                notificationList.forceLayout();
            }
        }
        const target = item ? Theme.px(item.implicitHeight, dpr) : 400;
        if (Math.abs(target - _lastAlignedContentHeight) < 0.5)
            return;
        _lastAlignedContentHeight = target;
        stablePopupHeight = target;
    }

    NotificationKeyboardController {
        id: keyboardController
        listView: null
        isOpen: root.shouldBeVisible
        onClose: () => {
            notificationHistoryVisible = false;
        }
    }

    popupWidth: triggerScreen ? Math.min(500, Math.max(380, triggerScreen.width - 48)) : 400
    popupHeight: stablePopupHeight
    positioning: ""
    animationScaleCollapsed: 0.94
    animationOffset: 0
    suspendShadowWhileResizing: false

    screen: triggerScreen

    function toggle() {
        notificationHistoryVisible = !notificationHistoryVisible;
    }

    function openSized() {
        if (!notificationHistoryVisible)
            return;

        primeContent();
        if (contentLoader.item) {
            updateStablePopupHeight();
            _pendingSizedOpen = false;
            Qt.callLater(() => {
                if (!notificationHistoryVisible)
                    return;
                updateStablePopupHeight();
                open();
                clearPrimedContent();
            });
            return;
        }

        _pendingSizedOpen = true;
    }

    onBackgroundClicked: {
        notificationHistoryVisible = false;
    }

    onNotificationHistoryVisibleChanged: {
        if (notificationHistoryVisible) {
            openSized();
        } else {
            _pendingSizedOpen = false;
            clearPrimedContent();
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
            root.updateStablePopupHeight();
            if (root._pendingSizedOpen && root.notificationHistoryVisible) {
                Qt.callLater(() => {
                    if (!root._pendingSizedOpen || !root.notificationHistoryVisible)
                        return;
                    root.updateStablePopupHeight();
                    root._pendingSizedOpen = false;
                    root.open();
                    root.clearPrimedContent();
                });
                return;
            }
            if (root.shouldBeVisible)
                Qt.callLater(root.setupKeyboardNavigation);
        }
    }

    Connections {
        target: contentLoader.item
        function onImplicitHeightChanged() {
            root.updateStablePopupHeight();
        }
    }

    onDprChanged: updateStablePopupHeight()

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            NotificationService.onOverlayOpen();
            updateStablePopupHeight();
            if (contentLoader.item)
                Qt.callLater(setupKeyboardNavigation);
        } else {
            NotificationService.onOverlayClose();
            keyboardController.keyboardNavigationActive = false;
            NotificationService.expandedGroups = {};
            NotificationService.expandedMessages = {};
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

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            property var externalKeyboardController: null
            property real cachedHeaderHeight: 32
            implicitHeight: {
                let baseHeight = Theme.spacingL * 2;
                baseHeight += cachedHeaderHeight;
                baseHeight += Theme.spacingM * 2;

                const settingsHeight = notificationSettings.expanded ? notificationSettings.contentHeight : 0;
                const currentListHeight = root.shouldBeVisible ? notificationList.stableContentHeight : notificationList.listContentHeight;
                let listHeight = notificationHeader.currentTab === 0 ? currentListHeight : Math.max(200, NotificationService.historyList.length * 80);
                if (notificationHeader.currentTab === 0 && NotificationService.groupedNotifications.length === 0) {
                    listHeight = 200;
                }
                if (notificationHeader.currentTab === 1 && NotificationService.historyList.length === 0) {
                    listHeight = 200;
                }

                const maxContentArea = 600;
                const availableListSpace = Math.max(200, maxContentArea - settingsHeight);

                baseHeight += settingsHeight;
                baseHeight += Math.min(listHeight, availableListSpace);

                const maxHeight = root.screen ? root.screen.height * 0.8 : Screen.height * 0.8;
                return Math.max(300, Math.min(baseHeight, maxHeight));
            }

            color: "transparent"
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus();
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    notificationHistoryVisible = false;
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Left) {
                    if (notificationHeader.currentTab > 0) {
                        notificationHeader.currentTab = 0;
                        event.accepted = true;
                    }
                    return;
                }

                if (event.key === Qt.Key_Right) {
                    if (notificationHeader.currentTab === 0 && SettingsData.notificationHistoryEnabled) {
                        notificationHeader.currentTab = 1;
                        event.accepted = true;
                    }
                    return;
                }
                if (notificationHeader.currentTab === 1) {
                    historyList.handleKey(event);
                    return;
                }
                if (externalKeyboardController) {
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

                    Item {
                        visible: notificationHeader.currentTab === 0
                        width: parent.width
                        height: parent.height - notificationContent.cachedHeaderHeight - notificationSettings.height - contentColumnInner.spacing * 2

                        KeyboardNavigatedNotificationList {
                            id: notificationList
                            objectName: "notificationList"
                            anchors.fill: parent
                            anchors.leftMargin: -shadowHorizontalGutter
                            anchors.rightMargin: -shadowHorizontalGutter
                            anchors.topMargin: -(shadowVerticalGutter + delegateShadowGutter / 2)
                            anchors.bottomMargin: -(shadowVerticalGutter + delegateShadowGutter / 2)
                            cardAnimateExpansion: true
                        }
                    }

                    HistoryNotificationList {
                        id: historyList
                        visible: notificationHeader.currentTab === 1
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
                showHints: notificationHeader.currentTab === 0 ? (externalKeyboardController && externalKeyboardController.showKeyboardHints) || false : historyList.showKeyboardHints
                z: 200
            }
        }
    }
}
