pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../Common/GSettings.js" as GSettings

Singleton {
    id: root
    readonly property var log: Log.scoped("AudioService")

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool soundsAvailable: MultimediaService.available
    property bool playersRequested: false
    property bool soundThemeSupported: false
    property bool soundThemeResolved: false
    property bool loginSoundPending: false
    property var availableSoundThemes: []
    property string currentSoundTheme: ""
    property var soundFilePaths: ({})

    readonly property var volumeChangeSound: soundsLoader.item?.volumeChangeSound ?? null
    readonly property var powerPlugSound: soundsLoader.item?.powerPlugSound ?? null
    readonly property var powerUnplugSound: soundsLoader.item?.powerUnplugSound ?? null
    readonly property var normalNotificationSound: soundsLoader.item?.normalNotificationSound ?? null
    readonly property var criticalNotificationSound: soundsLoader.item?.criticalNotificationSound ?? null
    readonly property var loginSound: soundsLoader.item?.loginSound ?? null
    readonly property var mediaDevices: soundsLoader.item?.mediaDevices ?? null
    property real notificationsVolume: 1.0
    property bool notificationsAudioMuted: false

    Loader {
        id: soundsLoader
        active: root.playersRequested && root.soundsAvailable
        source: "AudioSoundPlayers.qml"
        onLoaded: {
            item.volume = Qt.binding(() => root.notificationsVolume);
            item.volumeChangeSource = Qt.binding(() => root.getSoundPath("audio-volume-change"));
            item.powerPlugSource = Qt.binding(() => root.getSoundPath("power-plug"));
            item.powerUnplugSource = Qt.binding(() => root.getSoundPath("power-unplug"));
            item.normalNotificationSource = Qt.binding(() => root.getSoundPath("message"));
            item.criticalNotificationSource = Qt.binding(() => root.getSoundPath("message-new-instant"));
            item.loginSource = Qt.binding(() => root.getSoundPath("desktop-login"));
        }
    }

    property var deviceAliases: ({})
    property string wireplumberConfigPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/wireplumber/wireplumber.conf.d/51-dms-audio-aliases.conf"
    property bool wireplumberReloading: false

    property var sinkPorts: ({})

    readonly property int sinkMaxVolume: {
        const name = sink?.name ?? "";
        if (!name)
            return 100;
        return SessionData.deviceMaxVolumes[name] ?? 100;
    }

    readonly property int wheelVolumeStep: SettingsData.audioWheelScrollAmount

    signal micMuteChanged
    signal micVolumeChanged
    signal audioOutputCycled(string deviceName, string deviceIcon)
    signal deviceAliasChanged(string nodeName, string newAlias)
    signal wireplumberReloadStarted
    signal wireplumberReloadCompleted(bool success)

    function getMaxVolumePercent(node) {
        if (!node?.name)
            return 100;
        return SessionData.deviceMaxVolumes[node.name] ?? 100;
    }

    Connections {
        target: SessionData
        function onDeviceMaxVolumesChanged() {
            if (!root.sink?.audio)
                return;
            const maxVol = root.sinkMaxVolume;
            const currentPercent = Math.round(root.sink.audio.volume * 100);
            if (currentPercent > maxVol)
                root.sink.audio.volume = maxVol / 100;
        }
    }

    Process {
        id: loginSoundChecker
        onExited: exitCode => {
            if (exitCode === 0) {
                playLoginSound();
            }
        }
    }

    function getAvailableSinks() {
        const hidden = SessionData.hiddenOutputDeviceNames ?? [];
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink && (SettingsData.audioShowStreamDevices || !node.isStream) && !hidden.includes(node.name));
    }

    property list<PwNode> typedSinks: []
    property list<PwNode> typedSources: []

    function rebuildTypedNodeLists() {
        const newSinks = [];
        const newSources = [];
        for (const node of Pipewire.nodes.values) {
            if (!node?.audio || (node.isStream && !SettingsData.audioShowStreamDevices))
                continue;
            if (node.isSink)
                newSinks.push(node);
            else
                newSources.push(node);
        }
        typedSinks = newSinks;
        typedSources = newSources;
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            root.rebuildTypedNodeLists();
        }
    }

    Connections {
        target: SettingsData
        function onAudioShowStreamDevicesChanged() {
            root.rebuildTypedNodeLists();
        }
    }

    function setSink(node: PwNode): bool {
        if (!node)
            return false;
        Pipewire.preferredDefaultAudioSink = node;
        return true;
    }

    function setSource(node: PwNode): bool {
        if (!node)
            return false;
        Pipewire.preferredDefaultAudioSource = node;
        return true;
    }

    function setDefaultSinkByName(name) {
        if (!name)
            return false;
        for (const node of typedSinks) {
            if (node?.name === name)
                return setSink(node);
        }
        return false;
    }

    function setDefaultSourceByName(name) {
        if (!name)
            return false;
        for (const node of typedSources) {
            if (node?.name === name)
                return setSource(node);
        }
        return false;
    }

    function refreshSinkPorts(callback) {
        // ensure that parsed labels are in English
        Proc.runCommand("audio-list-sink-ports", ["env", "LC_ALL=C", "pactl", "list", "sinks"], (output, exitCode) => {
            if (exitCode === 0)
                root.sinkPorts = root.parseSinkPorts(output);
            if (callback)
                callback();
        }, 0);
    }

    function getSinkPorts(node) {
        return sinkPorts[node?.name] ?? null;
    }

    function sinkHasMultiplePorts(node) {
        return (sinkPorts[node?.name]?.ports?.length ?? 0) > 1;
    }

    function setSinkPort(sinkName, portName, callback) {
        Proc.runCommand("audio-set-sink-port", ["env", "LC_ALL=C", "pactl", "set-sink-port", sinkName, portName], (output, exitCode) => {
            const ok = exitCode === 0;
            if (callback)
                callback(ok, ok ? I18n.tr("Port switched", "audio sink port switched successful message") : (output || I18n.tr("Failed to switch port", "audio sink port switch failure message")));
            if (ok)
                Qt.callLater(() => root.refreshSinkPorts());
        }, 0);
    }

    function parseSinkPorts(text) {
        const result = {};
        const lines = (text || "").split("\n");
        let current = null;
        let inPorts = false;

        function commit() {
            if (current && current.name)
                result[current.name] = {
                    active: current.active,
                    ports: current.ports
                };
        }

        for (const rawLine of lines) {
            const line = rawLine.trim();

            if (/^Sink #\d+/.test(line)) {
                commit();
                current = {
                    name: null,
                    active: "",
                    ports: []
                };
                inPorts = false;
                continue;
            }

            if (!current)
                continue;

            if (line.startsWith("Name:")) {
                current.name = line.substring(5).trim();
                inPorts = false;
                continue;
            }

            if (line === "Ports:") {
                inPorts = true;
                continue;
            }

            if (line.startsWith("Active Port:")) {
                current.active = line.substring(12).trim();
                inPorts = false;
                continue;
            }

            if (inPorts) {
                // name up to first ": ", meta is the trailing "(...)", description is whatever's in between
                const match = line.match(/^(.+?):\s+(.*)\s+\(([^()]*)\)$/);
                if (!match)
                    continue;
                const meta = match[3];
                let availability = "unknown";
                if (meta.includes("not available"))
                    availability = "no";
                else if (/\bavailable\b/.test(meta))
                    availability = "yes";
                current.ports.push({
                    name: match[1],
                    description: match[2],
                    availability: availability,
                    priority: parseInt(meta.match(/priority:?\s*(\d+)/)?.[1] ?? "0", 10)
                });
            }
        }

        commit();
        return result;
    }

    function cycleAudioOutputDirection(forward) {
        const sinks = getAvailableSinks();
        if (sinks.length < 2)
            return null;

        const currentName = root.sink?.name ?? "";
        const currentIndex = sinks.findIndex(s => s.name === currentName);
        let nextIndex;
        if (forward) {
            nextIndex = (currentIndex + 1) % sinks.length;
        } else {
            nextIndex = (currentIndex - 1 + sinks.length) % sinks.length;
        }
        const nextSink = sinks[nextIndex];
        setDefaultSinkByName(nextSink.name);
        const name = displayName(nextSink);
        audioOutputCycled(name, sinkIcon(nextSink));
        return name;
    }

    function cycleAudioOutput() {
        return cycleAudioOutputDirection(true);
    }

    function getDeviceAlias(nodeName) {
        if (!nodeName)
            return null;
        return deviceAliases[nodeName] || null;
    }

    function hasDeviceAlias(nodeName) {
        if (!nodeName)
            return false;
        return deviceAliases.hasOwnProperty(nodeName) && deviceAliases[nodeName] !== null && deviceAliases[nodeName] !== "";
    }

    function setDeviceAlias(nodeName, customAlias) {
        if (!nodeName) {
            log.error("Cannot set alias - nodeName is empty");
            return false;
        }

        if (!customAlias || customAlias.trim() === "") {
            return removeDeviceAlias(nodeName);
        }

        const trimmedAlias = customAlias.trim();

        const updated = Object.assign({}, deviceAliases);
        updated[nodeName] = trimmedAlias;
        deviceAliases = updated;

        const btDevice = BluetoothService.deviceForNodeName(nodeName);
        if (btDevice)
            btDevice.name = trimmedAlias;

        writeWireplumberConfig();
        deviceAliasChanged(nodeName, trimmedAlias);
        return true;
    }

    function removeDeviceAlias(nodeName) {
        if (!nodeName)
            return false;

        if (!hasDeviceAlias(nodeName))
            return false;

        const updated = Object.assign({}, deviceAliases);
        delete updated[nodeName];
        deviceAliases = updated;

        // Empty BlueZ alias write resets to the device's real name.
        const btDevice = BluetoothService.deviceForNodeName(nodeName);
        if (btDevice)
            btDevice.name = "";

        writeWireplumberConfig();
        deviceAliasChanged(nodeName, "");
        return true;
    }

    function writeWireplumberConfig() {
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/wireplumber/wireplumber.conf.d";
        const configContent = generateWireplumberConfig();

        const shellCmd = `mkdir -p "${configDir}" && cat > "${wireplumberConfigPath}" << 'EOFCONFIG'
${configContent}
EOFCONFIG
`;

        Proc.runCommand("writeWireplumberConfig", ["sh", "-c", shellCmd], (output, exitCode) => {
            if (exitCode !== 0) {
                log.error("Failed to write WirePlumber config. Exit code:", exitCode);
                log.error("Error output:", output);
                ToastService.showError(I18n.tr("Failed to save audio config"), output || "");
                return;
            }

            reloadWireplumberConfig();
        }, 0);
    }

    function generateWireplumberConfig() {
        let config = "# Generated by DankMaterialShell - Audio Device Aliases\n";
        config += "# Do not edit manually - changes will be overwritten\n";
        config += "# Last updated: " + new Date().toISOString() + "\n\n";

        const aliasKeys = Object.keys(deviceAliases);
        if (aliasKeys.length === 0) {
            config += "# No device aliases configured\n";
            return config;
        }

        const alsaAliases = [];
        const bluezAliases = [];
        const otherAliases = [];

        for (const nodeName of aliasKeys) {
            const alias = deviceAliases[nodeName];
            if (!alias)
                continue;

            const rule = {
                nodeName: nodeName,
                alias: alias
            };

            if (nodeName.includes("alsa")) {
                alsaAliases.push(rule);
            } else if (nodeName.includes("bluez")) {
                bluezAliases.push(rule);
            } else {
                otherAliases.push(rule);
            }
        }

        if (alsaAliases.length > 0) {
            config += "monitor.alsa.rules = [\n";
            for (let i = 0; i < alsaAliases.length; i++) {
                const rule = alsaAliases[i];
                config += "  {\n";
                config += `    matches = [ { "node.name" = "${rule.nodeName}" } ]\n`;
                config += `    actions = { update-props = { "node.description" = "${rule.alias}" } }\n`;
                config += "  }";
                if (i < alsaAliases.length - 1)
                    config += ",";
                config += "\n";
            }
            config += "]\n\n";
        }

        if (bluezAliases.length > 0) {
            config += "monitor.bluez.rules = [\n";
            for (let i = 0; i < bluezAliases.length; i++) {
                const rule = bluezAliases[i];
                config += "  {\n";
                config += `    matches = [ { "node.name" = "${rule.nodeName}" } ]\n`;
                config += `    actions = { update-props = { "node.description" = "${rule.alias}" } }\n`;
                config += "  }";
                if (i < bluezAliases.length - 1)
                    config += ",";
                config += "\n";
            }
            config += "]\n\n";
        }

        if (otherAliases.length > 0) {
            config += "# Other device aliases (RAOP, USB, and other devices)\n";
            config += "wireplumber.rules = [\n";
            for (let i = 0; i < otherAliases.length; i++) {
                const rule = otherAliases[i];
                config += "  {\n";
                config += `    matches = [\n`;
                config += `      { "node.name" = "${rule.nodeName}" }\n`;
                config += `    ]\n`;
                config += `    actions = {\n`;
                config += `      update-props = {\n`;
                config += `        "node.description" = "${rule.alias}"\n`;
                config += `        "node.nick" = "${rule.alias}"\n`;
                config += `        "device.description" = "${rule.alias}"\n`;
                config += `      }\n`;
                config += `    }\n`;
                config += "  }";
                if (i < otherAliases.length - 1)
                    config += ",";
                config += "\n";
            }
            config += "]\n";
        }

        return config;
    }

    function reloadWireplumberConfig() {
        if (wireplumberReloading) {
            return;
        }

        wireplumberReloading = true;
        wireplumberReloadStarted();

        if (!SessionService.systemctlCommandAvailable) {
            Proc.runCommand("restartWireplumber", ["sh", "-c", "pkill -x wireplumber; sleep 1"], () => {
                Quickshell.execDetached(["wireplumber"]);
                wireplumberReloading = false;
                ToastService.showInfo(I18n.tr("Audio system restarted"), I18n.tr("Device names updated"));
                wireplumberReloadCompleted(true);
            }, 5000);
            return;
        }

        Proc.runCommand("restartWireplumber", ["systemctl", "--user", "restart", "wireplumber"], (output, exitCode) => {
            wireplumberReloading = false;

            if (exitCode === 0) {
                ToastService.showInfo(I18n.tr("Audio system restarted"), I18n.tr("Device names updated"));
                wireplumberReloadCompleted(true);
            } else {
                log.error("Failed to restart WirePlumber:", output);
                ToastService.showError(I18n.tr("Failed to restart audio system"), output);
                wireplumberReloadCompleted(false);
            }
        }, 5000);
    }

    function loadDeviceAliases() {
        const configPath = wireplumberConfigPath;

        Proc.runCommand("readWireplumberConfig", ["cat", configPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.debug("No existing WirePlumber config found");
                return;
            }

            const aliases = {};
            const lines = output.split('\n');
            let currentNodeName = null;

            for (const line of lines) {
                const nodeNameMatch = line.match(/"node\.name"\s*=\s*"([^"]+)"/);
                if (nodeNameMatch) {
                    currentNodeName = nodeNameMatch[1];
                }

                const descriptionMatch = line.match(/"node\.description"\s*=\s*"([^"]+)"/);
                if (descriptionMatch && currentNodeName) {
                    aliases[currentNodeName] = descriptionMatch[1];
                    currentNodeName = null;
                }
            }

            if (Object.keys(aliases).length > 0) {
                deviceAliases = aliases;
                log.debug("Loaded", Object.keys(aliases).length, "device aliases");
            }
        }, 0);
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            if (SessionData.suppressOSD)
                return;
            root.playVolumeChangeSoundIfEnabled();
        }
    }

    Connections {
        target: root.source?.audio ?? null

        function onMutedChanged() {
            root.micMuteChanged();
        }
    }

    function checkSoundThemeSupport() {
        Proc.runCommand("checkSoundThemeSupport", ["sh", "-c", GSettings.getCmd("org.gnome.desktop.sound", "theme-name")], (output, exitCode) => {
            soundThemeSupported = (output || "").trim().length > 0;
            if (!soundThemeSupported) {
                markSoundThemeResolved();
                return;
            }
            scanSoundThemes();
            getCurrentSoundTheme();
        }, 0);
    }

    function scanSoundThemes() {
        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS");
        const searchPaths = xdgDataDirs && xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat(Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))) : ["/usr/share", "/usr/local/share", Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))];

        const basePaths = searchPaths.map(p => p + "/sounds").join(" ");
        const script = `
            for base_dir in ${basePaths}; do
                [ -d "$base_dir" ] || continue
                for theme_dir in "$base_dir"/*; do
                    [ -d "$theme_dir/stereo" ] || continue
                    basename "$theme_dir"
                done
            done | sort -u
        `;

        Proc.runCommand("scanSoundThemes", ["sh", "-c", script], (output, exitCode) => {
            if (exitCode === 0 && output.trim()) {
                const themes = output.trim().split('\n').filter(t => t && t.length > 0);
                availableSoundThemes = themes;
            } else {
                availableSoundThemes = [];
            }
        }, 0);
    }

    function getCurrentSoundTheme() {
        Proc.runCommand("getCurrentSoundTheme", ["sh", "-c", GSettings.getCmd("org.gnome.desktop.sound", "theme-name")], (output, exitCode) => {
            currentSoundTheme = output.trim();
            log.debug("Current system sound theme:", currentSoundTheme || "none");
            if (currentSoundTheme && SettingsData.useSystemSoundTheme) {
                discoverSoundFiles(currentSoundTheme);
                return;
            }
            markSoundThemeResolved();
        }, 0);
    }

    function setSoundTheme(themeName) {
        if (!themeName || themeName === currentSoundTheme) {
            return;
        }

        Proc.runCommand("setSoundTheme", ["sh", "-c", GSettings.setCmd("org.gnome.desktop.sound", "theme-name", themeName)], (output, exitCode) => {
            if (exitCode === 0) {
                currentSoundTheme = themeName;
                if (SettingsData.useSystemSoundTheme) {
                    discoverSoundFiles(themeName);
                }
            }
        }, 0);
    }

    function discoverSoundFiles(themeName) {
        if (!themeName) {
            soundFilePaths = {};
            markSoundThemeResolved();
            return;
        }

        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS");
        const searchPaths = xdgDataDirs && xdgDataDirs.trim() !== "" ? xdgDataDirs.split(":").concat(Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))) : ["/usr/share", "/usr/local/share", Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))];

        const extensions = ["oga", "ogg", "wav", "mp3", "flac"];
        const themesToSearch = themeName !== "freedesktop" ? `${themeName} freedesktop` : themeName;

        const script = `
            for event_key in audio-volume-change power-plug power-unplug message message-new-instant desktop-login; do
                found=0

                case "$event_key" in
                    message)
                        names="dialog-information message message-lowpriority bell"
                        ;;
                    message-new-instant)
                        names="dialog-warning message-new-instant message-highlight"
                        ;;
                    *)
                        names="$event_key"
                        ;;
                esac

                for theme in ${themesToSearch}; do
                    for event_name in $names; do
                        for base_path in ${searchPaths.join(" ")}; do
                            theme_dir="$base_path/sounds/$theme"
                            [ -d "$theme_dir" ] || continue
                            file_path=$(find -L "$theme_dir" \\( ${extensions.map(e => `-name "$event_name.${e}"`).join(" -o ")} \\) -print 2>/dev/null | sort | head -1)
                            if [ -n "$file_path" ]; then
                                echo "$event_key=$file_path"
                                found=1
                                break
                            fi
                        done
                        [ $found -eq 1 ] && break
                    done
                    [ $found -eq 1 ] && break
                done
            done
        `;

        Proc.runCommand("discoverSoundFiles", ["sh", "-c", script], (output, exitCode) => {
            const paths = {};
            if (exitCode === 0 && output.trim()) {
                const lines = output.trim().split('\n');
                for (let line of lines) {
                    const parts = line.split('=');
                    if (parts.length === 2) {
                        paths[parts[0]] = "file://" + parts[1];
                    }
                }
            }
            soundFilePaths = paths;
            markSoundThemeResolved();
        }, 0);
    }

    function markSoundThemeResolved() {
        soundThemeResolved = true;
        if (!loginSoundPending)
            return;
        loginSoundPending = false;
        playLoginSound();
    }

    function getSoundPath(soundEvent) {
        const soundMap = {
            "audio-volume-change": "../assets/sounds/freedesktop/audio-volume-change.wav",
            "power-plug": "../assets/sounds/plasma/power-plug.wav",
            "power-unplug": "../assets/sounds/plasma/power-unplug.wav",
            "message": "../assets/sounds/freedesktop/message.wav",
            "message-new-instant": "../assets/sounds/freedesktop/message-new-instant.wav",
            "desktop-login": "../assets/sounds/freedesktop/desktop-login.wav"
        };

        const specialConditions = {
            "smooth": ["audio-volume-change"]
        };

        const themeLower = currentSoundTheme.toLowerCase();
        if (SettingsData.useSystemSoundTheme && specialConditions[themeLower]?.includes(soundEvent)) {
            const bundledPath = Qt.resolvedUrl(soundMap[soundEvent] || "../assets/sounds/freedesktop/message.wav");
            log.debug("Using bundled sound (special condition) for", soundEvent, ":", bundledPath);
            return bundledPath;
        }

        if (SettingsData.useSystemSoundTheme && soundFilePaths[soundEvent]) {
            log.debug("Using system sound for", soundEvent, ":", soundFilePaths[soundEvent]);
            return soundFilePaths[soundEvent];
        }

        const bundledPath = Qt.resolvedUrl(soundMap[soundEvent] || "../assets/sounds/freedesktop/message.wav");
        log.debug("Using bundled sound for", soundEvent, ":", bundledPath);
        return bundledPath;
    }

    function reloadSounds() {
        log.debug("Reloading sounds, useSystemSoundTheme:", SettingsData.useSystemSoundTheme, "currentSoundTheme:", currentSoundTheme);
        if (SettingsData.useSystemSoundTheme && currentSoundTheme) {
            discoverSoundFiles(currentSoundTheme);
            return;
        }
        soundFilePaths = {};
        markSoundThemeResolved();
    }

    function isMediaPlaying() {
        return MprisController.activePlayer?.isPlaying ?? false;
    }

    function shouldMuteForMedia() {
        return SettingsData.muteSoundsWhenMediaPlaying && isMediaPlaying();
    }

    function ensurePlayers() {
        if (!SettingsData.soundsEnabled)
            return;
        MultimediaService.ensureProbed();
        playersRequested = true;
    }

    function playVolumeChangeSound() {
        ensurePlayers();
        if (!soundsAvailable || !volumeChangeSound || notificationsAudioMuted || shouldMuteForMedia())
            return;
        volumeChangeSound.play();
    }

    function playPowerPlugSound() {
        ensurePlayers();
        if (!soundsAvailable || !powerPlugSound || notificationsAudioMuted || shouldMuteForMedia())
            return;
        powerPlugSound.play();
    }

    function playPowerUnplugSound() {
        ensurePlayers();
        if (!soundsAvailable || !powerUnplugSound || notificationsAudioMuted || shouldMuteForMedia())
            return;
        powerUnplugSound.play();
    }

    function playNormalNotificationSound() {
        ensurePlayers();
        if (!soundsAvailable || !normalNotificationSound || notificationsAudioMuted || shouldMuteForMedia())
            return;
        normalNotificationSound.play();
    }

    function playCriticalNotificationSound() {
        ensurePlayers();
        if (!soundsAvailable || !criticalNotificationSound || notificationsAudioMuted || shouldMuteForMedia())
            return;
        criticalNotificationSound.play();
    }

    function playLoginSound() {
        ensurePlayers();
        // playing before the theme paths land swaps the player source mid-playback, which stops it
        if (SettingsData.useSystemSoundTheme && !soundThemeResolved) {
            loginSoundPending = true;
            return;
        }
        if (!soundsAvailable || !loginSound || notificationsAudioMuted || shouldMuteForMedia()) {
            return;
        }
        loginSound.play();
    }

    function playLoginSoundIfApplicable() {
        if (SettingsData.soundsEnabled && SettingsData.soundLogin && !notificationsAudioMuted) {
            // plays login sound on session start, but only if a specific file doesn't exist,
            // to prevent it from playing on every DMS restart during the session
            const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
            const sessionId = Quickshell.env("XDG_SESSION_ID") || "0";

            if (!runtimeDir)
                return;

            const loginFile = `${runtimeDir}/danklinux.login-${sessionId}`;

            // if file doesn't exist, touch it (0)
            // If it exists, do nothing (1)
            loginSoundChecker.command = ["sh", "-c", `[ ! -f ${loginFile} ] && touch ${loginFile}`];
            loginSoundChecker.running = true;
        }
    }

    function playVolumeChangeSoundIfEnabled() {
        if (SettingsData.soundsEnabled && SettingsData.soundVolumeChanged && !notificationsAudioMuted) {
            playVolumeChangeSound();
        }
    }

    readonly property string sinkVolumeIconName: volumeIconName(sink)
    readonly property bool sinkSilent: isSilent(sink)

    function isSilent(node) {
        const audio = node?.audio;
        if (!audio)
            return false;
        return audio.muted || audio.volume === 0;
    }

    function volumeIconName(node, noDeviceIcon = "volume_off") {
        const audio = node?.audio;
        if (!audio)
            return noDeviceIcon;
        if (audio.muted)
            return "volume_off";
        if (audio.volume === 0)
            return "volume_mute";
        return audio.volume <= 0.33 ? "volume_down" : "volume_up";
    }

    function sinkIcon(node) {
        if (!node)
            return "speaker";

        const props = node.properties || {};
        const formFactor = (props["device.form-factor"] || "").toLowerCase();

        switch (formFactor) {
        case "headphone":
        case "headset":
        case "hands-free":
        case "handset":
            return "headset";
        case "tv":
        case "monitor":
            return "tv";
        case "speaker":
        case "computer":
        case "hifi":
        case "portable":
        case "car":
            return "speaker";
        }

        const bus = (props["device.bus"] || "").toLowerCase();
        if (bus === "bluetooth")
            return "headset";

        const name = (node.name || "").toLowerCase();
        if (name.includes("hdmi"))
            return "tv";
        if (name.includes("iec958") || name.includes("spdif"))
            return "speaker";

        if (bus === "usb")
            return "headset";

        return "speaker";
    }

    function displayName(node) {
        if (!node) {
            return "";
        }

        if (node.name && deviceAliases[node.name]) {
            return deviceAliases[node.name];
        }

        if (node.properties && node.properties["node.description"]) {
            const desc = node.properties["node.description"];
            if (desc !== node.name) {
                return desc;
            }
        }

        if (node.description && node.description !== node.name) {
            return node.description;
        }

        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"];
        }

        if (node.nickname && node.nickname !== node.name) {
            return node.nickname;
        }

        if (node.name.includes("analog-stereo")) {
            return "Built-in Audio Analog Stereo";
        }
        if (node.name.includes("bluez")) {
            return "Bluetooth Audio";
        }
        if (node.name.includes("usb")) {
            return "USB Audio";
        }
        if (node.name.includes("hdmi")) {
            return "HDMI Audio";
        }

        return node.name;
    }

    function originalName(node) {
        if (!node) {
            return "";
        }

        if (node.name.includes("analog-stereo")) {
            return "Built-in Audio Analog Stereo";
        }
        if (node.name.includes("bluez")) {
            return "Bluetooth Audio";
        }
        if (node.name.includes("usb")) {
            return "USB Audio";
        }
        if (node.name.includes("hdmi")) {
            return "HDMI Audio";
        }
        if (node.name.includes("raop_sink")) {
            const match = node.name.match(/raop_sink\.([^.]+)/);
            if (match) {
                return match[1].replace(/-/g, " ");
            }
        }

        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"];
        }

        if (node.nickname && node.nickname !== node.name) {
            return node.nickname;
        }

        return node.name;
    }

    function subtitle(name) {
        if (!name) {
            return "";
        }

        if (name.includes('usb-')) {
            if (name.includes('SteelSeries')) {
                return "USB Gaming Headset";
            }
            if (name.includes('Generic')) {
                return "USB Audio Device";
            }
            return "USB Audio";
        }

        if (name.includes('pci-')) {
            if (name.includes('01_00.1') || name.includes('01:00.1')) {
                return "NVIDIA GPU Audio";
            }
            return "PCI Audio";
        }

        if (name.includes('bluez')) {
            return "Bluetooth Audio";
        }
        if (name.includes('analog')) {
            return "Built-in Audio";
        }
        if (name.includes('hdmi')) {
            return "HDMI Audio";
        }

        return "";
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio && (SettingsData.audioShowStreamDevices || !node.isStream))
    }

    function setVolume(percentage) {
        if (!root.sink?.audio)
            return "No audio sink available";
        if (isNaN(percentage))
            return "Invalid percentage";

        const maxVol = root.sinkMaxVolume;
        const clampedVolume = Math.max(0, Math.min(maxVol, percentage));
        root.sink.audio.volume = clampedVolume / 100;
        return `Volume set to ${clampedVolume}%`;
    }

    function outputVolumeStep(step) {
        const parsed = parseInt(step || "5");
        return isNaN(parsed) ? 5 : Math.max(0, parsed);
    }

    function adjustDefaultSinkVolume(step, direction) {
        const audio = root.sink.audio;
        const maxVol = root.sinkMaxVolume;
        const stepValue = outputVolumeStep(step);
        const currentVolume = Math.round(audio.volume * 100);
        const newVolume = Math.max(0, Math.min(maxVol, currentVolume + direction * stepValue));

        if (audio.muted)
            audio.muted = false;

        audio.volume = newVolume / 100;
        return newVolume;
    }

    function toggleMute() {
        if (!root.sink?.audio) {
            return "No audio sink available";
        }

        root.sink.audio.muted = !root.sink.audio.muted;
        return root.sink.audio.muted ? "Audio muted" : "Audio unmuted";
    }

    function setMicVolume(percentage) {
        if (!root.source?.audio) {
            return "No audio source available";
        }

        const clampedVolume = Math.max(0, Math.min(100, percentage));
        root.source.audio.volume = clampedVolume / 100;
        micVolumeChanged();
        return `Microphone volume set to ${clampedVolume}%`;
    }

    function toggleMicMute() {
        if (!root.source?.audio) {
            return "No audio source available";
        }

        root.source.audio.muted = !root.source.audio.muted;
        return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted";
    }

    function incrementMicVolume(step) {
        if (!root.source?.audio)
            return "No audio source available";

        if (root.source.audio.muted)
            root.source.audio.muted = false;

        const currentVolume = Math.round(root.source.audio.volume * 100);
        const stepValue = parseInt(step || "5");
        const newVolume = Math.max(0, Math.min(100, currentVolume + stepValue));

        root.source.audio.volume = newVolume / 100;
        micVolumeChanged();
        return `Microphone volume increased to ${newVolume}%`;
    }

    function decrementMicVolume(step) {
        if (!root.source?.audio)
            return "No audio source available";

        if (root.source.audio.muted)
            root.source.audio.muted = false;

        const currentVolume = Math.round(root.source.audio.volume * 100);
        const stepValue = parseInt(step || "5");
        const newVolume = Math.max(0, Math.min(100, currentVolume - stepValue));

        root.source.audio.volume = newVolume / 100;
        micVolumeChanged();
        return `Microphone volume decreased to ${newVolume}%`;
    }

    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            return root.setVolume(parseInt(percentage));
        }

        function increment(step: string): string {
            if (!root.sink?.audio)
                return "No audio sink available";

            const newVolume = root.adjustDefaultSinkVolume(step, 1);
            return `Volume increased to ${newVolume}%`;
        }

        function decrement(step: string): string {
            if (!root.sink?.audio)
                return "No audio sink available";

            const newVolume = root.adjustDefaultSinkVolume(step, -1);
            return `Volume decreased to ${newVolume}%`;
        }

        function mute(): string {
            return root.toggleMute();
        }

        function setmic(percentage: string): string {
            return root.setMicVolume(parseInt(percentage));
        }

        function micmute(): string {
            return root.toggleMicMute();
        }

        function status(): string {
            let result = "Audio Status:\n";

            if (root.sink?.audio) {
                const volume = Math.round(root.sink.audio.volume * 100);
                const muteStatus = root.sink.audio.muted ? " (muted)" : "";
                const maxVol = root.sinkMaxVolume;
                result += `Output: ${volume}%${muteStatus} (max: ${maxVol}%)\n`;
            } else {
                result += "Output: No sink available\n";
            }

            if (root.source?.audio) {
                const micVolume = Math.round(root.source.audio.volume * 100);
                const muteStatus = root.source.audio.muted ? " (muted)" : "";
                result += `Input: ${micVolume}%${muteStatus}`;
            } else {
                result += "Input: No source available";
            }

            return result;
        }

        function getmaxvolume(): string {
            return `${root.sinkMaxVolume}`;
        }

        function setmaxvolume(percent: string): string {
            if (!root.sink?.name)
                return "No audio sink available";
            const val = parseInt(percent);
            if (isNaN(val))
                return "Invalid percentage";
            SessionData.setDeviceMaxVolume(root.sink.name, val);
            return `Max volume set to ${SessionData.getDeviceMaxVolume(root.sink.name)}%`;
        }

        function getmaxvolumefor(nodeName: string): string {
            if (!nodeName)
                return "No node name specified";
            return `${SessionData.getDeviceMaxVolume(nodeName)}`;
        }

        function setmaxvolumefor(nodeName: string, percent: string): string {
            if (!nodeName)
                return "No node name specified";
            const val = parseInt(percent);
            if (isNaN(val))
                return "Invalid percentage";
            SessionData.setDeviceMaxVolume(nodeName, val);
            return `Max volume for ${nodeName} set to ${SessionData.getDeviceMaxVolume(nodeName)}%`;
        }

        function cycleoutput(): string {
            const result = root.cycleAudioOutput();
            if (!result)
                return "Only one audio output available";
            return `Switched to: ${result}`;
        }
    }
    Connections {
        target: SettingsData
        function onUseSystemSoundThemeChanged() {
            reloadSounds();
        }
    }

    onSoundsAvailableChanged: {
        if (!soundsAvailable)
            return;
        checkSoundThemeSupport();
    }

    Component.onCompleted: {
        rebuildTypedNodeLists();
        loadDeviceAliases();
        if (SettingsData.soundsEnabled && SettingsData.useSystemSoundTheme)
            getCurrentSoundTheme();
    }
}
