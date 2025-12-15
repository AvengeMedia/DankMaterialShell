pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string mangoDmsDir: configDir + "/mango/dms"
    readonly property string outputsPath: mangoDmsDir + "/outputs.conf"

    property bool dwlAvailable: false
    property var outputs: ({})
    property var tagCount: 9
    property var layouts: []
    property string activeOutput: ""
    property var outputScales: ({})
    property string currentKeyboardLayout: {
        if (!outputs || !activeOutput)
            return "";
        const output = outputs[activeOutput];
        return (output && output.kbLayout) || "";
    }

    signal stateChanged

    Connections {
        target: DMSService
        function onCapabilitiesReceived() {
            checkCapabilities();
        }
        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkCapabilities();
            } else {
                dwlAvailable = false;
            }
        }
        function onDwlStateUpdate(data) {
            if (dwlAvailable) {
                handleStateUpdate(data);
            }
        }
    }

    Component.onCompleted: {
        if (DMSService.dmsAvailable) {
            checkCapabilities();
        }
        if (dwlAvailable) {
            refreshOutputScales();
        }
    }

    function checkCapabilities() {
        if (!DMSService.capabilities || !Array.isArray(DMSService.capabilities)) {
            dwlAvailable = false;
            return;
        }

        const hasDwl = DMSService.capabilities.includes("dwl");
        if (hasDwl && !dwlAvailable) {
            dwlAvailable = true;
            console.info("DwlService: DWL capability detected");
            requestState();
            refreshOutputScales();
        } else if (!hasDwl) {
            dwlAvailable = false;
        }
    }

    function requestState() {
        if (!DMSService.isConnected || !dwlAvailable) {
            return;
        }

        DMSService.sendRequest("dwl.getState", null, response => {
            if (response.result) {
                handleStateUpdate(response.result);
            }
        });
    }

    function handleStateUpdate(state) {
        outputs = state.outputs || {};
        tagCount = state.tagCount || 9;
        layouts = state.layouts || [];
        activeOutput = state.activeOutput || "";
        stateChanged();
    }

    function setTags(outputName, tagmask, toggleTagset) {
        if (!DMSService.isConnected || !dwlAvailable) {
            return;
        }

        DMSService.sendRequest("dwl.setTags", {
            "output": outputName,
            "tagmask": tagmask,
            "toggleTagset": toggleTagset
        }, response => {
            if (response.error) {
                console.warn("DwlService: setTags error:", response.error);
            }
        });
    }

    function setClientTags(outputName, andTags, xorTags) {
        if (!DMSService.isConnected || !dwlAvailable) {
            return;
        }

        DMSService.sendRequest("dwl.setClientTags", {
            "output": outputName,
            "andTags": andTags,
            "xorTags": xorTags
        }, response => {
            if (response.error) {
                console.warn("DwlService: setClientTags error:", response.error);
            }
        });
    }

    function setLayout(outputName, index) {
        if (!DMSService.isConnected || !dwlAvailable) {
            return;
        }

        DMSService.sendRequest("dwl.setLayout", {
            "output": outputName,
            "index": index
        }, response => {
            if (response.error) {
                console.warn("DwlService: setLayout error:", response.error);
            }
        });
    }

    function getOutputState(outputName) {
        if (!outputs || !outputs[outputName]) {
            return null;
        }
        return outputs[outputName];
    }

    function getActiveTags(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags) {
            return [];
        }
        return output.tags.filter(tag => tag.state === 1).map(tag => tag.tag);
    }

    function getTagsWithClients(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags) {
            return [];
        }
        return output.tags.filter(tag => tag.clients > 0).map(tag => tag.tag);
    }

    function getUrgentTags(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags) {
            return [];
        }
        return output.tags.filter(tag => tag.state === 2).map(tag => tag.tag);
    }

    function switchToTag(outputName, tagIndex) {
        const tagmask = 1 << tagIndex;
        setTags(outputName, tagmask, 0);
    }

    function toggleTag(outputName, tagIndex) {
        const output = getOutputState(outputName);
        if (!output || !output.tags) {
            console.log("toggleTag: no output or tags for", outputName);
            return;
        }

        let currentMask = 0;
        output.tags.forEach(tag => {
            if (tag.state === 1) {
                currentMask |= (1 << tag.tag);
            }
        });

        const clickedMask = 1 << tagIndex;
        const newMask = currentMask ^ clickedMask;

        console.log("toggleTag:", outputName, "tag:", tagIndex, "currentMask:", currentMask.toString(2), "clickedMask:", clickedMask.toString(2), "newMask:", newMask.toString(2));

        if (newMask === 0) {
            console.log("toggleTag: newMask is 0, switching to tag", tagIndex);
            setTags(outputName, 1 << tagIndex, 0);
        } else {
            console.log("toggleTag: setting combined mask", newMask);
            setTags(outputName, newMask, 0);
        }
    }

    function quit() {
        Quickshell.execDetached(["mmsg", "-d", "quit"]);
    }

    Process {
        id: scaleQueryProcess
        command: ["mmsg", "-A"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const newScales = {};
                    const lines = text.trim().split('\n');
                    for (const line of lines) {
                        const parts = line.trim().split(/\s+/);
                        if (parts.length >= 3 && parts[1] === "scale_factor") {
                            const outputName = parts[0];
                            const scale = parseFloat(parts[2]);
                            if (!isNaN(scale)) {
                                newScales[outputName] = scale;
                            }
                        }
                    }
                    outputScales = newScales;
                } catch (e) {
                    console.warn("DwlService: Failed to parse mmsg output:", e);
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("DwlService: mmsg failed with exit code:", exitCode);
            }
        }
    }

    function refreshOutputScales() {
        if (!dwlAvailable)
            return;
        scaleQueryProcess.running = true;
    }

    function getOutputScale(outputName) {
        return outputScales[outputName];
    }

    function getVisibleTags(outputName) {
        const output = getOutputState(outputName);
        if (!output || !output.tags) {
            return [];
        }

        const visibleTags = new Set();

        output.tags.forEach(tag => {
            if (tag.state === 1 || tag.clients > 0) {
                visibleTags.add(tag.tag);
            }
        });

        return Array.from(visibleTags).sort((a, b) => a - b);
    }

    function generateOutputsConfig(outputsData) {
        if (!outputsData || Object.keys(outputsData).length === 0)
            return

        let lines = ["# Auto-generated by DMS - do not edit manually", "# VRR is global: set adaptive_sync=1 in config.conf", ""]

        for (const outputName in outputsData) {
            const output = outputsData[outputName]
            if (!output)
                continue

            let width = 1920
            let height = 1080
            let refreshRate = 60
            if (output.modes && output.current_mode !== undefined) {
                const mode = output.modes[output.current_mode]
                if (mode) {
                    width = mode.width || 1920
                    height = mode.height || 1080
                    refreshRate = Math.round((mode.refresh_rate || 60000) / 1000)
                }
            }

            const x = output.logical?.x ?? 0
            const y = output.logical?.y ?? 0
            const scale = output.logical?.scale ?? 1.0
            const transform = transformToMango(output.logical?.transform ?? "Normal")

            const rule = [
                outputName,
                "0.55",
                "1",
                "tile",
                transform,
                scale,
                x,
                y,
                width,
                height,
                refreshRate
            ].join(",")

            lines.push("monitorrule=" + rule)
        }

        lines.push("")

        const content = lines.join("\n")

        Proc.runCommand("mango-write-outputs", ["sh", "-c", `mkdir -p "${mangoDmsDir}" && cat > "${outputsPath}" << 'EOF'\n${content}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("DwlService: Failed to write outputs config:", output)
                return
            }
            console.info("DwlService: Generated outputs config at", outputsPath)
            if (CompositorService.isDwl)
                reloadConfig()
        })
    }

    function reloadConfig() {
        Proc.runCommand("mango-reload", ["mmsg", "-d", "reload_config"], (output, exitCode) => {
            if (exitCode !== 0)
                console.warn("DwlService: mmsg reload_config failed:", output)
        })
    }

    function transformToMango(transform) {
        switch (transform) {
        case "Normal": return 0
        case "90": return 1
        case "180": return 2
        case "270": return 3
        case "Flipped": return 4
        case "Flipped90": return 5
        case "Flipped180": return 6
        case "Flipped270": return 7
        default: return 0
        }
    }
}
