pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    readonly property var brandIcons: ({
        "firefox": "\udb80\ude39",
        "google-chrome": "\uf268",
        "chromium": "\uf268",
        "chrome": "\uf268",
        "safari": "\uf267",
        "edge": "\uf282",
        "opera": "\uf26a",
        "brave": "\uf269",
        "brave-browser": "\uf269",
        "zen": "\udb83\ude95",

        "code": "\ue70c",
        "vscode": "\ue70c",
        "visual-studio-code": "\ue70c",
        "atom": "\uf29c",
        "sublime": "\ue7aa",
        "vim": "\ue62b",
        "nvim": "\ue62b",
        "neovim": "\ue62b",
        "webstorm": "\uf29b",
        "pycharm": "\uf29b",
        "intellij": "\uf29b",

        "discord": "\uf392",
        "slack": "\uf198",
        "telegram": "\uf2c6",
        "skype": "\uf17e",
        "teams": "\uf30a",
        "zoom": "\uf03d",
        "zoom workplace": "\uf03d",
        "signal": "\uf2c6",
        "whatsapp": "\uf232",
        "beepertexts": "\udb83\udd45",

        "github": "\uf408",
        "github-desktop": "\uf408",
        "gitlab": "\uf296",
        "docker": "\uf308",
        "kubernetes": "\uf308",
        "git": "\uf1d3",
        "terminal": "\uf120",
        "kitty": "\uf120",
        "alacritty": "\uf120",
        "wezterm": "\uf120",
        "datagrip": "\ue7bd",

        "spotify": "\uf1bc",
        "vlc": "\uf03d",
        "gimp": "\uf1c5",
        "blender": "\uf1c5",
        "obs": "\uf03d",
        "obs-studio": "\uf03d",
        "inkscape": "\uf1c5",
        "darktable": "\uf030",
        "rawtherapee": "\uf030",
        "krita": "\uf1fc",
        "kolourpaint": "\uf1fc",

        "libreoffice": "\uf1c2",
        "writer": "\uf1c2",
        "calc": "\uf1c3",
        "impress": "\uf1c4",
        "thunderbird": "\uf0e0",
        "notion": "\ue848",

        "nautilus": "\uf07c",
        "thunar": "\uf07c",
        "dolphin": "\uf07c",
        "files": "\uf07c",
        "file-manager": "\uf07c",
        "calculator": "\uf1ec",
        "qalculate": "\uf1ec",
        "io.github.qalculate.qalculate-qt": "\uf1ec",
        "settings": "\uf013",
        "gnome-settings": "\uf013",
        "systemsettings": "\uf013",
        "blueman-manager": "\uf293",

        "steam": "\uf1b6",
        "lutris": "\uf11b",
        "heroic": "\uf11b",

        "twitter": "\uf099",
        "reddit": "\uf281",
        "youtube": "\uf167",
        "twitch": "\uf1e8",
        "bluesky": "\ue28e",

        "evolution": "\uf0e0",
        "kmail": "\uf0e0",
        "calendar": "\uf073",

        "ticktick": "\udb80\udd34",
        "home assistant desktop": "\udb81\udfd0",
        "aws vpn client": "\ue7ad",
        "tv.plex.plex": "\udb81\udeba",
        "protonvpn-app": "\udb81\udd82"
    })

    function getNerdFontIcon(appId) {
        if (!appId) {
            return null;
        }

        const cleanAppId = appId.toLowerCase();

        if (brandIcons[cleanAppId]) {
            return brandIcons[cleanAppId];
        }

        for (const key in brandIcons) {
            if (cleanAppId.includes(key) || key.includes(cleanAppId)) {
                return brandIcons[key];
            }
        }

        return null;
    }

    function getAppIcon(appId) {
        const moddedAppId = Paths.moddedAppId(appId);
        const desktopEntry = DesktopEntries.heuristicLookup(moddedAppId);
        return Quickshell.iconPath(desktopEntry?.icon, true);
    }
}
