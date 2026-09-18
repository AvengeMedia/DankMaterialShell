import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    TestCase {
        id: input
        when: false
        name: "audio-sound-players"
    }
    AudioSoundPlayers {
        id: players
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.check(String(players.loginSound.source).endsWith("/assets/sounds/freedesktop/desktop-login.wav"), "player source resolves the sound file: " + players.loginSound.source);
                root.check(String(players.criticalNotificationSound.source).endsWith("message-new-instant.wav"), "each player maps its own event");
                AudioService.notificationsVolume = 0.25;
                root.check(players.loginSound.audioOutput.volume === 0.25 && players.volumeChangeSound.audioOutput.volume === 0.25, "player volume follows the service");
                console.log("FIXTURE_PASS audio sound players bind source and volume to the service");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
