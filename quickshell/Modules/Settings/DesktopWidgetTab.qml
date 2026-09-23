pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.Settings.DesktopWidgetSettings as DWS

Item {
    id: root

    readonly property string instanceId: SettingsUiState.selectedDesktopWidgetId
    readonly property var instanceData: (SettingsData.desktopWidgetInstances || []).find(instance => instance.id === instanceId) ?? null
    readonly property string widgetType: instanceData?.widgetType ?? ""
    readonly property var widgetDef: DesktopWidgetRegistry.getWidget(widgetType)
    readonly property string widgetName: instanceData?.name ?? widgetDef?.name ?? widgetType
    readonly property var cfg: instanceData?.config ?? {}
    readonly property string overlayCommand: "dms ipc call desktopWidget toggleOverlay " + instanceId
    readonly property var groupOptions: [
        {
            "value": "",
            "label": I18n.tr("None")
        }
    ].concat((SettingsData.desktopWidgetGroups || []).map(group => ({
                "value": group.id,
                "label": group.name
            })))

    function updateConfig(key, value) {
        const updates = {};
        updates[key] = value;
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates);
    }

    onWidgetNameChanged: SettingsUiState.selectedWidgetTitle = widgetName

    Component {
        id: clockSettings

        DWS.ClockSettings {
            instanceId: root.instanceId
            instanceData: root.instanceData
        }
    }

    Component {
        id: systemMonitorSettings

        DWS.SystemMonitorSettings {
            instanceId: root.instanceId
            instanceData: root.instanceData
        }
    }

    Component {
        id: pluginSettings

        DWS.PluginDesktopWidgetSettings {
            instanceId: root.instanceId
            instanceData: root.instanceData
            widgetType: root.widgetType
            widgetDef: root.widgetDef
        }
    }

    SettingsPage {
        visible: root.instanceData !== null

        SettingsCard {
            SettingsToggleRow {
                iconName: root.widgetDef?.icon ?? "widgets"
                text: root.widgetDef?.name ?? root.widgetType
                description: root.widgetDef?.description ?? ""
                checked: root.instanceData?.enabled ?? true
                onToggled: checked => SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        "enabled": checked
                    })
            }

            SettingsTextFieldRow {
                leftIconName: "badge"
                text: I18n.tr("Name")
                value: root.widgetName
                onEditingFinished: value => SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        "name": value
                    })
            }

            SettingsDropdownRow {
                visible: root.groupOptions.length > 1
                text: I18n.tr("Group", "noun, dropdown label for a desktop widget group")
                options: root.groupOptions.map(group => group.label)
                currentValue: root.groupOptions.find(group => group.value === (root.instanceData?.group ?? ""))?.label ?? I18n.tr("None")
                onValueChanged: value => SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        "group": root.groupOptions.find(group => group.label === value)?.value || null
                    })
            }
        }

        Loader {
            width: parent.width
            active: root.instanceData !== null
            sourceComponent: {
                switch (root.widgetType) {
                case "desktopClock":
                    return clockSettings;
                case "systemMonitor":
                    return systemMonitorSettings;
                default:
                    return pluginSettings;
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Behavior")

            SettingsToggleRow {
                text: I18n.tr("Show on overlay")
                checked: root.cfg.showOnOverlay ?? false
                onToggled: checked => root.updateConfig("showOnOverlay", checked)
            }

            SettingsToggleRow {
                visible: CompositorService.isNiri
                text: I18n.tr("Show on overview")
                checked: root.cfg.showOnOverview ?? false
                onToggled: checked => root.updateConfig("showOnOverview", checked)
            }

            SettingsToggleRow {
                visible: CompositorService.isNiri
                text: I18n.tr("Show on overview only")
                checked: root.cfg.showOnOverviewOnly ?? false
                onToggled: checked => root.updateConfig("showOnOverviewOnly", checked)
            }

            SettingsToggleRow {
                text: I18n.tr("Click through")
                checked: root.cfg.clickThrough ?? false
                onToggled: checked => root.updateConfig("clickThrough", checked)
            }

            SettingsToggleRow {
                text: I18n.tr("Sync position across displays")
                checked: root.cfg.syncPositionAcrossScreens ?? false
                onToggled: checked => {
                    if (checked)
                        SessionData.syncDesktopWidgetPositionToAllScreens(root.instanceId);
                    root.updateConfig("syncPositionAcrossScreens", checked);
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Command")

            SettingsRow {
                body: Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - copyButton.width - parent.spacing
                        text: root.overlayCommand
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.monoFontFamily
                        color: Theme.surfaceVariantText
                        elide: Text.ElideMiddle
                    }

                    DankActionButton {
                        id: copyButton
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "content_copy"
                        Accessible.name: I18n.tr("Copy")
                        onClicked: {
                            Quickshell.execDetached(["dms", "cl", "copy", root.overlayCommand]);
                            ToastService.showInfo(I18n.tr("Copied to clipboard"));
                        }
                    }
                }
            }
        }
    }
}
