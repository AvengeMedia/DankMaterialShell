pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    required property var mediaModel
    required property var controller

    readonly property bool dense: root.controller.compactDense
    readonly property real artworkSize: root.controller.compactIconSize
    readonly property real textGutter: Theme.spacingXS
    readonly property real cavaWidth: 20
    readonly property real minTextWidth: 48
    readonly property string timeText: systemClock.date.toLocaleTimeString(I18n.locale(), SettingsData.getEffectiveTimeFormat())
    readonly property bool clockVisible: SettingsData.dankIslandMediaClockVisible
    readonly property real naturalTextWidth: Math.max(root.minTextWidth, titleMetrics.width, root.dense ? 0 : artistMetrics.width) + root.textGutter * 2
    readonly property real measuredWidth: {
        let width = Theme.spacingS + root.artworkSize + Theme.spacingXS + root.cavaWidth + Theme.spacingXS + root.naturalTextWidth + Theme.spacingXS;
        if (root.clockVisible)
            width += clockText.implicitWidth + Theme.spacingXS * 2 + Theme.spacingS;
        return width;
    }

    function pushMeasuredWidth() {
        root.controller.setMediaContentWidth(root.measuredWidth);
    }

    onMeasuredWidthChanged: root.pushMeasuredWidth()
    Component.onCompleted: root.pushMeasuredWidth()

    TextMetrics {
        id: titleMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        text: root.mediaModel.title
    }

    TextMetrics {
        id: artistMetrics

        font.family: Theme.fontFamily
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
        id: infoRow

        anchors {
            left: artwork.right
            leftMargin: Theme.spacingXS
            right: root.clockVisible ? rightActivity.left : parent.right
            rightMargin: Theme.spacingXS
            verticalCenter: parent.verticalCenter
        }
        height: root.artworkSize
        spacing: Theme.spacingXS

        MediaCava {
            anchors.verticalCenter: parent.verticalCenter
            width: root.cavaWidth
            height: parent.height
            mediaModel: root.mediaModel
        }

        Column {
            id: textCol

            width: parent.width - root.cavaWidth - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Item {
                id: titleClip

                width: parent.width - root.textGutter * 2
                x: root.textGutter
                height: titleText.implicitHeight
                clip: true

                Text {
                    id: titleText

                    readonly property bool onScreen: Window.window?.visible ?? false
                    readonly property bool needsScrolling: implicitWidth > titleClip.width && SettingsData.scrollTitleEnabled
                    readonly property bool scrollActive: needsScrolling && titleClip.visible && root.visible && root.enabled && onScreen && root.mediaModel.playing
                    readonly property real maxScrollOffset: Math.max(0, implicitWidth - titleClip.width + root.textGutter)
                    property real scrollOffset: 0
                    property int scrollDirection: 1
                    property real scrollHoldMs: 1600

                    function resetScroll() {
                        scrollOffset = 0;
                        scrollDirection = 1;
                        scrollHoldMs = 1600;
                    }

                    function stepScroll(deltaMs) {
                        if (scrollHoldMs > 0) {
                            scrollHoldMs -= deltaMs;
                            return;
                        }
                        const next = scrollOffset + scrollDirection * deltaMs / 62.5;
                        if (next >= maxScrollOffset) {
                            scrollOffset = maxScrollOffset;
                            scrollDirection = -1;
                            scrollHoldMs = 1200;
                            return;
                        }
                        if (next <= 0) {
                            scrollOffset = 0;
                            scrollDirection = 1;
                            scrollHoldMs = 1600;
                            return;
                        }
                        scrollOffset = next;
                    }

                    onNeedsScrollingChanged: {
                        if (!needsScrolling)
                            resetScroll();
                    }
                    onTextChanged: resetScroll()

                    height: implicitHeight
                    width: needsScrolling ? implicitWidth : titleClip.width
                    x: needsScrolling ? -scrollOffset : 0
                    text: root.mediaModel.title
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    wrapMode: Text.NoWrap
                    elide: needsScrolling ? Text.ElideNone : Text.ElideRight

                    Timer {
                        interval: 60
                        repeat: true
                        running: titleText.scrollActive
                        onTriggered: {
                            if (cavaTickWatch.running)
                                return;
                            titleText.stepScroll(60);
                        }
                    }

                    Timer {
                        id: cavaTickWatch
                        interval: 150
                    }

                    Connections {
                        target: CavaService
                        enabled: titleText.scrollActive && SettingsData.audioVisualizerEnabled && CavaService.cavaAvailable
                        function onValuesChanged() {
                            cavaTickWatch.restart();
                            titleText.stepScroll(40);
                        }
                    }
                }
            }

            Text {
                x: root.textGutter
                width: parent.width - root.textGutter * 2
                visible: !root.dense
                text: root.mediaModel.artist
                color: Theme.surfaceTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
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
        width: root.clockVisible ? (clockText.implicitWidth + Theme.spacingXS * 2) : 0
        height: root.dense ? root.artworkSize : 36
        visible: root.clockVisible

        Rectangle {
            anchors.centerIn: parent
            width: clockText.implicitWidth + Theme.spacingXS * 2
            height: root.dense ? Math.max(22, root.artworkSize - Theme.spacingXS) : 32
            radius: height / 2
            color: clockArea.containsMouse ? Theme.surfaceTextHover : "transparent"

            Text {
                id: clockText

                anchors.centerIn: parent
                text: root.timeText
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }

            IslandSlotHoverArea {
                id: clockArea

                anchors.fill: parent
                controller: root.controller
                onClicked: root.controller.requestActivity("home", false, false)
            }
        }
    }
}
