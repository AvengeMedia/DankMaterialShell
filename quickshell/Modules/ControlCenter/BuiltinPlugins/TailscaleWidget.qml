import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: TailscaleService
    }

    ccWidgetIcon: "device_hub"
    ccWidgetPrimaryText: I18n.tr("Tailscale", "Tailscale mesh VPN widget title")
    ccWidgetSecondaryText: {
        if (!TailscaleService.available)
            return I18n.tr("Not available", "Tailscale service not available");
        if (!TailscaleService.connected)
            return I18n.tr("Disconnected", "Tailscale disconnected status");
        const count = TailscaleService.onlinePeerCount;
        return I18n.tr("%1 online", "Number of online Tailscale peers").arg(count);
    }
    ccWidgetIsActive: TailscaleService.connected

    onCcWidgetToggled: {}

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot

            property string searchQuery: ""
            property int filterIndex: 0  // 0=My Online, 1=All Online, 2=All
            property string expandedHostname: ""

            implicitHeight: detailColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: detailColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                // Not available state
                Column {
                    visible: !TailscaleService.available
                    width: parent.width
                    spacing: Theme.spacingS

                    Item {
                        width: parent.width
                        height: 80

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "vpn_key_off"
                                size: 36
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("Tailscale not available", "Warning when Tailscale service is not running")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // Connected content
                Item {
                    visible: TailscaleService.available
                    width: parent.width
                    height: parent.height - (parent.visibleChildren[0] === this ? 0 : y)
                    clip: true

                    Column {
                        id: headerColumn
                        width: parent.width
                        spacing: Theme.spacingS

                        // Search bar + refresh button
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankTextField {
                                Layout.fillWidth: true
                                placeholderText: I18n.tr("Search devices...", "Tailscale device search placeholder")
                                leftIconName: "search"
                                showClearButton: true
                                text: detailRoot.searchQuery
                                onTextEdited: detailRoot.searchQuery = text
                            }

                            DankActionButton {
                                iconName: "sync"
                                buttonSize: 28
                                iconSize: 16
                                iconColor: Theme.surfaceVariantText
                                tooltipText: I18n.tr("Refresh", "Refresh Tailscale device status")
                                onClicked: TailscaleService.refresh(null)
                            }
                        }

                        // Filter chips
                        DankFilterChips {
                            width: parent.width
                            currentIndex: detailRoot.filterIndex
                            showCounts: true
                            chipHeight: 26
                            model: [
                                {
                                    "label": I18n.tr("My Online", "Tailscale filter: my online devices"),
                                    "count": TailscaleService.myOnlinePeers.length
                                },
                                {
                                    "label": I18n.tr("Online", "Tailscale filter: all online devices"),
                                    "count": TailscaleService.onlinePeers.length
                                },
                                {
                                    "label": I18n.tr("All", "Tailscale filter: all devices"),
                                    "count": TailscaleService.allPeersList.length
                                }
                            ]
                            onSelectionChanged: index => {
                                detailRoot.filterIndex = index;
                            }
                        }
                    }

                    // Scrollable peer list — fills remaining space below header
                    DankFlickable {
                        anchors.top: headerColumn.bottom
                        anchors.topMargin: Theme.spacingS
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        contentHeight: peerListColumn.implicitHeight
                        clip: true

                        Column {
                            id: peerListColumn
                            width: parent.width
                            spacing: Theme.spacingXS

                            property var filteredPeers: {
                                let base;
                                switch (detailRoot.filterIndex) {
                                case 0:
                                    base = TailscaleService.myOnlinePeers;
                                    break;
                                case 1:
                                    base = TailscaleService.onlinePeers;
                                    break;
                                case 2:
                                    base = TailscaleService.allPeersList;
                                    break;
                                default:
                                    base = [];
                                }
                                if (detailRoot.searchQuery.length > 0)
                                    return TailscaleService.searchPeers(detailRoot.searchQuery, base);
                                return base;
                            }

                            // Empty state
                            Item {
                                width: parent.width
                                height: 60
                                visible: peerListColumn.filteredPeers.length === 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "devices"
                                        size: 28
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: detailRoot.searchQuery.length > 0 ? I18n.tr("No matching devices", "No Tailscale devices match search") : I18n.tr("No peers found", "No Tailscale peers found")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // Peer cards
                            Repeater {
                                model: peerListColumn.filteredPeers

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: peerListColumn.width
                                    height: peerCardColumn.implicitHeight + Theme.spacingS * 2
                                    radius: Theme.cornerRadius
                                    color: modelData.hostname === (TailscaleService.selfNode ? TailscaleService.selfNode.hostname : "") ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.surfaceContainerHighest

                                    property bool isSelf: modelData.hostname === (TailscaleService.selfNode ? TailscaleService.selfNode.hostname : "")
                                    property bool isExpanded: detailRoot.expandedHostname === modelData.hostname

                                    Column {
                                        id: peerCardColumn
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: Theme.spacingS
                                        spacing: 2

                                        RowLayout {
                                            width: parent.width
                                            spacing: Theme.spacingS

                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: modelData.online ? "#4caf50" : Theme.surfaceVariantText
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            StyledText {
                                                text: modelData.hostname || ""
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Bold
                                                color: Theme.surfaceText
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                visible: isSelf
                                                text: I18n.tr("This device", "Label for the user's own device in Tailscale")
                                                font.pixelSize: 10
                                                color: Theme.primary
                                                font.weight: Font.Medium
                                            }
                                        }

                                        RowLayout {
                                            width: parent.width
                                            spacing: Theme.spacingXS

                                            StyledText {
                                                text: modelData.tailscaleIp || ""
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceTextMedium
                                                Layout.fillWidth: true
                                            }

                                            DankActionButton {
                                                iconName: "content_copy"
                                                buttonSize: 20
                                                iconSize: 11
                                                iconColor: Theme.surfaceVariantText
                                                tooltipText: I18n.tr("Copy", "Copy to clipboard")
                                                onClicked: Quickshell.execDetached(["dms", "cl", "copy", modelData.tailscaleIp])
                                            }
                                        }

                                        StyledText {
                                            text: {
                                                const parts = [];
                                                if (modelData.os)
                                                    parts.push(modelData.os);
                                                if (modelData.online) {
                                                    parts.push(modelData.relay ? I18n.tr("relay: %1", "Tailscale relay server name").arg(modelData.relay) : I18n.tr("direct", "Tailscale direct connection"));
                                                } else if (modelData.lastSeen) {
                                                    parts.push(I18n.tr("last seen %1", "Tailscale peer last seen time").arg(modelData.lastSeen));
                                                }
                                                return parts.join(" \u2022 ");
                                            }
                                            font.pixelSize: 10
                                            color: Theme.surfaceVariantText
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }

                                        // Expanded: DNS name + copy, tags, owner
                                        Column {
                                            visible: isExpanded
                                            width: parent.width
                                            spacing: 2
                                            topPadding: 4

                                            RowLayout {
                                                width: parent.width
                                                spacing: Theme.spacingXS
                                                visible: (modelData.dnsName || "").length > 0

                                                StyledText {
                                                    text: modelData.dnsName || ""
                                                    font.pixelSize: 10
                                                    color: Theme.surfaceVariantText
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                DankActionButton {
                                                    iconName: "content_copy"
                                                    buttonSize: 20
                                                    iconSize: 11
                                                    iconColor: Theme.surfaceVariantText
                                                    onClicked: Quickshell.execDetached(["dms", "cl", "copy", modelData.dnsName])
                                                }
                                            }

                                            StyledText {
                                                visible: (modelData.tags || []).length > 0
                                                text: I18n.tr("Tags: %1", "Tailscale device tags").arg((modelData.tags || []).join(", "))
                                                font.pixelSize: 10
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                visible: (modelData.owner || "").length > 0
                                                text: I18n.tr("Owner: %1", "Tailscale device owner").arg(modelData.owner || "")
                                                font.pixelSize: 10
                                                color: Theme.surfaceVariantText
                                            }
                                        }
                                    }

                                    MouseArea {
                                        z: -1
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: detailRoot.expandedHostname = (detailRoot.expandedHostname === modelData.hostname) ? "" : modelData.hostname
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
