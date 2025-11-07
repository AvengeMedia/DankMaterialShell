import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: CupsService
    }

    ccWidgetIcon: CupsService.cupsAvailable && CupsService.getPrintersNum() > 0 ? "print" : "print_disabled"
    ccWidgetPrimaryText: I18n.tr("Printers")
    ccWidgetSecondaryText: {
        if (CupsService.cupsAvailable && CupsService.getPrintersNum() > 0) {
            return I18n.tr("Printers: ") + CupsService.getPrintersNum() + " - " + I18n.tr("Jobs: ") + CupsService.getTotalJobsNum()
        } else {
            if (!CupsService.cupsAvailable) {
                return I18n.tr("Print Server not available")
            } else {
                return I18n.tr("No printer found")
            }
        }
    }
    ccWidgetIsActive: CupsService.cupsAvailable && CupsService.getTotalJobsNum() > 0

    onCcWidgetToggled: {

    }

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot
            implicitHeight: detailColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                visible: !CupsService.cupsAvailable || CupsService.getPrintersNum() == 0
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "print_disabled"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: !CupsService.cupsAvailable ? I18n.tr("Print Server not available") : I18n.tr("No printer found")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            
            Column {
                id: detailColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS
                visible: CupsService.cupsAvailable && CupsService.getPrintersNum() > 0
                height: visible ? 120 : 0

                RowLayout {
                    spacing: Theme.spacingS
                    width: parent.width

                    DankDropdown {
                        id: printerDropdown
                        text: ""
                        Layout.fillWidth: true
                        Layout.maximumWidth: parent.width - 180
                        description: ""
                        currentValue: {
                            CupsService.getSelectedPrinter()
                        }
                        options: CupsService.getPrintersNames()
                        onValueChanged: value => {
                                            CupsService.setSelectedPrinter(value)
                                        }
                    }

                    Column {
                        spacing: Theme.spacingS

                        StyledText {
                            text: CupsService.getCurrentPrinterStatePrettyShort()
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Row {
                            spacing: Theme.spacingM

                            Rectangle {
                                height: 24
                                width: 80
                                radius: 14
                                color: printerStatusToggle.containsMouse ? Theme.errorHover : Theme.surfaceLight
                                visible: true
                                opacity: 1.0

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: CupsService.getCurrentPrinterState() === "stopped" ? "play_arrow" : "pause"
                                        size: Theme.fontSizeSmall + 4
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: CupsService.getCurrentPrinterState() === "stopped" ? I18n.tr("Resume") : I18n.tr("Pause")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: printerStatusToggle
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: true
                                    onClicked: {
                                        const selected = CupsService.getSelectedPrinter()
                                        if (CupsService.getCurrentPrinterState() === "stopped") {
                                            CupsService.resumePrinter(selected)
                                        } else {
                                            CupsService.pausePrinter(selected)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                height: 24
                                width: 80
                                radius: 14
                                color: clearJobsToggle.containsMouse ? Theme.errorHover : Theme.surfaceLight
                                visible: true
                                opacity: 1.0

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "delete_forever"
                                        size: Theme.fontSizeSmall + 4
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: I18n.tr("Jobs")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                    }
                                }

                                MouseArea {
                                    id: clearJobsToggle
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: true
                                    onClicked: {
                                        const selected = CupsService.getSelectedPrinter()
                                        CupsService.purgeJobs(selected)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    height: 1
                    width: parent.width
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                }

                DankFlickable {
                    width: parent.width
                    height: 160
                    contentHeight: listCol.height
                    clip: true

                    Column {
                        id: listCol
                        width: parent.width
                        spacing: Theme.spacingXS

                        Item {
                            width: parent.width
                            height: 120
                            visible: CupsService.getCurrentPrinterJobs().length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "work"
                                    size: 36
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: I18n.tr("The job queue of this printer is empty")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Repeater {
                            model: CupsService.getCurrentPrinterJobs()

                            delegate: Rectangle {
                                required property var modelData

                                width: parent ? parent.width : 300
                                height: 50
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHighest
                                border.width: 1
                                border.color: Theme.outlineLight
                                opacity: 1.0

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: "docs"
                                        size: Theme.iconSize + 2
                                        color: Theme.surfaceText
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Column {
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true

                                        StyledText {
                                            text: "[" + modelData.id + "] " + modelData.state + " (" + (modelData.size / 1024) + "kb)"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: {
                                                var date = new Date(modelData.timeCreated)
                                                return date.toLocaleString(Qt.locale(), Locale.ShortFormat)
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceTextMedium
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                DankActionButton {
                                    id: cancelJobButton
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconName: "delete"
                                    buttonSize: 36
                                    onClicked: {
                                        CupsService.cancelJob(CupsService.getSelectedPrinter(), modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
