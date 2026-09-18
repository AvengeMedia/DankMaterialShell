import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const resolver = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/LayoutResolver.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), resolver);
const plain = value => JSON.parse(JSON.stringify(value));
const screens = [
    { name: "DP-1", model: "Panel", x: 0, y: 0, width: 1920, height: 1080, scale: 1 },
    { name: "DP-2", model: "Panel", x: 1920, y: 0, width: 1600, height: 900, scale: 1.25 }
];
const islandDefaults = { islandReserveThickness: 40, islandCompactThickness: 38, islandOuterGap: 4 };
const bar = (id, position = 0, values = {}) => ({ id, position, enabled: true, ...values });

function resolve(configs, options = {}, screen = screens[0]) {
    return resolver.resolveScreen(configs.map(config => ({
        config, wingSize: config.gothCornersEnabled ? 12 : 0, barThickness: 40, popupThickness: 40, islandThickness: resolver.islandThickness(config, islandDefaults)
    })), screen, {
        screens, displayNameMode: "name", framePreferences: ["all"], effectiveFrameEnabled: false,
        effectiveConnected: false, frameThickness: 12, frameBarSize: 48, ...options
    });
}

test("island metrics clamp each setting and reserve the larger of strip and gap plus compact", () => {
    assert.deepEqual(plain(resolver.islandMetrics({}, islandDefaults)), { reserve: 40, compact: 38, gap: 4, thickness: 42 });
    assert.deepEqual(plain(resolver.islandMetrics({ islandReserveThickness: 500, islandCompactThickness: 1, islandOuterGap: -3 }, islandDefaults)), { reserve: 128, compact: 24, gap: 0, thickness: 128 });
    assert.equal(resolver.islandThickness({ islandReserveThickness: 30, islandCompactThickness: 60, islandOuterGap: 10 }, islandDefaults), 70);
});

test("absent, empty, explicit and fallback assignments remain distinct", () => {
    for (const count of [1, 2]) {
        const live = screens.slice(0, count);
        const covers = config => resolver.coversScreen(config, screens[0], live, "name");
        assert.equal(covers({}), true);
        assert.equal(covers({ screenPreferences: [] }), false);
        assert.equal(covers({ screenPreferences: ["all"] }), true);
        assert.equal(covers({ screenPreferences: ["DP-2"] }), false);
        assert.equal(covers({ screenPreferences: [], showOnLastDisplay: true }), count === 1);
        assert.equal(covers({ screenPreferences: ["missing"], showOnLastDisplay: true }), count === 1);
    }
});

test("model assignments follow screen position and preserve connector matching", () => {
    assert.equal(resolver.screenModelIndex(screens[1], screens), 1);
    assert.equal(resolver.screenModelIndex(screens[1], [screens[1]]), -1);
    for (const [preferences, mode, expected] of [
        [["Panel-1"], "model", true], [["Panel"], "model", false], [["Panel"], "name", true],
        [[{ model: "Panel", modelIndex: 1 }], "model", true], [[{ model: "Panel", modelIndex: 0 }], "model", false],
        [[{ name: "DP-2" }], "name", true], [["DP-2"], "model", true], [[], "model", false]
    ])
        assert.equal(resolver.screenMatches(screens[1], preferences, screens, mode), expected);
    const moved = [{ ...screens[0], x: 1920 }, { ...screens[1], x: 0 }];
    assert.equal(resolver.screenModelIndex(moved[1], moved), 0);
});

test("one to four mixed configs coexist in config order on every edge and frame mode", () => {
    for (const screen of screens)
        for (let count = 1; count <= 4; count++)
            for (let position = 0; position < 4; position++)
                for (const effectiveFrameEnabled of [false, true])
                    for (const effectiveConnected of [false, true]) {
                        const configs = ["z", "a", "m", "b"].slice(0, count).map((id, index) => bar(id, position, { island: index % 2 === 1, innerPadding: index * 2 }));
                        const layout = resolve(configs, { effectiveFrameEnabled, effectiveConnected }, screen);
                        assert.deepEqual(plain(layout.instances.map(instance => instance.barId)), configs.map(config => config.id));
                        let offset = 0;
                        for (const instance of layout.instances) {
                            assert.equal(instance.rowOffset, offset);
                            offset += instance.rowThickness;
                            assert.equal(instance.kind, configs[instance.configOrder].island ? "island" : effectiveFrameEnabled && effectiveConnected ? "frame" : "bar");
                        }
                        const band = layout.edges[["top", "bottom", "left", "right"][position]];
                        assert.equal(band.occupancy, offset);
                        assert.equal(band.reservation, offset);
                        if (layout.manualPlacement) {
                            const owned = layout.instances.reduce((sum, instance) => sum + instance.exclusionSize, 0);
                            assert.equal(owned + (effectiveFrameEnabled ? band.reservation : 0), offset);
                            assert.equal(layout.instances.every(instance => instance.exclusiveZone === -1), true);
                        }
                    }
});

