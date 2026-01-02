import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool __isChromeBrowser: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    readonly property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    property bool compactMode: false
    property var widgetData: null
    readonly property int textWidth: {
        const size = widgetData?.mediaSize !== undefined ? widgetData.mediaSize : SettingsData.mediaSize;
        switch (size) {
        case 0:
            return 0;
        case 2:
            return 180;
        case 3:
            return 240;
        default:
            return 120;
        }
    }
    readonly property int currentContentWidth: {
        if (isVerticalOrientation) {
            return widgetThickness - horizontalPadding * 2;
        }
        const controlsWidth = 20 + Theme.spacingXS + 24 + Theme.spacingXS + 20;
        const audioVizWidth = 20;
        const contentWidth = audioVizWidth + Theme.spacingXS + controlsWidth;
        return contentWidth + (textWidth > 0 ? textWidth + Theme.spacingXS : 0);
    }
    readonly property int currentContentHeight: {
        if (!isVerticalOrientation) {
            return widgetThickness - horizontalPadding * 2;
        }
        const audioVizHeight = 20;
        const playButtonHeight = 24;
        return audioVizHeight + Theme.spacingXS + playButtonHeight;
    }

    property real scrollAccumulatorY: 0
    property real touchpadThreshold: 100

    onWheel: function (wheelEvent) {
        if (SettingsData.audioScrollMode === "nothing")
            return;

        if (SettingsData.audioScrollMode === "volume") {
            if (!usePlayerVolume)
                return;

            wheelEvent.accepted = true;

            const deltaY = wheelEvent.angleDelta.y;
            const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            const currentVolume = activePlayer.volume * 100;

            let newVolume = currentVolume;
            if (isMouseWheelY) {
                if (deltaY > 0) {
                    newVolume = Math.min(100, currentVolume + 5);
                } else if (deltaY < 0) {
                    newVolume = Math.max(0, currentVolume - 5);
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
        } else if (SettingsData.audioScrollMode === "song") {
            if (!activePlayer)
                return;

            wheelEvent.accepted = true;

            const deltaY = wheelEvent.angleDelta.y;
            const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            if (isMouseWheelY) {
                if (deltaY > 0) {
                    activePlayer.previous();
                } else {
                    activePlayer.next();
                }
            } else {
                scrollAccumulatorY += deltaY;
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0) {
                        activePlayer.previous();
                    } else {
                        activePlayer.next();
                    }
                    scrollAccumulatorY = 0;
                }
            }
        }
    }

    content: Component {
        Item {
            implicitWidth: root.playerAvailable ? root.currentContentWidth : 0
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
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
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
                    width: 20
                    height: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    AudioVisualization {
                        anchors.fill: parent
                        visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                    }

                    DankIcon {
                        anchors.fill: parent
                        name: "music_note"
                        size: 20
                        color: Theme.primary
                        visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.popoutTarget && root.popoutTarget.setTriggerPosition) {
                                const globalPos = parent.mapToItem(null, 0, 0);
                                const currentScreen = root.parentScreen || Screen;
                                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, parent.width);
                                root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen);
                            }
                            root.clicked();
                        }
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: activePlayer && activePlayer.playbackState === 1 ? Theme.primary : Theme.primaryHover
                    visible: root.playerAvailable
                    opacity: activePlayer ? 1 : 0.3

                    DankIcon {
                        anchors.centerIn: parent
                        name: activePlayer && activePlayer.playbackState === 1 ? "pause" : "play_arrow"
                        size: 14
                        color: activePlayer && activePlayer.playbackState === 1 ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.playerAvailable
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            if (!activePlayer)
                                return;
                            if (mouse.button === Qt.LeftButton) {
                                activePlayer.togglePlaying();
                            } else if (mouse.button === Qt.MiddleButton) {
                                activePlayer.previous();
                            } else if (mouse.button === Qt.RightButton) {
                                activePlayer.next();
                            }
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

                    Item {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        AudioVisualization {
                            anchors.fill: parent
                            visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                        }

                        DankIcon {
                            anchors.fill: parent
                            name: "music_note"
                            size: 20
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
                            if (!activePlayer || !activePlayer.trackTitle) {
                                return "";
                            }

                            const title = isWebMedia ? activePlayer.trackTitle : (activePlayer.trackTitle || "Unknown Track");
                            const subtitle = isWebMedia ? (activePlayer.trackArtist || cachedIdentity) : (activePlayer.trackArtist || "");
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: textWidth
                        height: root.widgetThickness
                        visible: {
                            const size = widgetData?.mediaSize !== undefined ? widgetData.mediaSize : SettingsData.mediaSize;
                            return size > 0;
                        }
                        clip: true
                        color: "transparent"

                        StyledText {
                            id: mediaText
                            property bool needsScrolling: implicitWidth > textContainer.width && SettingsData.scrollTitleEnabled
                            property real scrollOffset: 0

                            anchors.verticalCenter: parent.verticalCenter
                            text: textContainer.displayText
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                            color: Theme.widgetTextColor
                            wrapMode: Text.NoWrap
                            x: needsScrolling ? -scrollOffset : 0
                            onTextChanged: {
                                scrollOffset = 0;
                                scrollAnimation.restart();
                            }

                            SequentialAnimation {
                                id: scrollAnimation
                                running: mediaText.needsScrolling && textContainer.visible
                                loops: Animation.Infinite

                                PauseAnimation {
                                    duration: 2000
                                }

                                NumberAnimation {
                                    target: mediaText
                                    property: "scrollOffset"
                                    from: 0
                                    to: mediaText.implicitWidth - textContainer.width + 5
                                    duration: Math.max(1000, (mediaText.implicitWidth - textContainer.width + 5) * 60)
                                    easing.type: Easing.Linear
                                }

                                PauseAnimation {
                                    duration: 2000
                                }

                                NumberAnimation {
                                    target: mediaText
                                    property: "scrollOffset"
                                    to: 0
                                    duration: Math.max(1000, (mediaText.implicitWidth - textContainer.width + 5) * 60)
                                    easing.type: Easing.Linear
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                if (root.popoutTarget && root.popoutTarget.setTriggerPosition) {
                                    const globalPos = mapToItem(null, 0, 0);
                                    const currentScreen = root.parentScreen || Screen;
                                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, root.width);
                                    root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen);
                                }
                                root.clicked();
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"
                        visible: root.playerAvailable
                        opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 12
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer) {
                                    activePlayer.previous();
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: activePlayer && activePlayer.playbackState === 1 ? Theme.primary : Theme.primaryHover
                        visible: root.playerAvailable
                        opacity: activePlayer ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: activePlayer && activePlayer.playbackState === 1 ? "pause" : "play_arrow"
                            size: 14
                            color: activePlayer && activePlayer.playbackState === 1 ? Theme.background : Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer) {
                                    activePlayer.togglePlaying();
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"
                        visible: playerAvailable
                        opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 12
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            enabled: root.playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (activePlayer) {
                                    activePlayer.next();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
