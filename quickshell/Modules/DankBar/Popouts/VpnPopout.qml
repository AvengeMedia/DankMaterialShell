import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:vpn"

    Ref {
        service: DMSNetworkService
    }

    property bool wasVisible: false
    property var triggerScreen: null

    popupWidth: 380
    popupHeight: Math.min(Screen.height - 100, contentLoader.item ? contentLoader.item.implicitHeight : 320)
    triggerWidth: 70
    screen: triggerScreen
    shouldBeVisible: false

    onShouldBeVisibleChanged: {
        if (shouldBeVisible && !wasVisible) {
            DMSNetworkService.getState();
        }
        wasVisible = shouldBeVisible;
    }

    onBackgroundClicked: close()

    content: Component {
        Rectangle {
            id: content

            implicitHeight: contentColumn.height + Theme.spacingL * 2
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Theme.outlineMedium
            border.width: 0
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

            Column {
                id: contentColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                RowLayout {
                    width: parent.width
                    height: 32
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("VPN Connections")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.close()
                    }
                }

                VpnDetailContent {
                    width: parent.width
                    listHeight: 200
                    parentPopout: root
                }
            }
        }
    }
}
