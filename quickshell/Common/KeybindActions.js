.pragma library

const ACTION_TYPES = [
    { id: "dms", label: "DMS Action", icon: "widgets" },
    { id: "compositor", label: "Compositor", icon: "desktop_windows" },
    { id: "spawn", label: "Run Command", icon: "terminal" },
    { id: "shell", label: "Shell Command", icon: "code" }
];

const DMS_ACTIONS = [
    { id: "spawn dms ipc call spotlight toggle", label: "App Launcher: Toggle" },
    { id: "spawn dms ipc call spotlight open", label: "App Launcher: Open" },
    { id: "spawn dms ipc call spotlight close", label: "App Launcher: Close" },
    { id: "spawn dms ipc call clipboard toggle", label: "Clipboard: Toggle" },
    { id: "spawn dms ipc call clipboard open", label: "Clipboard: Open" },
    { id: "spawn dms ipc call clipboard close", label: "Clipboard: Close" },
    { id: "spawn dms ipc call notifications toggle", label: "Notifications: Toggle" },
    { id: "spawn dms ipc call notifications open", label: "Notifications: Open" },
    { id: "spawn dms ipc call notifications close", label: "Notifications: Close" },
    { id: "spawn dms ipc call processlist toggle", label: "Task Manager: Toggle" },
    { id: "spawn dms ipc call processlist open", label: "Task Manager: Open" },
    { id: "spawn dms ipc call processlist close", label: "Task Manager: Close" },
    { id: "spawn dms ipc call processlist focusOrToggle", label: "Task Manager: Focus or Toggle" },
    { id: "spawn dms ipc call settings toggle", label: "Settings: Toggle" },
    { id: "spawn dms ipc call settings open", label: "Settings: Open" },
    { id: "spawn dms ipc call settings close", label: "Settings: Close" },
    { id: "spawn dms ipc call settings focusOrToggle", label: "Settings: Focus or Toggle" },
    { id: "spawn dms ipc call powermenu toggle", label: "Power Menu: Toggle" },
    { id: "spawn dms ipc call powermenu open", label: "Power Menu: Open" },
    { id: "spawn dms ipc call powermenu close", label: "Power Menu: Close" },
    { id: "spawn dms ipc call control-center toggle", label: "Control Center: Toggle" },
    { id: "spawn dms ipc call control-center open", label: "Control Center: Open" },
    { id: "spawn dms ipc call control-center close", label: "Control Center: Close" },
    { id: "spawn dms ipc call notepad toggle", label: "Notepad: Toggle" },
    { id: "spawn dms ipc call notepad open", label: "Notepad: Open" },
    { id: "spawn dms ipc call notepad close", label: "Notepad: Close" },
    { id: "spawn dms ipc call dash toggle", label: "Dashboard: Toggle" },
    { id: "spawn dms ipc call dash open overview", label: "Dashboard: Overview" },
    { id: "spawn dms ipc call dash open media", label: "Dashboard: Media" },
    { id: "spawn dms ipc call dash open weather", label: "Dashboard: Weather" },
    { id: "spawn dms ipc call dankdash wallpaper", label: "Wallpaper Browser" },
    { id: "spawn dms ipc call file browse wallpaper", label: "File: Browse Wallpaper" },
    { id: "spawn dms ipc call file browse profile", label: "File: Browse Profile" },
    { id: "spawn dms ipc call keybinds toggle niri", label: "Keybinds Cheatsheet: Toggle", compositor: "niri" },
    { id: "spawn dms ipc call keybinds open niri", label: "Keybinds Cheatsheet: Open", compositor: "niri" },
    { id: "spawn dms ipc call keybinds close", label: "Keybinds Cheatsheet: Close" },
    { id: "spawn dms ipc call lock lock", label: "Lock Screen" },
    { id: "spawn dms ipc call lock demo", label: "Lock Screen: Demo" },
    { id: "spawn dms ipc call inhibit toggle", label: "Idle Inhibit: Toggle" },
    { id: "spawn dms ipc call inhibit enable", label: "Idle Inhibit: Enable" },
    { id: "spawn dms ipc call inhibit disable", label: "Idle Inhibit: Disable" },
    { id: "spawn dms ipc call audio increment", label: "Volume Up" },
    { id: "spawn dms ipc call audio increment 1", label: "Volume Up (1%)" },
    { id: "spawn dms ipc call audio increment 5", label: "Volume Up (5%)" },
    { id: "spawn dms ipc call audio increment 10", label: "Volume Up (10%)" },
    { id: "spawn dms ipc call audio decrement", label: "Volume Down" },
    { id: "spawn dms ipc call audio decrement 1", label: "Volume Down (1%)" },
    { id: "spawn dms ipc call audio decrement 5", label: "Volume Down (5%)" },
    { id: "spawn dms ipc call audio decrement 10", label: "Volume Down (10%)" },
    { id: "spawn dms ipc call audio mute", label: "Volume Mute Toggle" },
    { id: "spawn dms ipc call audio micmute", label: "Microphone Mute Toggle" },
    { id: "spawn dms ipc call audio cycleoutput", label: "Audio Output: Cycle" },
    { id: "spawn dms ipc call brightness increment", label: "Brightness Up" },
    { id: "spawn dms ipc call brightness increment 1", label: "Brightness Up (1%)" },
    { id: "spawn dms ipc call brightness increment 5", label: "Brightness Up (5%)" },
    { id: "spawn dms ipc call brightness increment 10", label: "Brightness Up (10%)" },
    { id: "spawn dms ipc call brightness decrement", label: "Brightness Down" },
    { id: "spawn dms ipc call brightness decrement 1", label: "Brightness Down (1%)" },
    { id: "spawn dms ipc call brightness decrement 5", label: "Brightness Down (5%)" },
    { id: "spawn dms ipc call brightness decrement 10", label: "Brightness Down (10%)" },
    { id: "spawn dms ipc call brightness toggleExponential", label: "Brightness: Toggle Exponential" },
    { id: "spawn dms ipc call theme toggle", label: "Theme: Toggle Light/Dark" },
    { id: "spawn dms ipc call theme light", label: "Theme: Light Mode" },
    { id: "spawn dms ipc call theme dark", label: "Theme: Dark Mode" },
    { id: "spawn dms ipc call night toggle", label: "Night Mode: Toggle" },
    { id: "spawn dms ipc call night enable", label: "Night Mode: Enable" },
    { id: "spawn dms ipc call night disable", label: "Night Mode: Disable" },
    { id: "spawn dms ipc call bar toggle index 0", label: "Bar: Toggle (Primary)" },
    { id: "spawn dms ipc call bar reveal index 0", label: "Bar: Reveal (Primary)" },
    { id: "spawn dms ipc call bar hide index 0", label: "Bar: Hide (Primary)" },
    { id: "spawn dms ipc call bar toggleAutoHide index 0", label: "Bar: Toggle Auto-Hide (Primary)" },
    { id: "spawn dms ipc call bar autoHide index 0", label: "Bar: Enable Auto-Hide (Primary)" },
    { id: "spawn dms ipc call bar manualHide index 0", label: "Bar: Disable Auto-Hide (Primary)" },
    { id: "spawn dms ipc call dock toggle", label: "Dock: Toggle" },
    { id: "spawn dms ipc call dock reveal", label: "Dock: Reveal" },
    { id: "spawn dms ipc call dock hide", label: "Dock: Hide" },
    { id: "spawn dms ipc call dock toggleAutoHide", label: "Dock: Toggle Auto-Hide" },
    { id: "spawn dms ipc call dock autoHide", label: "Dock: Enable Auto-Hide" },
    { id: "spawn dms ipc call dock manualHide", label: "Dock: Disable Auto-Hide" },
    { id: "spawn dms ipc call mpris playPause", label: "Media: Play/Pause" },
    { id: "spawn dms ipc call mpris play", label: "Media: Play" },
    { id: "spawn dms ipc call mpris pause", label: "Media: Pause" },
    { id: "spawn dms ipc call mpris previous", label: "Media: Previous Track" },
    { id: "spawn dms ipc call mpris next", label: "Media: Next Track" },
    { id: "spawn dms ipc call mpris stop", label: "Media: Stop" },
    { id: "spawn dms ipc call niri screenshot", label: "Screenshot: Interactive", compositor: "niri" },
    { id: "spawn dms ipc call niri screenshotScreen", label: "Screenshot: Full Screen", compositor: "niri" },
    { id: "spawn dms ipc call niri screenshotWindow", label: "Screenshot: Window", compositor: "niri" },
    { id: "spawn dms ipc call hypr toggleOverview", label: "Hyprland: Toggle Overview", compositor: "hyprland" },
    { id: "spawn dms ipc call hypr openOverview", label: "Hyprland: Open Overview", compositor: "hyprland" },
    { id: "spawn dms ipc call hypr closeOverview", label: "Hyprland: Close Overview", compositor: "hyprland" },
    { id: "spawn dms ipc call wallpaper next", label: "Wallpaper: Next" },
    { id: "spawn dms ipc call wallpaper prev", label: "Wallpaper: Previous" }
];

