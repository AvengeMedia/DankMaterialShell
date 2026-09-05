pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: root
    readonly property var log: Log.scoped("Screensaver")

    property bool active: false
    property bool externalActive: false
    property string activeEffect: "drift"

    readonly property string contentType: SettingsData.screensaverType === "ascii" ? "ascii" : "text"
    readonly property string configuredText: SettingsData.screensaverText || "DankMaterialShell"

    function chooseEffect() {
        const configured = SettingsData.screensaverEffect;
        if (["drift", "bounce", "pulse", "reveal"].includes(configured))
            return configured;
        const effects = ["drift", "bounce", "pulse", "reveal"];
        const choices = effects.filter(effect => effect !== activeEffect);
        return choices[Math.floor(Math.random() * choices.length)];
    }

    function show(force) {
        if (!force && !SettingsData.screensaverEnabled)
            return false;
        if (!["text", "ascii"].includes(contentType)) {
            log.warn("unsupported screensaver content type:", contentType);
            return false;
        }
        if (IdleService.isShellLocked || IdleService.externalLockerActive)
            return false;

        if (SettingsData.screensaverEffect === "omarchy") {
            externalActive = true;
            active = true;
            Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/screensaver-ttfx.sh", "start", SessionData.resolveTerminal()]);
            return true;
        }

        activeEffect = chooseEffect();
        active = true;
        return true;
    }

    function hide() {
        if (externalActive)
            Quickshell.execDetached(["bash", Quickshell.shellDir + "/scripts/screensaver-ttfx.sh", "stop"]);
        externalActive = false;
        active = false;
    }

    Connections {
        target: IdleService

        function onScreensaverRequested() {
            root.show(false);
        }

        function onDismissScreensaver() {
            root.hide();
        }
    }

    Connections {
        target: SettingsData

        function onScreensaverEnabledChanged() {
            if (!SettingsData.screensaverEnabled)
                root.hide();
        }

        function onScreensaverEffectChanged() {
            if (root.active)
                root.hide();
        }
    }

    Timer {
        interval: 12000
        repeat: true
        running: root.active && SettingsData.screensaverEffect === "random"
        onTriggered: root.activeEffect = root.chooseEffect()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panel
            required property var modelData

            property bool inputEnabled: false
            property bool mouseInitialized: false
            property point lastMousePosition: Qt.point(-1, -1)
            property int visibleCharacters: 0
            property real offsetX: 0
            property real offsetY: 0
            property real contentScale: 1
            property real contentOpacity: 1

            readonly property string renderedText: root.activeEffect === "reveal" ? root.configuredText.substring(0, visibleCharacters) : root.configuredText

            function resetAnimationState() {
                offsetX = 0;
                offsetY = 0;
                contentScale = 1;
                contentOpacity = 1;
                visibleCharacters = root.activeEffect === "reveal" ? 0 : root.configuredText.length;
            }

            function prepareInput() {
                inputEnabled = false;
                mouseInitialized = false;
                lastMousePosition = Qt.point(-1, -1);
                inputEnableTimer.restart();
                Qt.callLater(inputScope.forceActiveFocus);
            }

            screen: modelData
            visible: root.active && !root.externalActive
            color: "black"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "dms:screensaver"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (!visible)
                    return;
                resetAnimationState();
                prepareInput();
            }

            Connections {
                target: root

                function onActiveEffectChanged() {
                    panel.resetAnimationState();
                }
            }

            Timer {
                id: inputEnableTimer
                interval: 500
                repeat: false
                onTriggered: panel.inputEnabled = true
            }

            Timer {
                interval: 45
                repeat: true
                running: root.active && root.activeEffect === "reveal" && panel.visibleCharacters < root.configuredText.length
                onTriggered: panel.visibleCharacters += Math.max(1, Math.ceil(root.configuredText.length / 50))
            }

            Item {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.82, 1100)
                height: Math.min(parent.height * 0.62, 700)
                opacity: panel.contentOpacity
                scale: panel.contentScale
                layer.enabled: root.active
                transform: Translate {
                    x: panel.offsetX
                    y: panel.offsetY
                }

                Text {
                    anchors.fill: parent
                    text: panel.renderedText
                    color: Theme.primary
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: root.contentType === "ascii" ? Text.NoWrap : Text.Wrap
                    font.family: root.contentType === "ascii" ? Theme.monoFontFamily : Theme.fontFamily
                    font.pixelSize: root.contentType === "ascii" ? 42 : 112
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                }
            }

            SequentialAnimation {
                running: root.active && root.activeEffect === "drift"
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "offsetX"; from: -40; to: 40; duration: 7000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: panel; property: "offsetY"; from: 24; to: -24; duration: 7000; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "offsetX"; from: 40; to: -40; duration: 7000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: panel; property: "offsetY"; from: -24; to: 24; duration: 7000; easing.type: Easing.InOutSine }
                }
            }

            SequentialAnimation {
                running: root.active && root.activeEffect === "bounce"
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "offsetX"; from: -panel.width * 0.08; to: panel.width * 0.08; duration: 5200; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: panel; property: "offsetY"; from: -panel.height * 0.1; to: panel.height * 0.1; duration: 4100; easing.type: Easing.InOutQuad }
                }
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "offsetX"; from: panel.width * 0.08; to: -panel.width * 0.08; duration: 5200; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: panel; property: "offsetY"; from: panel.height * 0.1; to: -panel.height * 0.1; duration: 4100; easing.type: Easing.InOutQuad }
                }
            }

            SequentialAnimation {
                running: root.active && root.activeEffect === "pulse"
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "contentScale"; from: 0.94; to: 1.04; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: panel; property: "contentOpacity"; from: 0.62; to: 1; duration: 2200; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "contentScale"; from: 1.04; to: 0.94; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: panel; property: "contentOpacity"; from: 1; to: 0.62; duration: 2200; easing.type: Easing.InOutSine }
                }
            }

            SequentialAnimation {
                running: root.active && root.activeEffect === "reveal"
                loops: Animation.Infinite
                NumberAnimation { target: panel; property: "contentOpacity"; from: 0.25; to: 1; duration: 1400; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 3800 }
                NumberAnimation { target: panel; property: "contentOpacity"; from: 1; to: 0.25; duration: 800; easing.type: Easing.InCubic }
                ScriptAction { script: panel.visibleCharacters = 0 }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.active && panel.inputEnabled
                hoverEnabled: true
                cursorShape: Qt.BlankCursor

                onPressed: root.hide()
                onClicked: root.hide()
                onWheel: root.hide()
                onPositionChanged: mouse => {
                    if (!panel.mouseInitialized) {
                        panel.lastMousePosition = Qt.point(mouse.x, mouse.y);
                        panel.mouseInitialized = true;
                        return;
                    }
                    if (Math.abs(mouse.x - panel.lastMousePosition.x) <= 5 && Math.abs(mouse.y - panel.lastMousePosition.y) <= 5)
                        return;
                    root.hide();
                }
            }

            FocusScope {
                id: inputScope
                anchors.fill: parent
                focus: root.active

                Keys.onPressed: event => {
                    if (!root.active || !panel.inputEnabled)
                        return;
                    root.hide();
                    event.accepted = true;
                }
            }
        }
    }

    IpcHandler {
        target: "screensaver"

        function start(): string {
            return root.show(true) ? "Screensaver started" : "Screensaver could not start";
        }

        function stop(): string {
            root.hide();
            return "Screensaver stopped";
        }

        function status(): string {
            return root.active ? "active" : "inactive";
        }
    }
}
