import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    // While this detail is shown, keep an mDNS browse running. Released on close.
    Component.onCompleted: ChromecastService.discoveryRefCount++
    Component.onDestruction: ChromecastService.discoveryRefCount--

    function formatTime(seconds) {
        if (!seconds || seconds < 0)
            return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return m + ":" + (sec < 10 ? "0" + sec : sec);
    }

    // Devices with the connected one pinned to the top (and injected if a scan
    // dropped it), so the active device shows once — at the top of the list —
    // instead of in a separate card above it.
    readonly property var sortedDevices: {
        // The core already returns devices in a stable order, so we only need to
        // pull the connected one to the top (injecting it if a scan dropped it).
        const devs = ChromecastService.devices ? ChromecastService.devices.slice() : [];
        const active = ChromecastService.connected ? ChromecastService.activeDevice : null;
        const activeId = active ? active.id : "";
        if (active && activeId) {
            const i = devs.findIndex(d => d.id === activeId);
            if (i >= 0)
                devs.splice(i, 1);
            devs.unshift(active);
        }
        return devs;
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        // Not-available state
        Item {
            width: parent.width
            height: 80
            visible: !ChromecastService.available

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "cast"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Casting not available", "Chromecast service unavailable message")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ---- Playback controls for the active Chromecast ----
        // AirPlay has no media controls (connecting just mirrors), so this card
        // is Chromecast-only; the connected device itself is shown at the top of
        // the device list below rather than duplicated here.
        Rectangle {
            width: parent.width
            visible: ChromecastService.available && ChromecastService.connected && ChromecastService.activeDevice && ChromecastService.activeDevice.protocol === "chromecast"
            implicitHeight: nowPlayingColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)

            Column {
                id: nowPlayingColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                // Progress bar (only when media with a known duration is playing)
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: !ChromecastService.screencasting && ChromecastService.playback && ChromecastService.playback.duration > 0

                    StyledText {
                        text: root.formatTime(ChromecastService.playback ? ChromecastService.playback.currentTime : 0)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    DankSlider {
                        id: seekSlider
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        minimum: 0
                        maximum: Math.max(1, Math.round(ChromecastService.playback ? ChromecastService.playback.duration : 1))
                        value: Math.round(ChromecastService.playback ? ChromecastService.playback.currentTime : 0)
                        unit: ""
                        showValue: false
                        onSliderDragFinished: finalValue => ChromecastService.seek(finalValue)
                    }

                    StyledText {
                        text: root.formatTime(ChromecastService.playback ? ChromecastService.playback.duration : 0)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // Transport controls
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: !ChromecastService.screencasting

                    DankActionButton {
                        iconName: ChromecastService.isPlaying ? "pause" : "play_arrow"
                        buttonSize: 32
                        iconSize: 20
                        iconColor: Theme.primary
                        tooltipText: ChromecastService.isPlaying ? I18n.tr("Pause") : I18n.tr("Play")
                        onClicked: {
                            if (ChromecastService.isPlaying)
                                ChromecastService.pause();
                            else
                                ChromecastService.play();
                        }
                    }

                    DankActionButton {
                        iconName: "stop"
                        buttonSize: 32
                        iconSize: 20
                        iconColor: Theme.surfaceVariantText
                        tooltipText: I18n.tr("Stop")
                        onClicked: ChromecastService.stop()
                    }

                    DankActionButton {
                        readonly property bool muted: ChromecastService.playback && ChromecastService.playback.muted
                        iconName: muted ? "volume_off" : "volume_up"
                        buttonSize: 32
                        iconSize: 20
                        iconColor: Theme.surfaceVariantText
                        tooltipText: muted ? I18n.tr("Unmute") : I18n.tr("Mute")
                        onClicked: ChromecastService.setMuted(!muted)
                    }

                    DankSlider {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        leftIcon: "volume_down"
                        minimum: 0
                        maximum: 100
                        value: Math.round((ChromecastService.playback ? ChromecastService.playback.volume : 0) * 100)
                        onSliderDragFinished: finalValue => ChromecastService.setVolume(finalValue / 100)
                    }
                }

                // Screen-mirror toggle — Chromecast only. For AirPlay, connecting
                // already mirrors the screen, so the Disconnect button stops it.
                DankToggle {
                    width: parent.width
                    text: I18n.tr("Mirror screen", "Chromecast screen mirroring toggle")
                    description: I18n.tr("Experimental — expect a few seconds of lag", "Chromecast screen mirroring latency warning")
                    checked: ChromecastService.screencasting
                    onToggled: value => {
                        if (value)
                            ChromecastService.castScreen();
                        else
                            ChromecastService.stopScreen();
                    }
                }
            }
        }

        // ---- Devices header ----
        RowLayout {
            width: parent.width
            visible: ChromecastService.available
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Devices", "Chromecast devices list header")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                Layout.fillWidth: true
            }

            DankIcon {
                name: "sync"
                size: 14
                color: Theme.surfaceVariantText
                visible: ChromecastService.discovering
                Layout.alignment: Qt.AlignVCenter

                RotationAnimation on rotation {
                    running: ChromecastService.discovering
                    from: 0
                    to: 360
                    duration: 1200
                    loops: Animation.Infinite
                }
            }
        }

        // ---- Device list ----
        DankFlickable {
            width: parent.width
            height: 160
            visible: ChromecastService.available
            contentHeight: deviceColumn.implicitHeight
            clip: true

            Column {
                id: deviceColumn
                width: parent.width
                spacing: Theme.spacingXS

                // Empty state
                Item {
                    width: parent.width
                    height: 60
                    visible: root.sortedDevices.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "tv"
                            size: 28
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: ChromecastService.discovering ? I18n.tr("Searching for devices…", "Chromecast discovery in progress") : I18n.tr("No devices found", "No Chromecast devices on the network")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Repeater {
                    model: root.sortedDevices

                    delegate: Rectangle {
                        id: deviceCard
                        required property var modelData

                        readonly property bool isActive: ChromecastService.connected && ChromecastService.activeDevice && ChromecastService.activeDevice.id === modelData.id

                        width: deviceColumn.width
                        height: deviceRow.implicitHeight + Theme.spacingS * 2
                        radius: Theme.cornerRadius
                        color: isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : (deviceArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerHighest)

                        RowLayout {
                            id: deviceRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                readonly property bool isAirplay: deviceCard.modelData.protocol === "airplay"
                                name: isAirplay ? (deviceCard.isActive ? "connected_tv" : "tv") : (deviceCard.isActive ? "cast_connected" : "cast")
                                size: 18
                                color: deviceCard.isActive ? Theme.primary : Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                StyledText {
                                    text: deviceCard.modelData.name || deviceCard.modelData.id
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    // Protocol label (+ model), so Chromecast vs AirPlay is clear.
                                    text: {
                                        const proto = deviceCard.modelData.protocol === "airplay" ? I18n.tr("AirPlay", "AirPlay protocol label") : I18n.tr("Chromecast", "Chromecast protocol label");
                                        const model = deviceCard.modelData.model || "";
                                        return model.length > 0 ? (proto + " · " + model) : proto;
                                    }
                                    font.pixelSize: 10
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            DankActionButton {
                                readonly property bool isPreferred: ChromecastService.preferredId === deviceCard.modelData.id
                                iconName: isPreferred ? "star" : "star_outline"
                                buttonSize: 28
                                iconSize: 16
                                iconColor: isPreferred ? Theme.primary : Theme.surfaceVariantText
                                tooltipText: isPreferred ? I18n.tr("Auto-connects — click to unset", "Chromecast preferred device hint") : I18n.tr("Auto-connect to this device", "Chromecast set preferred device")
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: ChromecastService.setPreferred(deviceCard.modelData.id)
                            }

                            DankActionButton {
                                iconName: deviceCard.isActive ? (ChromecastService.screencasting ? "stop_screen_share" : "cancel_presentation") : "cast"
                                buttonSize: 28
                                iconSize: 16
                                iconColor: deviceCard.isActive ? Theme.surfaceText : Theme.primary
                                tooltipText: deviceCard.isActive ? I18n.tr("Disconnect") : I18n.tr("Cast to this device")
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: {
                                    if (deviceCard.isActive)
                                        ChromecastService.disconnect();
                                    else
                                        ChromecastService.connect(deviceCard.modelData.id);
                                }
                            }
                        }

                        MouseArea {
                            id: deviceArea
                            z: -1
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!deviceCard.isActive)
                                    ChromecastService.connect(deviceCard.modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
