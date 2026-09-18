pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

FocusScope {
    id: root

    property string hubId: ""
    property var parentModal: null
    readonly property string headerFile: SettingsTabs.page(hubId)?.hubHeader ?? ""

    readonly property var rows: SettingsTabs.hubMainRows(hubId)
    readonly property var moreRows: SettingsTabs.hubMoreRows(hubId)

    onHubIdChanged: flickable.contentY = 0

    SettingsPage {
        id: flickable

        Loader {
            width: parent.width
            source: root.headerFile ? Qt.resolvedUrl(root.headerFile + ".qml") : ""
            onLoaded: item.parentModal = Qt.binding(() => root.parentModal)
        }

        SettingsGroup {
            width: parent.width
            visible: root.rows.length > 0

            Repeater {
                model: root.rows

                SettingsNavRow {
                    required property var modelData

                    iconName: modelData.icon
                    title: modelData.text
                    hint: modelData.hint ?? ""
                    trailingBadge: modelData.kind === "plugin" && PluginService.loadedPlugins[modelData.pluginId] === undefined ? I18n.tr("Disabled") : ""
                    onClicked: root.parentModal?.navigateTo(modelData.id)
                }
            }
        }

        SettingsCard {
            title: I18n.tr("More", "hub group of rarely used pages")
            visible: root.moreRows.length > 0

            Repeater {
                model: root.moreRows

                SettingsNavRow {
                    required property var modelData

                    iconName: modelData.icon
                    title: modelData.text
                    hint: modelData.hint ?? ""
                    onClicked: root.parentModal?.navigateTo(modelData.id)
                }
            }
        }
    }
}
