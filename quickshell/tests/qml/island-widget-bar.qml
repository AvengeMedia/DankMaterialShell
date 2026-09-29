import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankIsland
import qs.DankCommon.Common as DC

// A standard bar hosting the island widget in each section: the pill sits on its slot inside the band, the window is
// band sized at rest and grows only for the sheet, the exclusive zone never moves, and the sheet stays on screen.
ShellRoot {
    id: root

    readonly property var screen: Quickshell.screens[0]
    readonly property var cases: [
        {
            position: 0,
            section: "left"
        },
        {
            position: 0,
            section: "center"
        },
        {
            position: 0,
            section: "right"
        },
        {
            position: 1,
            section: "center"
        },
        {
            position: 1,
            section: "right"
        },
        {
            position: 2,
            section: "left"
        },
        {
            position: 2,
            section: "center"
        },
        {
            position: 2,
            section: "right"
        }
    ]
    property int caseIndex: 0
    readonly property string barId: "main" + caseIndex

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

    DankIsland {
        id: islands
    }

    function check(value, label) {
        if (!value)
            throw new Error(label);
    }

    function applyCase() {
        const current = root.cases[root.caseIndex];
        const widgets = {
            leftWidgets: ["clock"],
            centerWidgets: ["clock"],
            rightWidgets: ["clock"]
        };
        widgets[current.section + "Widgets"] = ["clock",
            {
                id: "island",
                enabled: true
            },
            "clock"];
        // Flat keys are what the bar used as a free island; the hosted island must ignore them.
        SettingsData.barConfigs = [Object.assign({
                id: root.barId,
                enabled: true,
                visible: true,
                position: current.position,
                islandFloating: true,
                islandPlacement: "free",
                islandSatellitePosition: "island",
                islandPalette: "dim",
                islandUseOverlayLayer: true,
                screenPreferences: ["all"]
            }, widgets)];
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
            SettingsData.frameEnabled = false;
            root.applyCase();
        }
    }

    Timer {
        id: steps

        property int index: 0
        property int waited: 0
        // A plain bar's window already carries its shadow padding; the island must add nothing at rest.
        property real restCross: 0
        property real restLeadingStart: 0
        property real lastSlotPos: -1
        property bool sprung: false
        property string lastOverlap: ""
        readonly property var body: IslandHostRegistry.hostFor(root.screen.name, root.barId)
        readonly property var slot: body?.slotItem ?? null
        readonly property var window: body?.hostWindow ?? null
        readonly property bool vertical: root.cases[root.caseIndex].position === 2
        readonly property bool farEdge: root.cases[root.caseIndex].position === 1 || root.cases[root.caseIndex].position === 3

        interval: 25
        repeat: true
        running: !!body && !!body.islandController

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

        function label(text) {
            return `case ${root.caseIndex} (${["top", "bottom", "left"][root.cases[root.caseIndex].position]} bar, ${root.cases[root.caseIndex].section}): ${text}`;
        }

        // Independent of the host's own anchor math: where the slot really is, in host coordinates.
        function slotCentreMapped() {
            const pos = slot.mapToItem(body, slot.width / 2, slot.height / 2);
            return vertical ? pos.y : pos.x;
        }

        function homeFace(item) {
            for (const child of item.children) {
                if (child.activity === "home" && child.face !== undefined && child.item)
                    return child;
                const found = homeFace(child);
                if (found)
                    return found;
            }
            return null;
        }

        function faceCentre() {
            const face = homeFace(body.surface);
            if (!face)
                return NaN;
            const pos = face.mapToItem(body, face.width / 2, face.height / 2);
            return vertical ? pos.y : pos.x;
        }

        // Moves with the band when a far-edge window grows.
        function leadingCross() {
            const leading = body.barBody.sectionRectFor("left");
            return vertical ? leading.x : leading.y;
        }

        function windowCross() {
            return vertical ? window.implicitWidth : window.implicitHeight;
        }

        function pillCrossStart() {
            return vertical ? body.currentVisualX : body.currentVisualY;
        }

        function pillCrossEnd() {
            return vertical ? body.currentVisualX + body.currentVisualWidth : body.currentVisualY + body.currentVisualHeight;
        }

        // A far-edge sheet grows away from the screen edge, into negative host coordinates.
        function sheetOut() {
            return farEdge ? pillCrossStart() < -40 : pillCrossEnd() > body.bandThickness + 40;
        }

        function pillAlongCentre() {
            return body.currentAlongPos + body.currentVisualAlong / 2;
        }

        function slotSize() {
            return vertical ? slot.height : slot.width;
        }

        function intersects(rect) {
            if (!rect || rect.w <= 0 || rect.h <= 0)
                return false;
            const x = body.originOffsetX + body.currentVisualX;
            const y = body.originOffsetY + body.currentVisualY;
            return x < rect.x + rect.w && x + body.currentVisualWidth > rect.x && y < rect.y + rect.h && y + body.currentVisualHeight > rect.y;
        }

        // Rows re-place siblings on polish, one frame after the slot resizes: wait for the slot to hold still across two ticks and for the neighbours to have moved out of its way.
        function layoutPending() {
            const pos = slotCentreMapped();
            const moved = Math.abs(pos - lastSlotPos) > 0.5;
            lastSlotPos = pos;
            lastOverlap = overlapsNeighbour();
            return moved || lastOverlap !== "";
        }

        function overlapsNeighbour() {
            const wrapper = slot.parent.parent;
            for (const sibling of wrapper.parent.children) {
                const item = sibling === wrapper ? null : (sibling.widgetItem ?? sibling.item ?? null);
                if (!item || !item.visible || item.width <= 0 || item.height <= 0)
                    continue;
                const pos = item.mapToItem(null, 0, 0);
                if (intersects({
                    x: pos.x,
                    y: pos.y,
                    w: item.width,
                    h: item.height
                }))
                    return `sibling at ${pos.x},${pos.y} ${item.width}x${item.height} vs pill ${body.originOffsetX + body.currentVisualX},${body.originOffsetY + body.currentVisualY} ${body.currentVisualWidth}x${body.currentVisualHeight} (slot ${slot.mapToItem(null, 0, 0).x} ${slot.width}, section ${wrapper.parent.width})`;
            }
            const section = root.cases[root.caseIndex].section;
            const leading = body.barBody.sectionRectFor("left");
            const trailing = body.barBody.sectionRectFor("right");
            if (section !== "left" && intersects(leading))
                return "leading section " + JSON.stringify(leading);
            if (section !== "right" && intersects(trailing))
                return "trailing section " + JSON.stringify(trailing);
            return "";
        }

        function checkRest(context) {
            root.check(body.chrome === "band", label("standard hosting wears the band"));
            root.check(!body.freeMode && !body.floating, label("island-mode placement keys do not leak into the hosted island"));
            root.check(pillCrossStart() >= 0 && pillCrossEnd() <= body.bandThickness + 0.5, label(`${context}: pill inside the band ${pillCrossStart()}..${pillCrossEnd()} vs ${body.bandThickness}`));
            root.check(Math.abs(slotSize() - body.compactTargetSize) <= 0.5, label(`${context}: slot reserves the compact size ${slotSize()} vs ${body.compactTargetSize}`));
            root.check(Math.abs(slotSize() - body.currentVisualAlong) <= 1, label(`${context}: pill fills its slot ${body.currentVisualAlong} vs ${slotSize()}`));
            root.check(Math.abs(pillAlongCentre() - slotCentreMapped()) <= 1, label(`${context}: pill centred on its slot ${pillAlongCentre()} vs ${slotCentreMapped()}`));
            if (context !== "wide face")
                root.check(Math.abs(faceCentre() - pillAlongCentre()) <= 1, label(`${context}: compact face drawn on its pill ${faceCentre()} vs ${pillAlongCentre()}`));
            const overlap = overlapsNeighbour();
            root.check(!overlap, label(`${context}: pill clear of its neighbours: ${overlap}`));
            if (restCross <= 0)
                restCross = windowCross();
            root.check(restCross < body.bandThickness + 48 && Math.abs(windowCross() - restCross) <= 1, label(`${context}: window keeps its rest size ${windowCross()} vs ${restCross} (band ${body.bandThickness})`));
            root.check(Math.abs(window.exclusiveZone - body.bandThickness) <= 1, label(`${context}: exclusive zone is the band ${window.exclusiveZone} vs ${body.bandThickness}`));
        }

        onTriggered: {
            if (++waited > 240) {
                finish(label(!slot ? "slot never registered" : index === 4 ? "window never shrank back after collapse" : "timed out at step " + index + (lastOverlap ? ", still overlapping: " + lastOverlap : "")));
                return;
            }
            const controller = body.islandController;
            try {
                switch (index) {
                case 0:
                    if (!slot || body.motionRunning || body.bandThickness <= 0 || window.exclusiveZone <= 0 || body.compactTargetSize <= 0 || slotSize() !== body.compactTargetSize || layoutPending())
                        return;
                    restLeadingStart = leadingCross();
                    root.check(ShellLayout.standaloneScreens(root.barId).length === 1, label("the bar keeps its own window"));
                    root.check(slot.parent.section === root.cases[root.caseIndex].section, label("slot sits in the configured section"));
                    root.check(window.mask.regions.some(region => region.item === body.inputMaskItem), label("bar mask carries the island envelope"));
                    checkRest("home");
                    controller.requestSystemActivity("volume");
                    next();
                    return;
                case 1:
                    if (controller.activeActivity !== "volume" || body.motionRunning || slotSize() !== body.compactTargetSize || layoutPending())
                        return;
                    root.check(body.compactTargetSize >= 200, label("volume face is wide"));
                    checkRest("wide face");
                    controller.finishTransient();
                    next();
                    return;
                case 2:
                    if (controller.activeActivity !== "home" || body.motionRunning || slotSize() !== body.compactTargetSize || layoutPending())
                        return;
                    checkRest("home again");
                    controller.requestToggle(true);
                    next();
                    return;
                case 3:
                    if (!controller.expanded || body.motionRunning || !sheetOut())
                        return;
                    root.check(windowCross() >= body.hostThickness - 1, label(`window grew for the sheet ${windowCross()} vs ${body.hostThickness}`));
                    root.check(Math.abs(window.exclusiveZone - body.bandThickness) <= 1, label("exclusive zone stays the band while expanded"));
                    root.check(body.currentAlongPos >= 0 && body.currentAlongPos + body.currentVisualAlong <= (vertical ? body.height : body.width), label(`sheet stays inside the bar ${body.currentAlongPos}..${body.currentAlongPos + body.currentVisualAlong}`));
                    root.check(body.surface.embeddedJoinRadius > 0, label("join corners are visible"));
                    // The content starts past the fold: the sheet clears the band by exactly its content size.
                    const contentCross = vertical ? controller.expandedTarget.width : controller.expandedTarget.height;
                    const pastBand = farEdge ? -pillCrossStart() : pillCrossEnd() - body.bandThickness;
                    root.check(Math.abs(pastBand - contentCross) <= 1, label(`sheet content clears the band ${pastBand} vs ${contentCross} (inset ${body.nearInset})`));
                    // A far-edge band moves by the growth; the section rects the dismiss holes use must follow it.
                    root.check(Math.abs((leadingCross() - restLeadingStart) - (farEdge ? windowCross() - restCross : 0)) <= 1, label(`section rects follow the band ${leadingCross()} vs rest ${restLeadingStart}, growth ${windowCross() - restCross}`));
                    controller.requestCollapse();
                    next();
                    return;
                case 4:
                    if (controller.expanded || body.motionRunning || Math.abs(windowCross() - restCross) > 1 || layoutPending())
                        return;
                    checkRest("after collapse");
                    if (root.caseIndex + 1 >= root.cases.length) {
                        // One real spring at the end: the window must stay grown until the sheet has fully sprung back.
                        SettingsData.reduceMotion = false;
                        controller.requestToggle(true);
                        next();
                        return;
                    }
                    index = 0;
                    waited = 0;
                    restCross = 0;
                    lastSlotPos = -1;
                    root.caseIndex++;
                    root.applyCase();
                    return;
                case 5:
                    if (!controller.expanded || body.motionRunning || !sheetOut())
                        return;
                    root.check(windowCross() >= body.hostThickness - 1, label(`window grew for the sprung sheet ${windowCross()} vs ${body.hostThickness}`));
                    controller.requestCollapse();
                    next();
                    return;
                case 6:
                    if (body.motionRunning) {
                        sprung = true;
                        if (sheetOut())
                            root.check(body.sheetOut && windowCross() >= body.hostThickness - 1, label(`window holds its size while the sheet springs back ${windowCross()} vs ${body.hostThickness}`));
                        return;
                    }
                    if (controller.expanded || Math.abs(windowCross() - restCross) > 1)
                        return;
                    root.check(sprung, label("collapse ran a real spring"));
                    root.check(!body.sheetOut, label("latch clears once the spring settles"));
                    finish("");
                    return;
                }
            } catch (error) {
                finish(error.message);
            }
        }
    }
}
