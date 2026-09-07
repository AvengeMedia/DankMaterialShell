pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("AqueousConfigService")
    property bool busy: false

    function requireCapabilities(result, required) {
        if (result?.protocol !== 1 || !Array.isArray(result.capabilities))
            throw new Error("unsupported aqueous-config protocol or discovery");
        for (const capability of required) {
            if (!result.capabilities.includes(capability))
                throw new Error("unsupported aqueous-config capability: " + capability);
        }
    }

    function helper(operation, input, callback) {
        const args = ["aqueous-config", operation, "--shell", "dms"];
        if (input !== null)
            args.push("--request", "-");
        AqueousService.runJson(args, input, (result, error) => {
            if (!error && result?.ok !== true)
                error = result?.code ? result.code + ": " + (result.message || "") : "aqueous-config rejected the request";
            callback(result, error);
        });
    }

    function request(operation, draft, callback) {
        if (!CompositorService.isAqueous || busy) {
            callback(null, busy ? "busy" : "unavailable");
            return;
        }
        busy = true;
        const complete = (result, error) => {
            busy = false;
            if (error)
                log.warn("helper operation failed:", operation, error);
            callback(error ? null : result, error);
        };
        if (operation === "snapshot") {
            helper("snapshot", null, (result, error) => {
                try {
                    if (error)
                        throw new Error(error);
                    requireCapabilities(result, ["schema_fields", "shell_dms"]);
                    if (typeof result.generation !== "string" || !result.generation)
                        throw new Error("missing configuration generation");
                    complete(result, "");
                } catch (e) {
                    complete(null, String(e));
                }
            });
            return;
        }
        if (!["apply", "validate"].includes(operation) || typeof draft?.expected_generation !== "string" || !draft.expected_generation) {
            complete(null, "invalid operation or missing expected_generation; reload configuration");
            return;
        }
        const request = Object.assign({}, draft, {
            protocol: 1
        });
        request.backup_dir = request.backup_dir || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/DankMaterialShell/aqueous-backups";
        const input = JSON.stringify(request);
        const required = ["validate", "stdin_requests", "generation_check", "atomic_file_replace", "shell_dms"];
        for (const [key, capability] of Object.entries({
            monitor_changes: "monitor_modes",
            custom_keybind_changes: "keybinds",
            sync_cursor: "cursor_sync",
            sync_typography: "typography_sync"
        })) {
            if (Object.prototype.hasOwnProperty.call(request, key))
                required.push(capability);
        }
        helper("version", null, (version, error) => {
            try {
                if (error)
                    throw new Error(error);
                requireCapabilities(version, required);
            } catch (e) {
                complete(null, String(e));
                return;
            }
            helper("validate", input, (validated, error) => {
                if (error || operation === "validate") {
                    complete(validated, error);
                    return;
                }
                helper("apply", input, complete);
            });
        });
    }

    function load(callback) {
        request("snapshot", null, callback);
    }

    function apply(draft, callback) {
        request("apply", draft, callback);
    }
}
