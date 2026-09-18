import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    required property ConfigInclude include
    property bool visibleCondition: true

    readonly property bool showLegacy: include.readOnly
    readonly property bool showSetup: !showLegacy && !include.included

    width: parent.width
    height: content.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.primary, 0.15)
    border.color: Theme.withAlpha(Theme.primary, 0.3)
    border.width: Theme.outlineWidth
    visible: visibleCondition && (showLegacy || showSetup) && !include.checking

    Row {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingL
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
                text: root.showLegacy ? I18n.tr("Hyprland conf mode") : I18n.tr("First Time Setup")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.primary
                width: parent.width
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                text: root.showLegacy ? I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before changing these settings.") : I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg(root.include.fragmentLabel)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignLeft
            }
        }

        DankButton {
            id: fixButton
            visible: root.showSetup
            text: root.include.fixing ? I18n.tr("Setting up...") : I18n.tr("Setup")
            backgroundColor: Theme.primary
            textColor: Theme.primaryText
            enabled: !root.include.fixing
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.include.fix()
        }
    }
}
