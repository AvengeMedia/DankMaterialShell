pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root
    readonly property var log: Log.scoped("IconThemeService")

    readonly property string settingsTheme: {
        if (typeof SettingsData === "undefined")
            return "";
        const t = SettingsData.resolveIconTheme();
        return (!t || t === "System Default") ? "" : t;
    }
    property string systemProbedTheme: ""
    readonly property string managedTheme: settingsTheme || systemProbedTheme

    property var _searchDirs: []
    property string _dirsForTheme: ""
    property var _cache: ({})
    property var _looseIconPaths: ({})
    property int _cacheGeneration: 0
    property int _rebuildGeneration: 0
    property int _looseIndexGeneration: 0
    property int revision: 0
    property bool _bumpPending: false

    // XDG icon spec order: user dirs win over system ones, so overrides in ~/.local/share/icons beat installed themes.
    readonly property var _userIconRoots: {
        const localData = Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation));
        const home = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation));
        return [home + "/.icons", localData + "/icons"];
    }

    readonly property var _dataDirs: {
        const xdg = Quickshell.env("XDG_DATA_DIRS") || "";
        const localData = Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation));
        const dataDirs = xdg.trim() !== "" ? [localData].concat(xdg.split(":")) : [localData, "/usr/local/share", "/usr/share"];
        for (const flatpak of [localData + "/flatpak/exports/share", "/var/lib/flatpak/exports/share"]) {
            if (!dataDirs.includes(flatpak))
                dataDirs.push(flatpak);
        }
        return dataDirs.filter((dir, index) => dir && dataDirs.indexOf(dir) === index);
    }

    readonly property var _baseDirs: {
        const bases = [..._userIconRoots];
        for (const d of _dataDirs) {
            const icons = d + "/icons";
            if (!bases.includes(icons))
                bases.push(icons);
        }
        return bases;
    }

    // Loose icon files (AppImage managers, legacy /usr/share/pixmaps installs) live outside any theme.
    readonly property var _looseDirs: {
        const dirs = _userIconRoots.concat(_dataDirs.map(d => d + "/pixmaps"));
        return dirs.filter((dir, index) => dirs.indexOf(dir) === index);
    }

    onManagedThemeChanged: _rebuild()
    Component.onCompleted: {
        Paths.iconResolver = name => resolve(name);
        _probeSystemTheme();
        _rebuild();
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root._indexLooseIcons(() => root._invalidateMisses());
        }
    }

    // "System Default" leaves Qt's lookup, which sees only hicolor unless a Qt platform theme or QS_ICON_THEME is configured.
    function _probeSystemTheme() {
        if (Quickshell.env("QS_ICON_THEME"))
            return;
        const script = `v=$(sed -n 's/^gtk-icon-theme-name *= *//p' "\${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" 2>/dev/null | head -1)
[ -z "$v" ] && v=$(${GSettings.getCmd("org.gnome.desktop.interface", "icon-theme")})
printf '%s' "$v" | tr -d "'\\""`;

        Proc.runCommand("iconThemeProbe", ["sh", "-c", script], (out, code) => {
            const theme = (out || "").trim();
            if (!theme)
                return;
            root.systemProbedTheme = theme;
        });
    }

    function _bumpRevision() {
        if (_bumpPending)
            return;
        _bumpPending = true;
        Qt.callLater(() => {
            _bumpPending = false;
            revision++;
        });
    }

    function _invalidateMisses() {
        const c = {};
        let changed = false;
        for (const name in _cache) {
            if (_cache[name])
                c[name] = _cache[name];
            else
                changed = true;
        }
        if (!changed)
            return;
        _cacheGeneration++;
        _cache = c;
        _bumpRevision();
    }

    function _indexLooseIcons(callback) {
        const generation = ++_looseIndexGeneration;
        const args = ["find", "-L"].concat(_looseDirs, ["-maxdepth", "1", "(", "-name", "*.svg", "-o", "-name", "*.png", "-o", "-name", "*.xpm", ")"]);
        Proc.runCommand("iconLooseIndex", args, (out, code) => {
            if (root._looseIndexGeneration !== generation)
                return;
            const index = {};
            const paths = (out || "").trim().split("\n").filter(s => s);
            for (const path of paths) {
                const fileName = path.substring(path.lastIndexOf("/") + 1);
                const name = fileName.replace(/\.(svg|png|xpm)$/, "");
                const current = index[name];
                index[name] = current ? root._pickBest([current, path]) : path;
            }
            root._looseIconPaths = index;
            if (callback)
                callback();
        }, 0);
    }

    function _rebuild() {
        const rebuildGeneration = ++_rebuildGeneration;
        _cacheGeneration++;
        _cache = ({});
        _dirsForTheme = "";
        _indexLooseIcons(() => root._invalidateMisses());
        if (!managedTheme) {
            _searchDirs = [];
            _bumpRevision();
            return;
        }
        const theme = managedTheme;
        const script = `theme=$1
shift
find_index() { target=$1; shift; for b; do [ -f "$b/$target/index.theme" ] && { echo "$b/$target/index.theme"; return 0; }; done; return 1; }
visited=""; queue="$theme"; order=""
while [ -n "$queue" ]; do
cur=\${queue%% *}; rest=\${queue#"$cur"}; queue=\${rest# }
[ -z "$cur" ] && continue
case " $visited " in *" $cur "*) continue;; esac
visited="$visited $cur"; order="$order $cur"
idx=$(find_index "$cur" "$@") || continue
inh=$(sed -n 's/^Inherits=//p' "$idx" | head -1 | tr -d '"' | tr ',' ' ')
queue="$queue $inh"
done
case " $visited " in *" hicolor "*) ;; *) order="$order hicolor";; esac
for t in $order; do for b; do d="$b/$t"; [ -d "$d" ] && echo "$d"; done; done`;

        Proc.runCommand("iconChain:" + theme, ["sh", "-c", script, "icon-chain", theme].concat(_baseDirs), (out, code) => {
            if (root.managedTheme !== theme || root._rebuildGeneration !== rebuildGeneration)
                return;
            root._searchDirs = (out || "").trim().split("\n").filter(s => s);
            root._dirsForTheme = theme;
            root._cacheGeneration++;
            root._cache = ({});
            root._bumpRevision();
        });
    }

    function resolve(name) {
        const _dep = revision;
        if (!managedTheme || !name)
            return "";
        if (name.startsWith("/") || name.startsWith("file://") || name.startsWith("image://") || name.startsWith("~"))
            return "";
        if (!/^[\w.+-]+$/.test(name))
            return "";
        if (_dirsForTheme !== managedTheme)
            return "";
        if (name in _cache)
            return _cache[name] || "";
        _cache[name] = null;
        _resolveAsync(name);
        return "";
    }

    function _resolveAsync(name) {
        const generation = _cacheGeneration;

        function finish(paths) {
            if (root._cacheGeneration !== generation)
                return;
            const best = paths.length > 0 ? root._pickBest(paths) : root._looseIconPaths[name] || "";
            const c = root._cache;
            c[name] = best ? Paths.toFileUrl(best) : "";
            root._cache = c;
            root._bumpRevision();
        }

        if (_searchDirs.length === 0) {
            finish([]);
            return;
        }

        const args = ["find", "-L"].concat(_searchDirs, ["(", "-name", name + ".svg", "-o", "-name", name + ".png", ")"]);
        Proc.runCommand("iconResolveTheme:" + name, args, (out, code) => {
            const paths = (out || "").trim().split("\n").filter(s => s);
            finish(paths);
        }, 0);
    }

    function _pickBest(paths) {
        let best = "";
        let bestScore = -1;
        for (let i = 0; i < paths.length; i++) {
            const s = _score(paths[i]);
            if (s > bestScore) {
                bestScore = s;
                best = paths[i];
            }
        }
        return best;
    }

    function _chainIndex(path) {
        for (let i = 0; i < _searchDirs.length; i++) {
            if (path.startsWith(_searchDirs[i] + "/"))
                return i;
        }
        for (let i = 0; i < _looseDirs.length; i++) {
            if (path.startsWith(_looseDirs[i] + "/"))
                return _searchDirs.length + i;
        }
        return _searchDirs.length + _looseDirs.length;
    }

    function _score(path) {
        let s = 0;
        if (path.includes("/apps/"))
            s += 3000000000;
        else if (path.includes("/categories/"))
            s += 1000000000;
        else if (path.includes("/places/") || path.includes("/devices/") || path.includes("/mimetypes/") || path.includes("/status/") || path.includes("/actions/"))
            s += 100000000;

        s += Math.min(99, Math.max(0, _searchDirs.length + _looseDirs.length - _chainIndex(path))) * 1000000;

        if (path.endsWith(".svg"))
            s += 100000;

        if (path.includes("/scalable/")) {
            s += 1000;
        } else {
            const m = path.match(/\/(\d+)(?:x\d+)?(?:@\d+x)?\//);
            if (m)
                s += Math.min(parseInt(m[1]), 999);
        }
        return s;
    }
}
