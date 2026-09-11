import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string confirmTitle: ""
    property string confirmMessage: ""
    property string confirmButtonText: I18n.tr("Confirm")
    property string cancelButtonText: I18n.tr("Cancel")
    property color confirmButtonColor: Theme.primary
    property int selectedButton: -1
    property bool keyboardNavigation: false

    signal buttonActivated(int button)
    signal cancelled

    function reset() {
        selectedButton = -1;
        keyboardNavigation = false;
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            cancelled();
            event.accepted = true;
            return;
        case Qt.Key_Left:
        case Qt.Key_Up:
            keyboardNavigation = true;
            selectedButton = 0;
            event.accepted = true;
            return;
        case Qt.Key_Right:
        case Qt.Key_Down:
            keyboardNavigation = true;
            selectedButton = 1;
            event.accepted = true;
            return;
        case Qt.Key_N:
        case Qt.Key_J:
        case Qt.Key_L:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true;
                selectedButton = event.key === Qt.Key_N ? (selectedButton + 1) % 2 : 1;
                event.accepted = true;
            }
            return;
        case Qt.Key_P:
        case Qt.Key_K:
        case Qt.Key_H:
            if (event.modifiers & Qt.ControlModifier) {
                keyboardNavigation = true;
                selectedButton = event.key === Qt.Key_P ? (selectedButton === -1 ? 1 : (selectedButton - 1 + 2) % 2) : 0;
                event.accepted = true;
            }
            return;
        case Qt.Key_Tab:
            keyboardNavigation = true;
            selectedButton = selectedButton === -1 ? 0 : (selectedButton + 1) % 2;
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            buttonActivated(selectedButton === -1 ? 1 : selectedButton);
            event.accepted = true;
            return;
        }
    }

    spacing: 0

    StyledText {
        text: root.confirmTitle
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
        font.weight: Font.Medium
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }

    Item {
        width: 1
        height: Theme.spacingL
    }

    StyledText {
        text: root.confirmMessage
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    Item {
        width: 1
        height: Theme.spacingL * 1.5
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingM

        Rectangle {
            width: 120
            height: 40
            radius: Theme.cornerRadius
            color: {
                if (root.keyboardNavigation && root.selectedButton === 0) {
                    return Theme.primaryHover;
                } else if (cancelButton.containsMouse) {
                    return Theme.surfacePressed;
                } else {
                    return Theme.surfaceVariantAlpha;
                }
            }
            border.color: (root.keyboardNavigation && root.selectedButton === 0) ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
            border.width: (root.keyboardNavigation && root.selectedButton === 0) ? 1 : 0

            StyledText {
                text: root.cancelButtonText
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.centerIn: parent
            }

            MouseArea {
                id: cancelButton

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.buttonActivated(0)
            }
        }

        Rectangle {
            width: 120
            height: 40
            radius: Theme.cornerRadius
            color: {
                const baseColor = root.confirmButtonColor;
                if (root.keyboardNavigation && root.selectedButton === 1) {
                    return Theme.withAlpha(baseColor, 1);
                } else if (confirmButton.containsMouse) {
                    return Theme.withAlpha(baseColor, 0.9);
                } else {
                    return baseColor;
                }
            }
            border.color: (root.keyboardNavigation && root.selectedButton === 1) ? "white" : Qt.rgba(1, 1, 1, 0)
            border.width: (root.keyboardNavigation && root.selectedButton === 1) ? 1 : 0

            StyledText {
                text: root.confirmButtonText
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.primaryText
                font.weight: Font.Medium
                anchors.centerIn: parent
            }

            MouseArea {
                id: confirmButton

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.buttonActivated(1)
            }
        }
    }

    Item {
        width: 1
        height: Theme.spacingL
    }
}
