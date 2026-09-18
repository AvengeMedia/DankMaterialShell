import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

DankCard {
    id: root

    property var plugin: ({})
    property bool busy: false
    property bool installed: false
    property bool selected: false
    property string fallbackIcon: "extension"
    property string previewSource: PluginService.previewUrl(plugin)
    property var badges: PluginService.badgeModel(plugin)
    property bool allowUninstall: false
    property var palette: null
    property real previewHeight: Math.round((width - Theme.spacingS * 2) * SettingsMetrics.choiceCardPreviewRatio)
    readonly property int infoHeight: Theme.iconButtonSize + Theme.fontSizeSmall * 4 + Theme.spacingS
    readonly property bool compatible: PluginService.checkPluginCompatibility(plugin.requires_dms)

    signal installRequested
    signal uninstallRequested

    implicitHeight: previewHeight + infoHeight + Theme.spacingS * 2 + Theme.spacingM
    radius: Theme.cornerRadiusM
    color: Theme.floatingWindowNestedSurface
    border.color: Theme.focusRingColor
    border.width: selected ? Theme.focusRingWidth : 0
    pad: 0
    clickable: true
    Accessible.name: plugin.name || ""

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
            radius: Theme.cornerRadiusS
            color: Theme.chipSurface

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
                size: Theme.avatarSize
                color: Theme.onSurfaceVariant
                visible: cardPreview.status !== Image.Ready
            }

            DankSpinner {
                anchors.centerIn: parent
                running: cardPreview.status === Image.Loading
                visible: running
            }
        }

        DankPaletteSwatch {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXS
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            visible: !!root.palette?.primary
            primaryColor: root.palette?.primary ?? Theme.primary
            secondaryColor: root.palette?.secondary ?? primaryColor
            tertiaryColor: root.palette?.tertiary ?? secondaryColor
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
                size: Theme.iconSizeMedium
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                width: parent.width - cardIcon.width - installAction.width - Theme.spacingS * 2
                text: root.plugin.name || ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            DankActionButton {
                id: installAction
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.busy && (root.installed ? root.allowUninstall : root.compatible)
                iconName: root.busy ? "hourglass_empty" : root.installed ? (root.allowUninstall ? "delete" : "check") : root.compatible ? "download" : "warning"
                iconColor: root.installed && root.allowUninstall ? Theme.error : Theme.primary
                tooltipText: root.installed ? (root.allowUninstall ? I18n.tr("Uninstall") : I18n.tr("Installed")) : root.compatible ? I18n.tr("Install") : I18n.tr("Requires %1", "version requirement").arg(root.plugin.requires_dms || "")
                onClicked: root.installed ? root.uninstallRequested() : root.installRequested()
            }
        }

        StyledText {
            width: parent.width
            text: I18n.tr("by %1", "author attribution").arg(root.plugin.author || I18n.tr("Unknown", "unknown author"))
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
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
