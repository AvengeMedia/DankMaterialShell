pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string target: ""
    property string section: ""
    property string settingLabel: ""
    property string reason: ""
    property var parentModal: null

    readonly property string resolvedTarget: target || (SettingsData.frameEnabled ? "frame" : "island")
    readonly property string iconName: {
        switch (resolvedTarget) {
        case "island":
            return "view_in_ar";
        default:
            return "frame_source";
        }
    }
    readonly property string buttonText: {
        switch (resolvedTarget) {
        case "island":
            return I18n.tr("Open Island", "settings: button that opens the Dank Island tab");
        default:
            return I18n.tr("Open Frame", "settings: button that opens the Frame tab");
        }
    }
    readonly property string tabName: {
        switch (resolvedTarget) {
        case "island":
            return "dank_island";
        default:
            return "frame";
        }
    }

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
            name: root.iconName
            size: Theme.iconSize
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.iconSize - openButton.width - Theme.spacingM * 2
            spacing: Theme.spacingXXS

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
            text: root.buttonText
            backgroundColor: Theme.primary
            textColor: Theme.primaryText
            buttonHeight: 32
            horizontalPadding: Theme.spacingM
            onClicked: {
                if (!root.parentModal)
                    return;
                if (root.section)
                    SettingsSearchService.navigateToSection(root.section);
                root.parentModal.showWithTabName(root.tabName);
            }
        }
    }
}
