import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout
    readonly property var player: MprisController.activePlayer
    readonly property int currentVolume: player ? Math.min(100, Math.round(player.volume * 100)) : 0
    readonly property bool volumeSupported: player?.volumeSupported ?? false
    property bool _suppressNewPlayer: false

    onPlayerChanged: {
        _suppressNewPlayer = true;
        _suppressTimer.restart();
    }

    Timer {
        id: _suppressTimer
        interval: 2000
        onTriggered: _suppressNewPlayer = false
    }

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(260, Screen.width - Theme.spacingM * 2)
    osdHeight: useVertical ? Math.min(260, Screen.height - Theme.spacingM * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    function getVolumeIcon(volume) {
        if (!player)
            return "music_note";
        if (volume === 0)
            return "music_off";
        return "music_note";
    }

    function toggleMute() {
        if (player) {
            player.volume = player.volume > 0 ? 0 : 1;
        }
    }

    function setVolume(volumePercent) {
        if (player) {
            player.volume = volumePercent / 100;
            resetHideTimer();
        }
    }

    Connections {
        target: player

        function onVolumeChanged() {
            if (SettingsData.osdMediaVolumeEnabled && volumeSupported && !_suppressNewPlayer) {
                root.show();
            }
        }
    }

    content: Loader {
        anchors.fill: parent
        sourceComponent: useVertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            width: parent.width - Theme.spacingS * 2
            height: 40

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: getVolumeIcon(player?.volume ?? 0)
                    size: Theme.iconSize
                    color: muteButton.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: muteButton

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleMute()
                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || volumeSlider.containsMouse);
                    }
                }
            }

            DankSlider {
                id: volumeSlider

                width: parent.width - Theme.iconSize - parent.gap * 3
                height: 40
                x: parent.gap * 2 + Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                minimum: 0
                maximum: 100
                enabled: volumeSupported
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: currentVolume
                alwaysShowValue: SettingsData.osdAlwaysShowValue

                Component.onCompleted: {
                    value = currentVolume;
                }

                onSliderValueChanged: newValue => {
                    setVolume(newValue);
                }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse || muteButton.containsMouse);
                }

                Connections {
                    target: player

                    function onVolumeChanged() {
                        if (volumeSlider && !volumeSlider.pressed) {
                            volumeSlider.value = currentVolume;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: verticalContent

        Item {
            anchors.fill: parent
            property int gap: Theme.spacingS

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap

                DankIcon {
                    anchors.centerIn: parent
                    name: getVolumeIcon(player?.volume ?? 0)
                    size: Theme.iconSize
                    color: muteButtonVert.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: muteButtonVert

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleMute()
                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || vertSliderArea.containsMouse);
                    }
                }
            }

            Item {
                id: vertSlider
                width: 12
                height: parent.height - Theme.iconSize - gap * 3 - 24
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap * 2 + Theme.iconSize

                property bool dragging: false
                property int value: currentVolume

                Rectangle {
                    id: vertTrack
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    color: Theme.outline
                    radius: Theme.cornerRadius
                }

                Rectangle {
                    id: vertFill
                    width: parent.width
                    height: (vertSlider.value / 100) * parent.height
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    radius: Theme.cornerRadius
                }

                Rectangle {
                    id: vertHandle
                    width: 24
                    height: 8
                    radius: Theme.cornerRadius
                    y: {
                        const ratio = vertSlider.value / 100;
                        const travel = parent.height - height;
                        return Math.max(0, Math.min(travel, travel * (1 - ratio)));
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    border.width: 3
                    border.color: Theme.surfaceContainer
                }

                MouseArea {
                    id: vertSliderArea
                    anchors.fill: parent
                    anchors.margins: -12
                    enabled: volumeSupported
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || muteButtonVert.containsMouse);
                    }

                    onPressed: mouse => {
                        vertSlider.dragging = true;
                        updateVolume(mouse);
                    }

                    onReleased: {
                        vertSlider.dragging = false;
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            updateVolume(mouse);
                        }
                    }

                    onClicked: mouse => {
                        updateVolume(mouse);
                    }

                    function updateVolume(mouse) {
                        const ratio = 1.0 - (mouse.y / height);
                        const volume = Math.max(0, Math.min(100, Math.round(ratio * 100)));
                        setVolume(volume);
                    }
                }

                Connections {
                    target: player

                    function onVolumeChanged() {
                        if (!vertSlider.dragging) {
                            vertSlider.value = currentVolume;
                        }
                    }
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: gap
                text: vertSlider.value + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                visible: SettingsData.osdAlwaysShowValue
            }
        }
    }

    onOsdShown: {
        if (player && contentLoader.item && contentLoader.item.item) {
            if (!useVertical) {
                const slider = contentLoader.item.item.children[0].children[1];
                if (slider && slider.value !== undefined) {
                    slider.value = currentVolume;
                }
            }
        }
    }
}
