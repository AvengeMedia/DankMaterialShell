#!/usr/bin/env python3
import re
import json
from collections import Counter
from pathlib import Path

ABBREVIATIONS = {
    "on-screen displays": ["osd"],
    "on-screen display": ["osd"],
    "do not disturb": ["dnd"],
    "keyboard shortcuts": ["keybinds", "hotkeys", "bindings", "keys"],
    "notifications": ["notif", "notifs", "alerts"],
    "notification": ["notif", "alert"],
    "wallpaper": ["background", "bg", "image", "picture", "desktop"],
    "transparency": ["opacity", "alpha", "translucent", "transparent"],
    "visibility": ["visible", "hide", "show", "hidden", "autohide", "auto-hide"],
    "temperature": ["temp", "celsius", "fahrenheit"],
    "configuration": ["config", "configure", "setup"],
    "applications": ["apps", "programs"],
    "application": ["app", "program"],
    "animation": ["motion", "transition", "animate", "animations"],
    "typography": ["font", "fonts", "text", "typeface"],
    "workspaces": ["workspace", "desktops", "virtual"],
    "workspace": ["desktop", "virtual"],
    "bluetooth": ["bt"],
    "network": ["wifi", "wi-fi", "ethernet", "internet", "connection", "wireless"],
    "display": ["monitor", "screen", "output"],
    "displays": ["monitors", "screens", "outputs"],
    "brightness": ["bright", "dim", "backlight"],
    "volume": ["audio", "sound", "speaker", "loudness"],
    "battery": ["power", "charge", "charging"],
    "clock": ["time", "watch"],
    "calendar": ["date", "day", "month", "year"],
    "launcher": ["app drawer", "app menu", "start menu", "applications"],
    "dock": ["taskbar", "panel"],
    "bar": ["panel", "taskbar", "topbar", "statusbar"],
    "theme": ["appearance", "look", "style", "colors", "colour"],
    "color": ["colour", "hue", "tint"],
    "colors": ["colours", "palette"],
    "dark": ["night", "dark mode"],
    "light": ["day", "light mode"],
    "lock screen": ["lockscreen", "login", "security"],
    "power": ["shutdown", "reboot", "restart", "suspend", "hibernate", "sleep"],
    "idle": ["afk", "inactive", "timeout", "screensaver"],
    "gamma": ["color temperature", "night light", "blue light", "redshift"],
    "media player": ["mpris", "music", "audio", "playback"],
    "clipboard": ["copy", "paste", "cliphist", "history"],
    "updater": ["updates", "upgrade", "packages"],
    "plugins": ["extensions", "addons", "widgets"],
    "spacing": ["gap", "gaps", "margin", "margins", "padding"],
    "corner": ["corners", "rounded", "radius", "round"],
    "matugen": ["dynamic", "wallpaper colors", "material"],
    "running apps": ["taskbar", "windows", "active", "open"],
    "weather": ["forecast", "temperature", "climate"],
    "sounds": ["audio", "effects", "sfx"],
    "printers": ["print", "cups", "printing"],
    "widgets": ["components", "modules"],
}

CATEGORY_KEYWORDS = {
    "Personalization": ["customize", "custom", "personal", "appearance"],
    "Time & Weather": ["clock", "forecast", "date"],
    "Keyboard Shortcuts": ["keys", "bindings", "hotkey"],
    "Dank Bar": ["panel", "topbar", "statusbar"],
    "Workspaces": ["virtual desktops", "spaces"],
    "Dock": ["taskbar", "launcher bar"],
    "Network": ["connectivity", "online"],
    "System": ["os", "linux"],
    "Launcher": ["start", "menu", "drawer"],
    "Theme & Colors": ["appearance", "look", "style", "scheme"],
    "Lock Screen": ["security", "login", "password"],
    "Plugins": ["extend", "addon"],
    "About": ["info", "version", "credits", "help"],
    "Typography & Motion": ["fonts", "animation", "text"],
    "Sounds": ["audio", "sfx", "effects"],
    "Media Player": ["music", "spotify", "mpris"],
    "Notifications": ["alerts", "messages", "toast"],
    "On-screen Displays": ["osd", "indicator", "popup"],
    "Running Apps": ["windows", "tasks", "active"],
    "System Updater": ["packages", "upgrade"],
    "Power & Sleep": ["shutdown", "suspend", "energy"],
    "Displays": ["monitor", "screen", "resolution"],
    "Desktop Widgets": ["conky", "desktop clock"],
}

