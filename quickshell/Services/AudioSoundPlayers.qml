import QtQuick
import QtMultimedia
import qs.Services

Item {
    id: root

    readonly property alias mediaDevices: devices
    readonly property alias volumeChangeSound: volumeChangePlayer
    readonly property alias powerPlugSound: powerPlugPlayer
    readonly property alias powerUnplugSound: powerUnplugPlayer
    readonly property alias normalNotificationSound: normalNotificationPlayer
    readonly property alias criticalNotificationSound: criticalNotificationPlayer
    readonly property alias loginSound: loginPlayer

    component SoundPlayer: MediaPlayer {
        required property string soundEvent
        source: AudioService.getSoundPath(soundEvent)
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: AudioService.notificationsVolume
        }
    }

    MediaDevices {
        id: devices
    }

    SoundPlayer {
        id: volumeChangePlayer
        soundEvent: "audio-volume-change"
    }

    SoundPlayer {
        id: powerPlugPlayer
        soundEvent: "power-plug"
    }

    SoundPlayer {
        id: powerUnplugPlayer
        soundEvent: "power-unplug"
    }

    SoundPlayer {
        id: normalNotificationPlayer
        soundEvent: "message"
    }

    SoundPlayer {
        id: criticalNotificationPlayer
        soundEvent: "message-new-instant"
    }

    SoundPlayer {
        id: loginPlayer
        soundEvent: "desktop-login"
    }
}
