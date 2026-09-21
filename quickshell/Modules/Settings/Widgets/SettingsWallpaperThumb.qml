import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string path: ""
    property string placeholderIcon: "image"
    property string emptyText: I18n.tr("Not set", "wallpaper not set label")
    property bool allowColor: true

    readonly property bool isColor: path.startsWith("#")
    readonly property bool isImage: path !== "" && !isColor
    readonly property string fileName: path !== "" ? path.split("/").pop() : emptyText

    signal browse
    signal pickColor
    signal clear

    height: width * SettingsMetrics.wallpaperThumbRatio
    radius: Theme.cornerRadiusM
    color: isColor ? path : Theme.chipSurface

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Loader {
            id: imageLoader
            anchors.fill: parent
            active: root.isImage

            sourceComponent: CachingImage {
                imagePath: root.path
                maxCacheSize: SettingsMetrics.wallpaperThumbCache
                animate: false
            }
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: root.placeholderIcon
        size: Theme.iconSizeLarge
        color: Theme.surfaceVariantText
        visible: !root.isColor && (!root.isImage || imageLoader.item?.status === Image.Error)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.browse()
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.withAlpha(Theme.scrimColor, Theme.scrimAlpha)
        opacity: hoverArea.containsMouse ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            NumberAnimation {
                duration: SettingsMetrics.fadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankActionButton {
                buttonSize: Theme.iconButtonSize
                iconName: "folder_open"
                iconSize: Theme.iconSizeMedium
                backgroundColor: Theme.chipSurface
                iconColor: Theme.surfaceText
                Accessible.name: I18n.tr("Browse")
                onClicked: root.browse()
            }

            DankActionButton {
                buttonSize: Theme.iconButtonSize
                iconName: "palette"
                iconSize: Theme.iconSizeMedium
                backgroundColor: Theme.chipSurface
                iconColor: Theme.surfaceText
                visible: root.allowColor
                tooltipText: I18n.tr("Custom")
                onClicked: root.pickColor()
            }

            DankActionButton {
                buttonSize: Theme.iconButtonSize
                iconName: "close"
                iconSize: Theme.iconSizeMedium
                backgroundColor: Theme.chipSurface
                iconColor: Theme.error
                visible: root.path !== ""
                Accessible.name: I18n.tr("Clear")
                onClicked: root.clear()
            }
        }
    }

    Rectangle {
        id: chip

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingS
        // sized from unelided metrics: the elided text's own implicitWidth shrinks with the chip and collapses it
        width: Math.min(chipMetrics.advanceWidth + Theme.spacingS * 2, parent.width - Theme.spacingS * 2)
        height: chipText.implicitHeight + Theme.spacingXS * 2
        radius: Theme.cornerRadiusS
        color: Theme.withAlpha(Theme.scrimColor, Theme.scrimAlpha)

        TextMetrics {
            id: chipMetrics
            font: chipText.font
            text: root.fileName
        }

        StyledText {
            id: chipText
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            text: chipMetrics.text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.contrastLight
            elide: Text.ElideMiddle
            maximumLineCount: 1
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