TAB_INDEX_MAP = {
    "WallpaperTab.qml": 0,
    "TimeWeatherTab.qml": 1,
    "KeybindsTab.qml": 2,
    "DankBarTab.qml": 3,
    "WorkspacesTab.qml": 4,
    "DockTab.qml": 5,
    "NetworkTab.qml": 7,
    "PrinterTab.qml": 8,
    "LauncherTab.qml": 9,
    "ThemeColorsTab.qml": 10,
    "LockScreenTab.qml": 11,
    "PluginsTab.qml": 12,
    "AboutTab.qml": 13,
    "TypographyMotionTab.qml": 14,
    "SoundsTab.qml": 15,
    "MediaPlayerTab.qml": 16,
    "NotificationsTab.qml": 17,
    "OSDTab.qml": 18,
    "RunningAppsTab.qml": 19,
    "SystemUpdaterTab.qml": 20,
    "PowerSleepTab.qml": 21,
    "WidgetsTab.qml": 22,
    "ClipboardTab.qml": 23,
    "DisplayConfigTab.qml": 24,
    "GammaControlTab.qml": 25,
    "DisplayWidgetsTab.qml": 26,
    "DesktopWidgetsTab.qml": 27,
}

TAB_CATEGORY_MAP = {
    0: "Personalization",
    1: "Time & Weather",
    2: "Keyboard Shortcuts",
    3: "Dank Bar",
    4: "Workspaces",
    5: "Dock",
    7: "Network",
    8: "System",
    9: "Launcher",
    10: "Theme & Colors",
    11: "Lock Screen",
    12: "Plugins",
    13: "About",
    14: "Typography & Motion",
    15: "Sounds",
    16: "Media Player",
    17: "Notifications",
    18: "On-screen Displays",
    19: "Running Apps",
    20: "System Updater",
    21: "Power & Sleep",
    22: "Dank Bar",
    23: "System",
    24: "Displays",
    25: "Displays",
    26: "Displays",
    27: "Desktop Widgets",
}

SEARCHABLE_COMPONENTS = [
    "SettingsCard",
    "SettingsToggleRow",
    "SettingsSliderCard",
    "SettingsDropdownRow",
    "SettingsButtonGroupRow",
    "SettingsSliderRow",
    "SettingsToggleCard",
]

STOPWORDS = {
    "the",
    "and",
    "for",
    "with",
    "from",
    "this",
    "that",
    "are",
    "was",
    "will",
    "can",
    "has",
    "have",
    "been",
    "when",
    "your",
    "use",
    "used",
    "using",
    "instead",
    "like",
    "such",
    "also",
    "only",
    "which",
    "each",
    "other",
    "some",
    "into",
    "than",
    "then",
    "them",
    "these",
    "those",
}


def enrich_keywords(label, description, category, existing_tags):
    keywords = set(existing_tags)

    label_lower = label.lower()
    label_words = re.split(r"[\s\-_&/]+", label_lower)
    keywords.update(w for w in label_words if len(w) > 2)

    for term, aliases in ABBREVIATIONS.items():
        if term in label_lower:
            keywords.update(aliases)

    if description:
        desc_lower = description.lower()
        desc_words = re.split(r"[\s\-_&/,.]+", desc_lower)
        keywords.update(w for w in desc_words if len(w) > 3 and w.isalpha())
        for term, aliases in ABBREVIATIONS.items():
            if term in desc_lower:
                keywords.update(aliases)

    if category in CATEGORY_KEYWORDS:
        keywords.update(CATEGORY_KEYWORDS[category])

    cat_lower = category.lower()
    cat_words = re.split(r"[\s\-_&/]+", cat_lower)
    keywords.update(w for w in cat_words if len(w) > 2)

    keywords = {k for k in keywords if k not in STOPWORDS and len(k) > 1}
    return sorted(keywords)


