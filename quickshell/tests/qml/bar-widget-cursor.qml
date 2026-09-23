import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.DankCommon.Common as DC

// Every MouseArea owns an arrow cursor, so one painted over a widget hides the widget's pointer cursor.
ShellRoot {
    id: root

    Item {
        Repeater {
            model: ScriptModel {
                values: SettingsData.barConfigs
                objectProp: "id"
            }
            delegate: DankBar {
                required property var modelData
                barConfig: modelData
            }
        }
    }

    function mouseAreas(item, found) {
        if (item.containsPress !== undefined && item.acceptedButtons !== undefined)
            found.push(item);
        for (const child of item.children || [])
            mouseAreas(child, found);
        return found;
    }

    function chain(item) {
        const items = [];
        for (let node = item; node; node = node.parent)
            items.unshift(node);
        return items;
    }

    // Paint order: z first, then declaration order under the first diverging ancestor.
    function paintsAbove(a, b) {
        const ca = chain(a), cb = chain(b);
        let i = 0;
        while (i < ca.length && i < cb.length && ca[i] === cb[i])
            i++;
        if (i === ca.length)
            return false;
        if (i === cb.length)
            return true;
        if (ca[i].z !== cb[i].z)
            return ca[i].z > cb[i].z;
        const siblings = ca[i - 1].children;
        return siblings.indexOf(ca[i]) > siblings.indexOf(cb[i]);
    }

    function areasCovering(widget) {
        const x = widget.width / 2, y = widget.height / 2;
        return mouseAreas(widget.Window.window.contentItem, []).filter(area => {
            if (!area.visible || !area.enabled || chain(area).includes(widget) || !paintsAbove(area, widget))
                return false;
            return area.contains(widget.mapToItem(area, x, y));
        });
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 0
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        onTriggered: {
            SettingsData.frameEnabled = false;
            SettingsData.reduceMotion = true;
            SettingsData.barConfigs = [
                {
                    id: "bar",
                    enabled: true,
                    visible: true,
                    position: 0,
                    leftWidgets: ["launcherButton"],
                    rightWidgets: ["clock"]
                }
            ];
        }
    }

    Timer {
        id: steps

        property int waited: 0
        readonly property var widget: BarWidgetService.getWidget("launcherButton", Quickshell.screens[0].name)

        interval: 25
        repeat: true
        running: SettingsData.barConfigs.length === 1

        function finish(message) {
            running = false;
            if (message)
                console.error("FIXTURE_FAIL", message);
            else
                console.info("FIXTURE_PASS");
            Qt.quit();
        }

        onTriggered: {
            if (!widget || widget.width <= 0 || !widget.visible) {
                if (++waited > 800)
                    finish("launcher button never appeared: widget=" + widget + " width=" + widget?.width + " visible=" + widget?.visible);
                return;
            }
            const covering = root.areasCovering(widget);
            finish(covering.length ? "MouseArea painted over the launcher button: " + covering : "");
        }
    }
}
