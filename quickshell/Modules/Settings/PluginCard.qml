import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var plugin: ({})
    property bool installed: false
    property bool selected: false
    property string fallbackIcon: "extension"
    property string previewSource: PluginService.previewUrl(plugin)
    property var badges: PluginService.badgeModel(plugin)
    property bool allowUninstall: false
    property real previewHeight: Math.round((width - Theme.spacingS * 2) * 0.52)
    readonly property int infoHeight: 100
    readonly property bool compatible: PluginService.checkPluginCompatibility(plugin.requires_dms)

    signal clicked
    signal installRequested
    signal uninstallRequested

    implicitHeight: previewHeight + infoHeight + Theme.spacingS * 2 + Theme.spacingM
    radius: Theme.cornerRadius
    color: cardMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.5) : Theme.withAlpha(Theme.surfaceVariant, 0.3)
    border.color: selected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
    border.width: selected ? 2 : 1
    scale: cardMouseArea.containsMouse ? 1.012 : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    MouseArea {
        id: cardMouseArea
        z: 0
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => cardRipple.trigger(mouse.x, mouse.y)
        onClicked: root.clicked()
    }

    DankRipple {
        id: cardRipple
        cornerRadius: root.radius
        rippleColor: Theme.surfaceVariantText
    }

    Item {
        id: previewArea
        z: 1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingS
        height: root.previewHeight

        ClippingRectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 2
            color: Theme.floatingWindowNestedSurface

            CachingImage {
                id: cardPreview
                anchors.fill: parent
                imagePath: root.previewSource
                maxCacheSize: 640
                fillMode: Image.PreserveAspectCrop
                animate: false
                visible: status === Image.Ready
            }

            DankIcon {
                anchors.centerIn: parent
                name: root.plugin.icon || root.fallbackIcon
                size: Theme.iconSize + 12
                color: Theme.withAlpha(Theme.outline, 0.6)
                visible: cardPreview.status !== Image.Ready
            }

            DankSpinner {
                anchors.centerIn: parent
                running: cardPreview.status === Image.Loading
                visible: running
            }
        }

        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.spacingXS
            spacing: Theme.spacingXXS

            Repeater {
                model: root.badges

                PluginBadge {
                    required property var modelData
                    label: modelData.label
                    iconName: modelData.icon
                    tone: PluginService.badgeTone(modelData.tone)
                    onImage: true
                }
            }
        }

        PluginBadge {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXS
            iconName: "thumb_up"
            label: root.plugin.upvotes || 0
            tone: Theme.primary
            onImage: true
            visible: !!root.plugin.issueUrl
        }
    }

    Column {
        z: 1
        anchors.top: previewArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Theme.spacingS
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingXXS

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankIcon {
                id: cardIcon
                name: root.plugin.icon || root.fallbackIcon
                size: Theme.iconSize - 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                width: parent.width - cardIcon.width - installAction.width - Theme.spacingS * 2
                text: root.plugin.name || ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                id: installAction

                property string buttonState: {
                    if (root.installed)
                        return "installed";
                    if (!root.compatible)
                        return "incompatible";
                    return "available";
                }

                width: 28
                height: 28
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    switch (buttonState) {
                    case "installed":
                        return root.allowUninstall && installMouseArea.containsMouse ? Theme.withAlpha(Theme.error, 0.15) : Theme.surfaceVariant;
                    case "incompatible":
                        return Theme.withAlpha(Theme.warning, 0.15);
                    default:
                        return Theme.primary;
                    }
                }
                opacity: buttonState === "available" && installMouseArea.containsMouse ? 0.85 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                DankIcon {
                    anchors.centerIn: parent
                    size: 15
                    name: {
                        switch (installAction.buttonState) {
                        case "installed":
                            return root.allowUninstall && installMouseArea.containsMouse ? "delete" : "check";
                        case "incompatible":
                            return "warning";
                        default:
                            return "download";
                        }
                    }
                    color: {
                        switch (installAction.buttonState) {
                        case "installed":
                            return root.allowUninstall && installMouseArea.containsMouse ? Theme.error : Theme.surfaceText;
                        case "incompatible":
                            return Theme.warning;
                        default:
                            return Theme.surface;
                        }
                    }
                }

                MouseArea {
                    id: installMouseArea

                    readonly property bool canUninstall: installAction.buttonState === "installed" && root.allowUninstall

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: installAction.buttonState === "available" || canUninstall
                    onClicked: canUninstall ? root.uninstallRequested() : root.installRequested()
                }
            }
        }

        StyledText {
            width: parent.width
            text: I18n.tr("by %1", "author attribution").arg(root.plugin.author || I18n.tr("Unknown", "unknown author"))
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.outline
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        StyledText {
            width: parent.width
            text: root.plugin.description || ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }
    }
}
