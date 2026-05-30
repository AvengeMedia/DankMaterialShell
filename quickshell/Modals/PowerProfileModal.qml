import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import Quickshell.Services.UPower

DankModal {
    id: root

    layerNamespace: "dms:power-profiles"
    keepPopoutsOpen: true

    property int selectedIndex: 0
    property var profileModel: PowerProfileWatcher.availableProfiles

    function openCentered() {
        open();
    }

    function hideDialog() {
        close();
    }

    shouldBeVisible: false
    modalWidth: 440
    modalHeight: 290
    enableShadow: true
    onBackgroundClicked: hideDialog()

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible)
            return;

        if (typeof PowerProfiles !== "undefined") {
            const current = PowerProfiles.profile;
            const idx = profileModel.indexOf(current);
            if (idx !== -1) {
                selectedIndex = idx;
            }
        }
    }

    onShouldHaveFocusChanged: {
        if (!shouldHaveFocus)
            return;
        Qt.callLater(() => modalFocusScope.forceActiveFocus());
    }

    modalFocusScope.Keys.onPressed: event => {
        if (event.isAutoRepeat) {
            event.accepted = true;
            return;
        }

        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            selectedIndex = (selectedIndex - 1 + profileModel.length) % profileModel.length;
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
            selectedIndex = (selectedIndex + 1) % profileModel.length;
            event.accepted = true;
            break;
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (selectedIndex >= 0 && selectedIndex < profileModel.length) {
                setProfile(profileModel[selectedIndex]);
            }
            event.accepted = true;
            break;
        case Qt.Key_1:
            if (profileModel.length > 0) {
                setProfile(profileModel[0]);
            }
            event.accepted = true;
            break;
        case Qt.Key_2:
            if (profileModel.length > 1) {
                setProfile(profileModel[1]);
            }
            event.accepted = true;
            break;
        case Qt.Key_3:
            if (profileModel.length > 2) {
                setProfile(profileModel[2]);
            }
            event.accepted = true;
            break;
        case Qt.Key_Escape:
            hideDialog();
            event.accepted = true;
            break;
        }
    }

    function setProfile(profile) {
        if (PowerProfileWatcher.applyProfile(profile)) {
            hideDialog();
            return;
        }

        if (!PowerProfileWatcher.available)
            ToastService.showError(I18n.tr("power-profiles-daemon not available"));
        else
            ToastService.showError(I18n.tr("Failed to set power profile"));
    }

    content: Component {
        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                Row {
                    width: parent.width

                    Column {
                        width: parent.width - 40
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Power Mode")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: I18n.tr("Choose a power profile")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hideDialog()
                    }
                }

                Row {
                    id: buttonsRow
                    width: parent.width
                    spacing: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: root.profileModel

                        Rectangle {
                            id: profileButton
                            required property int index
                            required property int modelData

                            readonly property bool isSelected: root.selectedIndex === index
                            readonly property bool isActive: (typeof PowerProfiles !== "undefined") && PowerProfiles.profile === modelData

                            width: (parent.width - Theme.spacingM * (root.profileModel.length - 1)) / root.profileModel.length
                            height: 120
                            radius: Theme.cornerRadius

                            color: {
                                if (isActive)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16);
                                if (isSelected)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                                if (mouseArea.containsMouse)
                                    return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12);
                                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.06);
                            }

                            border.color: isActive ? Theme.primary : (isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : "transparent")
                            border.width: (isActive || isSelected) ? 2 : 0

                            // Shortcut Key Badge on Top-Right Corner
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.spacingS
                                width: 20
                                height: 20
                                radius: 4
                                color: isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                border.color: isActive ? Theme.primary : "transparent"
                                border.width: isActive ? 1 : 0

                                StyledText {
                                    text: (index + 1).toString()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: isActive ? Theme.primary : Theme.surfaceTextMedium
                                    anchors.centerIn: parent
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: Theme.getPowerProfileIcon(modelData)
                                    size: Theme.iconSize + 16
                                    color: isActive ? Theme.primary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: Theme.getPowerProfileLabel(modelData)
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: isActive ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    root.selectedIndex = index;
                                }
                                onClicked: {
                                    root.setProfile(modelData);
                                }
                            }
                        }
                    }
                }

                // Selected power profile description
                StyledText {
                    text: (root.selectedIndex >= 0 && root.selectedIndex < root.profileModel.length) ? Theme.getPowerProfileDescription(root.profileModel[root.selectedIndex]) : ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceTextMedium
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - Theme.spacingL * 2
                }

                // Keyboard Shortcut Guide Footer
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXS
                    opacity: 0.5

                    DankIcon {
                        name: "keyboard"
                        size: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: I18n.tr("Use keys 1-3 or arrows, Enter/Space to select")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceText
                    }
                }
            }
        }
    }
}
