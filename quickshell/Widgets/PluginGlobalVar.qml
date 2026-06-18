import QtQuick
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("PluginGlobalVar")

    required property string varName
    property var defaultValue: undefined

    readonly property var value: {
        const pid = parent?.pluginId ?? "";
        if (!pid || !PluginService.globalVars[pid]) {
            return defaultValue;
        }
        return PluginService.globalVars[pid][varName] ?? defaultValue;
    }

    function set(newValue) {
        const pid = parent?.pluginId ?? "";
        if (pid) {
            PluginService.setGlobalVar(pid, varName, newValue);
        } else {
            log.warn("Cannot set", varName, "- no pluginId from parent");
        }
    }

    visible: false
    width: 0
    height: 0
}
