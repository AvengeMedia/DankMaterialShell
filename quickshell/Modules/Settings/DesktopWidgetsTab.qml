pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var expandedStates: ({})
    property var parentModal: null

    DesktopWidgetBrowser {
        id: widgetBrowser
        parentModal: root.parentModal
        onWidgetAdded: widgetType => {
            ToastService.showInfo(I18n.tr("Widget added"));
        }
    }

    PluginBrowser {
        id: desktopPluginBrowser
        parentModal: root.parentModal
        typeFilter: "desktop-widget"
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "widgets"
                title: I18n.tr("Desktop Widgets")

                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Add and configure widgets that appear on your desktop")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Add Widget")
                            iconName: "add"
                            onClicked: widgetBrowser.show()
                        }

                        DankButton {
                            text: I18n.tr("Browse Plugins")
                            iconName: "store"
                            onClicked: desktopPluginBrowser.show()
                        }
                    }
                }
            }

            Column {
                id: instancesColumn
                width: parent.width
                spacing: Theme.spacingM
                visible: SettingsData.desktopWidgetInstances.length > 0

                Repeater {
                    id: instanceRepeater
                    model: ScriptModel {
                        id: instancesModel
                        objectProp: "id"
                        values: SettingsData.desktopWidgetInstances
                    }

                    DesktopWidgetInstanceCard {
                        required property var modelData
                        required property int index

                        readonly property string instanceIdRef: modelData.id
                        readonly property var liveInstanceData: {
                            const instances = SettingsData.desktopWidgetInstances || [];
                            return instances.find(inst => inst.id === instanceIdRef) ?? modelData;
                        }

                        width: instancesColumn.width
                        instanceData: liveInstanceData
                        isExpanded: root.expandedStates[instanceIdRef] ?? false

                        onExpandedChanged: {
                            if (expanded === (root.expandedStates[instanceIdRef] ?? false))
                                return;
                            var states = Object.assign({}, root.expandedStates);
                            states[instanceIdRef] = expanded;
                            root.expandedStates = states;
                        }

                        onDuplicateRequested: SettingsData.duplicateDesktopWidgetInstance(instanceIdRef)

                        onDeleteRequested: {
                            SettingsData.removeDesktopWidgetInstance(instanceIdRef);
                            ToastService.showInfo(I18n.tr("Widget removed"));
                        }
                    }
                }
            }

            StyledText {
                visible: SettingsData.desktopWidgetInstances.length === 0
                text: I18n.tr("No widgets added. Click \"Add Widget\" to get started.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            SettingsCard {
                width: parent.width
                iconName: "info"
                title: I18n.tr("Help")

                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "drag_pan"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Move Widget")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Right-click and drag anywhere on the widget")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: Theme.primarySelected

                            DankIcon {
                                anchors.centerIn: parent
                                name: "open_in_full"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Resize Widget")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Right-click and drag the bottom-right corner")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }
    }
}
