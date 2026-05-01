import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: keyboardHints

    property bool wtypeAvailable: false
    property bool enterToPaste: false
    readonly property string hintsText: {
        if (!wtypeAvailable)
            return I18n.tr("Ctrl+Tab: Switch Tab • Ctrl+S: Pin/Unpin • Shift+Del: Clear All • Esc: Close");
        return enterToPaste ? I18n.tr("Ctrl+Tab: Switch Tab • Ctrl+S: Pin/Unpin • Shift+Enter: Copy • Shift+Del: Clear All • Esc: Close", "Keyboard hints when enter-to-paste is enabled") : I18n.tr("Ctrl+Tab: Switch Tab • Ctrl+S: Pin/Unpin • Shift+Enter: Paste • Shift+Del: Clear All • Esc: Close");
    }

    height: ClipboardConstants.keyboardHintsHeight
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
    border.color: Theme.primary
    border.width: 2
    opacity: visible ? 1 : 0
    z: 100

    Column {
        anchors.centerIn: parent
        spacing: 2

        StyledText {
            text: keyboardHints.enterToPaste ? I18n.tr("↑/↓: Navigate • Enter: Paste • Del: Delete • F10: Help", "Keyboard hints when enter-to-paste is enabled") : I18n.tr("↑/↓: Navigate • Enter/Ctrl+C: Copy • Del: Delete • F10: Help")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: keyboardHints.hintsText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
