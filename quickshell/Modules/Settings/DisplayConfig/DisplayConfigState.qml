pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("DisplayConfigState")

    readonly property bool hasOutputBackend: WlrOutputService.wlrOutputAvailable
    readonly property var wlrOutputs: WlrOutputService.outputs
    property var outputs: ({})
    property var savedOutputs: ({})
    property var allOutputs: buildAllOutputsMap()

    property var includeStatus: ({
            "exists": false,
            "included": false
        })
    property bool checkingInclude: false
    property bool fixingInclude: false

    property var pendingChanges: ({})
    property var pendingNiriChanges: ({})
    property var pendingHyprlandChanges: ({})
    property var originalNiriSettings: null
    property var originalHyprlandSettings: null
    property var originalOutputs: null
    property string originalDisplayNameMode: ""
    property bool formatChanged: originalDisplayNameMode !== "" && originalDisplayNameMode !== SettingsData.displayNameMode
    property bool hasPendingChanges: Object.keys(pendingChanges).length > 0 || Object.keys(pendingNiriChanges).length > 0 || Object.keys(pendingHyprlandChanges).length > 0 || formatChanged

    property bool validatingConfig: false
    property string validationError: ""

    property var currentOutputSet: []
    property string matchedProfile: ""
    property bool profilesLoading: false
    property var validatedProfiles: ({})
    property bool manualActivation: false
    property bool profilesReady: false
    property var monitorsCache: ({
            "version": 1,
            "configurations": []
        })
    property bool _monitorsSelfWrite: false
    // Last config entry that was applied (set by applyConfigEntry / confirmChanges).
    // Used to recover position, scale, and transform for disabled outputs that wlr
    // no longer reports a logical viewport for.
    property var lastAppliedEntry: null

    signal changesApplied(var changeDescriptions)
    signal changesConfirmed
    signal changesReverted
    signal profileActivated(string profileId, string profileName)
    signal profileSaved(string profileId, string profileName)
    signal profileDeleted(string profileId)
    signal profileError(string message)

    function buildCurrentOutputSet() {
        const connected = [];
        for (const name in outputs) {
            const output = outputs[name];
            connected.push(getOutputIdentifier(output, name));
        }
        return connected.sort();
    }

    function getOutputIdentifier(output, outputName) {
        if (SettingsData.displayNameMode === "model" && output?.make && output?.model) {
            if (CompositorService.isNiri) {
                const serial = output.serial || "Unknown";
                return output.make + " " + output.model + " " + serial;
            }
            return output.make + " " + output.model;
        }
        return outputName;
    }

    FileView {
        id: monitorsFile

        path: Paths.strip(Paths.config) + "/monitors.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onLoaded: root._reparseMonitorsJson(monitorsFile.text())
        onLoadFailed: root._reparseMonitorsJson("")
        onFileChanged: {
            if (root._monitorsSelfWrite) {
                root._monitorsSelfWrite = false;
                return;
            }
            monitorsFile.reload();
        }
        onSaveFailed: error => {
            root._monitorsSelfWrite = false;
            log.warn("Failed to save monitors.json:", error);
        }
    }

    function _reparseMonitorsJson(text) {
        if (!text || !text.trim()) {
            monitorsCache = {
                "version": 1,
                "configurations": []
            };
        } else {
            try {
                const parsed = JSON.parse(text);
                if (!Array.isArray(parsed.configurations))
                    parsed.configurations = [];
                monitorsCache = parsed;
            } catch (e) {
                log.warn("Failed to parse monitors.json, using empty config");
                monitorsCache = {
                    "version": 1,
                    "configurations": []
                };
            }
        }
        _initializeProfiles();
    }

    function _initializeProfiles() {
        if (!profilesReady && _shouldMigrateLegacyProfiles()) {
            _migrateLegacyProfiles();
            return;
        }
        validateProfiles();
    }

    function _shouldMigrateLegacyProfiles() {
        if ((monitorsCache.configurations || []).length > 0)
            return false;
        const legacy = SettingsData.displayProfiles || {};
        for (const c in legacy) {
            if (Object.keys(legacy[c] || {}).length > 0)
                return true;
        }
        return false;
    }

    function _migrateLegacyProfiles() {
        const legacy = SettingsData.displayProfiles || {};
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const compositorDirs = {
            "niri": configDir + "/niri/dms/profiles",
            "hyprland": configDir + "/hypr/dms/profiles",
            "dwl": configDir + "/mango/dms/profiles"
        };
        const compositorExts = {
            "niri": ".kdl",
            "hyprland": ".conf",
            "dwl": ".conf"
        };

        const tasks = [];
        for (const compositor in legacy) {
            const dir = compositorDirs[compositor];
            const ext = compositorExts[compositor];
            if (!dir || !ext)
                continue;
            for (const profileId in (legacy[compositor] || {})) {
                tasks.push({
                    compositor: compositor,
                    id: profileId,
                    name: legacy[compositor][profileId]?.name || "",
                    file: dir + "/" + profileId + ext
                });
            }
        }

        if (tasks.length === 0) {
            validateProfiles();
            return;
        }

        log.info("Migrating", tasks.length, "legacy display profiles to monitors.json");

        const migrated = [];
        let pending = tasks.length;
        const tryFinish = () => {
            pending--;
            if (pending > 0)
                return;
            const data = monitorsCache;
            data.configurations = (data.configurations || []).concat(migrated);
            writeMonitorsJson(data, success => {
                if (success) {
                    SettingsData.displayProfiles = {};
                    SettingsData.saveSettings();
                    log.info("Migrated", migrated.length, "of", tasks.length, "legacy profiles");
                } else {
                    log.warn("Failed to write migrated monitors.json");
                }
                validateProfiles();
            });
        };

        for (const task of tasks) {
            (function (t) {
                    Proc.runCommand("migrate-read-" + t.id, ["cat", t.file], (content, exitCode) => {
                        if (exitCode !== 0 || !content) {
                            log.warn("Skipping migration of profile", t.id, "- can't read", t.file);
                            tryFinish();
                            return;
                        }
                        let parsed;
                        switch (t.compositor) {
                        case "niri":
                            parsed = parseNiriOutputs(content);
                            break;
                        case "hyprland":
                            parsed = parseHyprlandOutputs(content);
                            break;
                        case "dwl":
                            parsed = parseMangoOutputs(content);
                            break;
                        default:
                            parsed = {};
                        }
                        const niriSettings = SettingsData.niriOutputSettings || {};
                        const hyprSettings = SettingsData.hyprlandOutputSettings || {};
                        const profileOutputs = {};
                        for (const outputName in parsed) {
                            const od = parsed[outputName];
                            profileOutputs[outputName] = extractOutputNeutralConfig(outputName, od, niriSettings, hyprSettings);
                        }
                        if (Object.keys(profileOutputs).length > 0)
                            migrated.push({
                                "id": t.id,
                                "name": t.name,
                                "outputs": profileOutputs
                            });
                        tryFinish();
                    });
                })(task);
        }
    }

    function readMonitorsJson(callback) {
        callback(monitorsCache);
    }

    function writeMonitorsJson(data, callback) {
        monitorsCache = data;
        _monitorsSelfWrite = true;
        monitorsFile.setText(JSON.stringify(data, null, 2));
        if (callback)
            callback(true);
    }

    function generateProfileId() {
        return "profile_" + Date.now() + "_" + Math.random().toString(36).slice(2, 9);
    }

    function generateAutoProfileId(outputIdentifiers) {
        const fp = outputSetFingerprint(outputIdentifiers);
        let hash = 0;
        for (let i = 0; i < fp.length; i++) {
            hash = ((hash << 5) - hash) + fp.charCodeAt(i);
        }
        const hashStr = (hash >>> 0).toString(16);
        return "auto_" + hashStr;
    }

    function configFingerprint(configEntry) {
        return Object.keys(configEntry.outputs || {}).sort().join("+");
    }

    function outputSetFingerprint(outputIdentifiers) {
        return [...outputIdentifiers].sort().join("+");
    }

    function findConfigEntryById(data, id) {
        const configs = data.configurations || [];
        for (let i = 0; i < configs.length; i++) {
            if (configs[i].id === id)
                return {
                    entry: configs[i],
                    index: i
                };
        }
        return null;
    }

    function findConfigEntryByFingerprint(data, outputIdentifiers, autoOnly) {
        const targetKey = outputSetFingerprint(outputIdentifiers);
        const configs = data.configurations || [];
        for (let i = 0; i < configs.length; i++) {
            if (configFingerprint(configs[i]) === targetKey) {
                if (autoOnly && configs[i].name)
                    continue;
                return {
                    entry: configs[i],
                    index: i
                };
            }
        }
        return null;
    }

    function getProfileMonitorInclusion(profileId) {
        const profile = validatedProfiles[profileId];
        const profileOutputIds = new Set(Object.keys(profile?.outputs || {}));
        const result = {};
        for (const rawName in allOutputs) {
            const od = allOutputs[rawName];
            const id = od ? getOutputIdentifier(od, rawName) : rawName;
            result[rawName] = profileOutputIds.has(id);
        }
        return result;
    }

    function updateProfileMonitors(profileId, enabledRawNames) {
        readMonitorsJson(data => {
            const match = findConfigEntryById(data, profileId);
            if (!match) {
                profileError(I18n.tr("Profile not found"));
                return;
            }
            const profileName = match.entry.name;
            const existingOutputs = match.entry.outputs || {};
            const mergedAll = buildOutputsWithPendingChanges();
            const niriSettings = buildMergedNiriSettings();
            const hyprlandSettings = buildMergedHyprlandSettings();
            const newOutputConfigs = {};
            for (const rawName of enabledRawNames) {
                const od = mergedAll[rawName] || allOutputs[rawName];
                if (!od)
                    continue;
                const outputId = getOutputIdentifier(od, rawName);
                newOutputConfigs[outputId] = existingOutputs[outputId] || extractOutputNeutralConfig(rawName, od, niriSettings, hyprlandSettings);
            }
            data.configurations[match.index] = {
                "id": profileId,
                "name": profileName,
                "outputs": newOutputConfigs
            };
            writeMonitorsJson(data, success => {
                if (!success)
                    return;
                const updated = JSON.parse(JSON.stringify(validatedProfiles));
                updated[profileId] = {
                    id: profileId,
                    name: profileName,
                    outputs: newOutputConfigs
                };
                validatedProfiles = updated;
                matchedProfile = findMatchingProfile();
                profileSaved(profileId, profileName);
            });
        });
    }

    // Extract neutral per-output config from current live state
    function extractOutputNeutralConfig(outputName, outputData, niriSettings, hyprlandSettings) {
        const modeData = (outputData.modes && outputData.current_mode !== undefined) ? outputData.modes[outputData.current_mode] : null;
        const modeStr = modeData ? modeData.width + "x" + modeData.height + "@" + (modeData.refresh_rate / 1000).toFixed(3) : null;
        const cfg = {
            "mode": modeStr,
            "position": {
                "x": outputData.logical?.x ?? 0,
                "y": outputData.logical?.y ?? 0
            },
            "scale": outputData.logical?.scale || 1.0,
            "transform": outputData.logical?.transform ?? "Normal",
            "vrr": outputData.vrr_enabled ?? false,
            "disabled": false
        };
        if (CompositorService.isNiri) {
            cfg.niri = Object.assign({}, niriSettings?.[getNiriOutputIdentifier(outputData, outputName)] || {});
            if (cfg.niri.disabled) {
                delete cfg.niri.disabled;
                cfg.disabled = true;
            }
        }
        if (CompositorService.isHyprland) {
            cfg.hyprland = Object.assign({}, hyprlandSettings?.[getHyprlandOutputIdentifier(outputData, outputName)] || {});
            if (outputData.mirror)
                cfg.hyprland.mirror = outputData.mirror;
            if (cfg.hyprland.disabled) {
                delete cfg.hyprland.disabled;
                cfg.disabled = true;
            }
        }
        return cfg;
    }

    // Convert monitors.json config entry → internal outputsData map
    function generateOutputsDataFromConfig(configEntry) {
        const result = {};
        const cfgOutputs = configEntry.outputs || {};
        for (const outputId in cfgOutputs) {
            const cfg = cfgOutputs[outputId];
            // Find matching live output to get modes list
            let liveOutput = null;
            for (const name in outputs) {
                if (getOutputIdentifier(outputs[name], name) === outputId || name === outputId) {
                    liveOutput = outputs[name];
                    break;
                }
            }
            const liveModes = liveOutput?.modes || [];
            let currentMode = liveModes.findIndex(m => {
                const s = m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3);
                return s === cfg.mode;
            });
            if (currentMode < 0 && liveModes.length > 0)
                currentMode = 0;
            const entry = {
                "name": outputId,
                "make": liveOutput?.make || "",
                "model": liveOutput?.model || "",
                "serial": liveOutput?.serial || "",
                "modes": liveModes,
                "current_mode": currentMode,
                "vrr_supported": liveOutput?.vrr_supported ?? false,
                "vrr_enabled": cfg.vrr ?? false,
                "logical": {
                    "x": cfg.position?.x ?? 0,
                    "y": cfg.position?.y ?? 0,
                    "scale": cfg.scale ?? 1.0,
                    "transform": cfg.transform ?? "Normal"
                }
            };
            if (cfg.hyprland?.mirror)
                entry.mirror = cfg.hyprland.mirror;
            result[outputId] = entry;
        }
        return result;
    }

    // Extract niri settings map from neutral config entry for generateNiriOutputsKdl
    function getNiriSettingsFromConfig(configEntry) {
        const result = {};
        for (const outputId in (configEntry.outputs || {})) {
            const cfg = configEntry.outputs[outputId];
            const settings = Object.assign({}, cfg.niri || {});
            if (cfg.disabled)
                settings.disabled = true;
            if (Object.keys(settings).length > 0)
                result[outputId] = settings;
        }
        return result;
    }

    // Extract hyprland settings map from neutral config entry
    function getHyprlandSettingsFromConfig(configEntry) {
        const result = {};
        for (const outputId in (configEntry.outputs || {})) {
            const cfg = configEntry.outputs[outputId];
            const settings = Object.assign({}, cfg.hyprland || {});
            if (cfg.disabled)
                settings.disabled = true;
            if (Object.keys(settings).length > 0)
                result[outputId] = settings;
        }
        return result;
    }

    function ensureEnabledOutput(configEntry) {
        const outputKeys = Object.keys(configEntry.outputs || {});
        if (outputKeys.length === 0)
            return false;
        const hasEnabled = outputKeys.some(k => !configEntry.outputs[k].disabled);
        if (hasEnabled)
            return false;
        delete configEntry.outputs[outputKeys[0]].disabled;
        return true;
    }

    // Write compositor config from a neutral config entry and optionally reload
    function applyConfigEntry(configEntry, configId, profileName, isManual) {
        ensureEnabledOutput(configEntry);
        // Capture the entry being applied so disabled-output settings fields can read
        // scale/position/transform back even when wlr reports no logical viewport.
        root.lastAppliedEntry = JSON.parse(JSON.stringify(configEntry));
        const outputsData = generateOutputsDataFromConfig(configEntry);

        const onWriteFailed = () => {
            if (isManual) {
                profilesLoading = false;
                manualActivation = false;
                profileError(I18n.tr("Failed to apply profile"));
            }
        };
        const onWriteSuccess = () => {
            SettingsData.setActiveDisplayProfile(CompositorService.compositor, configId);
            if (isManual) {
                profilesLoading = false;
                profileActivated(configId, profileName);
                manualActivationTimer.restart();
            }
            WlrOutputService.requestState();
        };

        switch (CompositorService.compositor) {
        case "niri":
            {
                const paths = getConfigPaths();
                if (!paths) {
                    onWriteFailed();
                    return;
                }
                const configContent = generateNiriOutputsKdl(outputsData, getNiriSettingsFromConfig(configEntry));
                Proc.runCommand("apply-config-write", ["sh", "-c", `mkdir -p "$(dirname "${paths.outputsFile}")" && cat > "${paths.outputsFile}" << 'EOF'\n${configContent}EOF`], (output, exitCode) => {
                    if (exitCode !== 0) {
                        onWriteFailed();
                        return;
                    }
                    onWriteSuccess();
                });
                break;
            }
        case "hyprland":
            HyprlandService.generateOutputsConfig(outputsData, getHyprlandSettingsFromConfig(configEntry), success => {
                if (success)
                    onWriteSuccess();
                else
                    onWriteFailed();
            });
            break;
        case "dwl":
            DwlService.generateOutputsConfig(outputsData, success => {
                if (success)
                    onWriteSuccess();
                else
                    onWriteFailed();
            });
            break;
        default:
            onWriteFailed();
        }
    }

    // ── Profile management ─────────────────────────────────────────────────

    function validateProfiles() {
        log.info("Validating profiles against current outputs...");
        readMonitorsJson(data => {
            const validated = {};
            let dirty = false;
            for (const entry of (data.configurations || [])) {
                const fp = configFingerprint(entry);
                if (!fp)
                    continue;
                if (!entry.id) {
                    entry.id = generateProfileId();
                    dirty = true;
                }
                if (ensureEnabledOutput(entry))
                    dirty = true;
                validated[entry.id] = {
                    id: entry.id,
                    name: entry?.name || "",
                    outputs: entry.outputs
                };
            }
            if (dirty)
                writeMonitorsJson(data, null);
            validatedProfiles = validated;
            matchedProfile = findMatchingProfile();
            if (!profilesReady) {
                profilesReady = true;
                applyAutoConfig();
            }
        });
    }

    function findMatchingProfile() {
        const currentKey = currentOutputSet.join("+");
        for (const id in validatedProfiles) {
            const p = validatedProfiles[id];
            if (p.name === "")
                continue;
            if (Object.keys(p.outputs || {}).sort().join("+") === currentKey)
                return id;
        }
        return "";
    }

    function createProfile(profileName) {
        const outputConfigs = buildCurrentOutputConfigs();
        const id = generateProfileId();

        profilesLoading = true;
        readMonitorsJson(data => {
            data.configurations.push({
                "id": id,
                "name": profileName,
                "outputs": outputConfigs
            });

            writeMonitorsJson(data, success => {
                profilesLoading = false;
                if (!success) {
                    profileError(I18n.tr("Failed to save profile"));
                    return;
                }
                const updated = JSON.parse(JSON.stringify(validatedProfiles));
                updated[id] = {
                    id: id,
                    name: profileName,
                    outputs: outputConfigs
                };
                validatedProfiles = updated;
                currentOutputSet = buildCurrentOutputSet();
                matchedProfile = findMatchingProfile();
                SettingsData.setActiveDisplayProfile(CompositorService.compositor, id);
                profileSaved(id, profileName);
            });
        });
    }

    function renameProfile(profileId, newName) {
        readMonitorsJson(data => {
            const match = findConfigEntryById(data, profileId);
            if (!match) {
                profileError(I18n.tr("Profile not found"));
                return;
            }
            match.entry.name = newName;
            data.configurations[match.index] = match.entry;
            writeMonitorsJson(data, success => {
                if (!success)
                    return;
                const updated = JSON.parse(JSON.stringify(validatedProfiles));
                if (updated[profileId])
                    updated[profileId].name = newName;
                validatedProfiles = updated;
            });
        });
    }

    function deleteProfile(profileId) {
        const compositor = CompositorService.compositor;
        const isActive = SettingsData.getActiveDisplayProfile(compositor) === profileId;

        profilesLoading = true;
        readMonitorsJson(data => {
            const match = findConfigEntryById(data, profileId);
            if (match)
                data.configurations.splice(match.index, 1);
            writeMonitorsJson(data, success => {
                profilesLoading = false;
                SettingsData.removeDisplayProfile(compositor, profileId);
                if (isActive) {
                    SettingsData.setActiveDisplayProfile(compositor, "");
                    backendWriteOutputsConfig(allOutputs);
                }
                const updated = JSON.parse(JSON.stringify(validatedProfiles));
                delete updated[profileId];
                validatedProfiles = updated;
                matchedProfile = findMatchingProfile();
                profileDeleted(profileId);
            });
        });
    }

    function activateProfile(profileId) {
        manualActivation = true;
        profilesLoading = true;
        readMonitorsJson(data => {
            const match = findConfigEntryById(data, profileId);
            if (!match) {
                profilesLoading = false;
                manualActivation = false;
                profileError(I18n.tr("Profile not found in monitors.json"));
                return;
            }
            applyConfigEntry(match.entry, profileId, match.entry.name || profileId, true);
        });
    }

    Timer {
        id: manualActivationTimer
        interval: 2000
        onTriggered: root.manualActivation = false
    }

    Timer {
        id: autoSelectDebounceTimer
        interval: 400
        onTriggered: {
            if (root.hasPendingChanges)
                return;
            root.applyAutoConfig();
        }
    }

    function applyAutoConfig() {
        if (!profilesReady || !SettingsData.displayProfileAutoSelect || manualActivation || !currentOutputSet.length)
            return;

        readMonitorsJson(data => {
            const match = findConfigEntryByFingerprint(data, currentOutputSet, true);
            if (match) {
                applyConfigEntry(match.entry, match.entry.id, "", false);
                return;
            }

            const outputConfigs = buildCurrentOutputConfigs();
            const id = generateAutoProfileId(currentOutputSet);
            const existingIdx = data.configurations.findIndex(c => c.id === id);
            if (existingIdx >= 0)
                data.configurations[existingIdx] = {
                    "id": id,
                    "name": "",
                    "outputs": outputConfigs
                };
            else
                data.configurations.push({
                    "id": id,
                    "name": "",
                    "outputs": outputConfigs
                });
            writeMonitorsJson(data, success => {
                if (!success)
                    return;
                const updated = JSON.parse(JSON.stringify(validatedProfiles));
                updated[id] = {
                    id: id,
                    name: "",
                    outputs: outputConfigs
                };
                validatedProfiles = updated;
                matchedProfile = "";
                const match = findConfigEntryById(data, id);
                if (match)
                    applyConfigEntry(match.entry, id, "", false);
            });
        });
    }

    function buildCurrentOutputConfigs() {
        const mergedAll = buildOutputsWithPendingChanges();
        const niriSettings = buildMergedNiriSettings();
        const hyprlandSettings = buildMergedHyprlandSettings();
        const outputConfigs = {};
        for (const name in outputs) {
            const od = mergedAll[name];
            if (od)
                outputConfigs[getOutputIdentifier(od, name)] = extractOutputNeutralConfig(name, od, niriSettings, hyprlandSettings);
        }
        return outputConfigs;
    }

    function deleteDisconnectedOutput(outputName) {
        if (outputs[outputName]?.connected)
            return;

        const updated = JSON.parse(JSON.stringify(savedOutputs));
        delete updated[outputName];
        savedOutputs = updated;

        const mergedOutputs = {};
        for (const name in outputs)
            mergedOutputs[name] = outputs[name];
        for (const name in updated)
            mergedOutputs[name] = updated[name];

        backendWriteOutputsConfig(mergedOutputs);
    }

    function buildAllOutputsMap() {
        const result = {};
        for (const name in savedOutputs) {
            result[name] = Object.assign({}, savedOutputs[name], {
                "connected": false
            });
        }
        for (const name in outputs) {
            const entry = JSON.parse(JSON.stringify(outputs[name]));
            entry.connected = true;
            // For disabled outputs wlr reports scale=0 (no logical viewport).
            // Overlay scale/position/transform from the last applied profile so
            // the settings UI can display meaningful values.
            if (!(entry.logical?.scale > 0)) {
                const profileCfg = getProfileOutputConfig(name);
                if (profileCfg) {
                    if (!entry.logical)
                        entry.logical = {};
                    entry.logical.scale = profileCfg.scale ?? 1.0;
                    entry.logical.x = profileCfg.position?.x ?? entry.logical.x ?? 0;
                    entry.logical.y = profileCfg.position?.y ?? entry.logical.y ?? 0;
                    if (profileCfg.transform)
                        entry.logical.transform = profileCfg.transform;
                } else if (entry.logical) {
                    entry.logical.scale = entry.logical.scale || 1.0;
                }
            }
            result[name] = entry;
        }
        return result;
    }

    function getProfileOutputConfig(outputName) {
        const sourceEntry = lastAppliedEntry || (matchedProfile ? validatedProfiles[matchedProfile] : null);
        if (!sourceEntry)
            return null;
        const cfgOutputs = sourceEntry.outputs || {};
        const outputId = getOutputIdentifier(outputs[outputName] || {}, outputName);
        return Object.entries(cfgOutputs).find(([key]) => key === outputId)?.[1] ?? null;
    }

    onOutputsChanged: {
        allOutputs = buildAllOutputsMap();
        const newOutputSet = buildCurrentOutputSet();
        if (JSON.stringify(newOutputSet) === JSON.stringify(currentOutputSet))
            return;
        // Physical output set changed — pending tweaks belong to the previous setup
        if (hasPendingChanges)
            clearPendingChanges();
        currentOutputSet = newOutputSet;
        autoSelectDebounceTimer.restart();
    }
    onSavedOutputsChanged: allOutputs = buildAllOutputsMap()
    onLastAppliedEntryChanged: allOutputs = buildAllOutputsMap()

    Connections {
        target: WlrOutputService
        function onStateChanged() {
            root.outputs = root.buildOutputsMap();
            root.reloadSavedOutputs();
        }
    }

    Connections {
        target: CompositorService
        function onCompositorChanged() {
            root.checkIncludeStatus();
        }
    }

    Component.onCompleted: {
        outputs = buildOutputsMap();
        reloadSavedOutputs();
    }

    function reloadSavedOutputs() {
        const paths = getConfigPaths();
        if (!paths) {
            savedOutputs = {};
            return;
        }

        Proc.runCommand("load-saved-outputs", ["cat", paths.outputsFile], (content, exitCode) => {
            if (exitCode !== 0 || !content.trim()) {
                savedOutputs = {};
                return;
            }
            const parsed = parseOutputsConfig(content);
            const filtered = filterDisconnectedOnly(parsed);
            savedOutputs = filtered;

            if (CompositorService.isHyprland) {
                initHyprlandSettingsFromConfig(parsed);
                syncHyprlandVrrFromConfig(parsed);
                syncHyprlandDisabledFromConfig(parsed);
            }
            if (CompositorService.isNiri) {
                syncNiriVrrFromConfig(parsed);
                syncNiriDisabledFromConfig(parsed);
            }
        });
    }

    function initHyprlandSettingsFromConfig(parsedOutputs) {
        const current = JSON.parse(JSON.stringify(SettingsData.hyprlandOutputSettings));
        let changed = false;

        for (const outputName in parsedOutputs) {
            const output = parsedOutputs[outputName];
            const settings = output.hyprlandSettings;
            if (!settings)
                continue;

            if (current[outputName])
                continue;

            const hasSettings = settings.colorManagement || settings.bitdepth || settings.sdrBrightness !== undefined || settings.sdrSaturation !== undefined;
            if (!hasSettings)
                continue;

            current[outputName] = {};
            if (settings.colorManagement)
                current[outputName].colorManagement = settings.colorManagement;
            if (settings.bitdepth)
                current[outputName].bitdepth = settings.bitdepth;
            if (settings.sdrBrightness !== undefined)
                current[outputName].sdrBrightness = settings.sdrBrightness;
            if (settings.sdrSaturation !== undefined)
                current[outputName].sdrSaturation = settings.sdrSaturation;
            changed = true;
        }

        if (changed) {
            SettingsData.hyprlandOutputSettings = current;
            SettingsData.saveSettings();
        }
    }

    function syncHyprlandVrrFromConfig(parsedOutputs) {
        const current = JSON.parse(JSON.stringify(SettingsData.hyprlandOutputSettings));
        let changed = false;
        for (const outputName in parsedOutputs) {
            const settings = parsedOutputs[outputName]?.hyprlandSettings;
            const fromConfig = settings?.vrrFullscreenOnly ?? false;
            const stored = current[outputName]?.vrrFullscreenOnly ?? false;
            if (fromConfig === stored)
                continue;
            if (!current[outputName])
                current[outputName] = {};
            if (fromConfig)
                current[outputName].vrrFullscreenOnly = true;
            else
                delete current[outputName].vrrFullscreenOnly;
            changed = true;
        }
        if (changed) {
            SettingsData.hyprlandOutputSettings = current;
            SettingsData.saveSettings();
        }
    }

    function syncNiriVrrFromConfig(parsedOutputs) {
        let changed = false;
        for (const outputName in parsedOutputs) {
            const output = parsedOutputs[outputName];
            const current = SettingsData.getNiriOutputSetting(outputName, "vrrOnDemand", false);
            const fromConfig = output.vrr_on_demand ?? false;
            if (current === fromConfig)
                continue;
            SettingsData.setNiriOutputSetting(outputName, "vrrOnDemand", fromConfig || undefined);
            changed = true;
        }
        if (changed)
            SettingsData.saveSettings();
    }

    function syncHyprlandDisabledFromConfig(parsedOutputs) {
        const current = JSON.parse(JSON.stringify(SettingsData.hyprlandOutputSettings));
        let changed = false;
        for (const outputName in parsedOutputs) {
            const settings = parsedOutputs[outputName]?.hyprlandSettings;
            const fromConfig = settings?.disabled ?? false;
            const stored = current[outputName]?.disabled ?? false;
            if (fromConfig === stored)
                continue;
            if (!current[outputName])
                current[outputName] = {};
            if (fromConfig)
                current[outputName].disabled = true;
            else
                delete current[outputName].disabled;
            changed = true;
        }
        if (changed) {
            SettingsData.hyprlandOutputSettings = current;
            SettingsData.saveSettings();
        }
    }

    function syncNiriDisabledFromConfig(parsedOutputs) {
        let changed = false;
        for (const outputName in parsedOutputs) {
            const output = parsedOutputs[outputName];
            const fromConfig = output.disabled ?? false;
            const current = SettingsData.getNiriOutputSetting(outputName, "disabled", false);
            if (current === fromConfig)
                continue;
            SettingsData.setNiriOutputSetting(outputName, "disabled", fromConfig || undefined);
            changed = true;
        }
        if (changed)
            SettingsData.saveSettings();
    }

    function filterDisconnectedOnly(parsedOutputs) {
        const result = {};
        const liveNames = Object.keys(outputs);
        const liveByIdentifier = {};
        for (const name of liveNames) {
            const o = outputs[name];
            if (o?.make && o?.model) {
                const serial = o.serial || "Unknown";
                const id = (o.make + " " + o.model + " " + serial).trim();
                liveByIdentifier[id] = true;
                liveByIdentifier[o.make + " " + o.model] = true;
            }
            liveByIdentifier[name] = true;
        }

        for (const savedName in parsedOutputs) {
            const trimmed = savedName.trim();
            if (!liveByIdentifier[trimmed])
                result[savedName] = parsedOutputs[savedName];
        }
        return result;
    }

    function parseOutputsConfig(content) {
        switch (CompositorService.compositor) {
        case "niri":
            return parseNiriOutputs(content);
        case "hyprland":
            return parseHyprlandOutputs(content);
        case "dwl":
            return parseMangoOutputs(content);
        default:
            return {};
        }
    }

    function parseNiriOutputs(content) {
        const result = {};
        const outputRegex = /output\s+"([^"]+)"\s*\{([^}]*)\}/g;
        let match;
        while ((match = outputRegex.exec(content)) !== null) {
            const name = match[1];
            const body = match[2];

            if (body.trim() === "off") {
                result[name] = {
                    "name": name,
                    "disabled": true,
                    "logical": {
                        "x": 0,
                        "y": 0,
                        "scale": 1.0,
                        "transform": "Normal"
                    }
                };
                continue;
            }

            const modeMatch = body.match(/mode\s+"(\d+)x(\d+)@([\d.]+)"/);
            const posMatch = body.match(/position\s+x=(-?\d+)\s+y=(-?\d+)/);
            const scaleMatch = body.match(/scale\s+([\d.]+)/);
            const transformMatch = body.match(/transform\s+"([^"]+)"/);
            const vrrMatch = body.match(/variable-refresh-rate/);
            const vrrOnDemandMatch = body.match(/variable-refresh-rate\s+on-demand=true/);

            result[name] = {
                "name": name,
                "logical": {
                    "x": posMatch ? parseInt(posMatch[1]) : 0,
                    "y": posMatch ? parseInt(posMatch[2]) : 0,
                    "scale": scaleMatch ? parseFloat(scaleMatch[1]) : 1.0,
                    "transform": transformMatch ? transformMatch[1] : "Normal"
                },
                "modes": modeMatch ? [
                    {
                        "width": parseInt(modeMatch[1]),
                        "height": parseInt(modeMatch[2]),
                        "refresh_rate": Math.round(parseFloat(modeMatch[3]) * 1000)
                    }
                ] : [],
                "current_mode": 0,
                "vrr_enabled": !!vrrMatch,
                "vrr_on_demand": !!vrrOnDemandMatch,
                "vrr_supported": true
            };
        }
        return result;
    }

    function parseHyprlandOutputs(content) {
        const result = {};
        const lines = content.split("\n");
        for (const line of lines) {
            const disableMatch = line.match(/^\s*monitor\s*=\s*([^,]+),\s*disable\s*$/);
            if (disableMatch) {
                const name = disableMatch[1].trim();
                result[name] = {
                    "name": name,
                    "logical": {
                        "x": 0,
                        "y": 0,
                        "scale": 1.0,
                        "transform": "Normal"
                    },
                    "modes": [],
                    "current_mode": -1,
                    "vrr_enabled": false,
                    "vrr_supported": false,
                    "hyprlandSettings": {
                        "disabled": true
                    }
                };
                continue;
            }
            const match = line.match(/^\s*monitor\s*=\s*([^,]+),\s*(\d+)x(\d+)@([\d.]+),\s*(-?\d+)x(-?\d+),\s*([\d.]+)/);
            if (!match)
                continue;
            const name = match[1].trim();
            const rest = line.substring(line.indexOf(match[7]) + match[7].length);

            let transform = 0, vrrMode = 0, bitdepth = undefined, cm = undefined;
            let sdrBrightness = undefined, sdrSaturation = undefined;

            const transformMatch = rest.match(/,\s*transform,\s*(\d+)/);
            if (transformMatch)
                transform = parseInt(transformMatch[1]);

            const vrrMatch = rest.match(/,\s*vrr,\s*(\d+)/);
            if (vrrMatch)
                vrrMode = parseInt(vrrMatch[1]);

            const bitdepthMatch = rest.match(/,\s*bitdepth,\s*(\d+)/);
            if (bitdepthMatch)
                bitdepth = parseInt(bitdepthMatch[1]);

            const cmMatch = rest.match(/,\s*cm,\s*(\w+)/);
            if (cmMatch)
                cm = cmMatch[1];

            const sdrBrightnessMatch = rest.match(/,\s*sdrbrightness,\s*([\d.]+)/);
            if (sdrBrightnessMatch)
                sdrBrightness = parseFloat(sdrBrightnessMatch[1]);

            const sdrSaturationMatch = rest.match(/,\s*sdrsaturation,\s*([\d.]+)/);
            if (sdrSaturationMatch)
                sdrSaturation = parseFloat(sdrSaturationMatch[1]);

            let mirror = "";
            const mirrorMatch = rest.match(/,\s*mirror,\s*([^,\s]+)/);
            if (mirrorMatch)
                mirror = mirrorMatch[1];

            result[name] = {
                "name": name,
                "logical": {
                    "x": parseInt(match[5]),
                    "y": parseInt(match[6]),
                    "scale": parseFloat(match[7]),
                    "transform": hyprlandToTransform(transform)
                },
                "modes": [
                    {
                        "width": parseInt(match[2]),
                        "height": parseInt(match[3]),
                        "refresh_rate": Math.round(parseFloat(match[4]) * 1000)
                    }
                ],
                "current_mode": 0,
                "vrr_enabled": vrrMode >= 1,
                "vrr_supported": true,
                "hyprlandSettings": {
                    "bitdepth": bitdepth,
                    "colorManagement": cm,
                    "sdrBrightness": sdrBrightness,
                    "sdrSaturation": sdrSaturation,
                    "vrrFullscreenOnly": vrrMode === 2 ? true : undefined
                },
                "mirror": mirror
            };
        }
        return result;
    }

    function hyprlandToTransform(value) {
        switch (value) {
        case 0:
            return "Normal";
        case 1:
            return "90";
        case 2:
            return "180";
        case 3:
            return "270";
        case 4:
            return "Flipped";
        case 5:
            return "Flipped90";
        case 6:
            return "Flipped180";
        case 7:
            return "Flipped270";
        default:
            return "Normal";
        }
    }

    function parseMangoOutputs(content) {
        const result = {};
        const lines = content.split("\n");
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed.startsWith("monitorrule="))
                continue;

            const params = {};
            for (const pair of trimmed.substring("monitorrule=".length).split(",")) {
                const colonIdx = pair.indexOf(":");
                if (colonIdx < 0)
                    continue;
                params[pair.substring(0, colonIdx).trim()] = pair.substring(colonIdx + 1).trim();
            }

            const name = params.name;
            if (!name)
                continue;

            result[name] = {
                "name": name,
                "logical": {
                    "x": parseInt(params.x || "0"),
                    "y": parseInt(params.y || "0"),
                    "scale": parseFloat(params.scale || "1"),
                    "transform": mangoToTransform(parseInt(params.rr || "0"))
                },
                "modes": [
                    {
                        "width": parseInt(params.width || "1920"),
                        "height": parseInt(params.height || "1080"),
                        "refresh_rate": parseFloat(params.refresh || "60") * 1000
                    }
                ],
                "current_mode": 0,
                "vrr_enabled": parseInt(params.vrr || "0") === 1,
                "vrr_supported": true
            };
        }
        return result;
    }

    function mangoToTransform(value) {
        switch (value) {
        case 0:
            return "Normal";
        case 1:
            return "90";
        case 2:
            return "180";
        case 3:
            return "270";
        case 4:
            return "Flipped";
        case 5:
            return "Flipped90";
        case 6:
            return "Flipped180";
        case 7:
            return "Flipped270";
        default:
            return "Normal";
        }
    }

    function getConfigPaths() {
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        switch (CompositorService.compositor) {
        case "niri":
            return {
                "configFile": configDir + "/niri/config.kdl",
                "outputsFile": configDir + "/niri/dms/outputs.kdl",
                "grepPattern": 'include.*"dms/outputs.kdl"',
                "includeLine": 'include "dms/outputs.kdl"'
            };
        case "hyprland":
            return {
                "configFile": configDir + "/hypr/hyprland.conf",
                "outputsFile": configDir + "/hypr/dms/outputs.conf",
                "grepPattern": 'source.*dms/outputs.conf',
                "includeLine": "source = ./dms/outputs.conf"
            };
        case "dwl":
            return {
                "configFile": configDir + "/mango/config.conf",
                "outputsFile": configDir + "/mango/dms/outputs.conf",
                "grepPattern": 'source.*dms/outputs.conf',
                "includeLine": "source=./dms/outputs.conf"
            };
        default:
            return null;
        }
    }

    function checkIncludeStatus() {
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland" && compositor !== "dwl") {
            includeStatus = {
                "exists": false,
                "included": false
            };
            return;
        }

        const filename = (compositor === "niri") ? "outputs.kdl" : "outputs.conf";
        const compositorArg = (compositor === "dwl") ? "mangowc" : compositor;

        checkingInclude = true;
        Proc.runCommand("check-outputs-include", ["dms", "config", "resolve-include", compositorArg, filename], (output, exitCode) => {
            checkingInclude = false;
            if (exitCode !== 0) {
                includeStatus = {
                    "exists": false,
                    "included": false
                };
                return;
            }
            try {
                includeStatus = JSON.parse(output.trim());
            } catch (e) {
                includeStatus = {
                    "exists": false,
                    "included": false
                };
            }
        });
    }

    function fixOutputsInclude() {
        const paths = getConfigPaths();
        if (!paths)
            return;

        fixingInclude = true;
        const outputsDir = paths.outputsFile.substring(0, paths.outputsFile.lastIndexOf("/"));
        const unixTime = Math.floor(Date.now() / 1000);
        const backupFile = paths.configFile + ".backup" + unixTime;

        Proc.runCommand("fix-outputs-include", ["sh", "-c", `cp "${paths.configFile}" "${backupFile}" 2>/dev/null; ` + `mkdir -p "${outputsDir}" && ` + `touch "${paths.outputsFile}" && ` + `if ! grep -v '^[[:space:]]*\\(//\\|#\\)' "${paths.configFile}" 2>/dev/null | grep -q '${paths.grepPattern}'; then ` + `echo '' >> "${paths.configFile}" && ` + `echo '${paths.includeLine}' >> "${paths.configFile}"; fi`], (output, exitCode) => {
            fixingInclude = false;
            if (exitCode !== 0)
                return;
            checkIncludeStatus();
            WlrOutputService.requestState();
        });
    }

    function buildOutputsMap() {
        const map = {};
        for (const output of wlrOutputs) {
            const normalizedModes = (output.modes || []).map(m => ({
                        "id": m.id,
                        "width": m.width,
                        "height": m.height,
                        "refresh_rate": m.refresh,
                        "preferred": m.preferred ?? false
                    }));
            map[output.name] = {
                "name": output.name,
                "make": output.make || "",
                "model": output.model || "",
                "serial": output.serialNumber || "",
                "modes": normalizedModes,
                "current_mode": normalizedModes.findIndex(m => m.id === output.currentMode?.id),
                "vrr_supported": output.adaptiveSyncSupported ?? false,
                "vrr_enabled": output.adaptiveSync === 1,
                "logical": {
                    "x": output.x ?? 0,
                    "y": output.y ?? 0,
                    "width": output.currentMode?.width ?? 1920,
                    "height": output.currentMode?.height ?? 1080,
                    "scale": output.scale || 1.0,
                    "transform": mapWlrTransform(output.transform)
                }
            };
        }
        return map;
    }

    function mapWlrTransform(wlrTransform) {
        switch (wlrTransform) {
        case 0:
            return "Normal";
        case 1:
            return "90";
        case 2:
            return "180";
        case 3:
            return "270";
        case 4:
            return "Flipped";
        case 5:
            return "Flipped90";
        case 6:
            return "Flipped180";
        case 7:
            return "Flipped270";
        default:
            return "Normal";
        }
    }

    function mapTransformToWlr(transform) {
        switch (transform) {
        case "Normal":
            return 0;
        case "90":
            return 1;
        case "180":
            return 2;
        case "270":
            return 3;
        case "Flipped":
            return 4;
        case "Flipped90":
            return 5;
        case "Flipped180":
            return 6;
        case "Flipped270":
            return 7;
        default:
            return 0;
        }
    }

    function backendFetchOutputs() {
        WlrOutputService.requestState();
    }

    function backendWriteOutputsConfig(outputsData) {
        switch (CompositorService.compositor) {
        case "niri":
            NiriService.generateOutputsConfig(outputsData);
            break;
        case "hyprland":
            HyprlandService.generateOutputsConfig(outputsData, buildMergedHyprlandSettings());
            break;
        case "dwl":
            DwlService.generateOutputsConfig(outputsData);
            break;
        default:
            WlrOutputService.applyOutputsConfig(outputsData, outputs);
            break;
        }
    }

    function normalizeOutputPositions(outputsData) {
        const names = Object.keys(outputsData);
        if (names.length === 0)
            return outputsData;

        let minX = Infinity;
        let minY = Infinity;

        for (const name of names) {
            const output = outputsData[name];
            if (!output.logical)
                continue;
            minX = Math.min(minX, output.logical.x);
            minY = Math.min(minY, output.logical.y);
        }

        if (minX === Infinity || (minX === 0 && minY === 0))
            return outputsData;

        const normalized = JSON.parse(JSON.stringify(outputsData));
        for (const name of names) {
            if (!normalized[name].logical)
                continue;
            normalized[name].logical.x -= minX;
            normalized[name].logical.y -= minY;
        }

        return normalized;
    }

    function buildOutputsWithPendingChanges() {
        const result = {};

        for (const outputName in savedOutputs) {
            if (!outputs[outputName])
                result[outputName] = JSON.parse(JSON.stringify(savedOutputs[outputName]));
        }

        for (const outputName in outputs) {
            result[outputName] = JSON.parse(JSON.stringify(outputs[outputName]));
        }

        for (const outputName in pendingChanges) {
            if (!result[outputName])
                continue;
            const changes = pendingChanges[outputName];
            if (changes.position && result[outputName].logical) {
                result[outputName].logical.x = changes.position.x;
                result[outputName].logical.y = changes.position.y;
            }
            if (changes.mode !== undefined && result[outputName].modes) {
                for (var i = 0; i < result[outputName].modes.length; i++) {
                    if (formatMode(result[outputName].modes[i]) === changes.mode) {
                        result[outputName].current_mode = i;
                        break;
                    }
                }
            }
            if (changes.scale !== undefined && result[outputName].logical)
                result[outputName].logical.scale = changes.scale;
            if (changes.transform !== undefined && result[outputName].logical)
                result[outputName].logical.transform = changes.transform;
            if (changes.vrr !== undefined)
                result[outputName].vrr_enabled = changes.vrr;
            if (changes.mirror !== undefined)
                result[outputName].mirror = changes.mirror;
        }
        return normalizeOutputPositions(result);
    }

    function backendUpdateOutputPosition(outputName, x, y) {
        if (!outputs || !outputs[outputName])
            return;
        const updatedOutputs = {};
        for (const name in outputs) {
            const output = outputs[name];
            if (name === outputName && output.logical) {
                updatedOutputs[name] = JSON.parse(JSON.stringify(output));
                updatedOutputs[name].logical.x = x;
                updatedOutputs[name].logical.y = y;
            } else {
                updatedOutputs[name] = output;
            }
        }
        outputs = updatedOutputs;
    }

    function backendUpdateOutputScale(outputName, scale) {
        if (!outputs || !outputs[outputName])
            return;
        const updatedOutputs = {};
        for (const name in outputs) {
            const output = outputs[name];
            if (name === outputName && output.logical) {
                updatedOutputs[name] = JSON.parse(JSON.stringify(output));
                updatedOutputs[name].logical.scale = scale;
            } else {
                updatedOutputs[name] = output;
            }
        }
        outputs = updatedOutputs;
    }

    function getOutputDisplayName(output, outputName) {
        return getOutputIdentifier(output, outputName);
    }

    function getNiriOutputIdentifier(output, outputName) {
        if (SettingsData.displayNameMode === "model" && output?.make && output?.model) {
            const serial = output.serial || "Unknown";
            return output.make + " " + output.model + " " + serial;
        }
        return outputName;
    }

    function getNiriSetting(output, outputName, key, defaultValue) {
        if (!CompositorService.isNiri)
            return defaultValue;
        const identifier = getNiriOutputIdentifier(output, outputName);
        const pending = pendingNiriChanges[identifier];
        if (pending && pending[key] !== undefined)
            return pending[key];
        return SettingsData.getNiriOutputSetting(identifier, key, defaultValue);
    }

    function setNiriSetting(output, outputName, key, value) {
        if (!CompositorService.isNiri)
            return;
        initOriginalNiriSettings();
        const identifier = getNiriOutputIdentifier(output, outputName);
        const newPending = JSON.parse(JSON.stringify(pendingNiriChanges));
        if (!newPending[identifier])
            newPending[identifier] = {};
        newPending[identifier][key] = value;
        pendingNiriChanges = newPending;
    }

    function initOriginalNiriSettings() {
        if (originalNiriSettings)
            return;
        originalNiriSettings = JSON.parse(JSON.stringify(SettingsData.niriOutputSettings));
    }

    function getHyprlandOutputIdentifier(output, outputName) {
        if (SettingsData.displayNameMode === "model" && output?.make && output?.model)
            return "desc:" + output.make + " " + output.model + " " + (output?.serial || "Unknown");
        return outputName;
    }

    function getHyprlandSetting(output, outputName, key, defaultValue) {
        if (!CompositorService.isHyprland)
            return defaultValue;
        const identifier = getHyprlandOutputIdentifier(output, outputName);
        const pending = pendingHyprlandChanges[identifier];
        if (pending && (key in pending)) {
            const val = pending[key];
            return (val !== null && val !== undefined) ? val : defaultValue;
        }
        return SettingsData.getHyprlandOutputSetting(identifier, key, defaultValue);
    }

    function setHyprlandSetting(output, outputName, key, value) {
        if (!CompositorService.isHyprland)
            return;
        initOriginalHyprlandSettings();
        const identifier = getHyprlandOutputIdentifier(output, outputName);
        const newPending = JSON.parse(JSON.stringify(pendingHyprlandChanges));
        if (!newPending[identifier])
            newPending[identifier] = {};
        newPending[identifier][key] = value;
        pendingHyprlandChanges = newPending;
    }

    function initOriginalHyprlandSettings() {
        if (originalHyprlandSettings)
            return;
        originalHyprlandSettings = JSON.parse(JSON.stringify(SettingsData.hyprlandOutputSettings));
    }

    function initOriginalOutputs() {
        if (!originalOutputs)
            originalOutputs = JSON.parse(JSON.stringify(outputs));
    }

    function setPendingChange(outputName, key, value) {
        initOriginalOutputs();
        const newPending = JSON.parse(JSON.stringify(pendingChanges));
        if (!newPending[outputName])
            newPending[outputName] = {};
        newPending[outputName][key] = value;
        pendingChanges = newPending;

        if (key === "scale") {
            recalculateAdjacentPositions(outputName, value);
            backendUpdateOutputScale(outputName, value);
        }
    }

    function recalculateAdjacentPositions(changedOutput, newScale) {
        const output = outputs[changedOutput];
        if (!output?.logical)
            return;
        const oldPhys = getPhysicalSize(output);
        const oldLogicalW = Math.round(oldPhys.w / (output.logical.scale || 1.0));
        const newLogicalW = Math.round(oldPhys.w / newScale);

        const changedX = getPendingValue(changedOutput, "position")?.x ?? output.logical.x;
        const changedY = getPendingValue(changedOutput, "position")?.y ?? output.logical.y;

        for (const name in outputs) {
            if (name === changedOutput)
                continue;
            const other = outputs[name];
            if (!other?.logical)
                continue;
            const otherX = getPendingValue(name, "position")?.x ?? other.logical.x;
            const otherY = getPendingValue(name, "position")?.y ?? other.logical.y;
            const otherSize = getLogicalSize(other);
            const otherRight = otherX + otherSize.w;

            if (Math.abs(changedX - otherRight) < 5) {
                const newX = otherRight;
                const newPending = JSON.parse(JSON.stringify(pendingChanges));
                if (!newPending[changedOutput])
                    newPending[changedOutput] = {};
                newPending[changedOutput].position = {
                    "x": newX,
                    "y": changedY
                };
                pendingChanges = newPending;
                backendUpdateOutputPosition(changedOutput, newX, changedY);
                return;
            }

            const changedRight = changedX + oldLogicalW;
            if (Math.abs(otherX - changedRight) < 5) {
                const newOtherX = changedX + newLogicalW;
                const newPending = JSON.parse(JSON.stringify(pendingChanges));
                if (!newPending[name])
                    newPending[name] = {};
                newPending[name].position = {
                    "x": newOtherX,
                    "y": otherY
                };
                pendingChanges = newPending;
                backendUpdateOutputPosition(name, newOtherX, otherY);
            }
        }
    }

    function getPendingValue(outputName, key) {
        if (!pendingChanges[outputName])
            return undefined;
        return pendingChanges[outputName][key];
    }

    function getEffectiveValue(outputName, key, originalValue) {
        const pending = getPendingValue(outputName, key);
        return pending !== undefined ? pending : originalValue;
    }

    // Returns true if the given output can currently be disabled.
    // Prevents disabling all outputs and prevents disabling the only output
    // in a single-display configuration.
    function canDisableOutput() {
        if (!CompositorService.isNiri && !CompositorService.isHyprland)
            return false;
        const totalOutputs = Object.keys(outputs).length;
        if (totalOutputs <= 1)
            return false;
        let enabledCount = 0;
        for (const name in outputs) {
            let disabled = false;
            if (CompositorService.isNiri)
                disabled = getNiriSetting(outputs[name], name, "disabled", false);
            else if (CompositorService.isHyprland)
                disabled = getHyprlandSetting(outputs[name], name, "disabled", false);
            if (!disabled)
                enabledCount++;
        }
        return enabledCount >= 2;
    }

    function clearPendingChanges() {
        pendingChanges = {};
        pendingNiriChanges = {};
        pendingHyprlandChanges = {};
        originalOutputs = null;
        originalNiriSettings = null;
        originalHyprlandSettings = null;
        originalDisplayNameMode = "";
    }

    function discardChanges() {
        if (originalDisplayNameMode !== "") {
            SettingsData.displayNameMode = originalDisplayNameMode;
            SettingsData.saveSettings();
        }
        backendFetchOutputs();
        clearPendingChanges();
    }

    function applyChanges() {
        if (!hasPendingChanges)
            return;
        const changeDescriptions = [];

        if (formatChanged) {
            const formatLabel = SettingsData.displayNameMode === "model" ? I18n.tr("Model") : I18n.tr("Name");
            changeDescriptions.push(I18n.tr("Config Format") + " → " + formatLabel);
        }

        for (const outputName in pendingChanges) {
            const changes = pendingChanges[outputName];
            if (changes.position)
                changeDescriptions.push(outputName + ": " + I18n.tr("Position") + " → " + changes.position.x + ", " + changes.position.y);
            if (changes.mode)
                changeDescriptions.push(outputName + ": " + I18n.tr("Mode") + " → " + changes.mode);
            if (changes.scale !== undefined)
                changeDescriptions.push(outputName + ": " + I18n.tr("Scale") + " → " + changes.scale);
            if (changes.transform)
                changeDescriptions.push(outputName + ": " + I18n.tr("Transform") + " → " + getTransformLabel(changes.transform));
            if (changes.vrr !== undefined)
                changeDescriptions.push(outputName + ": " + I18n.tr("VRR") + " → " + (changes.vrr ? I18n.tr("Enabled") : I18n.tr("Disabled")));
        }

        for (const outputId in pendingNiriChanges) {
            const changes = pendingNiriChanges[outputId];
            if (changes.disabled !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Disabled") + " → " + (changes.disabled ? I18n.tr("Yes") : I18n.tr("No")));
            if (changes.vrrOnDemand !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("VRR On-Demand") + " → " + (changes.vrrOnDemand ? I18n.tr("Enabled") : I18n.tr("Disabled")));
            if (changes.focusAtStartup !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Focus at Startup") + " → " + (changes.focusAtStartup ? I18n.tr("Yes") : I18n.tr("No")));
            if (changes.hotCorners !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Hot Corners") + " → " + I18n.tr("Modified"));
            if (changes.layout !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Layout") + " → " + I18n.tr("Modified"));
        }

        for (const outputId in pendingHyprlandChanges) {
            const changes = pendingHyprlandChanges[outputId];
            if (changes.disabled !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Disabled") + " → " + (changes.disabled ? I18n.tr("Yes") : I18n.tr("No")));
            if (changes.bitdepth !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Bit Depth") + " → " + changes.bitdepth);
            if (changes.colorManagement !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Color Management") + " → " + changes.colorManagement);
            if (changes.sdrBrightness !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("SDR Brightness") + " → " + changes.sdrBrightness);
            if (changes.sdrSaturation !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("SDR Saturation") + " → " + changes.sdrSaturation);
            if (changes.supportsHdr !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Force HDR") + " → " + (changes.supportsHdr ? I18n.tr("Yes") : I18n.tr("No")));
            if (changes.supportsWideColor !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("Force Wide Color") + " → " + (changes.supportsWideColor ? I18n.tr("Yes") : I18n.tr("No")));
            if (changes.vrrFullscreenOnly !== undefined)
                changeDescriptions.push(outputId + ": " + I18n.tr("VRR Fullscreen Only") + " → " + (changes.vrrFullscreenOnly ? I18n.tr("Enabled") : I18n.tr("Disabled")));
        }

        if (CompositorService.isNiri) {
            validateAndApplyNiriConfig(changeDescriptions);
            return;
        }

        changesApplied(changeDescriptions);

        if (formatChanged)
            SettingsData.saveSettings();

        if (CompositorService.isHyprland)
            commitHyprlandSettingsChanges();

        const mergedOutputs = buildOutputsWithPendingChanges();
        backendWriteOutputsConfig(mergedOutputs);
    }

    function validateAndApplyNiriConfig(changeDescriptions) {
        validatingConfig = true;
        validationError = "";

        const mergedOutputs = buildOutputsWithPendingChanges();
        const mergedNiriSettings = buildMergedNiriSettings();
        const configContent = generateNiriOutputsKdl(mergedOutputs, mergedNiriSettings);

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const tempFile = configDir + "/niri/dms/.outputs-validate-tmp.kdl";

        Proc.runCommand("niri-validate-write-tmp", ["sh", "-c", `mkdir -p "$(dirname "${tempFile}")" && cat > "${tempFile}" << 'EOF'\n${configContent}EOF`], (output, writeExitCode) => {
            if (writeExitCode !== 0) {
                validatingConfig = false;
                validationError = I18n.tr("Failed to write temp file for validation");
                ToastService.showError(I18n.tr("Config validation failed"), validationError, "", "display-config");
                return;
            }
            Proc.runCommand("niri-validate-config", ["sh", "-c", `niri validate -c "${tempFile}" 2>&1`], (validateOutput, validateExitCode) => {
                validatingConfig = false;
                Proc.runCommand("niri-validate-cleanup", ["rm", "-f", tempFile], () => {});
                if (validateExitCode !== 0) {
                    validationError = validateOutput.trim() || I18n.tr("Invalid configuration");
                    ToastService.showError(I18n.tr("Config validation failed"), validationError, "", "display-config");
                    return;
                }
                changesApplied(changeDescriptions);
                if (formatChanged)
                    SettingsData.saveSettings();
                commitNiriSettingsChanges();
                backendWriteOutputsConfig(mergedOutputs);
            });
        });
    }

    function buildMergedNiriSettings() {
        const merged = JSON.parse(JSON.stringify(SettingsData.niriOutputSettings));
        for (const outputId in pendingNiriChanges) {
            if (!merged[outputId])
                merged[outputId] = {};
            for (const key in pendingNiriChanges[outputId]) {
                merged[outputId][key] = pendingNiriChanges[outputId][key];
            }
        }
        // Never disable the only connected output — clear any stale flag
        if (Object.keys(outputs).length <= 1) {
            for (const id in merged)
                delete merged[id].disabled;
        }
        return merged;
    }

    function commitNiriSettingsChanges() {
        for (const outputId in pendingNiriChanges) {
            for (const key in pendingNiriChanges[outputId]) {
                SettingsData.setNiriOutputSetting(outputId, key, pendingNiriChanges[outputId][key]);
            }
        }
        // Clear stale disabled from SettingsData so NiriService reads clean state
        if (Object.keys(outputs).length <= 1) {
            for (const id in SettingsData.niriOutputSettings) {
                if (SettingsData.niriOutputSettings[id]?.disabled)
                    SettingsData.setNiriOutputSetting(id, "disabled", null);
            }
        }
    }

    function buildMergedHyprlandSettings() {
        const merged = JSON.parse(JSON.stringify(SettingsData.hyprlandOutputSettings));
        for (const outputId in pendingHyprlandChanges) {
            if (!merged[outputId])
                merged[outputId] = {};
            for (const key in pendingHyprlandChanges[outputId]) {
                const val = pendingHyprlandChanges[outputId][key];
                if (val === null || val === undefined)
                    delete merged[outputId][key];
                else
                    merged[outputId][key] = val;
            }
        }
        // Never disable the only connected output — clear any stale flag
        if (Object.keys(outputs).length <= 1) {
            for (const id in merged)
                delete merged[id].disabled;
        }
        return merged;
    }

    function commitHyprlandSettingsChanges() {
        for (const outputId in pendingHyprlandChanges) {
            for (const key in pendingHyprlandChanges[outputId]) {
                const val = pendingHyprlandChanges[outputId][key];
                if (val === null || val === undefined)
                    SettingsData.removeHyprlandOutputSetting(outputId, key);
                else
                    SettingsData.setHyprlandOutputSetting(outputId, key, val);
            }
        }
        // Clear stale disabled from SettingsData so HyprlandService reads clean state
        if (Object.keys(outputs).length <= 1) {
            for (const id in SettingsData.hyprlandOutputSettings) {
                if (SettingsData.hyprlandOutputSettings[id]?.disabled)
                    SettingsData.removeHyprlandOutputSetting(id, "disabled");
            }
        }
    }

    function generateNiriOutputsKdl(outputsData, niriSettings) {
        let kdlContent = `// Auto-generated by DMS - do not edit manually\n\n`;
        const sortedNames = Object.keys(outputsData).sort((a, b) => {
            const la = outputsData[a].logical || {};
            const lb = outputsData[b].logical || {};
            return (la.x ?? 0) - (lb.x ?? 0) || (la.y ?? 0) - (lb.y ?? 0);
        });
        for (const outputName of sortedNames) {
            const output = outputsData[outputName];
            const identifier = getNiriOutputIdentifier(output, outputName);
            const settings = niriSettings[identifier] || {};
            kdlContent += `output "${identifier}" {\n`;
            if (settings.disabled) {
                kdlContent += `    off\n}\n\n`;
                continue;
            }
            if (output.current_mode !== undefined && output.modes && output.modes[output.current_mode]) {
                const mode = output.modes[output.current_mode];
                kdlContent += `    mode "${mode.width}x${mode.height}@${(mode.refresh_rate / 1000).toFixed(3)}"\n`;
            }
            if (output.logical) {
                kdlContent += `    scale ${output.logical.scale ?? 1.0}\n`;
                if (output.logical.transform && output.logical.transform !== "Normal") {
                    const transformMap = {
                        "Normal": "normal",
                        "90": "90",
                        "180": "180",
                        "270": "270",
                        "Flipped": "flipped",
                        "Flipped90": "flipped-90",
                        "Flipped180": "flipped-180",
                        "Flipped270": "flipped-270"
                    };
                    kdlContent += `    transform "${transformMap[output.logical.transform] || "normal"}"\n`;
                }
                if (output.logical.x !== undefined && output.logical.y !== undefined)
                    kdlContent += `    position x=${output.logical.x} y=${output.logical.y}\n`;
            }
            if (settings.vrrOnDemand) {
                kdlContent += `    variable-refresh-rate on-demand=true\n`;
            } else if (output.vrr_enabled) {
                kdlContent += `    variable-refresh-rate\n`;
            }
            if (settings.focusAtStartup)
                kdlContent += `    focus-at-startup\n`;
            if (settings.backdropColor)
                kdlContent += `    backdrop-color "${settings.backdropColor}"\n`;
            kdlContent += generateHotCornersBlock(settings);
            kdlContent += generateLayoutBlock(settings);
            kdlContent += `}\n\n`;
        }
        return kdlContent;
    }

    function generateHotCornersBlock(settings) {
        if (!settings.hotCorners)
            return "";
        const hc = settings.hotCorners;
        if (hc.off)
            return `    hot-corners {\n        off\n    }\n`;
        const corners = hc.corners || [];
        if (corners.length === 0)
            return "";
        let block = `    hot-corners {\n`;
        for (const corner of corners)
            block += `        ${corner}\n`;
        block += `    }\n`;
        return block;
    }

    function generateLayoutBlock(settings) {
        if (!settings.layout)
            return "";
        const layout = settings.layout;
        const hasSettings = layout.gaps !== undefined || layout.defaultColumnWidth || layout.presetColumnWidths || layout.alwaysCenterSingleColumn !== undefined;
        if (!hasSettings)
            return "";
        let block = `    layout {\n`;
        if (layout.gaps !== undefined)
            block += `        gaps ${layout.gaps}\n`;
        if (layout.defaultColumnWidth?.type === "proportion") {
            const val = layout.defaultColumnWidth.value;
            const formatted = Number.isInteger(val) ? val.toFixed(1) : val.toString();
            block += `        default-column-width { proportion ${formatted}; }\n`;
        }
        if (layout.presetColumnWidths && layout.presetColumnWidths.length > 0) {
            block += `        preset-column-widths {\n`;
            for (const preset of layout.presetColumnWidths) {
                if (preset.type === "proportion") {
                    const val = preset.value;
                    const formatted = Number.isInteger(val) ? val.toFixed(1) : val.toString();
                    block += `            proportion ${formatted}\n`;
                }
            }
            block += `        }\n`;
        }
        if (layout.alwaysCenterSingleColumn !== undefined)
            block += layout.alwaysCenterSingleColumn ? `        always-center-single-column\n` : `        always-center-single-column false\n`;
        block += `    }\n`;
        return block;
    }

    function confirmChanges(profileId) {
        const outputConfigs = buildCurrentOutputConfigs();
        lastAppliedEntry = {
            outputs: outputConfigs
        };

        if (profileId) {
            readMonitorsJson(data => {
                const match = findConfigEntryById(data, profileId);
                if (match) {
                    data.configurations[match.index] = {
                        "id": match.entry.id,
                        "name": match.entry.name || "",
                        "outputs": outputConfigs
                    };
                    writeMonitorsJson(data, null);
                }
            });
        }

        clearPendingChanges();
        changesConfirmed();
    }

    function revertChanges() {
        const hadFormatChange = originalDisplayNameMode !== "";
        const hadNiriChanges = originalNiriSettings !== null;
        const hadHyprlandChanges = originalHyprlandSettings !== null;

        if (hadFormatChange) {
            SettingsData.displayNameMode = originalDisplayNameMode;
            SettingsData.saveSettings();
        }

        if (hadNiriChanges) {
            SettingsData.niriOutputSettings = JSON.parse(JSON.stringify(originalNiriSettings));
            SettingsData.saveSettings();
        }

        if (hadHyprlandChanges) {
            SettingsData.hyprlandOutputSettings = JSON.parse(JSON.stringify(originalHyprlandSettings));
            SettingsData.saveSettings();
        }

        pendingHyprlandChanges = {};
        pendingNiriChanges = {};

        if (!originalOutputs && !hadNiriChanges && !hadHyprlandChanges) {
            if (hadFormatChange)
                backendWriteOutputsConfig(buildOutputsWithPendingChanges());
            clearPendingChanges();
            changesReverted();
            return;
        }

        const original = originalOutputs ? JSON.parse(JSON.stringify(originalOutputs)) : buildOutputsWithPendingChanges();
        for (const name in savedOutputs) {
            if (!original[name])
                original[name] = JSON.parse(JSON.stringify(savedOutputs[name]));
        }
        backendWriteOutputsConfig(original);
        clearPendingChanges();
        if (originalOutputs)
            outputs = original;
        changesReverted();
    }

    function getOutputBounds() {
        if (!allOutputs || Object.keys(allOutputs).length === 0)
            return {
                "minX": 0,
                "minY": 0,
                "maxX": 1920,
                "maxY": 1080,
                "width": 1920,
                "height": 1080
            };

        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

        for (const name in allOutputs) {
            const output = allOutputs[name];
            if (!output.logical)
                continue;
            const x = output.logical.x;
            const y = output.logical.y;
            const size = getLogicalSize(output);
            minX = Math.min(minX, x);
            minY = Math.min(minY, y);
            maxX = Math.max(maxX, x + size.w);
            maxY = Math.max(maxY, y + size.h);
        }

        if (minX === Infinity)
            return {
                "minX": 0,
                "minY": 0,
                "maxX": 1920,
                "maxY": 1080,
                "width": 1920,
                "height": 1080
            };
        return {
            "minX": minX,
            "minY": minY,
            "maxX": maxX,
            "maxY": maxY,
            "width": maxX - minX,
            "height": maxY - minY
        };
    }

    function isRotated(transform) {
        switch (transform) {
        case "90":
        case "270":
        case "Flipped90":
        case "Flipped270":
            return true;
        default:
            return false;
        }
    }

    function getPhysicalSize(output) {
        if (!output)
            return {
                "w": 1920,
                "h": 1080
            };

        let w = 1920, h = 1080;
        if (output.modes && output.current_mode !== undefined) {
            const mode = output.modes[output.current_mode];
            if (mode) {
                w = mode.width || 1920;
                h = mode.height || 1080;
            }
        } else if (output.logical) {
            const scale = output.logical.scale || 1.0;
            w = Math.round((output.logical.width || 1920) * scale);
            h = Math.round((output.logical.height || 1080) * scale);
        }

        if (output.logical && isRotated(output.logical.transform))
            return {
                "w": h,
                "h": w
            };
        return {
            "w": w,
            "h": h
        };
    }

    function getLogicalSize(output) {
        if (!output)
            return {
                "w": 1920,
                "h": 1080
            };

        const phys = getPhysicalSize(output);
        const scale = output.logical?.scale || 1.0;

        return {
            "w": Math.round(phys.w / scale),
            "h": Math.round(phys.h / scale)
        };
    }

    function isOutputDisabled(outputName) {
        if (!outputs[outputName])
            return false;
        if (CompositorService.isHyprland)
            return getHyprlandSetting(outputs[outputName], outputName, "disabled", false);
        if (CompositorService.isNiri)
            return getNiriSetting(outputs[outputName], outputName, "disabled", false);
        return false;
    }

    function checkOverlap(testName, testX, testY, testW, testH) {
        for (const name in outputs) {
            if (name === testName)
                continue;
            if (isOutputDisabled(name))
                continue;
            const output = outputs[name];
            if (!output.logical)
                continue;
            const x = output.logical.x;
            const y = output.logical.y;
            const size = getLogicalSize(output);
            if (!(testX + testW <= x || testX >= x + size.w || testY + testH <= y || testY >= y + size.h))
                return true;
        }
        return false;
    }

    function snapToEdges(testName, posX, posY, testW, testH) {
        const snapThreshold = 200;
        let snappedX = posX;
        let snappedY = posY;
        let bestXDist = snapThreshold;
        let bestYDist = snapThreshold;

        for (const name in outputs) {
            if (name === testName)
                continue;
            if (isOutputDisabled(name))
                continue;
            const output = outputs[name];
            if (!output.logical)
                continue;
            const x = output.logical.x;
            const y = output.logical.y;
            const size = getLogicalSize(output);

            const rightEdge = x + size.w;
            const bottomEdge = y + size.h;
            const testRight = posX + testW;
            const testBottom = posY + testH;

            const xSnaps = [
                {
                    "val": rightEdge,
                    "dist": Math.abs(posX - rightEdge)
                },
                {
                    "val": x - testW,
                    "dist": Math.abs(testRight - x)
                },
                {
                    "val": x,
                    "dist": Math.abs(posX - x)
                },
                {
                    "val": rightEdge - testW,
                    "dist": Math.abs(testRight - rightEdge)
                }
            ];

            const ySnaps = [
                {
                    "val": bottomEdge,
                    "dist": Math.abs(posY - bottomEdge)
                },
                {
                    "val": y - testH,
                    "dist": Math.abs(testBottom - y)
                },
                {
                    "val": y,
                    "dist": Math.abs(posY - y)
                },
                {
                    "val": bottomEdge - testH,
                    "dist": Math.abs(testBottom - bottomEdge)
                }
            ];

            for (const snap of xSnaps) {
                if (snap.dist < bestXDist) {
                    bestXDist = snap.dist;
                    snappedX = snap.val;
                }
            }

            for (const snap of ySnaps) {
                if (snap.dist < bestYDist) {
                    bestYDist = snap.dist;
                    snappedY = snap.val;
                }
            }
        }

        if (checkOverlap(testName, snappedX, snappedY, testW, testH)) {
            if (!checkOverlap(testName, snappedX, posY, testW, testH))
                return Qt.point(snappedX, posY);
            if (!checkOverlap(testName, posX, snappedY, testW, testH))
                return Qt.point(posX, snappedY);
            return Qt.point(posX, posY);
        }
        return Qt.point(snappedX, snappedY);
    }

    function findBestSnapPosition(testName, posX, posY, testW, testH) {
        const outputNames = Object.keys(outputs).filter(n => n !== testName && !isOutputDisabled(n));

        if (outputNames.length === 0)
            return Qt.point(posX, posY);

        let bestPos = null;
        let bestDist = Infinity;

        for (const name of outputNames) {
            const output = outputs[name];
            if (!output.logical)
                continue;
            const x = output.logical.x;
            const y = output.logical.y;
            const size = getLogicalSize(output);

            const candidates = [
                {
                    "px": x + size.w,
                    "py": y
                },
                {
                    "px": x - testW,
                    "py": y
                },
                {
                    "px": x,
                    "py": y + size.h
                },
                {
                    "px": x,
                    "py": y - testH
                },
                {
                    "px": x + size.w,
                    "py": y + size.h - testH
                },
                {
                    "px": x - testW,
                    "py": y + size.h - testH
                },
                {
                    "px": x + size.w - testW,
                    "py": y + size.h
                },
                {
                    "px": x + size.w - testW,
                    "py": y - testH
                }
            ];

            for (const c of candidates) {
                if (checkOverlap(testName, c.px, c.py, testW, testH))
                    continue;
                const dist = Math.hypot(c.px - posX, c.py - posY);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestPos = Qt.point(c.px, c.py);
                }
            }
        }

        return bestPos || Qt.point(posX, posY);
    }

    function formatMode(mode) {
        if (!mode)
            return "";
        return mode.width + "x" + mode.height + "@" + (mode.refresh_rate / 1000).toFixed(3);
    }

    function getTransformLabel(transform) {
        switch (transform) {
        case "Normal":
            return I18n.tr("Normal");
        case "90":
            return I18n.tr("90°");
        case "180":
            return I18n.tr("180°");
        case "270":
            return I18n.tr("270°");
        case "Flipped":
            return I18n.tr("Flipped");
        case "Flipped90":
            return I18n.tr("Flipped 90°");
        case "Flipped180":
            return I18n.tr("Flipped 180°");
        case "Flipped270":
            return I18n.tr("Flipped 270°");
        default:
            return I18n.tr("Normal");
        }
    }

    function getTransformValue(label) {
        if (label === I18n.tr("Normal"))
            return "Normal";
        if (label === I18n.tr("90°"))
            return "90";
        if (label === I18n.tr("180°"))
            return "180";
        if (label === I18n.tr("270°"))
            return "270";
        if (label === I18n.tr("Flipped"))
            return "Flipped";
        if (label === I18n.tr("Flipped 90°"))
            return "Flipped90";
        if (label === I18n.tr("Flipped 180°"))
            return "Flipped180";
        if (label === I18n.tr("Flipped 270°"))
            return "Flipped270";
        return "Normal";
    }

    function setOriginalDisplayNameMode(mode) {
        if (originalDisplayNameMode === "")
            originalDisplayNameMode = mode;
    }
}
