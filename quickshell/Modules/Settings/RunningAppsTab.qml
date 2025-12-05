import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "apps"
                title: I18n.tr("Running Apps Settings")

                SettingsToggleRow {
                    text: I18n.tr("Running Apps Only In Current Workspace")
                    description: I18n.tr("Show only apps running in current workspace")
                    checked: SettingsData.runningAppsCurrentWorkspace
                    onToggled: checked => SettingsData.set("runningAppsCurrentWorkspace", checked)
                }
            }
        }
    }
}
