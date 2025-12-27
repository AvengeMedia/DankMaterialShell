pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.Settings.DesktopWidgetSettings as DWS

SettingsCard {
    id: root

    required property var instanceData
    property bool isExpanded: false
    property bool confirmingDelete: false

    readonly property string instanceId: instanceData?.id ?? ""
    readonly property string widgetType: instanceData?.widgetType ?? ""
    readonly property var widgetDef: DesktopWidgetRegistry.getWidget(widgetType)
    readonly property string widgetName: instanceData?.name ?? widgetDef?.name ?? widgetType

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
    collapsible: true
    expanded: isExpanded

    onExpandedChanged: isExpanded = expanded

    headerActions: [
        DankToggle {
            checked: instanceData?.enabled ?? true
            onToggled: isChecked => {
                if (!root.instanceId)
                    return;
                SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                    enabled: isChecked
                });
            }
        },
        DankActionButton {
            id: menuButton
            iconName: "more_vert"
            onClicked: actionsMenu.open()

            Popup {
                id: actionsMenu
                x: -width + parent.width
                y: parent.height + Theme.spacingXS
                width: 160
                padding: Theme.spacingXS
                modal: true
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                onClosed: root.confirmingDelete = false

                background: Rectangle {
                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                    radius: Theme.cornerRadius
                    border.color: Theme.outlineLight
                    border.width: 1
                }

                contentItem: Column {
                    spacing: 2

                    Rectangle {
                        width: parent.width
                        height: Theme.iconSizeLarge
                        radius: Theme.cornerRadius
                        color: duplicateArea.containsMouse ? Theme.primaryHover : "transparent"

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
                                text: I18n.tr("Duplicate")
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
                        color: deleteArea.containsMouse ? Theme.errorHover : "transparent"

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
        }
    ]

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
                        if (!root.instanceId)
                            return;
                        SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                            name: text
                        });
                    }
                }
            }
        }

        SettingsDivider {}

        SettingsToggleRow {
            text: I18n.tr("Show on Overlay")
            checked: instanceData?.config?.showOnOverlay ?? false
            onToggled: isChecked => {
                if (!root.instanceId)
                    return;
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
            text: I18n.tr("Show on Overview")
            checked: instanceData?.config?.showOnOverview ?? false
            onToggled: isChecked => {
                if (!root.instanceId)
                    return;
                SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, {
                    showOnOverview: isChecked
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
                }

                Rectangle {
                    width: parent.width
                    height: ipcText.height + Theme.spacingS * 2
                    radius: Theme.cornerRadius / 2
                    color: Theme.surfaceHover

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
