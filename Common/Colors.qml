pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform           // ← gives us StandardPaths

Singleton {
    id: root

    /* ────────────────  basic state ──────────────── */
    signal colorsUpdated()

    readonly property string _homeUrl: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string homeDir:  _homeUrl.startsWith("file://")
                                        ? _homeUrl.substring(7)
                                        : _homeUrl
    readonly property string wallpaperPath: homeDir + "/quickshell/current_wallpaper"

    property bool   matugenAvailable: false
    property string matugenJson:      ""
    property var    matugenColors:    ({})

    Component.onCompleted: {
        console.log("Colors.qml → home =", homeDir)
        matugenCheck.running = true          // kick off the chain
    }

    /* ────────────────  availability checks ──────────────── */
    Process {
        id: matugenCheck
        command: ["which", "matugen"]
        onExited: (code) => {
            matugenAvailable = (code === 0)
            console.log("Matugen in PATH:", matugenAvailable)

            if (!matugenAvailable) {
                console.warn("Matugen missing → dynamic theme disabled")
                Theme.rootObj.wallpaperErrorStatus = "matugen_missing"
                return
            }
            fileChecker.running = true
        }
    }

    Process {
        id: fileChecker                       // exists & readable?
        command: ["test", "-r", wallpaperPath]
        onExited: (code) => {
            if (code === 0) {
                matugenProcess.running = true
            } else {
                console.error("code", code)
                console.error("Wallpaper not found:", wallpaperPath)
                Theme.rootObj.showWallpaperError()
            }
        }
    }

    /* ────────────────  matugen invocation ──────────────── */
    Process {
        id: matugenProcess
        command: ["matugen", "-v", "image", wallpaperPath, "--json", "hex"]

        /* ── grab stdout as a stream ── */
        stdout: StdioCollector {
            id: matugenCollector
            onStreamFinished: {
                const out = matugenCollector.text
                if (!out.length) {
                    console.error("matugen produced zero bytes\nstderr:", matugenProcess.stderr)
                    Theme.rootObj.showWallpaperError()
                    return
                }
                try {
                    root.matugenJson   = out
                    root.matugenColors = JSON.parse(out)
                    root.colorsUpdated()
                    Theme.rootObj.wallpaperErrorStatus = ""
                } catch (e) {
                    console.error("JSON parse failed:", e)
                    Theme.rootObj.showWallpaperError()
                }
            }
        }

        /* grab stderr too, so we can print it above */
        stderr: StdioCollector { id: matugenErr }
    }

    /* ────────────────  public helper ──────────────── */
    function extractColors() {
        if (matugenAvailable)
            fileChecker.running = true
        else
            matugenCheck.running = true
    }

    function getMatugenColor(path, fallback) {
        let cur = matugenColors?.colors?.dark
        for (const part of path.split(".")) {
            if (!cur || typeof cur !== "object" || !(part in cur))
                return fallback
            cur = cur[part]
        }
        return cur || fallback
    }

    /* ────────────────  color properties (MD3) ──────────────── */
    property color primary:               getMatugenColor("primary",                "#42a5f5")
    property color secondary:             getMatugenColor("secondary",              "#8ab4f8")
    property color tertiary:              getMatugenColor("tertiary",               "#bb86fc")
    property color tertiaryContainer:     getMatugenColor("tertiary_container",     "#3700b3")
    property color error:                 getMatugenColor("error",                  "#cf6679")
    property color inversePrimary:        getMatugenColor("inverse_primary",        "#6200ea")

    /* backgrounds */
    property color bg:                    getMatugenColor("background",             "#1a1c1e")
    property color surface:               getMatugenColor("surface",                "#1a1c1e")
    property color surfaceContainer:      getMatugenColor("surface_container",      "#1e2023")
    property color surfaceContainerHigh:  getMatugenColor("surface_container_high", "#292b2f")
    property color surfaceVariant:        getMatugenColor("surface_variant",        "#44464f")

    /* text */
    property color surfaceText:           getMatugenColor("on_background",          "#e3e8ef")
    property color primaryText:           getMatugenColor("on_primary",             "#ffffff")
    property color surfaceVariantText:    getMatugenColor("on_surface_variant",     "#c4c7c5")

    /* containers & misc */
    property color primaryContainer:      getMatugenColor("primary_container",      "#1976d2")
    property color surfaceTint:           getMatugenColor("surface_tint",           "#8ab4f8")
    property color outline:               getMatugenColor("outline",                "#8e918f")

    /* legacy aliases */
    property color accentHi: primary
    property color accentLo: secondary

    function isColorDark(c) {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5
    }
}
