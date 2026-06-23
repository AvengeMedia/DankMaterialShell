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

    readonly property string managedTheme: {
        if (typeof SettingsData === "undefined")
            return "";
        const t = SettingsData.resolveIconTheme();
        return (!t || t === "System Default") ? "" : t;
    }

    property var _searchDirs: []
    property string _dirsForTheme: ""
    property var _cache: ({})
    property int revision: 0
    property bool _bumpPending: false

    readonly property var _baseDirs: {
        const xdg = Quickshell.env("XDG_DATA_DIRS") || "";
        const localData = Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation));
        const home = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation));
        const dataDirs = xdg.trim() !== "" ? xdg.split(":").concat([localData]) : ["/usr/share", "/usr/local/share", localData];
        return dataDirs.map(d => d + "/icons").concat([home + "/.icons"]);
    }

    onManagedThemeChanged: _rebuild()
    Component.onCompleted: _rebuild()

    function _bumpRevision() {
        if (_bumpPending)
            return;
        _bumpPending = true;
        Qt.callLater(() => {
            _bumpPending = false;
            revision++;
        });
    }

    function _rebuild() {
        _cache = ({});
        if (!managedTheme) {
            _searchDirs = [];
            _dirsForTheme = "";
            _bumpRevision();
            return;
        }
        const theme = managedTheme;
        const bases = _baseDirs.join(" ");
        const script = `BASES="${bases}"
find_index() { for b in $BASES; do [ -f "$b/$1/index.theme" ] && { echo "$b/$1/index.theme"; return 0; }; done; return 1; }
visited=""; queue="${theme}"; order=""
while [ -n "$queue" ]; do
  cur=\${queue%% *}; rest=\${queue#"$cur"}; queue=\${rest# }
  [ -z "$cur" ] && continue
  case " $visited " in *" $cur "*) continue;; esac
  visited="$visited $cur"; order="$order $cur"
  idx=$(find_index "$cur") || continue
  inh=$(sed -n 's/^Inherits=//p' "$idx" | head -1 | tr -d '"' | tr ',' ' ')
  queue="$queue $inh"
done
case " $visited " in *" hicolor "*) ;; *) order="$order hicolor";; esac
for t in $order; do for b in $BASES; do d="$b/$t"; [ -d "$d" ] && echo "$d"; done; done`;

        Proc.runCommand("iconChain:" + theme, ["sh", "-c", script], (out, code) => {
            if (root.managedTheme !== theme)
                return;
            root._searchDirs = (out || "").trim().split("\n").filter(s => s);
            root._dirsForTheme = theme;
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
        if (_dirsForTheme !== managedTheme || _searchDirs.length === 0)
            return "";
        if (name in _cache)
            return _cache[name] || "";
        _cache[name] = null;
        _resolveAsync(name);
        return "";
    }

    function _resolveAsync(name) {
        const dirs = _searchDirs.join(" ");
        const script = `find -L ${dirs} \\( -name '${name}.svg' -o -name '${name}.png' \\) 2>/dev/null`;
        Proc.runCommand("iconResolve:" + name, ["sh", "-c", script], (out, code) => {
            const paths = (out || "").trim().split("\n").filter(s => s);
            const best = root._pickBest(paths);
            const c = root._cache;
            c[name] = best ? Paths.toFileUrl(best) : "";
            root._cache = c;
            root._bumpRevision();
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
        return _searchDirs.length;
    }

    function _score(path) {
        let s = 0;
        if (path.includes("/apps/"))
            s += 3000000000;
        else if (path.includes("/categories/"))
            s += 1000000000;
        else if (path.includes("/places/") || path.includes("/devices/") || path.includes("/mimetypes/") || path.includes("/status/") || path.includes("/actions/"))
            s += 100000000;

        s += Math.max(0, (64 - _chainIndex(path))) * 1000000;

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
