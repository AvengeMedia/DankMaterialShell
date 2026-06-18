pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property var log: Log.scoped("GreeterUsersService")

    readonly property string greetCfgDir: Quickshell.env("DMS_GREET_CFG_DIR") || "/var/cache/dms-greeter"
    readonly property string usersCacheDir: greetCfgDir + "/users"

    property var users: []
    property var usernames: []
    property var profileImageMap: ({})
    property bool loaded: false
    property bool refreshing: false

    Component.onCompleted: refresh()

    function refresh() {
        if (refreshing)
            return;
        refreshing = true;
        _loadUsers();
    }

    function displayName(username) {
        const u = _findUser(username);
        if (!u)
            return username || "";
        const gecos = (u.gecos || "").trim();
        return gecos.length > 0 ? gecos : username;
    }

    function optionLabel(username) {
        const label = displayName(username);
        return label !== username ? label : username;
    }

    function usernameFromOptionLabel(label) {
        for (let i = 0; i < users.length; i++) {
            if (root.optionLabel(users[i].username) === label)
                return users[i].username;
        }
        return label;
    }

    function hasSyncedTheme(username) {
        if (!username)
            return false;
        return syncedThemePaths[username] === true;
    }

    property var syncedThemePaths: ({})

    function userCacheDir(username) {
        if (!username)
            return "";
        return usersCacheDir + "/" + username;
    }

    function syncedSettingsPath(username) {
        const dir = userCacheDir(username);
        return dir ? dir + "/settings.json" : "";
    }

    function _findUser(name) {
        for (let i = 0; i < users.length; i++) {
            if (users[i].username === name)
                return users[i];
        }
        return null;
    }

    function _loadUsers() {
        Proc.runCommand("greeterUsersService-loadUsers", ["sh", "-c", "getent passwd | awk -F: '$3>=1000 && $3<60000 && $1!=\"nobody\" && $7!~/(nologin|false)$/ && $6!=\"/var/empty\" {print $1\":\"$3\":\"$5\":\"$6\":\"$7}'"], (output, exitCode) => {
            const lines = (output || "").trim().split("\n").filter(l => l.length > 0);
            const list = [];
            const names = [];
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split(":");
                if (parts.length < 5)
                    continue;
                const username = parts[0];
                list.push({
                    username,
                    uid: parseInt(parts[1], 10),
                    gecos: (parts[2] || "").split(",")[0],
                    home: parts[3] || "",
                    shell: parts[4] || ""
                });
                names.push(username);
            }
            list.sort((a, b) => a.username.localeCompare(b.username));
            names.sort((a, b) => a.localeCompare(b));
            root.users = list;
            root.usernames = names;
            root.loaded = true;
            root.refreshing = false;
            _refreshSyncedThemeFlags();
            _loadProfileIcons();
        }, 0);
    }

    function _refreshSyncedThemeFlags() {
        if (usernames.length === 0) {
            syncedThemePaths = ({});
            return;
        }
        const checks = usernames.map(u => `[ -f "${syncedSettingsPath(u)}" ] && echo "${u}:1" || echo "${u}:0"`).join("; ");
        Proc.runCommand("greeterUsersService-syncedThemes", ["sh", "-c", checks], (output, exitCode) => {
            const map = {};
            const lines = (output || "").trim().split("\n").filter(l => l.length > 0);
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split(":");
                if (parts.length >= 2)
                    map[parts[0]] = parts[1] === "1";
            }
            root.syncedThemePaths = map;
        }, 0);
    }

    function profileImagePath(username) {
        if (!username)
            return "";
        return profileImageMap[username] || "";
    }

    function _loadProfileIcons() {
        if (users.length === 0) {
            profileImageMap = ({});
            return;
        }
        const script = users.map(u => {
            const safeUser = u.username.replace(/'/g, "'\\''");
            const safeHome = (u.home || "").replace(/'/g, "'\\''");
            const cacheDir = usersCacheDir + "/" + u.username;
            return `( icon=""; for f in "${cacheDir}/profile.jpg" "${cacheDir}/profile.jpeg" "${cacheDir}/profile.png" "${cacheDir}/profile.webp" "/var/lib/AccountsService/icons/${safeUser}" "${safeHome}/.face" "${safeHome}/.face.icon"; do if [ -f "$f" ] && [ -r "$f" ]; then icon="$f"; break; fi; done; echo "${u.username}:$icon" )`;
        }).join("; ");
        Proc.runCommand("greeterUsersService-profileIcons", ["sh", "-c", script], (output, exitCode) => {
            const map = {};
            const lines = (output || "").trim().split("\n").filter(l => l.length > 0);
            for (let i = 0; i < lines.length; i++) {
                const idx = lines[i].indexOf(":");
                if (idx <= 0)
                    continue;
                const user = lines[i].substring(0, idx);
                const icon = lines[i].substring(idx + 1).trim();
                map[user] = icon && icon.length > 0 ? icon : "";
            }
            for (let j = 0; j < users.length; j++) {
                const u = users[j].username;
                if (!(u in map))
                    map[u] = "";
            }
            root.profileImageMap = map;
        }, 0);
    }
}