test("row identity and occupancy stay fixed through reveal, floating and expansion", () => {
    const configs = [bar("z", 0, { autoHide: true }), bar("a", 0, { island: true, islandFloating: true }), bar("m")];
    const before = resolve(configs);
    const after = resolve(configs.map(config => ({ ...config, expanded: true, revealed: true })));
    assert.deepEqual(plain(after.instances), plain(before.instances));
    assert.deepEqual(plain(before.instances.map(instance => instance.reservation)), [0, 0, 130]);
    assert.equal(before.edges.top.reservation, 130);
    assert.equal(before.instances[0].exclusionSize, 130);
    assert.equal(before.edges.top.occupancy, 130);
    const resized = resolve(configs, {}, { ...screens[0], scale: 1.5, width: 1280 });
    assert.deepEqual(plain(before.instances.map(instance => instance.key)), plain(resized.instances.map(instance => instance.key)));
});

test("disabled and unassigned instances disappear; hidden bars keep row identity", () => {
    const layout = resolve([bar("disabled", 0, { enabled: false }), bar("missing", 0, { screenPreferences: [] }), bar("hidden", 0, { visible: false }), bar("visible")]);
    assert.deepEqual(plain(layout.instances.map(instance => instance.barId)), ["hidden", "visible"]);
    assert.deepEqual(plain(layout.instances.map(instance => instance.reservation)), [0, 88]);
});

test("accumulated clearance includes all islands and bars exactly once", () => {
    const configs = [bar("a", 0, { spacing: 2 }), bar("b", 0, { spacing: 10 }), bar("left", 2), bar("island", 0, { island: true })];
    const layout = resolve(configs);
    assert.equal(resolver.adjacentInfo(layout, configs[2], configs[0]).topBar, 46 + 60 + 42);
    assert.equal(resolver.adjacentInfo(layout, { autoHide: true }, configs[0]).topBar, 0);
    assert.equal(layout.instances.find(instance => instance.barId === "left").margins.top, 134);
    assert.equal(resolver.barBounds(layout, 40, 0, configs[1], configs[0], false, 0).y, 42);
    assert.equal(resolver.barBounds(layout, 40, 2, configs[2], configs[0], false, 0).y, 134);
});

test("frame overlays reserve once and every row retains its position", () => {
    const configs = [bar("hosted"), bar("island", 0, { island: true }), bar("overlay", 0, { useOverlayLayer: true })];
    const layout = resolve(configs, { effectiveFrameEnabled: true, effectiveConnected: true });
    assert.deepEqual(plain(layout.instances.map(instance => instance.kind)), ["frame", "island", "bar"]);
    assert.deepEqual(plain(layout.instances.map(instance => instance.rowOffset)), [0, 48, 90]);
    assert.equal(layout.edges.top.reservation, 138);
    assert.equal(layout.edges.top.frameExclusionEnabled, true);
    assert.equal(layout.instances.reduce((sum, instance) => sum + instance.exclusionSize, 0), 0);
    assert.equal(resolve(configs, { effectiveFrameEnabled: true, effectiveConnected: true, framePreferences: [] }).instances[0].kind, "bar");
});

test("popup triggers preserve each edge and connected gap policy", () => {
    const config = { bottomGap: 8, popupGapsAuto: false, popupGapsManual: 6 };
    const expected = [{ x: 20, y: 58, width: 24 }, { x: 20, y: 1022, width: 24 }, { x: 50, y: 30, width: 24 }, { x: 1870, y: 30, width: 24 }];
    for (let position = 0; position < 4; position++)
        assert.deepEqual(plain(resolver.popupTrigger({ x: 20, y: 30 }, screens[0], 40, 24, 4, position, config, null, false)), expected[position]);
    assert.equal(resolver.popupTrigger({ x: 20, y: 30 }, screens[0], 40, 24, 4, 0, config, null, true).y, 40);
});

test("painted wings keep rows apart and only the final wing extends past reservation", () => {
    const layout = resolve([bar("outer", 0, { gothCornersEnabled: true }), bar("inner", 0, { gothCornersEnabled: true })]);
    assert.deepEqual(plain(layout.instances.map(instance => instance.rowOffset)), [0, 56]);
    assert.equal(layout.edges.top.reservation, 100);
    assert.equal(layout.edges.top.occupancy, 112);
    assert.equal(layout.instances[0].paintedBounds.y + layout.instances[0].paintedBounds.height, layout.instances[1].paintedBounds.y);
});

test("surface origins include native cross-edge exclusions without adding manual margins twice", () => {
    const layout = resolve([bar("top"), bar("bottom", 1), bar("left", 2), bar("right", 3)]);
    assert.deepEqual(plain(resolver.surfaceOrigin(layout, 44, 992, { left: true, top: true, bottom: true }, {})), { x: 0, y: 44 });
    assert.deepEqual(plain(resolver.surfaceOrigin(layout, 1832, 44, { left: true, right: true, bottom: true }, {})), { x: 44, y: 1036 });
    assert.deepEqual(plain(resolver.surfaceOrigin(layout, 44, 992, { right: true, top: true, bottom: true }, { top: 44, bottom: 44, right: 44 })), { x: 1832, y: 44 });
    const frameIsland = resolve([bar("island", 0, { island: true })], { effectiveFrameEnabled: true });
    assert.equal(frameIsland.instances[0].rowOffset, 12);
    assert.equal(frameIsland.edges.top.reservation, 54);
});
