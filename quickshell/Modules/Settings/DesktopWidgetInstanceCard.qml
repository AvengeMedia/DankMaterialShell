pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.Settings.DesktopWidgetSettings as DWS

SettingsCard {
    id: root

    required property var instanceData
    property bool isExpanded: false

    readonly property string instanceId: instanceData?.id ?? ""
    readonly property string widgetType: instanceData?.widgetType ?? ""
    readonly property var widgetDef: DesktopWidgetRegistry.getWidget(widgetType)
    readonly property string widgetName: instanceData?.name ?? widgetDef?.name ?? widgetType

    signal deleteRequested

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
    collapsible: true
    expanded: isExpanded

    onExpandedChanged: isExpanded = expanded

    Row {
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width - toggleRow.width - deleteBtn.width - Theme.spacingS * 2
            height: 1
        }

        Row {
            id: toggleRow
            spacing: Theme.spacingS

            StyledText {
                text: (instanceData?.enabled ?? true) ? I18n.tr("Enabled") : I18n.tr("Disabled")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            DankToggle {
                checked: instanceData?.enabled ?? true
                onToggled: isChecked => {
                    if (!root.instanceId) return;
                    SettingsData.updateDesktopWidgetInstance(root.instanceId, { enabled: isChecked });
                }
            }
        }

        DankButton {
            id: deleteBtn
            iconName: "delete"
            backgroundColor: "transparent"
            textColor: Theme.error
            buttonHeight: 32
            horizontalPadding: 4
            onClicked: root.deleteRequested()
        }
    }

    Column {
        width: parent.width
        spacing: 0
        visible: root.isExpanded
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        SettingsDivider {}

        Item {
            width: parent.width
            height: nameRow.height + Theme.spacingM * 2

            Row {
                id: nameRow
                x: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM
                width: parent.width - Theme.spacingM * 2

                StyledText {
                    text: I18n.tr("Name")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 80
                }

                DankTextField {
                    width: parent.width - 80 - Theme.spacingM
                    text: root.widgetName
                    onEditingFinished: {
                        if (!root.instanceId) return;
                        SettingsData.updateDesktopWidgetInstance(root.instanceId, { name: text });
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
                if (!item) return;
                item.instanceId = root.instanceId;
                item.instanceData = Qt.binding(() => root.instanceData);
            }
        }
    }
}
