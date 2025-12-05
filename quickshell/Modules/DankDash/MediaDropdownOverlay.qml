import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property int dropdownType: 0
    property var activePlayer: null
    property var allPlayers: []
    property point anchorPos: Qt.point(0, 0)
    property bool isRightEdge: false

    property bool __isChromeBrowser: {
        if (!activePlayer?.identity)
            return false;
        const id = activePlayer.identity.toLowerCase();
        return id.includes("chrome") || id.includes("chromium");
    }
    property bool usePlayerVolume: activePlayer && activePlayer.volumeSupported && !__isChromeBrowser
    property real currentVolume: usePlayerVolume ? activePlayer.volume : (AudioService.sink?.audio?.volume ?? 0)
    property bool volumeAvailable: (activePlayer && activePlayer.volumeSupported && !__isChromeBrowser) || (AudioService.sink && AudioService.sink.audio)
    property var availableDevices: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)

    signal closeRequested
    signal deviceSelected(var device)
    signal playerSelected(var player)
    signal volumeChanged(real volume)
    signal panelEntered
    signal panelExited

    property int __volumeHoverCount: 0

    function volumeAreaEntered() {
        __volumeHoverCount++;
        panelEntered();
    }

    function volumeAreaExited() {
        __volumeHoverCount--;
        Qt.callLater(() => {
            if (__volumeHoverCount <= 0)
                panelExited();
        });
    }

    Rectangle {
        id: volumePanel
        visible: dropdownType === 1 && volumeAvailable
        width: 60
        height: 180
        x: isRightEdge ? anchorPos.x : anchorPos.x - width
        y: anchorPos.y - height / 2
        radius: Theme.cornerRadius * 2
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
        border.width: 1

        opacity: dropdownType === 1 ? 1 : 0
        scale: dropdownType === 1 ? 1 : 0.96
        transformOrigin: isRightEdge ? Item.Left : Item.Right

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1.0
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowOpacity: 0.7
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            hoverEnabled: true
            onEntered: volumeAreaEntered()
            onExited: volumeAreaExited()
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            Item {
                id: volumeSlider
                width: parent.width * 0.5
                height: parent.height - Theme.spacingXL * 2
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    radius: Theme.cornerRadius
                }

                Rectangle {
                    width: parent.width
                    height: volumeAvailable ? (Math.min(1.0, currentVolume) * parent.height) : 0
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    bottomLeftRadius: Theme.cornerRadius
                    bottomRightRadius: Theme.cornerRadius
                }

                Rectangle {
                    width: parent.width + 8
                    height: 8
                    radius: Theme.cornerRadius
                    y: {
                        const ratio = volumeAvailable ? Math.min(1.0, currentVolume) : 0;
                        const travel = parent.height - height;
                        return Math.max(0, Math.min(travel, travel * (1 - ratio)));
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primary
                    border.width: 3
                    border.color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 1.0)
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    enabled: volumeAvailable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    onEntered: volumeAreaEntered()
                    onExited: volumeAreaExited()
                    onPressed: mouse => updateVolume(mouse)
                    onPositionChanged: mouse => {
                        if (pressed)
                            updateVolume(mouse);
                    }
                    onClicked: mouse => updateVolume(mouse)

                    function updateVolume(mouse) {
                        if (!volumeAvailable)
                            return;
                        const ratio = 1.0 - (mouse.y / height);
                        const volume = Math.max(0, Math.min(1, ratio));
                        root.volumeChanged(volume);
                    }
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Theme.spacingL
                text: volumeAvailable ? Math.round(currentVolume * 100) + "%" : "0%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                font.weight: Font.Medium
            }
        }
    }

    Rectangle {
        id: audioDevicesPanel
        visible: dropdownType === 2
        width: 280
        height: Math.max(200, Math.min(280, availableDevices.length * 50 + 100))
        x: isRightEdge ? anchorPos.x : anchorPos.x - width
        y: anchorPos.y - height / 2
        radius: Theme.cornerRadius * 2
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
        border.width: 2

        opacity: dropdownType === 2 ? 1 : 0
        scale: dropdownType === 2 ? 1 : 0.96
        transformOrigin: isRightEdge ? Item.Left : Item.Right

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1.0
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowOpacity: 0.7
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM

            StyledText {
                text: I18n.tr("Audio Output Devices (") + availableDevices.length + ")"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: Theme.spacingM
            }

            DankFlickable {
                width: parent.width
                height: parent.height - 40
                contentHeight: deviceColumn.height
                clip: true

                Column {
                    id: deviceColumn
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: availableDevices
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: deviceMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: modelData === AudioService.sink ? 2 : 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM
                                width: parent.width - Theme.spacingM * 2

                                DankIcon {
                                    name: getAudioDeviceIcon(modelData)
                                    size: 20
                                    color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter

                                    function getAudioDeviceIcon(device) {
                                        if (!device?.name)
                                            return "speaker";
                                        const name = device.name.toLowerCase();
                                        if (name.includes("bluez") || name.includes("bluetooth"))
                                            return "headset";
                                        if (name.includes("hdmi"))
                                            return "tv";
                                        if (name.includes("usb"))
                                            return "headset";
                                        return "speaker";
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20 - Theme.spacingM * 2

                                    StyledText {
                                        text: AudioService.displayName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        width: parent.width
                                    }

                                    StyledText {
                                        text: modelData === AudioService.sink ? "Active" : "Available"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }

                            MouseArea {
                                id: deviceMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData) {
                                        Pipewire.preferredDefaultAudioSink = modelData;
                                        root.deviceSelected(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: playersPanel
        visible: dropdownType === 3
        width: 240
        height: Math.max(180, Math.min(240, (allPlayers?.length || 0) * 50 + 80))
        x: isRightEdge ? anchorPos.x : anchorPos.x - width
        y: anchorPos.y - height / 2
        radius: Theme.cornerRadius * 2
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.98)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
        border.width: 2

        opacity: dropdownType === 3 ? 1 : 0
        scale: dropdownType === 3 ? 1 : 0.96
        transformOrigin: isRightEdge ? Item.Left : Item.Right

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 8
            shadowBlur: 1.0
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowOpacity: 0.7
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM

            StyledText {
                text: I18n.tr("Media Players (") + (allPlayers?.length || 0) + ")"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: Theme.spacingM
            }

            DankFlickable {
                width: parent.width
                height: parent.height - 40
                contentHeight: playerColumn.height
                clip: true

                Column {
                    id: playerColumn
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: allPlayers || []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: playerMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            border.color: modelData === activePlayer ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: modelData === activePlayer ? 2 : 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM
                                width: parent.width - Theme.spacingM * 2

                                DankIcon {
                                    name: "music_note"
                                    size: 20
                                    color: modelData === activePlayer ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20 - Theme.spacingM * 2

                                    StyledText {
                                        text: {
                                            if (!modelData)
                                                return "Unknown Player";
                                            const identity = modelData.identity || "Unknown Player";
                                            const trackTitle = modelData.trackTitle || "";
                                            return trackTitle.length > 0 ? identity + " - " + trackTitle : identity;
                                        }
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: modelData === activePlayer ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        width: parent.width
                                    }

                                    StyledText {
                                        text: {
                                            if (!modelData)
                                                return "";
                                            const artist = modelData.trackArtist || "";
                                            const isActive = modelData === activePlayer;
                                            if (artist.length > 0)
                                                return artist + (isActive ? " (Active)" : "");
                                            return isActive ? "Active" : "Available";
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        width: parent.width
                                    }
                                }
                            }

                            MouseArea {
                                id: playerMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData?.identity) {
                                        root.playerSelected(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: dropdownType !== 0
        onClicked: closeRequested()
    }
}
