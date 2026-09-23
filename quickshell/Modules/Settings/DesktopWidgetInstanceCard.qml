pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

SettingsReorderRow {
    id: root

    required property var instanceData
    property bool confirmingDelete: false

    readonly property string instanceId: instanceData?.id ?? ""
    readonly property string widgetType: instanceData?.widgetType ?? ""
    readonly property var widgetDef: DesktopWidgetRegistry.getWidget(widgetType)
    readonly property string widgetName: instanceData?.name ?? widgetDef?.name ?? widgetType

    signal configureRequested
    signal deleteRequested
    signal duplicateRequested

    iconName: widgetDef?.icon ?? "widgets"
    title: widgetName
    clickable: true
    onClicked: configureRequested()

    trailing: [
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Theme.iconSize
            color: Theme.onSurfaceVariant
            rotation: I18n.isRtl ? 180 : 0
        },
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dividerWidth
            height: SettingsMetrics.splitDividerHeight
            color: Theme.outlineVariant
        },
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
        }
    ]
}
