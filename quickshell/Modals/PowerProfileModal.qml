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
    property var profileModel: (typeof PowerProfiles !== "undefined") ? [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : []) : [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]

    function openCentered() {
        open();
    }

    function hideDialog() {
        close();
    }

    shouldBeVisible: false
    modalWidth: 380
    modalHeight: 220
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
        if (typeof PowerProfiles !== "undefined") {
            PowerProfiles.profile = profile;
        }
        hideDialog();
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
                            height: 100
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

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: Theme.getPowerProfileIcon(modelData)
                                    size: Theme.iconSize + 8
                                    color: isActive ? Theme.primary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: Theme.getPowerProfileLabel(modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: isActive ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Rectangle {
                                    width: 18
                                    height: 14
                                    radius: 3
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    StyledText {
                                        text: (index + 1).toString()
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                                        font.weight: Font.Medium
                                        anchors.centerIn: parent
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = index;
                                    root.setProfile(modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
