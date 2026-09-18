import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Column {
    id: root

    property string label: ""
    property string path: ""
    property string placeholderIcon: "image"
    property string emptyText: I18n.tr("Not set", "wallpaper not set label")
    property bool allowColor: true
    property bool canCycle: false

    readonly property bool isColor: path.startsWith("#")
    readonly property bool isImage: path !== "" && !isColor

    signal browse
    signal pickColor
    signal clear
    signal previous
    signal next

    spacing: Theme.spacingS

    StyledText {
        width: parent.width
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
        horizontalAlignment: Text.AlignHCenter
        visible: root.label !== ""
    }

    Rectangle {
        id: frame
        width: parent.width
        height: width * SettingsMetrics.wallpaperThumbRatio
        radius: Theme.cornerRadiusM
        color: root.isColor ? root.path : Theme.surfaceVariant

        ClippingRectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"

            Loader {
                id: imageLoader
                anchors.fill: parent
                active: root.visible && (root.Window.window?.visible ?? false) && root.isImage
                asynchronous: true

                sourceComponent: CachingImage {
                    imagePath: root.path
                    animate: false
                }
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: root.placeholderIcon
            size: Theme.iconSizeLarge
            color: Theme.surfaceVariantText
            visible: !root.isColor && imageLoader.item?.status !== Image.Ready
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.browse()
        }

        Rectangle {
            anchors.fill: parent
            radius: frame.radius
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
                    backgroundColor: Theme.surfaceContainerHigh
                    iconColor: Theme.surfaceText
                    Accessible.name: I18n.tr("Browse")
                    onClicked: root.browse()
                }

                DankActionButton {
                    buttonSize: Theme.iconButtonSize
                    iconName: "palette"
                    iconSize: Theme.iconSizeMedium
                    backgroundColor: Theme.surfaceContainerHigh
                    iconColor: Theme.surfaceText
                    visible: root.allowColor
                    tooltipText: I18n.tr("Custom")
                    onClicked: root.pickColor()
                }

                DankActionButton {
                    buttonSize: Theme.iconButtonSize
                    iconName: "close"
                    iconSize: Theme.iconSizeMedium
                    backgroundColor: Theme.surfaceContainerHigh
                    iconColor: Theme.error
                    visible: root.path !== ""
                    Accessible.name: I18n.tr("Clear")
                    onClicked: root.clear()
                }
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

    RowLayout {
        width: parent.width
        spacing: Theme.spacingS

        DankActionButton {
            buttonSize: Theme.iconButtonSize
            iconName: "skip_previous"
            iconSize: Theme.iconSize
            visible: root.canCycle
            Accessible.name: I18n.tr("Previous")
            onClicked: root.previous()
        }

        StyledText {
            Layout.fillWidth: true
            text: root.path !== "" ? root.path.split("/").pop() : root.emptyText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            elide: Text.ElideMiddle
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
        }

        DankActionButton {
            buttonSize: Theme.iconButtonSize
            iconName: "skip_next"
            iconSize: Theme.iconSize
            visible: root.canCycle
            Accessible.name: I18n.tr("Next")
            onClicked: root.next()
        }
    }
}
