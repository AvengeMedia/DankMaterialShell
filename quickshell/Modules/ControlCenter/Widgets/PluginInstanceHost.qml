import QtQuick
import qs.Services

Item {
    id: root

    readonly property var log: Log.scoped("PluginInstanceHost")

    property string pluginId: ""
    property var instance: null

    visible: false
    width: 0
    height: 0

    function create() {
        if (instance || !pluginId)
            return;
        const pluginComponent = PluginService.pluginWidgetComponents[pluginId];
        if (!pluginComponent)
            return;
        try {
            instance = pluginComponent.createObject(root, {
                "pluginId": pluginId,
                "pluginService": PluginService,
                "visible": false,
                "width": 0,
                "height": 0
            });
        } catch (e) {
            log.warn("stale plugin component for", pluginId, "- reloading");
            PluginService.reloadPlugin(pluginId);
        }
    }

    function drop() {
        if (!instance)
            return;
        const stale = instance;
        instance = null;
        stale.destroy();
    }

    function recreate() {
        drop();
        create();
    }

    onPluginIdChanged: recreate()
    Component.onCompleted: create()
    Component.onDestruction: drop()

    Connections {
        target: PluginService
        enabled: root.pluginId !== ""

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId || !root.instance)
                return;
            root.instance.loadPluginData();
        }

        function onPluginLoaded(loadedPluginId) {
            if (loadedPluginId !== root.pluginId)
                return;
            root.recreate();
        }
    }
}
