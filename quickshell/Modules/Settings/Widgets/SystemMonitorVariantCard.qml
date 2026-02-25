pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var variant: ({})
    property bool expanded: false

    signal expandToggled(bool isExpanded)
    signal deleteRequested
    signal nameChanged(string newName)
    signal configChanged(string key, var value)

    readonly property var cfg: variant.config || {}

    function updateConfig(key, value) {
        var newConfig = JSON.parse(JSON.stringify(cfg));
        newConfig[key] = value;
        root.configChanged("config", newConfig);
    }

    width: parent?.width ?? 0
    height: variantColumn.height
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    clip: true

    Column {
        id: variantColumn
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: headerContent.height + Theme.spacingM * 2

            Row {
                id: headerContent
                x: Theme.spacingM
                y: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingM

                DankIcon {
                    name: root.expanded ? "expand_less" : "expand_more"
                    size: Theme.iconSize
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - Theme.iconSize - deleteBtn.width - Theme.spacingM * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    StyledText {
                        text: root.variant.name || "Unnamed"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    StyledText {
                        property var features: {
                            var f = [];
                            if (root.cfg.showCpu)
                                f.push("CPU");
                            if (root.cfg.showMemory)
                                f.push("RAM");
                            if (root.cfg.showNetwork)
                                f.push("Net");
                            if (root.cfg.showDisk)
                                f.push("Disk");
                            if (root.cfg.showGpuTemp)
                                f.push("GPU");
                            return f;
                        }
                        text: features.length > 0 ? features.join(", ") : I18n.tr("No features enabled")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: deleteBtn
                    width: 32
                    height: 32
                    radius: 16
                    color: deleteMouse.containsMouse ? Theme.error : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: "delete"
                        size: 16
                        color: deleteMouse.containsMouse ? Theme.background : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteRequested()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: deleteBtn.width + Theme.spacingM
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandToggled(!root.expanded)
            }
        }

        Column {
            width: parent.width
            spacing: 0
            visible: root.expanded

            SettingsDivider {}

            Item {
                width: parent.width
                height: nameRow.height + Theme.spacingM * 2

                Row {
                    id: nameRow
                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Name")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: 80
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankTextField {
                        width: parent.width - 80 - Theme.spacingM
                        text: root.variant.name || ""
                        onEditingFinished: {
                            if (text !== root.variant.name)
                                root.nameChanged(text);
                        }
                    }
                }
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Header")
                checked: root.cfg.showHeader ?? true
                onToggled: checked => root.updateConfig("showHeader", checked)
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show CPU")
                checked: root.cfg.showCpu ?? true
                onToggled: checked => root.updateConfig("showCpu", checked)
            }

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show CPU Graph")
                visible: root.cfg.showCpu
                checked: root.cfg.showCpuGraph ?? true
                onToggled: checked => root.updateConfig("showCpuGraph", checked)
            }

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show CPU Temp")
                visible: root.cfg.showCpu
                checked: root.cfg.showCpuTemp ?? true
                onToggled: checked => root.updateConfig("showCpuTemp", checked)
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Memory")
                checked: root.cfg.showMemory ?? true
                onToggled: checked => root.updateConfig("showMemory", checked)
            }

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Memory Graph")
                visible: root.cfg.showMemory
                checked: root.cfg.showMemoryGraph ?? true
                onToggled: checked => root.updateConfig("showMemoryGraph", checked)
            }

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Memory in GB")
                visible: root.cfg.showMemory
                checked: root.cfg.showInGb ?? false
                onToggled: checked => root.updateConfig("showInGb", checked)
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Network")
                checked: root.cfg.showNetwork ?? true
                onToggled: checked => root.updateConfig("showNetwork", checked)
            }

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Network Graph")
                visible: root.cfg.showNetwork
                checked: root.cfg.showNetworkGraph ?? true
                onToggled: checked => root.updateConfig("showNetworkGraph", checked)
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Disk")
                checked: root.cfg.showDisk ?? true
                onToggled: checked => root.updateConfig("showDisk", checked)
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show GPU Temperature")
                checked: root.cfg.showGpuTemp ?? false
                onToggled: checked => root.updateConfig("showGpuTemp", checked)
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.cfg.showGpuTemp && DgopService.availableGpus.length > 0

                Item {
                    width: 1
                    height: Theme.spacingS
                }

                Repeater {
                    model: DgopService.availableGpus

                    Rectangle {
                        required property var modelData

                        width: (parent?.width ?? 0) - Theme.spacingM * 2
                        x: Theme.spacingM
                        height: 40
                        radius: Theme.cornerRadius
                        color: root.cfg.gpuPciId === modelData.pciId ? Theme.primarySelected : Theme.surfaceContainer
                        border.color: root.cfg.gpuPciId === modelData.pciId ? Theme.primary : "transparent"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "videocam"
                                size: Theme.iconSizeSmall
                                color: root.cfg.gpuPciId === modelData.pciId ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.displayName || "Unknown GPU"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                width: parent.width - Theme.iconSizeSmall - Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.updateConfig("gpuPciId", modelData.pciId)
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingS
                }
            }

            SettingsDivider {}

            DankToggle {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                text: I18n.tr("Show Top Processes")
                checked: root.cfg.showTopProcesses ?? false
                onToggled: checked => root.updateConfig("showTopProcesses", checked)
            }

            SettingsDivider {}

            Column {
                width: parent.width - Theme.spacingM * 2
                x: Theme.spacingM
                topPadding: Theme.spacingM
                bottomPadding: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    width: parent.width

                    StyledText {
                        id: transparencyLabel
                        text: I18n.tr("Transparency")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - transparencyLabel.width - transparencyValue.width
                        height: 1
                    }

                    StyledText {
                        id: transparencyValue
                        text: transparencySlider.value + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                DankSlider {
                    id: transparencySlider
                    width: parent.width
                    minimum: 0
                    maximum: 100
                    value: Math.round((root.cfg.transparency ?? 0.8) * 100)
                    showValue: false
                    wheelEnabled: false
                    onSliderDragFinished: finalValue => root.updateConfig("transparency", finalValue / 100)
                }
            }

            Item {
                width: 1
                height: Theme.spacingM
            }
        }
    }
}