def extract_i18n_string(value):
    match = re.search(r'I18n\.tr\(["\']([^"\']+)["\']', value)
    if match:
        return match.group(1)
    match = re.search(r'^["\']([^"\']+)["\']$', value.strip())
    if match:
        return match.group(1)
    return None


def extract_tags(value):
    match = re.search(r"\[([^\]]+)\]", value)
    if not match:
        return []
    content = match.group(1)
    tags = re.findall(r'["\']([^"\']+)["\']', content)
    return tags


def parse_component_block(content, start_pos, component_name):
    brace_count = 0
    started = False
    block_start = start_pos

    for i in range(start_pos, len(content)):
        if content[i] == "{":
            if not started:
                block_start = i
                started = True
            brace_count += 1
        elif content[i] == "}":
            brace_count -= 1
            if started and brace_count == 0:
                return content[block_start : i + 1]
    return ""


def extract_property(block, prop_name):
    pattern = rf"{prop_name}\s*:\s*([^\n]+)"
    match = re.search(pattern, block)
    if match:
        return match.group(1).strip()
    return None


def find_settings_components(content, filename):
    results = []
    tab_index = TAB_INDEX_MAP.get(filename, -1)

    if tab_index == -1:
        return results

    for component in SEARCHABLE_COMPONENTS:
        pattern = rf"\b{component}\s*\{{"
        for match in re.finditer(pattern, content):
            block = parse_component_block(content, match.start(), component)
            if not block:
                continue

            setting_key = extract_property(block, "settingKey")
            if setting_key:
                setting_key = setting_key.strip("\"'")

            if not setting_key:
                continue

            title_raw = extract_property(block, "title")
            text_raw = extract_property(block, "text")
            label = None
            if title_raw:
                label = extract_i18n_string(title_raw)
            if not label and text_raw:
                label = extract_i18n_string(text_raw)

            if not label:
                continue

            icon_raw = extract_property(block, "iconName")
            icon = None
            if icon_raw:
                icon = icon_raw.strip("\"'")
                if icon.startswith("{") or "?" in icon:
                    icon = None

            tags_raw = extract_property(block, "tags")
            tags = []
            if tags_raw:
                tags = extract_tags(tags_raw)

            desc_raw = extract_property(block, "description")
            description = None
            if desc_raw:
                description = extract_i18n_string(desc_raw)

            visible_raw = extract_property(block, "visible")
            condition_key = None
            if visible_raw:
                if "CompositorService.isNiri" in visible_raw:
                    condition_key = "isNiri"
                elif "CompositorService.isHyprland" in visible_raw:
                    condition_key = "isHyprland"
                elif "KeybindsService.available" in visible_raw:
                    condition_key = "keybindsAvailable"
                elif "AudioService.soundsAvailable" in visible_raw:
                    condition_key = "soundsAvailable"
                elif "CupsService.cupsAvailable" in visible_raw:
                    condition_key = "cupsAvailable"
                elif "NetworkService.usingLegacy" in visible_raw:
                    condition_key = "networkNotLegacy"
                elif "DMSService.isConnected" in visible_raw:
                    condition_key = "dmsConnected"
                elif "Theme.matugenAvailable" in visible_raw:
                    condition_key = "matugenAvailable"
                elif "CompositorService.isDwl" in visible_raw:
                    condition_key = "isDwl"

            category = TAB_CATEGORY_MAP.get(tab_index, "Settings")
            enriched_keywords = enrich_keywords(label, description, category, tags)

            entry = {
                "section": setting_key,
                "label": label,
                "tabIndex": tab_index,
                "category": category,
                "keywords": enriched_keywords,
            }

            if icon:
                entry["icon"] = icon
            if description:
                entry["description"] = description
            if condition_key:
                entry["conditionKey"] = condition_key

            results.append(entry)

    return results


