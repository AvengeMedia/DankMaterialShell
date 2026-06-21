import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    readonly property string fallbackURL: "http://nmcheck.gnome.org/check_network_status.txt"
    readonly property string ssid: NetworkService.currentWifiSSID

    function openPortal() {
        const url = NetworkService.portalURL && NetworkService.portalURL.length > 0 ? NetworkService.portalURL : root.fallbackURL;
        Qt.openUrlExternally(url);
        root.close();
    }

    shouldBeVisible: false
    allowStacking: true
    useOverlayLayer: true
    modalWidth: 420
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingM * 2 : 220

    onBackgroundClicked: root.close()

    content: Component {
        FocusScope {
            id: portalContent

            anchors.fill: parent
            focus: true
            implicitHeight: mainColumn.implicitHeight

            Keys.onEscapePressed: event => {
                root.close();
                event.accepted = true;
            }

            Keys.onReturnPressed: event => {
                root.openPortal();
                event.accepted = true;
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                anchors.topMargin: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "wifi_lock"
                        size: Theme.iconSizeLarge
                        color: Theme.primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSizeLarge - Theme.spacingM
                        text: I18n.tr("Sign in to network")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.ssid.length > 0 ? I18n.tr("The network \"%1\" requires sign-in before you can reach the internet.").arg(root.ssid) : I18n.tr("This network requires sign-in before you can reach the internet.")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    visible: NetworkService.vpnConnected
                    text: I18n.tr("A VPN is active. You may need to disconnect it to reach the login page.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            width: Math.max(80, dismissText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: dismissArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                            border.color: Theme.surfaceVariantAlpha
                            border.width: 1

                            StyledText {
                                id: dismissText
                                anchors.centerIn: parent
                                text: I18n.tr("Dismiss")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: dismissArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.close()
                            }
                        }

                        Rectangle {
                            width: Math.max(120, openText.contentWidth + Theme.spacingM * 2)
                            height: 36
                            radius: Theme.cornerRadius
                            color: openArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                            StyledText {
                                id: openText
                                anchors.centerIn: parent
                                text: I18n.tr("Open login page")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.background
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: openArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openPortal()
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }

            DankActionButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                iconName: "close"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: root.close()
            }
        }
    }
}
