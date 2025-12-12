pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import "../Common/KeybindActions.js" as Actions

Singleton {
    id: root

    readonly property bool shortcutInhibitorAvailable: {
        try {
            return typeof ShortcutInhibitor !== "undefined";
        } catch (e) {
            return false;
        }
    }

    property bool available: CompositorService.isNiri && shortcutInhibitorAvailable
    property string currentProvider: "niri"

    readonly property string cheatsheetProvider: {
        if (CompositorService.isNiri)
            return "niri";
        if (CompositorService.isHyprland)
            return "hyprland";
        return "";
    }
    property bool cheatsheetAvailable: cheatsheetProvider !== ""
    property bool cheatsheetLoading: false
    property var cheatsheet: ({})

    property bool loading: false
    property bool saving: false
    property bool fixing: false
    property string lastError: ""
    property bool dmsBindsIncluded: true

    property var dmsStatus: ({
            exists: true,
            included: true,
            includePosition: -1,
            totalIncludes: 0,
            bindsAfterDms: 0,
            effective: true,
            overriddenBy: 0,
            statusMessage: ""
        })

    property var _rawData: null
    property var keybinds: ({})
    property var _allBinds: ({})
    property var _categories: []
    property var _flatCache: []
    property var displayList: []
    property int _dataVersion: 0

    readonly property var categoryOrder: Actions.getCategoryOrder()
    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string dmsBindsPath: configDir + "/niri/dms/binds.kdl"
    readonly property var actionTypes: Actions.getActionTypes()
    readonly property var dmsActions: getDmsActions()

    signal bindsLoaded
    signal bindSaved(string key)
    signal bindSaveCompleted(bool success)
    signal bindRemoved(string key)
    signal dmsBindsFixed
    signal cheatsheetLoaded

    Connections {
        target: CompositorService
        function onCompositorChanged() {
            if (!CompositorService.isNiri)
                return;
            Qt.callLater(root.loadBinds);
        }
    }

    Connections {
        target: NiriService
        enabled: CompositorService.isNiri
        function onConfigReloaded() {
            Qt.callLater(root.loadBinds, false);
        }
    }

    Process {
        id: cheatsheetProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.cheatsheet = JSON.parse(text);
                } catch (e) {
                    console.error("[KeybindsService] Failed to parse cheatsheet:", e);
                    root.cheatsheet = {};
                }
                root.cheatsheetLoading = false;
                root.cheatsheetLoaded();
            }
        }

        onExited: exitCode => {
            if (exitCode === 0)
                return;
            console.warn("[KeybindsService] Cheatsheet load failed with code:", exitCode);
            root.cheatsheetLoading = false;
        }
    }

    Process {
        id: loadProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._rawData = JSON.parse(text);
                    root._processData();
                } catch (e) {
                    console.error("[KeybindsService] Failed to parse binds:", e);
                }
                root.loading = false;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[KeybindsService] Load process failed with code:", exitCode);
                root.loading = false;
            }
        }
    }

    Process {
        id: saveProcess
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                root.lastError = text.trim();
                ToastService.showError(I18n.tr("Failed to save keybind"), "", root.lastError, "keybinds");
            }
        }

        onExited: exitCode => {
            root.saving = false;
            if (exitCode !== 0) {
                console.error("[KeybindsService] Save failed with code:", exitCode);
                root.bindSaveCompleted(false);
                return;
            }
            root.lastError = "";
            root.bindSaveCompleted(true);
            root.loadBinds(false);
        }
    }

    Process {
        id: removeProcess
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                root.lastError = text.trim();
                ToastService.showError(I18n.tr("Failed to remove keybind"), "", root.lastError, "keybinds");
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.error("[KeybindsService] Remove failed with code:", exitCode);
                return;
            }
            root.lastError = "";
            root.loadBinds(false);
        }
    }

    Process {
        id: fixProcess
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                root.lastError = text.trim();
                ToastService.showError(I18n.tr("Failed to add binds include"), "", root.lastError, "keybinds");
            }
        }

        onExited: exitCode => {
            root.fixing = false;
            if (exitCode !== 0) {
                console.error("[KeybindsService] Fix failed with code:", exitCode);
                return;
            }
            root.lastError = "";
            root.dmsBindsIncluded = true;
            root.dmsBindsFixed();
            ToastService.showSuccess(I18n.tr("Binds include added"), I18n.tr("dms/binds.kdl is now included in config.kdl"), "", "keybinds");
            Qt.callLater(root.forceReload);
        }
    }

    function fixDmsBindsInclude() {
        if (fixing || dmsBindsIncluded)
            return;
        fixing = true;
        const niriConfigDir = configDir + "/niri";
        const timestamp = Math.floor(Date.now() / 1000);
        const backupPath = `${niriConfigDir}/config.kdl.dmsbackup${timestamp}`;
        const script = `mkdir -p "${niriConfigDir}/dms" && touch "${niriConfigDir}/dms/binds.kdl" && cp "${niriConfigDir}/config.kdl" "${backupPath}" && echo 'include "dms/binds.kdl"' >> "${niriConfigDir}/config.kdl"`;
        fixProcess.command = ["sh", "-c", script];
        fixProcess.running = true;
    }

    function forceReload() {
        _allBinds = {};
        _flatCache = [];
        _categories = [];
        loadBinds(true);
    }

    function loadCheatsheet(provider) {
        if (cheatsheetProcess.running)
            return;
        const target = provider || cheatsheetProvider;
        if (!target)
            return;
        cheatsheetLoading = true;
        cheatsheetProcess.command = ["dms", "keybinds", "show", target];
        cheatsheetProcess.running = true;
    }

    function loadBinds(showLoading) {
        if (loadProcess.running || !available)
            return;
        const hasData = Object.keys(_allBinds).length > 0;
        loading = showLoading !== false && !hasData;
        loadProcess.command = ["dms", "keybinds", "show", currentProvider];
        loadProcess.running = true;
    }

    function _processData() {
        keybinds = _rawData || {};
        if (currentProvider === "niri") {
            dmsBindsIncluded = _rawData?.dmsBindsIncluded ?? true;
            const status = _rawData?.dmsStatus;
            if (status) {
                dmsStatus = {
                    exists: status.exists ?? true,
                    included: status.included ?? true,
                    includePosition: status.includePosition ?? -1,
                    totalIncludes: status.totalIncludes ?? 0,
                    bindsAfterDms: status.bindsAfterDms ?? 0,
                    effective: status.effective ?? true,
                    overriddenBy: status.overriddenBy ?? 0,
                    statusMessage: status.statusMessage ?? ""
                };
            }
        }

        if (!_rawData?.binds) {
            _allBinds = {};
            _categories = [];
            _flatCache = [];
            displayList = [];
            _dataVersion++;
            bindsLoaded();
            return;
        }

        const processed = {};
        const bindsData = _rawData.binds;
        for (const cat in bindsData) {
            const binds = bindsData[cat];
            for (let i = 0; i < binds.length; i++) {
                const bind = binds[i];
                const targetCat = Actions.isDmsAction(bind.action) ? "DMS" : cat;
                if (!processed[targetCat])
                    processed[targetCat] = [];
                processed[targetCat].push(bind);
            }
        }

        const sortedCats = Object.keys(processed).sort((a, b) => {
            const ai = categoryOrder.indexOf(a);
            const bi = categoryOrder.indexOf(b);
            return (ai === -1 ? 999 : ai) - (bi === -1 ? 999 : bi);
        });

        const grouped = [];
        const actionMap = {};
        for (let ci = 0; ci < sortedCats.length; ci++) {
            const category = sortedCats[ci];
            const binds = processed[category];
            if (!binds)
                continue;
            for (let i = 0; i < binds.length; i++) {
                const bind = binds[i];
                const action = bind.action || "";
                const keyData = {
                    key: bind.key || "",
                    source: bind.source || "config",
                    isOverride: bind.source === "dms",
                    cooldownMs: bind.cooldownMs || 0
                };
                if (actionMap[action]) {
                    actionMap[action].keys.push(keyData);
                    if (!actionMap[action].desc && bind.desc)
                        actionMap[action].desc = bind.desc;
                    if (!actionMap[action].conflict && bind.conflict)
                        actionMap[action].conflict = bind.conflict;
                } else {
                    const entry = {
                        category: category,
                        action: action,
                        desc: bind.desc || "",
                        keys: [keyData],
                        conflict: bind.conflict || null
                    };
                    actionMap[action] = entry;
                    grouped.push(entry);
                }
            }
        }

        const list = [];
        for (const cat of sortedCats) {
            list.push({
                id: "cat:" + cat,
                type: "category",
                name: cat
            });
            const binds = processed[cat];
            if (!binds)
                continue;
            for (const bind of binds)
                list.push({
                    id: "bind:" + bind.key,
                    type: "bind",
                    key: bind.key,
                    desc: bind.desc
                });
        }

        _allBinds = processed;
        _categories = sortedCats;
        _flatCache = grouped;
        displayList = list;
        _dataVersion++;
        bindsLoaded();
    }

    function getCategories() {
        return _categories;
    }

    function getFlatBinds() {
        return _flatCache;
    }

    function saveBind(originalKey, bindData) {
        if (!bindData.key || !Actions.isValidAction(bindData.action))
            return;
        saving = true;
        const cmd = ["dms", "keybinds", "set", currentProvider, bindData.key, bindData.action, "--desc", bindData.desc || ""];
        if (originalKey && originalKey !== bindData.key)
            cmd.push("--replace-key", originalKey);
        if (bindData.cooldownMs > 0)
            cmd.push("--cooldown-ms", String(bindData.cooldownMs));
        saveProcess.command = cmd;
        saveProcess.running = true;
        bindSaved(bindData.key);
    }

    function removeBind(key) {
        if (!key)
            return;
        removeProcess.command = ["dms", "keybinds", "remove", currentProvider, key];
        removeProcess.running = true;
        bindRemoved(key);
    }

    function isDmsAction(action) {
        return Actions.isDmsAction(action);
    }

    function isValidAction(action) {
        return Actions.isValidAction(action);
    }

    function getActionType(action) {
        return Actions.getActionType(action);
    }

    function getActionLabel(action) {
        return Actions.getActionLabel(action);
    }

    function getCompositorCategories() {
        return Actions.getCompositorCategories();
    }

    function getCompositorActions(category) {
        return Actions.getCompositorActions(category);
    }

    function getDmsActions() {
        return Actions.getDmsActions(CompositorService.isNiri, CompositorService.isHyprland);
    }

    function buildSpawnAction(command, args) {
        return Actions.buildSpawnAction(command, args);
    }

    function buildShellAction(shellCmd) {
        return Actions.buildShellAction(shellCmd);
    }

    function parseSpawnCommand(action) {
        return Actions.parseSpawnCommand(action);
    }

    function parseShellCommand(action) {
        return Actions.parseShellCommand(action);
    }
}
