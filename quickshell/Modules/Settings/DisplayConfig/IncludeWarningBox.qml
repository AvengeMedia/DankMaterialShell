import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    width: parent.width
    height: warningContent.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius

    readonly property bool showLegacy: DisplayConfigState.readOnly
    readonly property bool showError: !showLegacy && DisplayConfigState.includeStatus.exists && !DisplayConfigState.includeStatus.included
    readonly property bool showSetup: !showLegacy && !DisplayConfigState.includeStatus.exists && !DisplayConfigState.includeStatus.included

    color: (showLegacy || showError || showSetup) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0)
    border.color: (showLegacy || showError || showSetup) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0)
    border.width: 1
    visible: (showLegacy || showError || showSetup) && DisplayConfigState.hasOutputBackend && !DisplayConfigState.checkingInclude

    Column {
        id: warningContent
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: "warning"
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - (fixButton.visible ? fixButton.width + Theme.spacingM : 0) - Theme.spacingM
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: {
                        if (root.showLegacy)
                            return I18n.tr("Hyprland conf mode");
                        if (root.showSetup)
                            return I18n.tr("First Time Setup");
                        if (root.showError)
                            return I18n.tr("Outputs Include Missing");
                        return "";
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.primary
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    text: {
                        if (root.showLegacy)
                            return I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before editing display settings.");
                        if (root.showSetup)
                            return I18n.tr("Click 'Setup' to create the outputs config and add include to your compositor config.");
                        if (root.showError)
                            return I18n.tr("dms/outputs config exists but is not included in your compositor config. Display changes won't persist.");
                        return "";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }
            }

            DankButton {
                id: fixButton
                visible: !root.showLegacy && (root.showError || root.showSetup)
                text: {
                    if (DisplayConfigState.fixingInclude)
                        return I18n.tr("Fixing...");
                    if (root.showSetup)
                        return I18n.tr("Setup");
                    return I18n.tr("Fix Now");
                }
                backgroundColor: Theme.primary
                textColor: Theme.primaryText
                enabled: !DisplayConfigState.fixingInclude
                anchors.verticalCenter: parent.verticalCenter
                onClicked: DisplayConfigState.fixOutputsInclude()
            }
        }
    }
}
