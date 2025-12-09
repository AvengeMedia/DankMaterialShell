pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

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
}
