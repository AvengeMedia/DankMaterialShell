{
    description = "Dank Material Shell";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
        quickshell = {
            url = "git+https://git.outfoxxed.me/quickshell/quickshell";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        dgop = {
            url = "github:AvengeMedia/dgop";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        dms-cli = {
            url = "github:AvengeMedia/danklinux";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = {
        self,
        nixpkgs,
        quickshell,
        dgop,
        dms-cli,
        ...
    }: let
        forEachSystem = fn:
            nixpkgs.lib.genAttrs
            ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"]
            (system: fn system nixpkgs.legacyPackages.${system});
    in {
        formatter = forEachSystem (_: pkgs: pkgs.alejandra);

        packages = forEachSystem (system: pkgs: {
            dankMaterialShell = pkgs.stdenvNoCC.mkDerivation {
                name = "dankMaterialShell";
                src = ./.;
                installPhase = ''
                    mkdir -p $out/etc/xdg/quickshell/DankMaterialShell
                    cp -r . $out/etc/xdg/quickshell/DankMaterialShell
                    ln -s $out/etc/xdg/quickshell/DankMaterialShell $out/etc/xdg/quickshell/dms
                '';
            };

            quickshell = quickshell.packages.${system}.default;

            default = self.packages.${system}.dankMaterialShell;
        });

        homeModules.dankMaterialShell = {
            config,
            pkgs,
            lib,
            ...
        }: let
            cfg = config.programs.dankMaterialShell;
            inherit (lib.types) bool;
        in {
            options.programs.dankMaterialShell = {
                enable = lib.mkEnableOption "DankMaterialShell";
                enableKeybinds = lib.mkEnableOption "DankMaterialShell niri keybinds";
                enableSystemd = lib.mkEnableOption "DankMaterialShell systemd startup";
                enableSpawn = lib.mkEnableOption "DankMaterialShell niri spawn-at-startup";
                enableSystemMonitoring = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to use system monitoring widgets";
                };
                enableClipboard = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to use the clipboard widget";
                };
                enableVPN = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to use the VPN widget";
                };
                enableBrightnessControl = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to have brightness/backlight support";
                };
                enableNightMode = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to have night mode support";
                };
                enableDynamicTheming = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to have dynamic theming support";
                };
                enableAudioWavelength = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add needed dependencies to have audio waveleng support";
                };
                enableCalendarEvents = lib.mkOption {
                    type = bool;
                    default = true;
                    description = "Add calendar events support via khal";
                };
                quickshell = {
                    package = lib.mkPackageOption pkgs "quickshell" {};
                };
            };

            config = lib.mkIf cfg.enable {
                programs.quickshell = {
                    enable = true;
                    package = cfg.quickshell.package;

                    configs.dms = "${
                        self.packages.${pkgs.system}.dankMaterialShell
                    }/etc/xdg/quickshell/DankMaterialShell";
                    activeConfig = lib.mkIf cfg.enableSystemd "dms";

                    systemd = lib.mkIf cfg.enableSystemd {
                        enable = true;
                        target = "graphical-session.target";
                    };
                };

                programs.niri.settings = lib.mkMerge [
                    (lib.mkIf cfg.enableKeybinds {
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
                            }
                            // lib.attrsets.optionalAttrs cfg.enableNightMode {
                                "Mod+Alt+N" = {
                                    allow-when-locked = true;
                                    action = dms-ipc "night" "toggle";
                                    hotkey-overlay.title = "Toggle Night Mode";
                                };
                            };
                    })
                    (lib.mkIf cfg.enableSpawn {
                        spawn-at-startup = [
                            {command = ["dms" "run"];}
                        ];
                    })
                ];

                home.packages =
                    [
                        pkgs.material-symbols
                        pkgs.inter
                        pkgs.fira-code

                        pkgs.ddcutil
                        pkgs.libsForQt5.qt5ct
                        pkgs.kdePackages.qt6ct
                        dms-cli.packages.${pkgs.system}.default
                    ]
                    ++ lib.optional cfg.enableSystemMonitoring dgop.packages.${pkgs.system}.dgop
                    ++ lib.optionals cfg.enableClipboard [pkgs.cliphist pkgs.wl-clipboard]
                    ++ lib.optionals cfg.enableVPN [pkgs.glib pkgs.networkmanager]
                    ++ lib.optional cfg.enableBrightnessControl pkgs.brightnessctl
                    ++ lib.optional cfg.enableNightMode pkgs.gammastep
                    ++ lib.optional cfg.enableDynamicTheming pkgs.matugen
                    ++ lib.optional cfg.enableAudioWavelength pkgs.cava
                    ++ lib.optional cfg.enableCalendarEvents pkgs.khal;
            };
        };
    };
}
