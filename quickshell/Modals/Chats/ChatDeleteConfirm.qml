pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// Confirmation before deleting a message.
//
// Deleting is bound to Delete and Shift+Delete, which are easy keys to hit by
// mistake, and neither kind of delete can be undone. Deleting for everyone is
// worse still: it reaches other people's devices.
StyledRect {
    id: root

    property bool forEveryone: false
    property var message: null

    signal confirmed
    signal cancelled

    color: Theme.withAlpha(Theme.surfaceContainer, 0.97)
    radius: Theme.cornerRadius

    // Swallow clicks so nothing behind reacts while the question is up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    onVisibleChanged: {
        if (visible)
            cancelButton.forceActiveFocus();
    }

    Keys.onEscapePressed: event => {
        root.cancelled();
        event.accepted = true;
    }

    // Enter confirms, matching every other yes/no in the shell. Cancel holds
    // focus, so a reflexive Enter on a dialog you did not expect is the safe
    // answer only if you have not read it -- which is why the text says which
    // kind of delete this is.
    Keys.onReturnPressed: event => {
        root.confirmed();
        event.accepted = true;
    }

    Keys.onEnterPressed: event => {
        root.confirmed();
        event.accepted = true;
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(400, parent.width - Theme.spacingXL * 2)
        spacing: Theme.spacingM

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "delete"
            size: Theme.iconSizeLarge
            color: root.forEveryone ? Theme.error : Theme.surfaceVariantText
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.forEveryone ? I18n.tr("Delete this for everyone?") : I18n.tr("Delete this for you only?")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.forEveryone ? I18n.tr("This removes the message from everyone's device. It cannot be undone.") : I18n.tr("This removes the message from this device only. Everyone else keeps their copy.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        // What is about to go, so a mis-selected message is caught here.
        StyledRect {
            width: parent.width
            height: Math.min(preview.implicitHeight + Theme.spacingS * 2, 90)
            visible: (root.message?.text ?? "") !== ""
            radius: Theme.cornerRadius / 2
            color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)

            StyledText {
                id: preview
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingS
                text: root.message?.text ?? ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingS

            DankButton {
                id: cancelButton
                text: I18n.tr("Cancel")
                backgroundColor: "transparent"
                textColor: Theme.surfaceText
                onClicked: root.cancelled()
            }

            DankButton {
                text: root.forEveryone ? I18n.tr("Delete for everyone") : I18n.tr("Delete")
                iconName: "delete"
                backgroundColor: Theme.error
                textColor: Theme.onPrimary
                onClicked: root.confirmed()
            }
        }
    }
}
