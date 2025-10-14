import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    property bool compactMode: false
    readonly property int textWidth: {
        switch (SettingsData.mediaSize) {
        case 0:
            return 0; // No text in small mode
        case 2:
            return 180; // Large text area
        default:
            return 120; // Medium text area
        }
    }
    readonly property int currentContentWidth: {
        if (isVertical) {
            return widgetThickness;
        }
        const controlsWidth = 20 + Theme.spacingXS + 24 + Theme.spacingXS + 20;
        const audioVizWidth = 20;
        const contentWidth = audioVizWidth + Theme.spacingXS + controlsWidth;
        return contentWidth + (textWidth > 0 ? textWidth + Theme.spacingXS : 0) + horizontalPadding * 2;
    }
    readonly property int currentContentHeight: {
        if (!isVertical) {
            return widgetThickness;
        }
        const audioVizHeight = 20;
        const playButtonHeight = 24;
        return audioVizHeight + Theme.spacingXS + playButtonHeight + horizontalPadding * 2;
    }
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barThickness: 48
    property real widgetThickness: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetThickness / 30))

    signal clicked()

    width: currentContentWidth
    height: currentContentHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    states: [
        State {
            name: "shown"
            when: playerAvailable

            PropertyChanges {
                target: root
                opacity: 1
                width: currentContentWidth
                height: currentContentHeight
            }

        },
        State {
            name: "hidden"
            when: !playerAvailable

            PropertyChanges {
                target: root
                opacity: 0
                width: isVertical ? widgetThickness : 0
                height: isVertical ? 0 : widgetThickness
            }

        }
    ]
    transitions: [
        Transition {
            from: "shown"
            to: "hidden"

            SequentialAnimation {
                PauseAnimation {
                    duration: 500
                }

                NumberAnimation {
                    properties: isVertical ? "opacity,height" : "opacity,width"
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }

            }

        },
        Transition {
            from: "hidden"
            to: "shown"

            NumberAnimation {
                properties: isVertical ? "opacity,height" : "opacity,width"
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }

        }
    ]

    Column {
        id: verticalLayout
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        AudioVisualization {
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.popupTarget && root.popupTarget.setTriggerPosition) {
                        const globalPos = parent.mapToGlobal(0, 0)
                        const currentScreen = root.parentScreen || Screen
                        const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, parent.width)
                        root.popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen)
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

        visible: !root.isVertical
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
                height: 20
                visible: SettingsData.mediaSize > 0
                clip: true
                color: "transparent"

                StyledText {
                    id: mediaText

                    property bool needsScrolling: implicitWidth > textContainer.width
                    property real scrollOffset: 0

                    anchors.verticalCenter: parent.verticalCenter
                    text: textContainer.displayText
                    font.pixelSize: Theme.barTextSize(barThickness)
                    color: Theme.surfaceText
                    font.weight: Font.Medium
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
                        if (root.popupTarget && root.popupTarget.setTriggerPosition) {
                            const globalPos = mapToGlobal(0, 0)
                            const currentScreen = root.parentScreen || Screen
                            const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, root.width)
                            root.popupTarget.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen)
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
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: prevArea

                    anchors.fill: parent
                    enabled: root.playerAvailable
                    hoverEnabled: true
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
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: nextArea

                    anchors.fill: parent
                    enabled: root.playerAvailable
                    hoverEnabled: true
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


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

}