def parse_tabs_from_sidebar(sidebar_file):
    with open(sidebar_file, "r", encoding="utf-8") as f:
        content = f.read()

    pattern = r'"text"\s*:\s*I18n\.tr\("([^"]+)"(?:,\s*"[^"]+")?\).*?"icon"\s*:\s*"([^"]+)".*?"tabIndex"\s*:\s*(\d+)'
    tabs = []

    for match in re.finditer(pattern, content, re.DOTALL):
        label, icon, tab_idx = match.group(1), match.group(2), int(match.group(3))

        before_text = content[: match.start()]
        parent_match = re.search(
            r'"text"\s*:\s*I18n\.tr\("([^"]+)"\)[^{]*"children"[^[]*\[[^{]*$',
            before_text,
        )
        parent = parent_match.group(1) if parent_match else None

        cond = None
        after_pos = match.end()
        snippet = content[match.start() : min(after_pos + 200, len(content))]
        for qml_cond, key in [
            ("shortcutsOnly", "keybindsAvailable"),
            ("soundsOnly", "soundsAvailable"),
            ("cupsOnly", "cupsAvailable"),
            ("dmsOnly", "dmsConnected"),
            ("hyprlandNiriOnly", "isHyprlandOrNiri"),
            ("clipboardOnly", "dmsConnected"),
        ]:
            if f'"{qml_cond}": true' in snippet:
                cond = key
                break

        tabs.append(
            {
                "tabIndex": tab_idx,
                "label": label,
                "icon": icon,
                "parent": parent,
                "conditionKey": cond,
            }
        )

    return tabs


def generate_tab_entries(sidebar_file):
    tabs = parse_tabs_from_sidebar(sidebar_file)

    label_counts = Counter([t["label"] for t in tabs])

    entries = []
    for tab in tabs:
        label = (
            f"{tab['parent']}: {tab['label']}"
            if label_counts[tab["label"]] > 1 and tab["parent"]
            else tab["label"]
        )
        category = TAB_CATEGORY_MAP.get(tab["tabIndex"], "Settings")

        keywords = enrich_keywords(tab["label"], None, category, [])

        if tab["parent"]:
            parent_keywords = [
                w for w in re.split(r"[\s\-_&/]+", tab["parent"].lower()) if len(w) > 2
            ]
            keywords = sorted(
                set(
                    keywords
                    + parent_keywords
                    + [k for p in parent_keywords for k in ABBREVIATIONS.get(p, [])]
                )
            )

        entry = {
            "section": f"_tab_{tab['tabIndex']}",
            "label": label,
            "tabIndex": tab["tabIndex"],
            "category": category,
            "keywords": keywords,
            "icon": tab["icon"],
        }
        if tab["conditionKey"]:
            entry["conditionKey"] = tab["conditionKey"]
        entries.append(entry)

    return entries


def extract_settings_index(root_dir):
    settings_dir = Path(root_dir) / "Modules" / "Settings"
    all_entries = []
    seen_keys = set()

    for qml_file in settings_dir.glob("*.qml"):
        if not qml_file.name.endswith("Tab.qml"):
            continue

        with open(qml_file, "r", encoding="utf-8") as f:
            content = f.read()

        entries = find_settings_components(content, qml_file.name)
        for entry in entries:
            key = entry["section"]
            if key not in seen_keys:
                seen_keys.add(key)
                all_entries.append(entry)

    return all_entries


def main():
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent
    sidebar_file = root_dir / "Modals" / "Settings" / "SettingsSidebar.qml"

    print("Extracting settings search index...")
    settings_entries = extract_settings_index(root_dir)
    tab_entries = generate_tab_entries(sidebar_file)

    all_entries = tab_entries + settings_entries

    all_entries.sort(key=lambda x: (x["tabIndex"], x["label"]))

    output_path = script_dir / "settings_search_index.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(all_entries, f, indent=2, ensure_ascii=False)

    print(f"Found {len(settings_entries)} searchable settings")
    print(f"Found {len(tab_entries)} tab entries")
    print(f"Total: {len(all_entries)} entries")
    print(f"Output: {output_path}")

    conditions = set()
    for entry in all_entries:
        if "conditionKey" in entry:
            conditions.add(entry["conditionKey"])

    if conditions:
        print(f"Condition keys found: {', '.join(sorted(conditions))}")


if __name__ == "__main__":
    main()
