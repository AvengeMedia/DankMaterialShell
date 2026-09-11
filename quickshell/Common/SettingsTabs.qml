pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    readonly property var structure: [
        {
            "id": "personalization",
            "text": I18n.tr("Personalization"),
            "icon": "palette",
            "children": [
                {
                    "id": "wallpaper",
                    "text": I18n.tr("Wallpaper"),
                    "icon": "wallpaper",
                    "tabIndex": 0
                },
                {
                    "id": "theme",
                    "text": I18n.tr("Theme & Colors"),
                    "icon": "format_paint",
                    "tabIndex": 10
                },
                {
                    "id": "typography",
                    "text": I18n.tr("Typography & Motion"),
                    "icon": "text_fields",
                    "tabIndex": 14
                },
                {
                    "id": "time_weather",
                    "text": I18n.tr("Time & Weather"),
                    "icon": "schedule",
                    "tabIndex": 1
                },
                {
                    "id": "sounds",
                    "text": I18n.tr("Sounds"),
                    "icon": "volume_up",
                    "tabIndex": 15,
                    "soundsOnly": true
                },
                {
                    "id": "compositor_layout",
                    "text": CompositorService.isNiri ? "Niri" : (CompositorService.isHyprland ? "Hyprland" : "MangoWC"),
                    "icon": "layers",
                    "tabIndex": 37,
                    "layoutCapable": true
                }
            ]
        },
        {
            "id": "dankbar",
            "text": I18n.tr("Bar"),
            "icon": "toolbar",
            "children": [
                {
                    "id": "dankbar_appearance",
                    "text": I18n.tr("Appearance"),
                    "icon": "palette",
                    "tabIndex": 6
                },
                {
                    "id": "dankbar_settings",
                    "text": I18n.tr("General"),
                    "icon": "tune",
                    "tabIndex": 3
                },
                {
                    "id": "dankbar_widgets",
                    "text": I18n.tr("Widgets"),
                    "icon": "widgets",
                    "tabIndex": 22
                },
                {
                    "id": "workspaces",
                    "text": I18n.tr("Workspaces"),
                    "icon": "view_module",
                    "tabIndex": 4
                },
                {
                    "id": "frame",
                    "text": I18n.tr("Frame"),
                    "icon": "frame_source",
                    "tabIndex": 33,
                    "frameOnly": true
                },
                {
                    "id": "dank_island",
                    "text": I18n.tr("Island"),
                    "icon": "view_in_ar",
                    "tabIndex": 46,
                    "islandOnly": true
                }
            ]
        },
        {
            "id": "workspaces_widgets",
            "text": I18n.tr("Widgets & Notifications"),
            "icon": "dashboard",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "dank_dash",
                    "text": I18n.tr("Dashboard"),
                    "icon": "space_dashboard",
                    "tabIndex": 43
                },
                {
                    "id": "media_player",
                    "text": I18n.tr("Media Player"),
                    "icon": "music_note",
                    "tabIndex": 16
                },
                {
                    "id": "notifications",
                    "text": I18n.tr("Notifications"),
                    "icon": "notifications",
                    "tabIndex": 17
                },
                {
                    "id": "osd",
                    "text": I18n.tr("On-screen Displays"),
                    "icon": "tune",
                    "tabIndex": 18
                },
                {
                    "id": "desktop_widgets",
                    "text": I18n.tr("Desktop Widgets"),
                    "icon": "widgets",
                    "tabIndex": 27
                }
            ]
        },
        {
            "id": "dock_launcher",
            "text": I18n.tr("Dock & Launcher"),
            "icon": "shelf_auto_hide",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "dock",
                    "text": I18n.tr("Dock"),
                    "icon": "dock_to_bottom",
                    "tabIndex": 5
                },
                {
                    "id": "launcher",
                    "text": I18n.tr("Launcher"),
                    "icon": "grid_view",
                    "tabIndex": 9
                }
            ]
        },
        {
            "id": "keybinds",
            "text": I18n.tr("Keyboard Shortcuts"),
            "icon": "keyboard",
            "tabIndex": 2,
            "shortcutsOnly": true
        },
        {
            "id": "displays",
            "text": I18n.tr("Displays"),
            "icon": "monitor",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "display_config",
                    "text": I18n.tr("Configuration"),
                    "icon": "display_settings",
                    "tabIndex": 24
                },
                {
                    "id": "display_gamma",
                    "text": I18n.tr("Gamma Control"),
                    "icon": "brightness_6",
                    "tabIndex": 25
                },
                {
                    "id": "display_widgets",
                    "text": I18n.tr("Widgets", "settings_displays"),
                    "icon": "widgets",
                    "tabIndex": 26
                }
            ]
        },
        {
            "id": "network",
            "text": I18n.tr("Network"),
            "icon": "wifi",
            "dmsOnly": true,
            "children": [
                {
                    "id": "network_status",
                    "text": I18n.tr("Status"),
                    "icon": "lan",
                    "tabIndex": 7
                },
                {
                    "id": "network_ethernet",
                    "text": I18n.tr("Ethernet"),
                    "icon": "settings_ethernet",
                    "tabIndex": 39
                },
                {
                    "id": "network_wifi",
                    "text": I18n.tr("WiFi"),
                    "icon": "wifi",
                    "tabIndex": 40
                },
                {
                    "id": "network_cellular",
                    "text": I18n.tr("Cellular"),
                    "icon": "network_cell",
                    "tabIndex": 47,
                    "cellularOnly": true
                },
                {
                    "id": "network_vpn",
                    "text": I18n.tr("VPN"),
                    "icon": "vpn_key",
                    "tabIndex": 41
                }
            ]
        },
        {
            "id": "applications",
            "text": I18n.tr("Applications"),
            "icon": "apps",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "default_apps",
                    "text": I18n.tr("Default Apps"),
                    "icon": "star",
                    "tabIndex": 34
                },
                {
                    "id": "running_apps",
                    "text": I18n.tr("Running Apps"),
                    "icon": "app_registration",
                    "tabIndex": 19,
                    "hyprlandNiriOnly": true
                },
                {
                    "id": "autostart",
                    "text": I18n.tr("Autostart Apps"),
                    "icon": "line_start",
                    "tabIndex": 36,
                    "autostartOnly": true
                },
                {
                    "id": "window_rules",
                    "text": I18n.tr("Window Rules"),
                    "icon": "select_window",
                    "tabIndex": 38,
                    "windowRulesCapable": true
                }
            ]
        },
        {
            "id": "system",
            "text": I18n.tr("System"),
            "icon": "memory",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "audio",
                    "text": I18n.tr("Audio"),
                    "icon": "headphones",
                    "tabIndex": 29
                },
                {
                    "id": "mouse_touchpad",
                    "text": I18n.tr("Mouse & Touchpad"),
                    "icon": "mouse",
                    "tabIndex": 44,
                    "niriOnly": true
                },
                {
                    "id": "keyboard",
                    "text": I18n.tr("Keyboard"),
                    "icon": "keyboard",
                    "tabIndex": 45,
                    "niriOnly": true
                },
                {
                    "id": "locale",
                    "text": I18n.tr("Locale"),
                    "icon": "language",
                    "tabIndex": 30
                },
                {
                    "id": "clipboard",
                    "text": I18n.tr("Clipboard"),
                    "icon": "content_paste",
                    "tabIndex": 23,
                    "clipboardOnly": true
                },
                {
                    "id": "printers",
                    "text": I18n.tr("Printers"),
                    "icon": "print",
                    "tabIndex": 8,
                    "cupsOnly": true
                },
                {
                    "id": "multiplexers",
                    "text": I18n.tr("Multiplexers"),
                    "icon": "terminal",
                    "tabIndex": 32
                },
                {
                    "id": "updater",
                    "text": I18n.tr("System Updater"),
                    "icon": "refresh",
                    "tabIndex": 20,
                    "updaterOnly": true
                },
                {
                    "id": "users",
                    "text": I18n.tr("Users"),
                    "icon": "manage_accounts",
                    "tabIndex": 35
                }
            ]
        },
        {
            "id": "power_security",
            "text": I18n.tr("Power & Security"),
            "icon": "security",
            "collapsedByDefault": true,
            "children": [
                {
                    "id": "battery",
                    "text": I18n.tr("Battery"),
                    "icon": "battery_charging_full",
                    "tabIndex": 42
                },
                {
                    "id": "lock_screen",
                    "text": I18n.tr("Lock Screen"),
                    "icon": "lock",
                    "tabIndex": 11
                },
                {
                    "id": "greeter",
                    "text": I18n.tr("Greeter"),
                    "icon": "login",
                    "tabIndex": 31,
                    "greeterOnly": true
                },
                {
                    "id": "power_sleep",
                    "text": I18n.tr("Power & Sleep"),
                    "icon": "power_settings_new",
                    "tabIndex": 21
                }
            ]
        },
        {
            "id": "plugins",
            "text": I18n.tr("Plugins"),
            "icon": "extension",
            "tabIndex": 12
        },
        {
            "id": "separator",
            "separator": true
        },
        {
            "id": "about",
            "text": I18n.tr("About"),
            "icon": "info",
            "tabIndex": 13
        }
    ]
}