const COMPOSITOR_ACTIONS = {
    "Window": [
        { id: "close-window", label: "Close Window" },
        { id: "fullscreen-window", label: "Fullscreen" },
        { id: "maximize-column", label: "Maximize Column" },
        { id: "center-column", label: "Center Column" },
        { id: "toggle-window-floating", label: "Toggle Floating" },
        { id: "switch-preset-column-width", label: "Cycle Column Width" },
        { id: "switch-preset-window-height", label: "Cycle Window Height" },
        { id: "consume-or-expel-window-left", label: "Consume/Expel Left" },
        { id: "consume-or-expel-window-right", label: "Consume/Expel Right" },
        { id: "toggle-column-tabbed-display", label: "Toggle Tabbed" }
    ],
    "Focus": [
        { id: "focus-column-left", label: "Focus Left" },
        { id: "focus-column-right", label: "Focus Right" },
        { id: "focus-window-down", label: "Focus Down" },
        { id: "focus-window-up", label: "Focus Up" },
        { id: "focus-column-first", label: "Focus First Column" },
        { id: "focus-column-last", label: "Focus Last Column" }
    ],
    "Move": [
        { id: "move-column-left", label: "Move Left" },
        { id: "move-column-right", label: "Move Right" },
        { id: "move-window-down", label: "Move Down" },
        { id: "move-window-up", label: "Move Up" },
        { id: "move-column-to-first", label: "Move to First" },
        { id: "move-column-to-last", label: "Move to Last" }
    ],
    "Workspace": [
        { id: "focus-workspace-down", label: "Focus Workspace Down" },
        { id: "focus-workspace-up", label: "Focus Workspace Up" },
        { id: "focus-workspace-previous", label: "Focus Previous Workspace" },
        { id: "move-column-to-workspace-down", label: "Move to Workspace Down" },
        { id: "move-column-to-workspace-up", label: "Move to Workspace Up" },
        { id: "move-workspace-down", label: "Move Workspace Down" },
        { id: "move-workspace-up", label: "Move Workspace Up" }
    ],
    "Monitor": [
        { id: "focus-monitor-left", label: "Focus Monitor Left" },
        { id: "focus-monitor-right", label: "Focus Monitor Right" },
        { id: "focus-monitor-down", label: "Focus Monitor Down" },
        { id: "focus-monitor-up", label: "Focus Monitor Up" },
        { id: "move-column-to-monitor-left", label: "Move to Monitor Left" },
        { id: "move-column-to-monitor-right", label: "Move to Monitor Right" },
        { id: "move-column-to-monitor-down", label: "Move to Monitor Down" },
        { id: "move-column-to-monitor-up", label: "Move to Monitor Up" }
    ],
    "Screenshot": [
        { id: "screenshot", label: "Screenshot (Interactive)" },
        { id: "screenshot-screen", label: "Screenshot Screen" },
        { id: "screenshot-window", label: "Screenshot Window" }
    ],
    "System": [
        { id: "toggle-overview", label: "Toggle Overview" },
        { id: "show-hotkey-overlay", label: "Show Hotkey Overlay" },
        { id: "power-off-monitors", label: "Power Off Monitors" },
        { id: "power-on-monitors", label: "Power On Monitors" },
        { id: "toggle-keyboard-shortcuts-inhibit", label: "Toggle Shortcuts Inhibit" },
        { id: "quit", label: "Quit Niri" },
        { id: "suspend", label: "Suspend" }
    ],
    "Alt-Tab": [
        { id: "next-window", label: "Next Window" },
        { id: "previous-window", label: "Previous Window" }
    ]
};

