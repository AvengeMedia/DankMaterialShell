pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "../Common/AqueousBlur.js" as AqueousBlur
import qs.Services

Singleton {
    id: root

    readonly property string contextKey: CompositorService.isAqueous && BlurService.probeFinished && SettingsData._hasLoaded ? AqueousService.session : ""
    readonly property bool available: contextKey !== "" && supported && globalEnabled
    property bool supported: false
    property bool globalEnabled: false
    property bool appliedEnabled: false
    property bool busy: false
    property bool pending: false
    property string error: ""

    function refresh() {
        pending = true;
        Qt.callLater(root.sync);
    }

    function finish(message) {
        error = message;
        busy = false;
        if (message) {
            pending = false;
            Log.scoped("AqueousBlurService").warn(message);
            return;
        }
        if (pending)
            Qt.callLater(root.sync);
    }

    function sync() {
        if (!contextKey || !pending || busy || AqueousConfigService.busy)
            return;
        pending = false;
        busy = true;
        error = "";
        const session = contextKey;
        const desired = SettingsData.blurEnabled ?? false;
        const frame = SettingsData.frameBlurEnabled ?? false;
        const protocol = BlurService.compositorSupported;
        AqueousConfigService.load((snapshot, message) => {
            if (session !== root.contextKey) {
                root.finish("");
                return;
            }
            try {
                if (message)
                    throw new Error(message);
                AqueousConfigService.requireCapabilities(snapshot, ["validate", "stdin_requests", "generation_check", "atomic_file_replace", "shell_dms"]);
                const global = snapshot.fields?.find(field => field.id === "blur.enabled");
                if (typeof global?.value !== "boolean" || typeof snapshot.raw_files?.rules !== "string")
                    throw new Error("unsupported Aqueous blur configuration snapshot");
                root.supported = true;
                root.globalEnabled = global.value;
                if (desired && !protocol && !global.value) {
                    root.appliedEnabled = false;
                    root.finish("");
                    return;
                }
                const source = snapshot.raw_files.rules;
                const updated = AqueousBlur.rules(source, desired, frame, protocol);
                if (source === updated) {
                    root.appliedEnabled = desired && !protocol;
                    root.finish("");
                    return;
                }
                AqueousConfigService.apply({
                    expected_generation: snapshot.generation,
                    create_user_override: true,
                    raw_files: {
                        rules: updated
                    }
                }, (result, applyError) => {
                    if (session !== root.contextKey) {
                        root.finish("");
                        return;
                    }
                    if (applyError) {
                        root.finish(applyError);
                        return;
                    }
                    if (result?.raw_files?.rules !== updated) {
                        root.finish("Aqueous helper did not apply the requested blur rules");
                        return;
                    }
                    root.appliedEnabled = desired && !protocol;
                    root.finish("");
                });
            } catch (e) {
                root.finish(String(e));
            }
        });
    }

    onContextKeyChanged: {
        supported = false;
        globalEnabled = false;
        appliedEnabled = false;
        error = "";
        refresh();
    }

    Connections {
        target: SettingsData
        function onBlurEnabledChanged() {
            root.refresh();
        }
        function onFrameBlurEnabledChanged() {
            root.refresh();
        }
    }

    Connections {
        target: BlurService
        function onCompositorSupportedChanged() {
            root.refresh();
        }
    }

    Connections {
        target: AqueousConfigService
        function onBusyChanged() {
            if (!AqueousConfigService.busy && root.pending)
                Qt.callLater(root.sync);
        }
    }

    Component.onCompleted: refresh()
}
