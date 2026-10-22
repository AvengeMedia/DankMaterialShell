pragma Singleton

import Quickshell

// cli-policy.json switches, set by `dms run` on each launch (core/internal/clipolicy).
Singleton {
    readonly property bool disableLockIpcUnlock: Quickshell.env("DMS_POLICY_DISABLE_LOCK_IPC_UNLOCK") === "1"
}
