import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.Clipboard

Item {
    id: header

    property int totalCount: 0
    property bool showKeyboardHints: false
    property string activeTab: "recents"
    property int pinnedCount: 0

    signal keyboardHintsToggled
    signal clearAllClicked
    signal closeClicked
    signal tabChanged(string tabName)

    height: ClipboardConstants.headerHeight

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        DankIcon {
            name: "content_paste"
            size: Theme.iconSize
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: I18n.tr("Clipboard History") + ` (${totalCount})`
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        DankActionButton {
            iconName: "push_pin"
            iconSize: Theme.iconSize - 4
            iconColor: header.activeTab === "saved" ? Theme.primary : Theme.surfaceText
            visible: header.pinnedCount > 0
            tooltipText: header.activeTab === "saved" ? I18n.tr("Recent") : I18n.tr("Saved")
            onClicked: tabChanged(header.activeTab === "saved" ? "recents" : "saved")
        }

        DankActionButton {
            iconName: "info"
            iconSize: Theme.iconSize - 4
            iconColor: showKeyboardHints ? Theme.primary : Theme.surfaceText
            tooltipText: I18n.tr("Keyboard Shortcuts")
            onClicked: keyboardHintsToggled()
        }

        DankActionButton {
            iconName: "delete_sweep"
            iconSize: Theme.iconSize
            iconColor: Theme.surfaceText
            tooltipText: I18n.tr("Clear All")
            onClicked: clearAllClicked()
        }

        DankActionButton {
            iconName: "close"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            onClicked: closeClicked()
        }
    }
}
