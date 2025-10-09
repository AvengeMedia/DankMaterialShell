import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    property bool networkInfoModalVisible: false
    property string networkSSID: ""
    property var networkData: null

    function showNetworkInfo(ssid, data) {
        networkSSID = ssid
        networkData = data
        networkInfoModalVisible = true
        open()
        NetworkService.fetchNetworkInfo(ssid)
    }

    function hideDialog() {
        networkInfoModalVisible = false
        close()
        networkSSID = ""
        networkData = null
    }

    visible: networkInfoModalVisible
    width: 600
    height: 500
    enableShadow: true
    onBackgroundClicked: hideDialog()
    onVisibleChanged: {
        if (!visible) {
            networkSSID = ""
            networkData = null
        }
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
                            text: I18n.tr("Network Information")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: `Details for "${networkSSID}"`
                            font.pixelSize: Theme.fontSizeMedium
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

                Rectangle {
                    id: detailsRect

                    width: parent.width
                    height: parent.height - 140
                    radius: Theme.cornerRadius
                    color: Theme.surfaceHover
                    border.color: Theme.outlineStrong
                    border.width: 1
                    clip: true

                    DankFlickable {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        contentHeight: detailsText.contentHeight

                        StyledText {
                            id: detailsText

                            width: parent.width
                            text: NetworkService.networkInfoDetails && NetworkService.networkInfoDetails.replace(/\\n/g, '\n') || "No information available"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                        }
                    }

                }

                Item {
                    width: parent.width
                    height: 40

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(70, closeText.contentWidth + Theme.spacingM * 2)
                        height: 36
                        radius: Theme.cornerRadius
                        color: closeArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

                        StyledText {
                            id: closeText

                            anchors.centerIn: parent
                            text: I18n.tr("Close")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.background
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: closeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hideDialog()
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

    }

}
