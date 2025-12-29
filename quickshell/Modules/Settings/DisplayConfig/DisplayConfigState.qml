pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

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

    signal changesApplied(var changeDescriptions)
    signal changesConfirmed
    signal changesReverted

    function buildAllOutputsMap() {
        const result = {};
        for (const name in savedOutputs) {
            result[name] = Object.assign({}, savedOutputs[name], {
                "connected": false
            });
        }
        for (const name in outputs) {
            result[name] = Object.assign({}, outputs[name], {
                "connected": true
            });
        }
        return result;
    }

    onOutputsChanged: allOutputs = buildAllOutputsMap()
    onSavedOutputsChanged: allOutputs = buildAllOutputsMap()

    Connections {
        target: WlrOutputService
        function onStateChanged() {
            root.outputs = root.buildOutputsMap();
            root.reloadSavedOutputs();
        }
    }

    Component.onCompleted: {
        outputs = buildOutputsMap();
        reloadSavedOutputs();
        checkIncludeStatus();
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

            if (CompositorService.isHyprland)
                initHyprlandSettingsFromConfig(parsed);
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

            const modeMatch = body.match(/mode\s+"(\d+)x(\d+)@([\d.]+)"/);
            const posMatch = body.match(/position\s+x=(-?\d+)\s+y=(-?\d+)/);
            const scaleMatch = body.match(/scale\s+([\d.]+)/);
            const transformMatch = body.match(/transform\s+"([^"]+)"/);
            const vrrMatch = body.match(/variable-refresh-rate(?:\s+on)?/);

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

            let transform = 0, vrr = false, bitdepth = undefined, cm = undefined;
            let sdrBrightness = undefined, sdrSaturation = undefined;

            const transformMatch = rest.match(/,\s*transform,\s*(\d+)/);
            if (transformMatch)
                transform = parseInt(transformMatch[1]);

            const vrrMatch = rest.match(/,\s*vrr,\s*(\d+)/);
            if (vrrMatch)
                vrr = vrrMatch[1] === "1";

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
                "vrr_enabled": vrr,
                "vrr_supported": true,
                "hyprlandSettings": {
                    "bitdepth": bitdepth,
                    "colorManagement": cm,
                    "sdrBrightness": sdrBrightness,
                    "sdrSaturation": sdrSaturation
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
            const match = line.match(/^\s*monitorrule=([^,]+),([^,]+),([^,]+),([^,]+),(\d+),([\d.]+),(-?\d+),(-?\d+),(\d+),(\d+),(\d+)/);
            if (!match)
                continue;
            const name = match[1].trim();
            result[name] = {
                "name": name,
                "logical": {
                    "x": parseInt(match[7]),
                    "y": parseInt(match[8]),
                    "scale": parseFloat(match[6]),
                    "transform": mangoToTransform(parseInt(match[5]))
                },
                "modes": [
                    {
                        "width": parseInt(match[9]),
                        "height": parseInt(match[10]),
                        "refresh_rate": parseInt(match[11]) * 1000
                    }
                ],
                "current_mode": 0,
                "vrr_enabled": false,
                "vrr_supported": false
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
        const paths = getConfigPaths();
        if (!paths) {
            includeStatus = {
                "exists": false,
                "included": false
            };
            return;
        }

        checkingInclude = true;
        Proc.runCommand("check-outputs-include", ["sh", "-c", `exists=false; included=false; ` + `[ -f "${paths.outputsFile}" ] && exists=true; ` + `[ -f "${paths.configFile}" ] && grep -v '^[[:space:]]*\\(//\\|#\\)' "${paths.configFile}" | grep -q '${paths.grepPattern}' && included=true; ` + `echo "$exists $included"`], (output, exitCode) => {
            checkingInclude = false;
            const parts = output.trim().split(" ");
            includeStatus = {
                "exists": parts[0] === "true",
                "included": parts[1] === "true"
            };
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
                    "scale": output.scale ?? 1.0,
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
        if (SettingsData.displayNameMode === "model" && output?.make && output?.model) {
            if (CompositorService.isNiri) {
                const serial = output.serial || "Unknown";
                return output.make + " " + output.model + " " + serial;
            }
            return output.make + " " + output.model;
        }
        return outputName;
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
            return "desc:" + output.make + " " + output.model;
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
        return merged;
    }

    function commitNiriSettingsChanges() {
        for (const outputId in pendingNiriChanges) {
            for (const key in pendingNiriChanges[outputId]) {
                SettingsData.setNiriOutputSetting(outputId, key, pendingNiriChanges[outputId][key]);
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
    }

    function generateNiriOutputsKdl(outputsData, niriSettings) {
        let kdlContent = `// Auto-generated by DMS - do not edit manually\n\n`;
        for (const outputName in outputsData) {
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

    function confirmChanges() {
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

    function checkOverlap(testName, testX, testY, testW, testH) {
        for (const name in outputs) {
            if (name === testName)
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
        const outputNames = Object.keys(outputs).filter(n => n !== testName);

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
