import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services

Item {
    id: root

    required property string iconValue
    required property int iconSize
    property string fallbackText: "A"
    property color iconColor: Theme.surfaceText
    property color colorOverride: "transparent"
    property real brightnessOverride: 0.0
    property real contrastOverride: 0.0
    property real saturationOverride: 0.0
    property color fallbackBackgroundColor: Theme.surfaceLight
    property color fallbackTextColor: Theme.primary
    property real materialIconSizeAdjustment: Theme.spacingM
    property real unicodeIconScale: 0.7
    property real fallbackTextScale: 0.4
    property real iconMargins: 0
    property real fallbackLeftMargin: 0
    property real fallbackRightMargin: 0
    property real fallbackTopMargin: 0
    property real fallbackBottomMargin: 0

    readonly property bool isMaterial: iconValue && iconValue.startsWith("material:")
    readonly property bool isUnicode: iconValue && iconValue.startsWith("unicode:")
    readonly property bool isSvgCorner: iconValue && iconValue.startsWith("svg+corner:")
    readonly property bool isSvg: iconValue && !isSvgCorner && iconValue.startsWith("svg:")
    readonly property bool isImage: iconValue && iconValue.startsWith("image:")
    readonly property bool hasColorOverride: colorOverride.a > 0
    readonly property string materialName: isMaterial ? iconValue.substring(9) : ""
    readonly property string unicodeChar: isUnicode ? iconValue.substring(8) : ""
    readonly property string imagePath: isImage ? iconValue.substring(6) : ""
    readonly property string svgSource: {
        if (isSvgCorner) {
            const parts = iconValue.substring(11).split("|");
            return parts[0] || "";
        }
        if (isSvg)
            return iconValue.substring(4);
        return "";
    }
    readonly property string svgCornerIcon: isSvgCorner ? (iconValue.substring(11).split("|")[1] || "") : ""
    readonly property bool hasSpecialPrefix: isMaterial || isUnicode || isSvg || isSvgCorner || isImage
    readonly property string iconPath: {
        if (hasSpecialPrefix || !iconValue)
            return "";
        return Quickshell.iconPath(iconValue, true) || DesktopService.resolveIconPath(iconValue);
    }

    visible: iconValue !== undefined && iconValue !== ""

    DankIcon {
        anchors.centerIn: parent
        name: root.materialName
        size: root.iconSize - root.materialIconSizeAdjustment
        color: root.hasColorOverride ? root.colorOverride : root.iconColor
        visible: root.isMaterial
    }

    StyledText {
        anchors.centerIn: parent
        text: root.unicodeChar
        font.pixelSize: root.iconSize * root.unicodeIconScale
        color: root.hasColorOverride ? root.colorOverride : root.iconColor
        visible: root.isUnicode
    }

    DankSVGIcon {
        anchors.centerIn: parent
        source: root.svgSource
        size: root.iconSize
        cornerIcon: root.svgCornerIcon
        colorOverride: root.colorOverride
        brightnessOverride: root.brightnessOverride
        contrastOverride: root.contrastOverride
        saturationOverride: root.saturationOverride
        visible: root.isSvg || root.isSvgCorner
    }

    CachingImage {
        id: cachingImg
        anchors.fill: parent
        imagePath: root.imagePath
        maxCacheSize: root.iconSize * 2
        visible: root.isImage && status === Image.Ready
    }

    Loader {
        id: iconImgLoader
        anchors.fill: parent
        anchors.margins: root.iconMargins
        active: !root.hasSpecialPrefix && root.iconPath !== ""
        sourceComponent: IconImage {
            anchors.fill: parent
            source: root.iconPath
            backer.sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            mipmap: true
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    Rectangle {
        id: fallbackRect

        anchors.fill: parent
        anchors.leftMargin: root.fallbackLeftMargin
        anchors.rightMargin: root.fallbackRightMargin
        anchors.topMargin: root.fallbackTopMargin
        anchors.bottomMargin: root.fallbackBottomMargin
        visible: !root.hasSpecialPrefix && (root.iconPath === "" || !iconImgLoader.item || iconImgLoader.item.status !== Image.Ready)
        color: root.fallbackBackgroundColor
        radius: Theme.cornerRadius
        border.width: 0
        border.color: Theme.primarySelected

        StyledText {
            anchors.centerIn: parent
            text: root.fallbackText
            font.pixelSize: root.iconSize * root.fallbackTextScale
            color: root.fallbackTextColor
            font.weight: Font.Bold
        }
    }
}
