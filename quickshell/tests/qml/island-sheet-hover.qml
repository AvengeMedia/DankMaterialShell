import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.Modules.Frame
import qs.DankCommon.Common as DC

// Qt 6.11 caches pointer bounds at first hover (PointerOverflowMarker): the sheet grown past the band must still take the pointer.
ShellRoot {
    id: root

    readonly property var screen: Quickshell.screens[0]
    readonly property string barId: "main"

    TestCase {
        id: input
        when: false
    }

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

    Frame {}

    DankIsland {}

    function config(withIsland) {
        return [
            {
                id: root.barId,
                enabled: true,
                visible: true,
                position: 0,
                screenPreferences: ["all"],
                leftWidgets: ["clock"],
                centerWidgets: withIsland ? [
                    {
                        id: "island",
                        enabled: true
                    },
                    "clock"] : ["clock"],
                rightWidgets: ["clock"]
            }
        ];
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
            SettingsData.reduceMotion = true;
            SettingsData.frameMode = "connected";
            SettingsData.frameEnabled = true;
            FrameTransitionState.acknowledge(FrameTransitionState.revision);
            SettingsData.barConfigs = root.config(false);
        }
    }

    Timer {
        id: steps

        property bool expanding: false
        property int waited: 0
        readonly property var body: IslandHostRegistry.hostFor(root.screen.name, root.barId)
        readonly property var bareBody: BarWidgetService.frameHostedBars[root.screen.name]?.[root.barId] ?? null
        readonly property var frame: body?.hostWindow ?? null

        interval: 25
        repeat: true
        running: (!!body && !!body.islandController || !!bareBody) && SettingsData.frameEnabled

        function finish(message) {
            if (message)
                console.error("FIXTURE_FAIL", message);
            else
                console.log("FIXTURE_PASS");
            stop();
            Qt.quit();
        }

        onTriggered: {
            if (++waited > 800) {
                finish("timed out " + (expanding ? "expanding the sheet" : "waiting for the island at rest"));
                return;
            }
            if (!body) {
                const content = bareBody.hostWindow?.contentItem ?? null;
                if (!content || content.width <= 0 || bareBody.width <= 0)
                    return;
                input.mouseMove(content, 40, bareBody.hostOffsetY + bareBody.height / 2, 0);
                SettingsData.barConfigs = root.config(true);
                waited = 0;
                return;
            }
            const controller = body.islandController;
            if (!expanding) {
                if (body.motionRunning || body.bandThickness <= 0 || frame.cutoutTopInset <= 0)
                    return;
                input.mouseMove(frame.contentItem, 40, frame.cutoutTopInset / 2, 0);
                controller.requestToggle(true);
                expanding = true;
                waited = 0;
                return;
            }
            if (!controller.expanded || body.motionRunning)
                return;
            const sheet = ConnectedModeState.surfaceDescriptor(root.screen.name, "island");
            if (!sheet.presented)
                return;
            input.mouseMove(frame.contentItem, sheet.bodyRect.x + sheet.bodyRect.width / 2, sheet.bodyRect.y + sheet.bodyRect.height - 30, 0);
            finish(controller.pointerInside ? "" : "hover past the band reaches the sheet");
        }
    }
}
