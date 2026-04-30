pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string settingLabel: ""
    property string reason: ""
    property var parentModal: null

    width: parent?.width ?? 0
    height: contentRow.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.primary, 0.08)
    border.color: Theme.withAlpha(Theme.primary, 0.18)
    border.width: 1

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        DankIcon {
            name: "frame_source"
            size: Theme.iconSize
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.iconSize - openButton.width - Theme.spacingM * 2
            spacing: 2

            StyledText {
                text: root.settingLabel
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                wrapMode: Text.WordWrap
            }

            StyledText {
                text: root.reason
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.reason !== ""
            }
        }

        DankButton {
            id: openButton
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Open Frame")
            backgroundColor: Theme.primary
            textColor: Theme.primaryText
            buttonHeight: 32
            horizontalPadding: Theme.spacingM
            onClicked: {
                if (!root.parentModal)
                    return;
                root.parentModal.showWithTabName("frame");
            }
        }
    }
}
