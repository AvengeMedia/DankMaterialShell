import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.Clipboard

Item {
    id: header

    property int recentsCount: 0
    property int savedCount: 0
    property bool showKeyboardHints: false
    property string activeTab: "recents"
    property int pinnedCount: 0
    property string activeFilter: "all"

    signal keyboardHintsToggled
    signal clearAllClicked
    signal closeClicked
    signal tabChanged(string tabName)
    signal filterChanged(string filter)

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
            text: (header.activeTab === "saved" ? I18n.tr("Clipboard Saved") : I18n.tr("Clipboard History")) + ` (${header.activeTab === "saved" ? header.savedCount : header.recentsCount})`
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        DankDropdown {
            width: 140

            text: ""
            currentValue: {
                switch (header.activeFilter) {
                    case "text":
                        return I18n.tr("Text");
                    case "long_text":
                        return I18n.tr("Long Text");
                    case "image":
                        return I18n.tr("Image");
                    default:
                        return I18n.tr("All");
                }
            }

            options: [I18n.tr("All"), I18n.tr("Text"), I18n.tr("Long Text"), I18n.tr("Image")]

            onValueChanged: value => {
                switch (value) {
                    case I18n.tr("Text"):
                        filterChanged("text");
                        break;
                    case I18n.tr("Long Text"):
                        filterChanged("long_text");
                        break;
                    case I18n.tr("Image"):
                        filterChanged("image");
                        break;
                    default:
                        filterChanged("all");
                }
            }
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
            backgroundColor: header.activeTab === "saved" ? Theme.primarySelected : "transparent"
            visible: header.pinnedCount > 0 || header.activeTab === "saved"
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
