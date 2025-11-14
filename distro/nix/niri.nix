{
    config,
    lib,
    ...
}: let
    cfg = config.programs.dankMaterialShell;
in {
    options.programs.dankMaterialShell = {
        niri = {
            enableKeybinds = lib.mkEnableOption "DankMaterialShell niri keybinds";
            enableSpawn = lib.mkEnableOption "DankMaterialShell niri spawn-at-startup";
        };
    };

    config = lib.mkIf cfg.enable {
        programs.niri.settings = lib.mkMerge [
            (lib.mkIf cfg.niri.enableKeybinds {
                binds = with config.lib.niri.actions; let
                    dms-ipc = spawn "dms" "ipc";
                in
                    {
                        "Mod+Space" = {
                            action = dms-ipc "spotlight" "toggle";
                            hotkey-overlay.title = "Toggle Application Launcher";
                        };
                        "Mod+N" = {
                            action = dms-ipc "notifications" "toggle";
                            hotkey-overlay.title = "Toggle Notification Center";
                        };
                        "Mod+Comma" = {
                            action = dms-ipc "settings" "toggle";
                            hotkey-overlay.title = "Toggle Settings";
                        };
                        "Mod+P" = {
                            action = dms-ipc "notepad" "toggle";
                            hotkey-overlay.title = "Toggle Notepad";
                        };
                        "Super+Alt+L" = {
                            action = dms-ipc "lock" "lock";
                            hotkey-overlay.title = "Toggle Lock Screen";
                        };
                        "Mod+X" = {
                            action = dms-ipc "powermenu" "toggle";
                            hotkey-overlay.title = "Toggle Power Menu";
                        };
                        "XF86AudioRaiseVolume" = {
                            allow-when-locked = true;
                            action = dms-ipc "audio" "increment" "3";
                        };
                        "XF86AudioLowerVolume" = {
                            allow-when-locked = true;
                            action = dms-ipc "audio" "decrement" "3";
                        };
                        "XF86AudioMute" = {
                            allow-when-locked = true;
                            action = dms-ipc "audio" "mute";
                        };
                        "XF86AudioMicMute" = {
                            allow-when-locked = true;
                            action = dms-ipc "audio" "micmute";
                        };
                        "Mod+Alt+N" = {
                            allow-when-locked = true;
                            action = dms-ipc "night" "toggle";
                            hotkey-overlay.title = "Toggle Night Mode";
                        };
                    }
                    // lib.attrsets.optionalAttrs cfg.enableSystemMonitoring {
                        "Mod+M" = {
                            action = dms-ipc "processlist" "toggle";
                            hotkey-overlay.title = "Toggle Process List";
                        };
                    }
                    // lib.attrsets.optionalAttrs cfg.enableClipboard {
                        "Mod+V" = {
                            action = dms-ipc "clipboard" "toggle";
                            hotkey-overlay.title = "Toggle Clipboard Manager";
                        };
                    }
                    // lib.attrsets.optionalAttrs cfg.enableBrightnessControl {
                        "XF86MonBrightnessUp" = {
                            allow-when-locked = true;
                            action = dms-ipc "brightness" "increment" "5" "";
                        };
                        "XF86MonBrightnessDown" = {
                            allow-when-locked = true;
                            action = dms-ipc "brightness" "decrement" "5" "";
                        };
                    };
            })

            (lib.mkIf cfg.niri.enableSpawn {
                spawn-at-startup =
                    [
                        {command = ["dms" "run"];}
                    ]
                    ++ lib.optionals cfg.enableClipboard [
                        {
                            command = ["wl-paste" "--watch" "cliphist" "store"];
                        }
                    ];
            })
        ];
    };
}
