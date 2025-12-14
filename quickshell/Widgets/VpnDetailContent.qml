import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var parentPopout: null
    property string expandedUuid: ""
    property int listHeight: 180

    implicitHeight: 32 + 1 + listHeight + Theme.spacingS * 4 + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    FileBrowserSurfaceModal {
        id: fileBrowser
        browserTitle: I18n.tr("Import VPN")
        browserIcon: "vpn_key"
        browserType: "vpn"
        fileExtensions: VPNService.getFileFilter()
        parentPopout: root.parentPopout

        onFileSelected: path => {
            VPNService.importVpn(path.replace("file://", ""));
        }
    }

    ConfirmModal {
        id: deleteConfirm
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            spacing: Theme.spacingS
            width: parent.width

            StyledText {
                text: {
                    if (!DMSNetworkService.connected)
                        return I18n.tr("Active: None");
                    const names = DMSNetworkService.activeNames || [];
                    if (names.length <= 1)
                        return I18n.tr("Active: ") + (names[0] || "VPN");
                    return I18n.tr("Active: ") + names[0] + " +" + (names.length - 1);
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }

            Rectangle {
                height: 28
                radius: 14
                color: importArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                width: 90
                Layout.alignment: Qt.AlignVCenter
                opacity: VPNService.importing ? 0.5 : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: VPNService.importing ? "sync" : "add"
                        size: Theme.fontSizeSmall
                        color: Theme.primary
                    }

                    StyledText {
                        text: I18n.tr("Import")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: importArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: VPNService.importing ? Qt.BusyCursor : Qt.PointingHandCursor
                    enabled: !VPNService.importing
                    onClicked: fileBrowser.open()
                }
            }

            Rectangle {
                height: 28
                radius: 14
                color: discAllArea.containsMouse ? Theme.errorHover : Theme.surfaceLight
                visible: DMSNetworkService.connected
                width: 100
                Layout.alignment: Qt.AlignVCenter
                opacity: DMSNetworkService.isBusy ? 0.5 : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "link_off"
                        size: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: I18n.tr("Disconnect")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: discAllArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                    enabled: !DMSNetworkService.isBusy
                    onClicked: DMSNetworkService.disconnectAllActive()
                }
            }

            DankActionButton {
                Layout.alignment: Qt.AlignVCenter
                iconName: "settings"
                buttonSize: 28
                iconSize: 16
                iconColor: Theme.surfaceVariantText
                onClicked: {
                    PopoutService.closeControlCenter();
                    PopoutService.openSettingsWithTab("network");
                }
            }
        }

        Rectangle {
            height: 1
            width: parent.width
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        Item {
            width: parent.width
            height: root.listHeight

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: DMSNetworkService.profiles.length === 0

                DankIcon {
                    name: "vpn_key_off"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("No VPN profiles")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Click Import to add a .ovpn or .conf")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DankListView {
                id: vpnListView
                anchors.fill: parent
                visible: DMSNetworkService.profiles.length > 0
                spacing: 4
                cacheBuffer: 200
                clip: true

                model: ScriptModel {
                    values: DMSNetworkService.profiles
                    objectProp: "uuid"
                }

                delegate: VpnProfileDelegate {
                    required property var modelData
                    width: vpnListView.width
                    profile: modelData
                    isExpanded: root.expandedUuid === modelData.uuid
                    onToggleExpand: {
                        if (root.expandedUuid === modelData.uuid) {
                            root.expandedUuid = "";
                            return;
                        }
                        root.expandedUuid = modelData.uuid;
                        VPNService.getConfig(modelData.uuid);
                    }
                    onDeleteRequested: {
                        deleteConfirm.showWithOptions({
                            "title": I18n.tr("Delete VPN"),
                            "message": I18n.tr("Delete \"") + modelData.name + "\"?",
                            "confirmText": I18n.tr("Delete"),
                            "confirmColor": Theme.error,
                            "onConfirm": () => VPNService.deleteVpn(modelData.uuid)
                        });
                    }
                }
            }
        }

        Item {
            width: 1
            height: Theme.spacingS
        }
    }
}
