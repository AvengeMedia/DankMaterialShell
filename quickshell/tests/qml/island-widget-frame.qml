import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.Modules.Frame
import qs.DankCommon.Common as DC

// A connected-frame bar hosting the island widget: the frame hosts the body, the SDF slot follows the sheet, shared shortcuts
// route into it, a right-section island bulges out of the ring on the right, and transient launcher windows join the grab.
ShellRoot {
    id: root

    property int fallbackCalls: 0
    readonly property var screen: Quickshell.screens[0]
    readonly property string barId: "main"

    TestCase {
        id: input
        when: false
    }

    QtObject {
        id: cachedLauncher
        property bool edgeHoverManaged: false
        property bool triggerUsesOverlayLayer: false
        function show() {
            root.fallbackCalls++;
        }
        function hide() {}
        function toggle() {
            root.fallbackCalls++;
        }
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

    DankIsland {
        id: islands
    }

    function check(value, label) {
        if (!value)
            throw new Error(label);
    }

    function config(position, routing, section) {
        const widgets = { leftWidgets: ["clock"], centerWidgets: ["clock"], rightWidgets: ["clock"] };
        if (routing)
            widgets[(section ?? "center") + "Widgets"] = [{ id: "island", enabled: true, islandSharedRouting: routing }, "clock"];
        // Flat keys are the bar's island-mode settings; the hosted island reads only its widget entry.
        return [Object.assign({ id: root.barId, enabled: true, visible: true, position, islandFloating: true, islandPlacement: "free", islandSatellitePosition: "island", islandPalette: "dim", islandUseOverlayLayer: true, islandSharedRouting: "always", screenPreferences: ["all"] }, widgets)];
    }

    // Stands in for a launcher context menu window; the frame's grab must include it.
    PanelWindow {
        id: probe

        visible: false
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
            SettingsData.launcherStyle = "island";
            SettingsData.frameMode = "connected";
            SettingsData.frameEnabled = true;
            FrameTransitionState.acknowledge(FrameTransitionState.revision);
            // The island joins a bar the pointer has already crossed; a hover must still reach the sheet past the band.
            SettingsData.barConfigs = root.config(0, "");
            PopoutService.dankLauncherV2Modal = cachedLauncher;
        }
    }

    Timer {
        id: steps

        property int index: 0
        property int waited: 0
        readonly property var body: IslandHostRegistry.hostFor(root.screen.name, root.barId)
        readonly property var bareBody: BarWidgetService.frameHostedBars[root.screen.name]?.[root.barId] ?? null
        readonly property var frame: body?.hostWindow ?? null
        readonly property string key: JSON.stringify([root.screen.name, root.barId])

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

        function next() {
            index++;
            waited = 0;
        }

        function pillStart() {
            return body.hostOriginY + body.currentVisualY;
        }

        // The centre section places its widgets from a timer; until it runs the slot still sits at x 0. Side rows start at 0.
        function slotPlaced(section) {
            const slot = body.slotItem;
            const target = section ?? "center";
            return !!slot && slot.width > 0 && slot.parent.section === target && (target !== "center" || slot.x > 0);
        }

        function pillOnSlot() {
            const slot = body.slotItem;
            const expected = slot.mapToItem(body, slot.width / 2, 0).x;
            const centre = body.currentAlongPos + body.currentVisualAlong / 2;
            root.check(!body.freeMode && Math.abs(centre - expected) <= 1, `pill centred on its slot: ${centre} vs ${expected}`);
        }

        onTriggered: {
            if (++waited > 240) {
                finish("timed out at step " + index);
                return;
            }
            if (!body) {
                const content = bareBody.hostWindow?.contentItem ?? null;
                if (!content || content.width <= 0 || bareBody.width <= 0)
                    return;
                input.mouseMove(content, 40, bareBody.hostOffsetY + bareBody.height / 2, 0);
                SettingsData.barConfigs = root.config(0, "normal");
                waited = 0;
                return;
            }
            const controller = body.islandController;
            try {
                switch (index) {
                case 0:
                    root.check(ShellLayout.frameKeys(root.screen).includes(key), "hosting bar is frame hosted");
                    root.check(ShellLayout.islandKeys.includes(key), "hosting bar owns an island slot");
                    root.check(!SettingsData.dankIslandOwnsEdge(root.screen, "top"), "hosted island does not own the edge");
                    root.check(SettingsData.dankIslandEnabled, "island module is on");
                    root.check(ShellLayout.standaloneScreens(root.barId).length === 0, "no standalone bar window");
                    root.check(frame.targetScreen === root.screen, "body is hosted by the frame window");
                    root.check(body.chrome === "none", "frame hosting paints through the SDF");
                    if (body.motionRunning || body.bandThickness <= 0 || frame.cutoutTopInset <= 0 || !slotPlaced())
                        return;
                    root.check(pillStart() >= 0 && pillStart() + body.currentVisualHeight <= frame.cutoutTopInset + 0.5, `pill inside the top band: ${pillStart()}..${pillStart() + body.currentVisualHeight} vs ${frame.cutoutTopInset}`);
                    pillOnSlot();
                    root.check((body.barBody.sectionRectFor("left")?.w ?? 0) > 0, "section rect passthrough");
                    root.check(frame.mask.regions.some(region => region.item === body.inputMaskItem), "frame mask carries the island envelope");
                    // Hovered at rest with the pill inside the band, then expanded: the sheet must still take the pointer.
                    input.mouseMove(frame.contentItem, 40, frame.cutoutTopInset / 2, 0);
                    controller.requestToggle(true);
                    next();
                    return;
                case 1: {
                    if (!controller.expanded || body.motionRunning)
                        return;
                    const sheet = ConnectedModeState.surfaceDescriptor(root.screen.name, "island");
                    if (!sheet.presented)
                        return;
                    input.mouseMove(frame.contentItem, sheet.bodyRect.x + sheet.bodyRect.width / 2, sheet.bodyRect.y + sheet.bodyRect.height - 30, 0);
                    root.check(controller.pointerInside, "hover past the band reaches the sheet");
                    input.mouseMove(frame.contentItem, 40, frame.height - 3, 0);
                    controller.requestCollapse();
                    next();
                    return;
                }
                case 2:
                    if (controller.expanded || body.motionRunning)
                        return;
                    SettingsData.barConfigs = root.config(1, "normal");
                    next();
                    return;
                case 3:
                    if (body.edge !== "bottom" || body.motionRunning || !slotPlaced())
                        return;
                    root.check(pillStart() >= frame.height - frame.cutoutBottomInset - 0.5 && pillStart() + body.currentVisualHeight <= frame.height + 0.5, `pill inside the bottom band: ${pillStart()}..${pillStart() + body.currentVisualHeight} vs ${frame.height - frame.cutoutBottomInset}..${frame.height}`);
                    pillOnSlot();
                    SettingsData.barConfigs = root.config(0, "always");
                    next();
                    return;
                case 4:
                    if (body.edge !== "top" || body.motionRunning)
                        return;
                    PopoutService.openDankLauncherV2();
                    root.check(root.fallbackCalls === 0, "always-here keeps the launcher out of the modal");
                    next();
                    return;
                case 5: {
                    if (!controller.expanded || controller.activeActivity !== "launcher" || body.motionRunning)
                        return;
                    const descriptor = ConnectedModeState.surfaceDescriptor(root.screen.name, "island");
                    if (!descriptor.presented)
                        return;
                    root.check(descriptor.kind === "island" && descriptor.barSide === "top", "island descriptor kind and side");
                    const dx = Math.abs(descriptor.bodyRect.x - (body.hostOriginX + body.currentVisualX));
                    const dy = Math.abs(descriptor.bodyRect.y - pillStart());
                    const dw = Math.abs(descriptor.bodyRect.width - body.currentVisualWidth);
                    const dh = Math.abs(descriptor.bodyRect.height - body.currentVisualHeight);
                    root.check(dx <= 1 && dy <= 1 && dw <= 1 && dh <= 1, `published body follows the surface: ${dx} ${dy} ${dw} ${dh}`);
                    root.check(descriptor.bodyRect.y + descriptor.bodyRect.height > frame.cutoutTopInset + 40, "sheet extends past the cutout");
                    root.check((frame._islandSdfSlot.param.x > 0.5 && frame._islandSdfSlot.rect.y === frame.cutoutTopInset), "SDF slot active at the cutout edge");
                    if (!controller.launcherInputFocused)
                        return;
                    PopoutService.toggleDankLauncherV2();
                    next();
                    return;
                }
                case 6:
                    if (controller.expanded || body.motionRunning)
                        return;
                    root.check(!(ConnectedModeState.surfaceDescriptors[root.screen.name]?.island), "lease released once collapsed");
                    SettingsData.barConfigs = root.config(0, "normal");
                    next();
                    return;
                case 7:
                    if (body.motionRunning)
                        return;
                    PopoutService.openDankLauncherV2();
                    root.check(root.fallbackCalls === 1, "normal routing keeps the modal launcher");
                    SettingsData.barConfigs = root.config(0, "always", "right");
                    next();
                    return;
                case 8:
                    if (body.motionRunning || !slotPlaced("right"))
                        return;
                    pillOnSlot();
                    root.check(body.currentAlongPos > body.width / 2, `pill sits in the right section: ${body.currentAlongPos}`);
                    PopoutService.openDankLauncherV2();
                    next();
                    return;
                case 9: {
                    if (!controller.expanded || controller.activeActivity !== "launcher" || body.motionRunning)
                        return;
                    const descriptor = ConnectedModeState.surfaceDescriptor(root.screen.name, "island");
                    if (!descriptor.presented)
                        return;
                    root.check(Math.abs(descriptor.bodyRect.x - (body.hostOriginX + body.currentVisualX)) <= 1, "published body follows the right-section sheet");
                    root.check(descriptor.bodyRect.x + descriptor.bodyRect.width / 2 > root.screen.width / 2, `sheet bulges out right of centre: ${descriptor.bodyRect.x}+${descriptor.bodyRect.width}`);
                    root.check(descriptor.bodyRect.x + descriptor.bodyRect.width <= root.screen.width - Theme.spacingS + 0.5, `sheet stays on screen: ${descriptor.bodyRect.x + descriptor.bodyRect.width} vs ${root.screen.width}`);
                    root.check((frame._islandSdfSlot.param.x > 0.5 && frame._islandSdfSlot.rect.y === frame.cutoutTopInset), "SDF slot active for the right-section sheet");
                    controller.transientSurfaces.setActive(root, true, probe);
                    root.check(Array.from(frame.islandChrome.windows).includes(probe), "transient launcher window joins the frame grab");
                    controller.transientSurfaces.setActive(root, false, null);
                    root.check(!Array.from(frame.islandChrome.windows).includes(probe), "released transient window leaves the grab");
                    PopoutService.toggleDankLauncherV2();
                    next();
                    return;
                }
                case 10:
                    if (controller.expanded || body.motionRunning)
                        return;
                    root.check(!(ConnectedModeState.surfaceDescriptors[root.screen.name]?.island), "lease released after the right-section sheet");
                    finish("");
                    return;
                }
            } catch (error) {
                finish(error.message);
            }
        }
    }
}
