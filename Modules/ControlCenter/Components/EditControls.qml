import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Row {
    id: root

    property var availableWidgets: []
    property Item popoutContent: null

    signal addWidget(string widgetId)
    signal resetToDefault()
    signal clearAll()

    height: 48
    spacing: Theme.spacingS

    onAddWidget: addWidgetPopup.close()

    Popup {
        id: addWidgetPopup
        parent: popoutContent
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        width: 400
        height: 300
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            border.color: Theme.primarySelected
            border.width: 0
            radius: Theme.cornerRadius
        }

        contentItem: Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingL

            Row {
                id: headerRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.spacingM

                DankIcon {
                    name: "add_circle"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Typography {
                    text: I18n.tr("Add Widget")
                    style: Typography.Style.Subtitle
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankListView {
                anchors.top: headerRow.bottom
                anchors.topMargin: Theme.spacingM
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingS
                clip: true
                model: root.availableWidgets

                delegate: Rectangle {
                    width: 400 - Theme.spacingL * 2
                    height: 50
                    radius: Theme.cornerRadius
                    color: widgetMouseArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 0

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon {
                            name: modelData.icon
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: 400 - Theme.spacingL * 2 - Theme.iconSize - Theme.spacingM * 3 - Theme.iconSize

                            Typography {
                                text: modelData.text
                                style: Typography.Style.Body
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Typography {
                                text: modelData.description
                                style: Typography.Style.Caption
                                color: Theme.outline
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        DankIcon {
                            name: "add"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: widgetMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.addWidget(modelData.id)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 48
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        border.color: Theme.primary
        border.width: 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "add"
                size: Theme.iconSize - 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Typography {
                text: I18n.tr("Add Widget")
                style: Typography.Style.Button
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: addWidgetPopup.open()
        }
    }

    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 48
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
        border.color: Theme.warning
        border.width: 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "settings_backup_restore"
                size: Theme.iconSize - 2
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }

            Typography {
                text: I18n.tr("Defaults")
                style: Typography.Style.Button
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.resetToDefault()
        }
    }

    Rectangle {
        width: (parent.width - Theme.spacingS * 2) / 3
        height: 48
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
        border.color: Theme.error
        border.width: 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "clear_all"
                size: Theme.iconSize - 2
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            Typography {
                text: I18n.tr("Reset")
                style: Typography.Style.Button
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearAll()
        }
    }
}