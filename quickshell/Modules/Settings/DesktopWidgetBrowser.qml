pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

WidgetPickerWindow {
    id: root

    signal widgetAdded(string widgetType)

    function addWidget(widget) {
        const widgetType = widget.id;
        const defaultConfig = DesktopWidgetRegistry.getDefaultConfig(widgetType);
        const name = widget.name || widgetType;
        SettingsData.createDesktopWidgetInstance(widgetType, name, defaultConfig);
        root.widgetAdded(widgetType);
        root.hide();
    }

    objectName: "desktopWidgetBrowser"
    title: I18n.tr("Add Desktop Widget")
    widgets: DesktopWidgetRegistry.registeredWidgetsList || []
    featuredFirst: true
    showEmptyState: true
    widgetDelegate: tileDelegate

    onWidgetChosen: widget => addWidget(widget)

    Component {
        id: tileDelegate

        Rectangle {
            id: delegateRoot

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 72
            radius: Theme.cornerRadius
            property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
            color: isSelected ? Theme.primarySelected : widgetArea.containsMouse ? Theme.primaryHover : Theme.floatingWindowNestedSurface
            border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.2)
            border.width: isSelected ? Theme.outlineWidthFocused : Theme.outlineWidth

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.cornerRadius
                    color: Theme.primarySelected
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: delegateRoot.modelData.icon || "widgets"
                        size: Theme.iconSize
                        color: Theme.primary
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS
                    width: parent.width - 44 - Theme.iconSize - Theme.spacingM * 3

                    Row {
                        spacing: Theme.spacingS

                        StyledText {
                            text: delegateRoot.modelData.name || delegateRoot.modelData.id
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                            color: Theme.surfaceText
                        }

                        Rectangle {
                            visible: delegateRoot.modelData.featured || false
                            width: featuredWidgetRow.implicitWidth + Theme.spacingXS * 2
                            height: 18
                            radius: Theme.fullRadius(width, height)
                            color: Theme.withAlpha(Theme.secondary, 0.15)
                            border.color: Theme.withAlpha(Theme.secondary, 0.4)
                            border.width: Theme.outlineWidth
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                id: featuredWidgetRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXXS

                                DankIcon {
                                    name: "star"
                                    size: 10
                                    color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr("featured")
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    color: Theme.secondary
                                    font.weight: Theme.fontWeightMedium
                                }
                            }
                        }

                        Rectangle {
                            visible: delegateRoot.modelData.type === "plugin"
                            width: pluginLabel.implicitWidth + Theme.spacingXS * 2
                            height: 18
                            radius: Theme.fullRadius(width, height)
                            color: Theme.withAlpha(Theme.secondary, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                id: pluginLabel
                                anchors.centerIn: parent
                                text: I18n.tr("Plugin")
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: Theme.secondary
                            }
                        }
                    }

                    StyledText {
                        text: delegateRoot.modelData.description || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        elide: Text.ElideRight
                        width: parent.width
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        visible: text !== ""
                    }
                }

                DankIcon {
                    name: "add"
                    size: Theme.iconSizeMedium
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: widgetArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addWidget(delegateRoot.modelData)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }
}
