pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.Settings.DesktopWidgetSettings as DWS

SettingsReorderRow {
    id: root

    required property var instanceData
    property bool isExpanded: false
    property bool confirmingDelete: false

    readonly property string instanceId: instanceData?.id ?? ""
    readonly property string widgetType: instanceData?.widgetType ?? ""
    readonly property var widgetDef: DesktopWidgetRegistry.getWidget(widgetType)
    readonly property string widgetName: instanceData?.name ?? widgetDef?.name ?? widgetType

    signal expandedToggled(bool expanded)
    signal deleteRequested
    signal duplicateRequested

    property Component clockSettingsComponent: Component {
        DWS.ClockSettings {}
    }

    property Component systemMonitorSettingsComponent: Component {
        DWS.SystemMonitorSettings {}
    }

    property Component pluginSettingsComponent: Component {
        DWS.PluginDesktopWidgetSettings {
            instanceId: root.instanceId
            instanceData: root.instanceData
            widgetType: root.widgetType
            widgetDef: root.widgetDef
        }
    }

    width: parent?.width ?? 400
    iconName: widgetDef?.icon ?? "widgets"
    title: widgetName
    clickable: true
    onClicked: expandedToggled(!isExpanded)

    trailing: [
        DankToggle {
            anchors.verticalCenter: parent.verticalCenter
            hideText: true
            checked: instanceData?.enabled ?? true
            onToggled: isChecked => {
                SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                    enabled: isChecked
                });
            }
        },
        DankActionButton {
            id: menuButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "more_vert"
            Accessible.name: I18n.tr("Options")
            onClicked: {
                if (actionsMenu.visible) {
                    actionsMenu.close();
                    return;
                }
                actionsMenu.open();
            }

            Popup {
                id: actionsMenu
                x: -width + parent.width
                y: parent.height + Theme.spacingXS
                width: 160
                padding: Theme.spacingXS
                modal: false
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                onClosed: root.confirmingDelete = false

                background: Rectangle {
                    color: Theme.floatingWindowSurface
                    radius: Theme.windowRadius
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth
                }

                contentItem: Column {
                    spacing: Theme.spacingXXS

                    Rectangle {
                        width: parent.width
                        height: Theme.iconSizeLarge
                        radius: Theme.cornerRadius
                        color: duplicateArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "content_copy"
                                size: Theme.iconSizeSmall
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Duplicate", "verb, desktop widget menu action")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: duplicateArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionsMenu.close();
                                root.duplicateRequested();
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.iconSizeLarge
                        radius: Theme.cornerRadius
                        color: deleteArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: root.confirmingDelete ? "warning" : "delete"
                                size: Theme.iconSizeSmall
                                color: Theme.error
                            }

                            StyledText {
                                text: root.confirmingDelete ? I18n.tr("Confirm Delete") : I18n.tr("Delete")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.error
                            }
                        }

                        MouseArea {
                            id: deleteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.confirmingDelete) {
                                    actionsMenu.close();
                                    root.deleteRequested();
                                    return;
                                }
                                root.confirmingDelete = true;
                            }
                        }
                    }
                }
            }
        },
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.isExpanded ? "expand_less" : "expand_more"
            size: Theme.iconSize
            color: Theme.onSurfaceVariant
        }
    ]

    body: Column {
        width: parent.width
        visible: root.isExpanded
        height: root.isExpanded ? implicitHeight : 0
        spacing: 0

        SettingsTextFieldRow {
            leftIconName: "badge"
            text: I18n.tr("Name")
            value: root.widgetName
            onEditingFinished: value => SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                    name: value
                })
        }

        SettingsDivider {}

        SettingsDropdownRow {
            readonly property var groupsData: {
                const items = [
                    {
                        value: "",
                        label: I18n.tr("None")
                    }
                ];
                for (const g of SettingsData.desktopWidgetGroups || []) {
                    items.push({
                        value: g.id,
                        label: g.name
                    });
                }
                return items;
            }

            visible: (SettingsData.desktopWidgetGroups || []).length > 0
            text: I18n.tr("Group", "noun, dropdown label for a desktop widget group")
            options: groupsData.map(g => g.label)
            currentValue: groupsData.find(g => g.value === (root.instanceData?.group ?? ""))?.label ?? I18n.tr("None")
            onValueChanged: value => SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                    group: groupsData.find(g => g.label === value)?.value || null
                })
        }

        SettingsDivider {
            visible: (SettingsData.desktopWidgetGroups || []).length > 0
        }

        SettingsToggleRow {
            text: I18n.tr("Show on overlay")
            checked: instanceData?.config?.showOnOverlay ?? false
            onToggled: isChecked => {
                SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
                    showOnOverlay: isChecked
                });
            }
        }

        SettingsDivider {
            visible: CompositorService.isNiri
        }

        SettingsToggleRow {
            visible: CompositorService.isNiri
            text: I18n.tr("Show on overview")
            checked: instanceData?.config?.showOnOverview ?? false
            onToggled: isChecked => {
                SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
                    showOnOverview: isChecked
                });
            }
        }

        SettingsDivider {
            visible: CompositorService.isNiri
        }

        SettingsToggleRow {
            visible: CompositorService.isNiri
            text: I18n.tr("Show on overview only")
            checked: instanceData?.config?.showOnOverviewOnly ?? false
            onToggled: isChecked => {
                SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
                    showOnOverviewOnly: isChecked
                });
            }
        }

        SettingsDivider {}

        SettingsToggleRow {
            text: I18n.tr("Click through")
            checked: instanceData?.config?.clickThrough ?? false
            onToggled: isChecked => {
                SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
                    clickThrough: isChecked
                });
            }
        }

        SettingsDivider {}

        SettingsToggleRow {
            text: I18n.tr("Sync position across displays")
            checked: instanceData?.config?.syncPositionAcrossScreens ?? false
            onToggled: isChecked => {
                if (isChecked)
                    SessionData.syncDesktopWidgetPositionToAllScreens(root.instanceId);
                SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
                    syncPositionAcrossScreens: isChecked
                });
            }
        }

        SettingsDivider {}

        Item {
            width: parent.width
            height: ipcColumn.height + Theme.spacingM * 2

            Column {
                id: ipcColumn
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Command")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                Rectangle {
                    width: parent.width
                    height: ipcText.height + Theme.spacingS * 2
                    radius: Theme.cornerRadiusS
                    color: Theme.chipSurface

                    Row {
                        x: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        width: parent.width - Theme.spacingS * 2

                        StyledText {
                            id: ipcText
                            text: "dms ipc call desktopWidget toggleOverlay " + root.instanceId
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.monoFontFamily
                            color: Theme.surfaceVariantText
                            width: parent.width - copyBtn.width - Theme.spacingS
                            elide: Text.ElideMiddle
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankButton {
                            id: copyBtn
                            iconName: "content_copy"
                            Accessible.name: I18n.tr("Copy")
                            backgroundColor: "transparent"
                            textColor: Theme.surfaceText
                            buttonHeight: 28
                            horizontalPadding: 4
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                Quickshell.execDetached(["dms", "cl", "copy", "dms ipc call desktopWidget toggleOverlay " + root.instanceId]);
                                ToastService.showInfo(I18n.tr("Copied to clipboard"));
                            }
                        }
                    }
                }
            }
        }

        SettingsDivider {}

        Loader {
            id: settingsLoader
            width: parent.width
            active: root.isExpanded && root.widgetType !== ""

            sourceComponent: {
                switch (root.widgetType) {
                case "desktopClock":
                    return clockSettingsComponent;
                case "systemMonitor":
                    return systemMonitorSettingsComponent;
                default:
                    return pluginSettingsComponent;
                }
            }

            onLoaded: {
                if (!item)
                    return;
                item.instanceId = root.instanceId;
                item.instanceData = Qt.binding(() => root.instanceData);
            }
        }
    }
}
