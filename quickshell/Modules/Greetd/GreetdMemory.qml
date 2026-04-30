pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "GreetdEnv.js" as GreetdEnv
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("GreetdMemory")

    readonly property string greetCfgDir: Quickshell.env("DMS_GREET_CFG_DIR") || "/var/cache/dms-greeter"
    readonly property string sessionConfigPath: greetCfgDir + "/session.json"
    readonly property string memoryFile: greetCfgDir + "/.local/state/memory.json"
    readonly property bool rememberLastSession: GreetdEnv.readBoolOverride(Quickshell.env, ["DMS_GREET_REMEMBER_LAST_SESSION", "DMS_SAVE_SESSION"], true)
    readonly property bool rememberLastUser: GreetdEnv.readBoolOverride(Quickshell.env, ["DMS_GREET_REMEMBER_LAST_USER", "DMS_SAVE_USERNAME"], true)

    property string lastSessionId: ""
    property string lastSuccessfulUser: ""
    property bool memoryReady: false
    property bool isLightMode: false
    property bool nightModeEnabled: false

    Component.onCompleted: {
        loadMemory();
        loadSessionConfig();
    }

    function loadMemory() {
        parseMemory(memoryFileView.text());
    }

    function loadSessionConfig() {
        parseSessionConfig(sessionConfigFileView.text());
    }

    function parseSessionConfig(content) {
        try {
            if (content && content.trim()) {
                const config = JSON.parse(content);
                isLightMode = config.isLightMode !== undefined ? config.isLightMode : false;
                nightModeEnabled = config.nightModeEnabled !== undefined ? config.nightModeEnabled : false;
            }
        } catch (e) {
            log.warn("Failed to parse greeter session config:", e);
        }
    }

    function parseMemory(content) {
        try {
            if (!content || !content.trim())
                return;
            const memory = JSON.parse(content);
            lastSessionId = rememberLastSession ? (memory.lastSessionId || "") : "";
            lastSuccessfulUser = rememberLastUser ? (memory.lastSuccessfulUser || "") : "";
            if (!rememberLastSession || !rememberLastUser)
                saveMemory();
        } catch (e) {
            log.warn("Failed to parse greetd memory:", e);
        }
    }

    function saveMemory() {
        let memory = {};
        if (rememberLastSession && lastSessionId)
            memory.lastSessionId = lastSessionId;
        if (rememberLastUser && lastSuccessfulUser)
            memory.lastSuccessfulUser = lastSuccessfulUser;
        memoryFileView.setText(JSON.stringify(memory, null, 2));
    }

    function setLastSessionId(id) {
        if (!rememberLastSession) {
            if (lastSessionId !== "") {
                lastSessionId = "";
                saveMemory();
            }
            return;
        }
        lastSessionId = id || "";
        saveMemory();
    }

    function setLastSuccessfulUser(username) {
        if (!rememberLastUser) {
            if (lastSuccessfulUser !== "") {
                lastSuccessfulUser = "";
                saveMemory();
            }
            return;
        }
        lastSuccessfulUser = username || "";
        saveMemory();
    }

    FileView {
        id: memoryFileView
        path: root.memoryFile
        blockLoading: false
        blockWrites: false
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            parseMemory(memoryFileView.text());
            root.memoryReady = true;
        }
        onLoadFailed: {
            root.memoryReady = true;
        }
    }

    FileView {
        id: sessionConfigFileView
        path: root.sessionConfigPath
        blockLoading: false
        blockWrites: true
        atomicWrites: false
        watchChanges: false
        printErrors: true
        onLoaded: {
            parseSessionConfig(sessionConfigFileView.text());
        }
        onLoadFailed: error => {
            log.warn("Could not load greeter session config from", root.sessionConfigPath, "error:", error);
        }
    }
}
