import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const index = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Services/IconThemeIndex.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), index);
const searchDirs = ["/user/theme", "/system/theme", "/system/inherited", "/system/hicolor"];
const looseDirs = ["/user/icons", "/system/pixmaps"];

function build(paths) {
    const result = index.create();
    for (const path of paths)
        index.add(result, path, searchDirs, looseDirs);
    return result.paths;
}

test("index keeps the existing category, root, format, size and tie priorities", () => {
    const cases = [
        ["/user/theme/actions/icon.svg", "/system/inherited/apps/icon.png"],
        ["/system/theme/apps/scalable/icon.svg", "/user/theme/apps/16/icon.png"],
        ["/user/theme/apps/512/icon.png", "/user/theme/apps/16/icon.svg"],
        ["/user/theme/apps/512/icon.svg", "/user/theme/apps/scalable/icon.svg"],
        ["/user/theme/apps/16x16/icon.png", "/user/theme/apps/48x48@2x/icon.png"],
        ["/system/pixmaps/icon.svg", "/user/icons/icon.png"]
    ];
    for (const [loser, winner] of cases) {
        assert.equal(build([loser, winner]).icon, winner);
        assert.equal(build([winner, loser]).icon, winner);
    }
    const ties = ["/user/theme/apps/a/icon.svg", "/user/theme/apps/b/icon.svg"];
    assert.equal(build(ties).icon, ties[0]);
});

test("index bounds retained paths by resolvable names and handles object property names", () => {
    const paths = ["/user/theme/apps/icon.svg", "/user/theme/apps/16/icon.png", "/system/pixmaps/loose.xpm", "/user/theme/apps/__proto__.svg", "/user/theme/apps/constructor.png", "/user/theme/apps/not a name.svg"];
    const result = build(paths);
    assert.equal(Object.keys(result).length, 4);
    assert.equal(result.__proto__, paths[3]);
    assert.equal(result.constructor, paths[4]);
    assert.equal(result.loose, paths[2]);
});

test("first lookup uses the completed index without spawning or retaining misses", () => {
    const source = readFileSync(process.env.ICON_SERVICE_SOURCE || new URL("../Services/IconThemeService.qml", import.meta.url), "utf8");
    const resolve = source.match(/^    function resolve\(name\) \{[\s\S]*?^    \}/m)[0];
    let spawns = 0;
    const context = vm.createContext({
        _iconPaths: build(["/user/theme/apps/icon.svg"]),
        Paths: { toFileUrl: path => "file://" + path },
        revision: 0, managedTheme: "theme", _dirsForTheme: "theme", _cache: {},
        _resolveAsync: () => spawns++
    });
    vm.runInContext(resolve, context);
    assert.equal(context.resolve("icon"), "file:///user/theme/apps/icon.svg");
    for (let i = 0; i < 100; i++)
        assert.equal(context.resolve("missing-" + i), "");
    assert.equal(spawns, 0);
    assert.equal(Object.keys(context._iconPaths).length, 1);
});
