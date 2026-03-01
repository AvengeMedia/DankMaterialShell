pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool wlrOutputAvailable: false
    property var outputs: []
    property int serial: 0

    signal stateChanged
    signal configurationApplied(bool success, string message)

    Connections {
        target: DMSService

        function onCapabilitiesReceived() {
            checkCapabilities();
        }

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkCapabilities();
                return;
            }
            wlrOutputAvailable = false;
        }

        function onWlrOutputStateUpdate(data) {
            if (!wlrOutputAvailable) {
                return;
            }
            handleStateUpdate(data);
        }
    }

    Component.onCompleted: {
        if (!DMSService.dmsAvailable) {
            return;
        }
        checkCapabilities();
    }

    function checkCapabilities() {
        if (!DMSService.capabilities || !Array.isArray(DMSService.capabilities)) {
            wlrOutputAvailable = false;
            return;
        }

        const hasWlrOutput = DMSService.capabilities.includes("wlroutput");
        if (hasWlrOutput && !wlrOutputAvailable) {
            wlrOutputAvailable = true;
            console.info("WlrOutputService: wlr-output-management capability detected");
            requestState();
            return;
        }

        if (!hasWlrOutput) {
            wlrOutputAvailable = false;
        }
    }

    function requestState() {
        if (!DMSService.isConnected || !wlrOutputAvailable) {
            return;
        }

        DMSService.sendRequest("wlroutput.getState", null, response => {
            if (!response.result) {
                return;
            }
            handleStateUpdate(response.result);
        });
    }

    function handleStateUpdate(state) {
        outputs = state.outputs || [];
        serial = state.serial || 0;

        if (outputs.length === 0) {
            console.warn("WlrOutputService: Received empty outputs list");
        } else {
            console.log("WlrOutputService: Updated with", outputs.length, "outputs, serial:", serial);
            outputs.forEach((output, index) => {
                console.log("WlrOutputService: Output", index, "-", output.name, "enabled:", output.enabled, "mode:", output.currentMode ? output.currentMode.width + "x" + output.currentMode.height + "@" + (output.currentMode.refresh / 1000) + "Hz" : "none");
            });
        }
        stateChanged();
    }

    function getOutput(name) {
        for (const output of outputs) {
            if (output.name === name) {
                return output;
            }
        }
        return null;
    }

    function getEnabledOutputs() {
        return outputs.filter(output => output.enabled);
    }

    function applyConfiguration(heads, callback) {
        if (!DMSService.isConnected || !wlrOutputAvailable) {
            if (callback) {
                callback(false, "Not connected");
            }
            return;
        }

        console.log("WlrOutputService: Applying configuration for", heads.length, "outputs");
        heads.forEach((head, index) => {
            console.log("WlrOutputService: Head", index, "- name:", head.name, "enabled:", head.enabled, "modeId:", head.modeId, "customMode:", JSON.stringify(head.customMode), "position:", JSON.stringify(head.position), "scale:", head.scale, "transform:", head.transform, "adaptiveSync:", head.adaptiveSync);
        });

        DMSService.sendRequest("wlroutput.applyConfiguration", {
            "heads": heads
        }, response => {
            const success = !response.error;
            const message = response.error || response.result?.message || "";

            if (response.error) {
                console.warn("WlrOutputService: applyConfiguration error:", response.error);
            } else {
                console.log("WlrOutputService: Configuration applied successfully");
            }

            configurationApplied(success, message);
            if (callback) {
                callback(success, message);
            }
        });
    }

    function testConfiguration(heads, callback) {
        if (!DMSService.isConnected || !wlrOutputAvailable) {
            if (callback) {
                callback(false, "Not connected");
            }
            return;
        }

        console.log("WlrOutputService: Testing configuration for", heads.length, "outputs");

        DMSService.sendRequest("wlroutput.testConfiguration", {
            "heads": heads
        }, response => {
            const success = !response.error;
            const message = response.error || response.result?.message || "";

            if (response.error) {
                console.warn("WlrOutputService: testConfiguration error:", response.error);
            } else {
                console.log("WlrOutputService: Configuration test passed");
            }

            if (callback) {
                callback(success, message);
            }
        });
    }

    function setOutputEnabled(outputName, enabled, callback) {
        const output = getOutput(outputName);
        if (!output) {
            console.warn("WlrOutputService: Output not found:", outputName);
            if (callback) {
                callback(false, "Output not found");
            }
            return;
        }

        const heads = [
            {
                "name": outputName,
                "enabled": enabled
            }
        ];

        if (enabled && output.currentMode) {
            heads[0].modeId = output.currentMode.id;
        }

        applyConfiguration(heads, callback);
    }

    function setOutputMode(outputName, modeId, callback) {
        const heads = [
            {
                "name": outputName,
                "enabled": true,
                "modeId": modeId
            }
        ];

        applyConfiguration(heads, callback);
    }

    function setOutputCustomMode(outputName, width, height, refresh, callback) {
        const heads = [
            {
                "name": outputName,
                "enabled": true,
                "customMode": {
                    "width": width,
                    "height": height,
                    "refresh": refresh
                }
            }
        ];

        applyConfiguration(heads, callback);
    }

    function setOutputPosition(outputName, x, y, callback) {
        const heads = [
            {
                "name": outputName,
                "enabled": true,
                "position": {
                    "x": x,
                    "y": y
                }
            }
        ];

        applyConfiguration(heads, callback);
    }

    function setOutputScale(outputName, scale, callback) {
        const heads = [
            {
                "name": outputName,
                "enabled": true,
                "scale": scale
            }
        ];

        applyConfiguration(heads, callback);
    }

    function setOutputTransform(outputName, transform, callback) {
        const heads = [
            {
                "name": outputName,
                "enabled": true,
                "transform": transform
            }
        ];

        applyConfiguration(heads, callback);
    }

    function setOutputAdaptiveSync(outputName, state, callback) {
        const heads = [
            {
                "name": outputName,
                "enabled": true,
                "adaptiveSync": state
            }
        ];

        applyConfiguration(heads, callback);
    }

    function configureOutput(config, callback) {
        const heads = [config];
        applyConfiguration(heads, callback);
    }

    function configureMultipleOutputs(configs, callback) {
        applyConfiguration(configs, callback);
    }

    // High-level apply matching the generateOutputsConfig() pattern used by
    // NiriService, HyprlandService and DwlService.  Instead of writing a
    // config file, the changes are applied directly via the
    // wlr-output-management protocol.
    function applyOutputsConfig(outputsData, connectedOutputs) {
        if (!wlrOutputAvailable)
            return;
        const heads = [];
        for (const name in outputsData) {
            if (!connectedOutputs[name])
                continue;
            const output = outputsData[name];
            const mode = (output.modes && output.current_mode >= 0) ? output.modes[output.current_mode] : null;
            const enabled = !!mode;
            const head = {
                "name": name,
                "enabled": enabled
            };

            if (enabled) {
                if (mode.id !== undefined)
                    head.modeId = mode.id;
                else
                    head.customMode = {
                        "width": mode.width,
                        "height": mode.height,
                        "refresh": mode.refresh_rate
                    };

                if (output.logical) {
                    head.position = {
                        "x": output.logical.x ?? 0,
                        "y": output.logical.y ?? 0
                    };
                    head.scale = output.logical.scale ?? 1.0;
                    head.transform = transformFromName(output.logical.transform);
                }
            }
            heads.push(head);
        }

        if (heads.length > 0)
            applyConfiguration(heads);
    }

    function transformFromName(name) {
        switch (name) {
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
}
