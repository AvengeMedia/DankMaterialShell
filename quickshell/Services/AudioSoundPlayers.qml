import QtQuick
import QtMultimedia

Item {
    id: root

    property real volume: 1.0
    property url volumeChangeSource
    property url powerPlugSource
    property url powerUnplugSource
    property url normalNotificationSource
    property url criticalNotificationSource
    property url loginSource

    readonly property alias mediaDevices: devices
    readonly property alias volumeChangeSound: volumeChangePlayer
    readonly property alias powerPlugSound: powerPlugPlayer
    readonly property alias powerUnplugSound: powerUnplugPlayer
    readonly property alias normalNotificationSound: normalNotificationPlayer
    readonly property alias criticalNotificationSound: criticalNotificationPlayer
    readonly property alias loginSound: loginPlayer

    MediaDevices {
        id: devices
    }

    MediaPlayer {
        id: volumeChangePlayer
        source: root.volumeChangeSource
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: root.volume
        }
    }

    MediaPlayer {
        id: powerPlugPlayer
        source: root.powerPlugSource
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: root.volume
        }
    }

    MediaPlayer {
        id: powerUnplugPlayer
        source: root.powerUnplugSource
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: root.volume
        }
    }

    MediaPlayer {
        id: normalNotificationPlayer
        source: root.normalNotificationSource
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: root.volume
        }
    }

    MediaPlayer {
        id: criticalNotificationPlayer
        source: root.criticalNotificationSource
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: root.volume
        }
    }

    MediaPlayer {
        id: loginPlayer
        source: root.loginSource
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: root.volume
        }
    }
}
