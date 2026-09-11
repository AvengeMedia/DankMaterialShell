import QtQuick
import qs.Common

Item {
    id: root

    property string confirmTitle: ""
    property string confirmMessage: ""
    property string confirmButtonText: I18n.tr("Confirm")
    property string cancelButtonText: I18n.tr("Cancel")
    property color confirmButtonColor: Theme.primary
    property var onConfirm: function () {}
    property var onCancel: function () {}
    property real backgroundOpacity: 0.5

    signal dialogClosed

    function show(title, message, onConfirmCallback, onCancelCallback) {
        showWithOptions({
            "title": title,
            "message": message,
            "onConfirm": onConfirmCallback,
            "onCancel": onCancelCallback
        });
    }

    function showWithOptions(options) {
        confirmTitle = options.title || "";
        confirmMessage = options.message || "";
        confirmButtonText = options.confirmText || I18n.tr("Confirm");
        cancelButtonText = options.cancelText || I18n.tr("Cancel");
        confirmButtonColor = options.confirmColor || Theme.primary;
        onConfirm = options.onConfirm || (() => {});
        onCancel = options.onCancel || (() => {});
        dialogContent.reset();
        visible = true;
        overlayFocusScope.forceActiveFocus();
    }

    function close() {
        visible = false;
        dialogClosed();
    }

    function _activate(button) {
        const cancelCallback = onCancel;
        const confirmCallback = onConfirm;
        close();
        if (button === 0) {
            cancelCallback && cancelCallback();
            return;
        }
        confirmCallback && confirmCallback();
    }

    anchors.fill: parent
    visible: false
    z: 100

    FocusScope {
        id: overlayFocusScope

        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => dialogContent.handleKey(event)

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.backgroundOpacity
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root._activate(0)
        }

        Rectangle {
            width: 350
            height: dialogContent.implicitHeight + Theme.spacingL
            anchors.centerIn: parent
            radius: Theme.cornerRadius
            // No compositor blur behind an in-window card; popupTransparency would show raw content through
            color: Theme.surfaceContainer
            border.color: Theme.outlineMedium
            border.width: 1

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            ConfirmDialogContent {
                id: dialogContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingL
                confirmTitle: root.confirmTitle
                confirmMessage: root.confirmMessage
                confirmButtonText: root.confirmButtonText
                cancelButtonText: root.cancelButtonText
                confirmButtonColor: root.confirmButtonColor
                onButtonActivated: button => root._activate(button)
                onCancelled: root._activate(0)
            }
        }
    }
}
