pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var mediaModel
    required property var controller

    readonly property bool dense: root.controller.compactDense
    readonly property real artworkSize: root.controller.compactIconSize
    readonly property real textGutter: Theme.spacingXS
    readonly property real cavaWidth: 20
    readonly property real minTextWidth: 48
    readonly property real clockLeadPad: Theme.spacingXS / 2
    readonly property real clockTrailPad: Theme.spacingS
    readonly property real clockPillHeight: root.dense ? Math.max(22, root.artworkSize - Theme.spacingXS) : 32
    readonly property string timeText: systemClock.date.toLocaleTimeString(I18n.locale(), SettingsData.getEffectiveTimeFormat())
    readonly property bool clockVisible: SettingsData.dankIslandMediaClockVisible
    readonly property real naturalTextWidth: Math.max(root.minTextWidth, titleMetrics.width, root.dense ? 0 : artistMetrics.width) + root.textGutter * 2
    readonly property real measuredWidth: {
        let width = Theme.spacingS + root.artworkSize + Theme.spacingXS + root.cavaWidth + Theme.spacingXS + root.naturalTextWidth + Theme.spacingXS;
        if (root.clockVisible)
            width += clockText.width + Theme.spacingXS * 2 + Theme.spacingS;
        return width;
    }

    function pushMeasuredWidth() {
        root.controller.setMediaContentWidth(root.measuredWidth);
    }

    onMeasuredWidthChanged: root.pushMeasuredWidth()
    Component.onCompleted: root.pushMeasuredWidth()

    StyledTextMetrics {
        id: titleMetrics

        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        text: root.mediaModel.title
    }

    StyledTextMetrics {
        id: artistMetrics

        font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
        text: root.dense ? "" : root.mediaModel.artist
    }

    SystemClock {
        id: systemClock

        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    MediaArtwork {
        id: artwork

        anchors {
            left: parent.left
            leftMargin: Theme.spacingS
            verticalCenter: parent.verticalCenter
        }
        width: root.artworkSize
        height: width
        mediaModel: root.mediaModel
    }

    Row {
        anchors {
            left: artwork.right
            leftMargin: Theme.spacingXS
            right: root.clockVisible ? rightActivity.left : parent.right
            rightMargin: Theme.spacingXS
            verticalCenter: parent.verticalCenter
        }
        height: root.artworkSize
        spacing: Theme.spacingXS

        AudioVisualization {
            anchors.verticalCenter: parent.verticalCenter
            width: root.cavaWidth
            height: parent.height
            maxBarHeight: Math.max(3, height - 2)
            idleIconName: "graphic_eq"
        }

        Column {
            width: parent.width - root.cavaWidth - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            ScrollingText {
                x: root.textGutter
                width: parent.width - root.textGutter * 2
                text: root.mediaModel.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                active: root.enabled && root.mediaModel.playing
                holdStartMs: 1600
                holdEndMs: 1200
                pxPerMs: 1 / 62.5
                overscroll: root.textGutter
            }

            StyledText {
                x: root.textGutter
                width: parent.width - root.textGutter * 2
                visible: !root.dense
                text: root.mediaModel.artist
                color: Theme.surfaceTextSecondary
                font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: rightActivity

        anchors {
            right: parent.right
            rightMargin: Theme.spacingS
            verticalCenter: parent.verticalCenter
        }
        width: root.clockVisible ? (clockText.width + Theme.spacingXS * 2) : 0
        height: root.clockPillHeight
        visible: root.clockVisible

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: clockArea.containsMouse ? Theme.surfaceTextHover : "transparent"

            NumericText {
                id: clockText

                anchors.centerIn: parent
                isMonospace: false
                text: root.timeText
                reserveText: root.timeText.replace(/\d/g, "0")
                width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                horizontalAlignment: Text.AlignHCenter
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }

            IslandSlotHoverArea {
                id: clockArea

                anchors.verticalCenter: parent.verticalCenter
                x: -root.clockLeadPad
                width: parent.width + root.clockLeadPad + root.clockTrailPad
                height: root.height
                controller: root.controller
                onClicked: root.controller.requestActivity("home", false, false)
            }
        }
    }
}
