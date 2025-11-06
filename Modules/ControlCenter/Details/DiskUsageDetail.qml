import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string currentMountPath: "/"
    property string instanceId: ""

    signal mountPathChanged(string newMountPath)

    implicitHeight: diskContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"])
    }

    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"])
    }

    DankFlickable {
        id: diskContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        contentHeight: diskColumn.height
        clip: true

        Column {
            id: diskColumn
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 100
                visible: !DgopService.dgopAvailable || !DgopService.diskMounts || DgopService.diskMounts.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: DgopService.dgopAvailable ? "storage" : "error"
                        size: 32
                        color: DgopService.dgopAvailable ? Theme.primary : Theme.error
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: DgopService.dgopAvailable ? "No disk data available" : "dgop not available"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Repeater {
                model: DgopService.diskMounts || []
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 80
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: modelData.mount === currentMountPath ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: modelData.mount === currentMountPath ? 2 : 0

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            DankIcon {
                                name: "storage"
                                size: Theme.iconSize
                                color: {
                                    const percentStr = modelData.percent?.replace("%", "") || "0"
                                    const percent = parseFloat(percentStr) || 0
                                    if (percent > 90) return Theme.error
                                    if (percent > 75) return Theme.warning
                                    return modelData.mount === currentMountPath ? Theme.primary : Theme.surfaceText
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: {
                                    const percentStr = modelData.percent?.replace("%", "") || "0"
                                    const percent = parseFloat(percentStr) || 0
                                    return percent.toFixed(0) + "%"
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width - parent.parent.anchors.leftMargin - parent.spacing - 50 - Theme.spacingM

                            StyledText {
                                text: modelData.mount === "/" ? "Root Filesystem" : modelData.mount
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData.mount === currentMountPath ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: modelData.mount
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                                visible: modelData.mount !== "/"
                            }

                            StyledText {
                                text: `${modelData.used || "?"} / ${modelData.size || "?"}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentMountPath = modelData.mount
                            mountPathChanged(modelData.mount)
                        }
                    }

                }
            }
        }
    }
}