const CATEGORY_ORDER = ["DMS", "Execute", "Workspace", "Window", "Monitor", "Screenshot", "System", "Overview", "Alt-Tab", "Other"];

function getActionTypes() {
    return ACTION_TYPES;
}

function getDmsActions(isNiri, isHyprland) {
    const result = [];
    for (let i = 0; i < DMS_ACTIONS.length; i++) {
        const action = DMS_ACTIONS[i];
        if (!action.compositor) {
            result.push(action);
            continue;
        }
        switch (action.compositor) {
        case "niri":
            if (isNiri)
                result.push(action);
            break;
        case "hyprland":
            if (isHyprland)
                result.push(action);
            break;
        }
    }
    return result;
}

function getCompositorCategories() {
    return Object.keys(COMPOSITOR_ACTIONS);
}

function getCompositorActions(category) {
    return COMPOSITOR_ACTIONS[category] || [];
}

function getCategoryOrder() {
    return CATEGORY_ORDER;
}

function findDmsAction(actionId) {
    for (let i = 0; i < DMS_ACTIONS.length; i++) {
        if (DMS_ACTIONS[i].id === actionId)
            return DMS_ACTIONS[i];
    }
    return null;
}

function findCompositorAction(actionId) {
    for (const cat in COMPOSITOR_ACTIONS) {
        const acts = COMPOSITOR_ACTIONS[cat];
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].id === actionId)
                return acts[i];
        }
    }
    return null;
}

