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
    property bool compactMode: false
    readonly property int textWidth: {
        switch (SettingsData.mediaSize) {
        case 0:
            return 0;
        case 2:
            return 180;
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

    onWheel: function (wheelEvent) {
        if (!activePlayer) {
            wheelEvent.accepted = false;
            return;
        }

        wheelEvent.accepted = true;

        // If volume is not supported, return early to avoid error logs but accepting the scroll,
        // to keep the consistency of not scrolling workspaces when scrolling in the media widget.
        if (!activePlayer.volumeSupported) {
            return;
        }

        const delta = wheelEvent.angleDelta.y;
        const currentVolume = (activePlayer.volume * 100) || 0;

        let newVolume;
        if (delta > 0) {
            newVolume = Math.min(100, currentVolume + 5);
        } else {
            newVolume = Math.max(0, currentVolume - 5);
        }

        activePlayer.volume = newVolume / 100;
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

                AudioVisualization {
                    anchors.horizontalCenter: parent.horizontalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.popoutTarget && root.popoutTarget.setTriggerPosition) {
                                const globalPos = parent.mapToGlobal(0, 0)
                                const currentScreen = root.parentScreen || Screen
                                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, parent.width)
                                root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen)
                            }
                            root.clicked()
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
                        onClicked: (mouse) => {
                            if (!activePlayer) return
                            if (mouse.button === Qt.LeftButton) {
                                activePlayer.togglePlaying()
                            } else if (mouse.button === Qt.MiddleButton) {
                                activePlayer.previous()
                            } else if (mouse.button === Qt.RightButton) {
                                activePlayer.next()
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

                    AudioVisualization {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: textContainer
                        property string displayText: {
                            if (!activePlayer || !activePlayer.trackTitle) {
                                return "";
                            }

                            let identity = activePlayer.identity || "";
                            let isWebMedia = identity.toLowerCase().includes("firefox") || identity.toLowerCase().includes("chrome") || identity.toLowerCase().includes("chromium") || identity.toLowerCase().includes("edge") || identity.toLowerCase().includes("safari");
                            let title = "";
                            let subtitle = "";
                            if (isWebMedia && activePlayer.trackTitle) {
                                title = activePlayer.trackTitle;
                                subtitle = activePlayer.trackArtist || identity;
                            } else {
                                title = activePlayer.trackTitle || "Unknown Track";
                                subtitle = activePlayer.trackArtist || "";
                            }
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: textWidth
                        height: root.widgetThickness
                        visible: SettingsData.mediaSize > 0
                        clip: true
                        color: "transparent"

                        StyledText {
                            id: mediaText
                            property bool needsScrolling: implicitWidth > textContainer.width
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
                                    const globalPos = mapToGlobal(0, 0)
                                    const currentScreen = root.parentScreen || Screen
                                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, root.width)
                                    root.popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen)
                                }
                                root.clicked()
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
                        color: prevArea.containsMouse ? Theme.primaryHover : "transparent"
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
                        color: nextArea.containsMouse ? Theme.primaryHover : "transparent"
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
