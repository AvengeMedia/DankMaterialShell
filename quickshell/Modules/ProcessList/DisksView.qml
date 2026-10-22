pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import "../../Common/Format.js" as Format
import "Drives.js" as Drives

Item {
    id: root


    readonly property var drives: DriveService.drives ?? []
    readonly property bool hasDrives: drives.length > 0
    readonly property var mounts: DgopService.diskMounts ?? []
    // With drive data, only mounts outside every drive; without it (old core, no UDisks), all of them
    readonly property var looseMounts: hasDrives ? mounts.filter(m => !Drives.driveByMount(m.mount, drives)) : mounts

    Ref {
        service: DgopService
        modules: ["disk", "diskmounts"]
        active: root.visible
    }

    Ref {
        service: DriveService
        active: root.visible
    }

    DFlickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight

        ColumnLayout {
            id: column
            width: scroll.width
            spacing: Theme.spacingL

            // Old-core fallback keeps the aggregate I/O line the card would otherwise carry
            Row {
                visible: !root.hasDrives
                spacing: Theme.spacingL

                StyledText {
                    text: I18n.tr("Disk read", "disk read rate") + " " + Format.formatRate(DgopService.diskReadRate)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                }

                StyledText {
                    text: I18n.tr("Disk write", "disk write rate") + " " + Format.formatRate(DgopService.diskWriteRate)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.tertiary
                }
            }

            Repeater {
                model: root.drives

                DriveCard {
                    required property var modelData

                    required property int index
                    Layout.fillWidth: true
                    expanded: index === 0
                    drive: modelData
                    mounts: root.mounts
                    onInstallRequested: DriveService.install()
                }
            }

            DCollapsibleSection {
                id: mountSection
                visible: root.looseMounts.length > 0
                title: I18n.tr("Mount Points", "mount points header in system monitor")
                expanded: !root.hasDrives

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.looseMounts

                        Item {
                            id: mountRow
                            required property var modelData

                            readonly property real usedPct: (parseFloat(modelData?.percent) || 0) / 100
                            readonly property color usageColor: usedPct > 0.95 ? Theme.error : usedPct > 0.85 ? Theme.warning : Theme.primary

                            width: parent.width
                            height: 52

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingM

                                Column {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        width: parent.width
                                        text: mountRow.modelData?.mount ?? ""
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideMiddle
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: (mountRow.modelData?.device ?? "") + " • " + (mountRow.modelData?.fstype ?? "")
                                        wrapMode: Text.NoWrap
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }
                                }

                                Column {
                                    Layout.preferredWidth: 180
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: Theme.fullRadius(width, height)
                                        color: Theme.outlineHeavy

                                        Rectangle {
                                            width: parent.width * Math.min(1, mountRow.usedPct)
                                            height: parent.height
                                            radius: Theme.fullRadius(width, height)
                                            color: mountRow.usageColor
                                        }
                                    }

                                    StyledText {
                                        anchors.right: parent.right
                                        text: (mountRow.modelData?.used ?? "") + " / " + (mountRow.modelData?.size ?? "")
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }
                                }

                                StyledText {
                                    Layout.preferredWidth: 50
                                    text: mountRow.modelData?.percent ?? ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeightMedium
                                    color: mountRow.usedPct > 0.85 ? mountRow.usageColor : Theme.surfaceText
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.spacingXL
                visible: !root.hasDrives && root.mounts.length === 0
                text: I18n.tr("No mount points found", "empty state in disk mounts list")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        }
    }
}
