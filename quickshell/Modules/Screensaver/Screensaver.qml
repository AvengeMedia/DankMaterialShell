pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "ContentClassifier.js" as ContentClassifier

Scope {
    id: root

    property bool active: false
    property int cycleRevision: 0
    property int zoneIndex: 4
    property string currentEffect: ""
    property string previousEffect: ""

    readonly property string configuredContent: SettingsData.screensaverText || "DankMaterialShell"
    readonly property string contentMode: ContentClassifier.classify(configuredContent, SettingsData.screensaverType)
    readonly property string animationSpeed: SettingsData.screensaverSpeed
    readonly property bool showShapes: SettingsData.screensaverShowShapes
    readonly property bool reducedMotion: SettingsData.reduceMotion || Theme.springMotionDisabled
    readonly property int cycleInterval: animationSpeed === "calm" ? 11000 : animationSpeed === "lively" ? 6000 : 8200
    readonly property var textEffects: ["materialMorph", "expressiveTypography", "tonalSweep", "splitBloom", "orbitAssemble", "colorWave"]
    readonly property var asciiEffects: ["asciiReveal", "asciiAssemble", "asciiDrift", "asciiDecrypt", "asciiPour", "asciiScatter", "asciiWave"]

    function effectDeck() {
        return contentMode === "ascii" ? asciiEffects : textEffects;
    }

    function chooseNextEffect() {
        const deck = effectDeck();
        if (reducedMotion)
            return deck[0];
        const candidates = deck.filter(effect => effect !== currentEffect);
        return candidates[Math.floor(Math.random() * candidates.length)];
    }

    function advanceScene() {
        previousEffect = currentEffect;
        currentEffect = chooseNextEffect();
        let nextZone = zoneIndex;
        while (nextZone === zoneIndex)
            nextZone = Math.floor(Math.random() * 9);
        zoneIndex = nextZone;
        cycleRevision++;
    }

    function show() {
        if (IdleService.isShellLocked)
            return false;
        currentEffect = chooseNextEffect();
        cycleRevision++;
        active = true;
        return true;
    }

    function hide() {
        active = false;
    }

    Connections {
        target: IdleService

        function onScreensaverRequested() {
            root.show();
        }

        function onDismissScreensaver() {
            root.hide();
        }

        function onLockRequested() {
            root.hide();
        }
    }

    onContentModeChanged: {
        if (active)
            advanceScene();
    }

    Timer {
        interval: root.cycleInterval
        repeat: true
        running: root.active && !root.reducedMotion
        onTriggered: root.advanceScene()
    }

    Variants {
        model: Quickshell.screens

        delegate: ScreensaverSurface {
            required property var modelData
            screen: modelData
            controller: root
        }
    }

    IpcHandler {
        target: "screensaver"
        enabled: true

        function open(): string {
            return root.show() ? "Screensaver opened" : "Screensaver could not open";
        }

        function close(): string {
            root.hide();
            return "Screensaver closed";
        }

        function toggle(): string {
            if (root.active) {
                root.hide();
                return "Screensaver closed";
            }
            return open();
        }

        function start(): string {
            return open();
        }

        function stop(): string {
            return close();
        }

        function status(): string {
            return JSON.stringify({
                active: root.active,
                mode: root.contentMode,
                effect: root.currentEffect
            });
        }
    }
}
