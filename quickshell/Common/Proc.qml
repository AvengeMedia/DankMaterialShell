pragma Singleton

import Quickshell
import qs.DankCommon.Common as DankCommon

Singleton {
    readonly property int noTimeout: DankCommon.Proc.noTimeout
    readonly property string dmsBin: DankCommon.Proc.dmsBin

    function runCommand(id, command, callback, debounceMs, timeoutMs) {
        DankCommon.Proc.runCommand(id, command, callback, debounceMs, timeoutMs);
    }
}
