pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Common

// PaletteInjectService owns ~/.config/matugen/palette-inject.json, the file the
// DMS core reads on each theme build to run external palette commands. The UI
// edits this list; the core consumes it. The file uses the {"palettes": [...]}
// shape; a legacy single-object file is read transparently and rewritten as a
// list on the next save.
Singleton {
    id: root

    readonly property var log: Log.scoped("PaletteInjectService")

    readonly property string configRoot: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string dir: configRoot + "/matugen"
    readonly property string filePath: dir + "/palette-inject.json"

    property var palettes: []
    property bool loaded: false

    function load() {
        configFile.path = "";
        configFile.path = root.filePath;
    }

    function newPalette(namespace) {
        return {
            "enabled": true,
            "namespace": namespace,
            "command": "",
            "args": [],
            "output_file": ""
        };
    }

    function nextPaletteName() {
        var used = {};
        for (var i = 0; i < root.palettes.length; i++)
            used[root.palettes[i].namespace] = true;
        var n = 1;
        while (used["palette" + n])
            n++;
        return "palette" + n;
    }

    function addPalette() {
        var next = root.palettes.slice();
        next.push(root.newPalette(root.nextPaletteName()));
        root.palettes = next;
        root.save();
    }

    function removePalette(index) {
        if (index < 0 || index >= root.palettes.length)
            return;
        var next = root.palettes.slice();
        next.splice(index, 1);
        root.palettes = next;
        root.save();
    }

    function updatePalette(index, field, value) {
        if (index < 0 || index >= root.palettes.length)
            return;
        var next = root.palettes.slice();
        var entry = Object.assign({}, next[index]);
        entry[field] = value;
        next[index] = entry;
        root.palettes = next;
        root.save();
    }

    // argsText/argsFromText bridge the array core schema and a single-line field:
    // arguments are shown space-joined and split back on whitespace, so simple
    // commands (e.g. run {image} --format json) round-trip cleanly.
    function argsText(entry) {
        var a = entry && entry.args ? entry.args : [];
        return a.join(" ");
    }

    function argsFromText(text) {
        var trimmed = (text || "").trim();
        if (trimmed.length === 0)
            return [];
        return trimmed.split(/\s+/);
    }

    function save() {
        var payload = {
            "palettes": root.palettes
        };
        Proc.runCommand("", ["mkdir", "-p", root.dir], () => {
            configFile.setText(JSON.stringify(payload, null, 2));
        });
    }

    function normalize(data) {
        var list = [];
        var raw = (data && data.palettes && data.palettes.length !== undefined) ? data.palettes : (data && data.command !== undefined ? [data] : []);
        for (var i = 0; i < raw.length; i++) {
            var e = raw[i] || {};
            list.push({
                "enabled": e.enabled === true,
                "namespace": e.namespace || "",
                "command": e.command || "",
                "args": (e.args && e.args.length !== undefined) ? e.args : [],
                "output_file": e.output_file || ""
            });
        }
        return list;
    }

    FileView {
        id: configFile
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            try {
                root.palettes = root.normalize(JSON.parse(text()));
            } catch (e) {
                root.log.warn("Failed to parse palette-inject.json:", e);
                root.palettes = [];
            }
            root.loaded = true;
        }

        onLoadFailed: {
            root.palettes = [];
            root.loaded = true;
        }
    }
}