function getActionLabel(action) {
    if (!action)
        return "";

    const dmsAct = findDmsAction(action);
    if (dmsAct)
        return dmsAct.label;

    const compAct = findCompositorAction(action);
    if (compAct)
        return compAct.label;

    if (action.startsWith("spawn sh -c "))
        return action.slice(12).replace(/^["']|["']$/g, "");
    if (action.startsWith("spawn "))
        return action.slice(6);
    return action;
}

function getActionType(action) {
    if (!action)
        return "compositor";
    if (action.startsWith("spawn dms ipc call "))
        return "dms";
    if (action.startsWith("spawn sh -c ") || action.startsWith("spawn bash -c "))
        return "shell";
    if (action.startsWith("spawn "))
        return "spawn";
    return "compositor";
}

function isDmsAction(action) {
    if (!action)
        return false;
    return action.startsWith("spawn dms ipc call ");
}

function isValidAction(action) {
    if (!action)
        return false;
    switch (action) {
    case "spawn":
    case "spawn ":
    case "spawn sh -c \"\"":
    case "spawn sh -c ''":
        return false;
    }
    return true;
}

function isKnownCompositorAction(action) {
    if (!action)
        return false;
    return findCompositorAction(action) !== null;
}

function buildSpawnAction(command, args) {
    if (!command)
        return "";
    let parts = [command];
    if (args && args.length > 0)
        parts = parts.concat(args.filter(function(a) { return a; }));
    return "spawn " + parts.join(" ");
}

function buildShellAction(shellCmd) {
    if (!shellCmd)
        return "";
    return "spawn sh -c \"" + shellCmd.replace(/"/g, "\\\"") + "\"";
}

function parseSpawnCommand(action) {
    if (!action || !action.startsWith("spawn "))
        return { command: "", args: [] };
    const rest = action.slice(6);
    const parts = rest.split(" ").filter(function(p) { return p; });
    return {
        command: parts[0] || "",
        args: parts.slice(1)
    };
}

function parseShellCommand(action) {
    if (!action)
        return "";
    if (!action.startsWith("spawn sh -c "))
        return "";
    var content = action.slice(12);
    if ((content.startsWith('"') && content.endsWith('"')) || (content.startsWith("'") && content.endsWith("'")))
        content = content.slice(1, -1);
    return content.replace(/\\"/g, "\"");
}
