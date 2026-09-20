import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Modules.DankBar
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root
    property var surfaceContext: null
    readonly property real contentScale: surfaceContext?.kind === "dock" ? widgetThickness / 40 : 1

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool _hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(activePlayer)
    readonly property bool _isPlaying: !!activePlayer && activePlayer.playbackState === 1 && !_hoverPreview

    readonly property bool __isChromeBrowser: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    property bool compactMode: false
    property var widgetData: null
    readonly property bool adaptiveWidthEnabled: SettingsData.widgetOption("music", widgetData, "mediaAdaptiveWidthEnabled")
    readonly property int maxTextWidth: {
        const size = SettingsData.widgetOption("music", widgetData, "mediaSize");
        switch (size) {
        case 0:
            return 0;
        case 2:
            return 180 * root.contentScale;
        case 3:
            return 240 * root.contentScale;
        default:
            return 120 * root.contentScale;
        }
    }
    readonly property int currentContentWidth: {
        if (isVerticalOrientation) {
            return contentThickness;
        }
        return 0;
    }
    readonly property int currentContentHeight: {
        if (!isVerticalOrientation) {
            return contentThickness;
        }
        const audioVizHeight = BarMetrics.mediaControlSize * root.contentScale;
        const playButtonHeight = 24 * root.contentScale;
        return audioVizHeight + Theme.spacingXS + playButtonHeight;
    }

    property real scrollAccumulatorY: 0
    property real touchpadThreshold: 100

    onWheel: function (wheelEvent) {
        if (SettingsData.widgetOption("music", widgetData, "audioScrollMode") === "nothing")
            return;

        if (SettingsData.widgetOption("music", widgetData, "audioScrollMode") === "volume") {
            if (!usePlayerVolume)
                return;

            wheelEvent.accepted = true;

            const deltaY = wheelEvent.angleDelta.y;
            const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            const currentVolume = activePlayer.volume * 100;

            let newVolume = currentVolume;
            if (isMouseWheelY) {
                if (deltaY > 0) {
                    newVolume = Math.min(100, currentVolume + SettingsData.audioWheelScrollAmount);
                } else if (deltaY < 0) {
                    newVolume = Math.max(0, currentVolume - SettingsData.audioWheelScrollAmount);
                }
            } else {
                scrollAccumulatorY += deltaY;
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0) {
                        newVolume = Math.min(100, currentVolume + 1);
                    } else {
                        newVolume = Math.max(0, currentVolume - 1);
                    }
                    scrollAccumulatorY = 0;
                }
            }

            activePlayer.volume = newVolume / 100;
        } else if (SettingsData.widgetOption("music", widgetData, "audioScrollMode") === "song") {
            if (!activePlayer)
                return;

            wheelEvent.accepted = true;

            const deltaY = wheelEvent.angleDelta.y;
            const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            if (isMouseWheelY) {
                if (deltaY > 0) {
                    MprisController.previousOrRewind();
                } else {
                    MprisController.next();
                }
            } else {
                scrollAccumulatorY += deltaY;
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0) {
                        MprisController.previousOrRewind();
                    } else {
                        MprisController.next();
                    }
                    scrollAccumulatorY = 0;
                }
            }
        }
    }

    component PlayButton: Item {
        width: Theme.iconSize * root.contentScale
        height: width
        visible: root.playerAvailable

        DankIconButton {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            buttonSize: parent.width
            iconSize: 14 * root.contentScale
            radius: pressed ? Theme.cornerRadiusXS : (checked ? Theme.cornerRadiusFull : Theme.cornerRadiusS)
            variant: "filled"
            round: false
            checkable: true
            checked: root._isPlaying
            iconName: root._isPlaying ? "pause" : "play_arrow"
            Accessible.name: root._isPlaying ? I18n.tr("Pause") : I18n.tr("Play")
            enabled: root.activePlayer?.canTogglePlaying ?? false
            onClicked: root.activePlayer.togglePlaying()
        }
    }

    content: Component {
        Item {
            id: contentRoot
            readonly property real measuredTextWidth: {
                if (!root.playerAvailable || root.maxTextWidth <= 0)
                    return 0;
                // Preserve the fixed-width text slot even if metadata is briefly empty.
                if (!root.adaptiveWidthEnabled)
                    return root.maxTextWidth;
                if (textContainer.displayText.length === 0)
                    return 0;
                const rawWidth = mediaText.implicitTextWidth;
                if (!isFinite(rawWidth) || rawWidth <= 0)
                    return 0;
                return Math.min(root.maxTextWidth, Math.ceil(rawWidth));
            }
            readonly property int horizontalContentWidth: {
                const controlsWidth = 64 * root.contentScale + Theme.spacingXS * 2;
                const audioVizWidth = BarMetrics.mediaControlSize * root.contentScale;
                const baseWidth = audioVizWidth + Theme.spacingXS + controlsWidth;
                return baseWidth + (measuredTextWidth > 0 ? measuredTextWidth + Theme.spacingXS : 0);
            }

            implicitWidth: root.playerAvailable ? (root.isVerticalOrientation ? root.currentContentWidth : horizontalContentWidth) : 0
            implicitHeight: root.playerAvailable ? root.currentContentHeight : 0
            opacity: root.playerAvailable ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                }
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Column {
                id: verticalLayout
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Item {
                    width: BarMetrics.mediaControlSize * root.contentScale
                    height: BarMetrics.mediaControlSize * root.contentScale
                    anchors.horizontalCenter: parent.horizontalCenter

                    AudioVisualization {
                        enabled: root.surfaceLive
                        anchors.fill: parent
                        visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                    }

                    DankIcon {
                        anchors.fill: parent
                        name: "music_note"
                        size: BarMetrics.mediaControlSize * root.contentScale
                        color: Theme.primary
                        visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            root.triggerRipple(this, mouse.x, mouse.y);
                        }
                        onClicked: root.clicked()
                    }
                }

                PlayButton {
                    anchors.horizontalCenter: parent.horizontalCenter

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                MprisController.previousOrRewind();
                                return;
                            }
                            MprisController.next();
                        }
                    }
                }
            }

            Row {
                id: mediaRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Row {
                    id: mediaInfo
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: BarMetrics.mediaControlSize * root.contentScale
                        height: BarMetrics.mediaControlSize * root.contentScale
                        anchors.verticalCenter: parent.verticalCenter

                        AudioVisualization {
                            enabled: root.surfaceLive
                            anchors.fill: parent
                            visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                        }

                        DankIcon {
                            anchors.fill: parent
                            name: "music_note"
                            size: BarMetrics.mediaControlSize * root.contentScale
                            color: Theme.primary
                            visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                        }
                    }

                    Rectangle {
                        id: textContainer
                        readonly property string cachedIdentity: activePlayer ? (activePlayer.identity || "") : ""
                        readonly property string lowerIdentity: cachedIdentity.toLowerCase()
                        readonly property bool isWebMedia: lowerIdentity.includes("firefox") || lowerIdentity.includes("chrome") || lowerIdentity.includes("chromium") || lowerIdentity.includes("edge") || lowerIdentity.includes("safari")

                        property string displayText: {
                            if (!activePlayer || !MprisController.stableTitle)
                                return "";
                            const title = MprisController.stableTitle;
                            const subtitle = isWebMedia ? (MprisController.stableArtist || cachedIdentity) : MprisController.stableArtist;
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: contentRoot.measuredTextWidth
                        height: root.widgetThickness
                        visible: root.maxTextWidth > 0
                        clip: true
                        color: "transparent"

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                            }
                        }

                        ScrollingText {
                            id: mediaText
                            anchors.fill: parent
                            text: textContainer.displayText
                            color: root.contentColor
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            active: root.surfaceLive && root._isPlaying
                            animateTextChange: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => {
                                root.triggerRipple(this, mouse.x, mouse.y);
                                root.clicked();
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: BarMetrics.mediaControlSize * root.contentScale
                        height: BarMetrics.mediaControlSize * root.contentScale
                        radius: Theme.cornerRadiusFull
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        visible: root.playerAvailable
                        opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 12 * root.contentScale
                            color: root.contentColor
                        }

                        StateLayer {
                            id: prevArea
                            enabled: root.playerAvailable
                            stateColor: root.contentColor
                            onClicked: MprisController.previousOrRewind()
                        }
                    }

                    PlayButton {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: BarMetrics.mediaControlSize * root.contentScale
                        height: BarMetrics.mediaControlSize * root.contentScale
                        radius: Theme.cornerRadiusFull
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        visible: playerAvailable
                        opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 12 * root.contentScale
                            color: root.contentColor
                        }

                        StateLayer {
                            id: nextArea
                            enabled: root.playerAvailable
                            stateColor: root.contentColor
                            onClicked: {
                                if (activePlayer) {
                                    MprisController.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
