pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var deviceNode
    property string deviceType: "output"

    property bool showHideButton: false
    property bool isHidden: false

    signal editRequested(var deviceNode)
    signal resetRequested(var deviceNode)
    signal hideRequested(var deviceNode)

    width: parent?.width ?? 0
    height: deviceRowContent.height + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: deviceMouseArea.containsMouse ? Theme.surfaceHover : "transparent"

    readonly property bool hasCustomAlias: AudioService.hasDeviceAlias(deviceNode?.name ?? "")
    readonly property string displayedName: AudioService.displayName(deviceNode)

    Row {
        id: deviceRowContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        DankIcon {
            name: root.deviceType === "input" ? "mic" : "speaker"
            size: Theme.iconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.iconSize - Theme.spacingM * 3 - buttonsRow.width
            spacing: 2

            StyledText {
                text: root.displayedName
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: root.deviceNode?.name ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width - (customAliasLabel.visible ? customAliasLabel.width + Theme.spacingS : 0)
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                    }

                    Rectangle {
                        id: customAliasLabel
                        visible: root.hasCustomAlias
                        height: customAliasText.implicitHeight + 4
                        width: customAliasText.implicitWidth + Theme.spacingS * 2
                        radius: 3
                        color: Theme.withAlpha(Theme.primary, 0.15)
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            id: customAliasText
                            text: I18n.tr("Custom")
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.primary
                            font.weight: Font.Medium
                            anchors.centerIn: parent
                        }
                    }
                }

                StyledText {
                    visible: root.hasCustomAlias
                    text: I18n.tr("Original: %1").arg(AudioService.originalName(root.deviceNode))
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                    width: parent.width
                    elide: Text.ElideRight
                    opacity: 0.6
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }

        Row {
            id: buttonsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankActionButton {
                id: resetButton
                visible: root.hasCustomAlias
                buttonSize: 36
                iconName: "restart_alt"
                iconSize: 20
                backgroundColor: Theme.surfaceContainerHigh
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.tr("Reset to default name")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    root.resetRequested(root.deviceNode);
                }
            }

            DankActionButton {
                id: hideButton
                visible: root.showHideButton
                buttonSize: 36
                iconName: root.isHidden ? "visibility" : "visibility_off"
                iconSize: 20
                backgroundColor: Theme.surfaceContainerHigh
                iconColor: root.isHidden ? Theme.primary : Theme.surfaceVariantText
                tooltipText: root.isHidden ? I18n.tr("Show device") : I18n.tr("Hide device")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    root.hideRequested(root.deviceNode);
                }
            }

            DankActionButton {
                id: editButton
                buttonSize: 36
                iconName: "edit"
                iconSize: 20
                backgroundColor: Theme.buttonBg
                iconColor: Theme.buttonText
                tooltipText: I18n.tr("Set custom name")
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isHidden
                onClicked: {
                    root.editRequested(root.deviceNode);
                }
            }
        }
    }

    MouseArea {
        id: deviceMouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        z: -1
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
