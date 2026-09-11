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
    readonly property bool isVertical: root.controller.isVertical
    readonly property real artworkSize: root.controller.compactIconSize
    readonly property real textGutter: Theme.spacingXS
    readonly property real cavaWidth: 20
    readonly property real minTextWidth: 48
    readonly property real clockLeadPad: Theme.spacingXS / 2
    readonly property real clockTrailPad: Theme.spacingS
    readonly property real clockPillHeight: root.dense ? Math.max(22, root.artworkSize - Theme.spacingXS) : 32
    // A fully rounded side strip crowds square content, so the vertical face insets on both axes.
    readonly property real verticalPad: Theme.spacingS
    readonly property real verticalArtworkSize: Math.max(12, Math.min(root.artworkSize, root.width - root.verticalPad * 2))
    readonly property string timeText: systemClock.date.toLocaleTimeString(I18n.locale(), SettingsData.getEffectiveTimeFormat())
    readonly property string hourText: {
        const hours = systemClock.date.getHours();
        if (SettingsData.use24HourClock)
            return String(hours).padStart(2, "0");
        return String(hours === 0 ? 12 : (hours > 12 ? hours - 12 : hours)).padStart(2, "0");
    }
    readonly property string minuteText: String(systemClock.date.getMinutes()).padStart(2, "0")
    readonly property bool clockVisible: root.controller.mediaClockVisible
    readonly property real naturalTextWidth: Math.max(root.minTextWidth, titleMetrics.width, root.dense ? 0 : artistMetrics.width) + root.textGutter * 2
    readonly property real measuredWidth: {
        let width = Theme.spacingS + root.artworkSize + Theme.spacingXS + root.cavaWidth + Theme.spacingXS + root.naturalTextWidth + Theme.spacingXS;
        if (root.clockVisible)
            width += clockText.width + Theme.spacingXS * 2 + Theme.spacingS;
        return width;
    }

    function pushMeasuredLength() {
        root.controller.setMediaContentLength(root.isVertical ? verticalFace.implicitHeight + root.verticalPad * 2 : root.measuredWidth);
    }

    onMeasuredWidthChanged: root.pushMeasuredLength()
    onIsVerticalChanged: root.pushMeasuredLength()
    Component.onCompleted: root.pushMeasuredLength()

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
        visible: !root.isVertical
        width: root.artworkSize
        height: width
        artUrl: root.mediaModel.artUrl
    }

    Row {
        visible: !root.isVertical
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
        visible: root.clockVisible && !root.isVertical

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

    // A side strip has no room for track text, so the vertical face is artwork over the meter.
    Column {
        id: verticalFace

        anchors.centerIn: parent
        visible: root.isVertical
        spacing: Theme.spacingXS

        onImplicitHeightChanged: root.pushMeasuredLength()

        MediaArtwork {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.verticalArtworkSize
            height: width
            artUrl: root.mediaModel.artUrl
        }

        AudioVisualization {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.verticalArtworkSize
            height: root.cavaWidth
            maxBarHeight: Math.max(3, height - 2)
            idleIconName: "graphic_eq"
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.clockVisible
            width: verticalClock.width
            height: verticalClock.height

            // A side strip cannot fit "10:42 PM" on one line, so the hour sits over the minute.
            Column {
                id: verticalClock

                spacing: 0

                NumericText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    isMonospace: false
                    text: root.hourText
                    reserveText: "00"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }

                NumericText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    isMonospace: false
                    text: root.minuteText
                    reserveText: "00"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }
            }

            IslandSlotHoverArea {
                anchors.centerIn: parent
                width: root.width
                height: parent.height + Theme.spacingXS
                controller: root.controller
                onClicked: root.controller.requestActivity("home", false, false)
            }
        }
    }
}
