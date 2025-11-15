{
    config,
    pkgs,
    lib,
    dmsPkgs,
    ...
}: let
    cfg = config.programs.dankMaterialShell;
in {
    imports = [
        (lib.mkRemovedOptionModule ["programs" "dankMaterialShell" "enableNightMode"] "Night mode is now always available.")
        (lib.mkRenamedOptionModule ["programs" "dankMaterialShell" "enableSystemd"] ["programs" "dankMaterialShell" "systemd" "enable"])
    ];
    options.programs.dankMaterialShell = with lib.types; {
        enable = lib.mkEnableOption "DankMaterialShell";

        systemd = {
            enable = lib.mkEnableOption "DankMaterialShell systemd startup";
            restartIfChanged = lib.mkOption {
                type = bool;
                default = true;
                description = "Auto-restart dms.service when dankMaterialShell changes";
            };
        };
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
        enableColorPicker = lib.mkOption {
            type = bool;
            default = true;
            description = "Add needed dependencies to have color picking support";
        };
        enableDynamicTheming = lib.mkOption {
            type = bool;
            default = true;
            description = "Add needed dependencies to have dynamic theming support";
        };
        enableAudioWavelength = lib.mkOption {
            type = bool;
            default = true;
            description = "Add needed dependencies to have audio wavelength support";
        };
        enableCalendarEvents = lib.mkOption {
            type = bool;
            default = true;
            description = "Add calendar events support via khal";
        };
        enableSystemSound = lib.mkOption {
            type = bool;
            default = true;
            description = "Add needed dependencies to have system sound support";
        };
        quickshell = {
            package = lib.mkPackageOption pkgs "quickshell" {};
        };
    };

    config = lib.mkIf cfg.enable
    {
        environment.etc."xdg/quickshell".source = "${dmsPkgs.dankMaterialShell}/quickshell";

        systemd.user.services.dms = lib.mkIf cfg.systemd.enable {
            Unit = {
                Description = "DankMaterialShell";
                PartOf = [config.wayland.systemd.target];
                After = [config.wayland.systemd.target];
                X-Restart-Triggers = lib.optional cfg.systemd.restartIfChanged config.programs.quickshell.configs.dms;
            };

            Service = {
                ExecStart = lib.getExe dmsPkgs.dmsCli + " run --session";
                Restart = "on-failure";
            };

            Install.WantedBy = [config.wayland.systemd.target];
        };

        environment.systemPackages =
            [
                cfg.quickshell.package
                pkgs.material-symbols
                pkgs.inter
                pkgs.fira-code

                pkgs.ddcutil
                pkgs.libsForQt5.qt5ct
                pkgs.kdePackages.qt6ct

                dmsPkgs.dmsCli
            ]
            ++ lib.optional cfg.enableSystemMonitoring dmsPkgs.dgop
            ++ lib.optionals cfg.enableClipboard [pkgs.cliphist pkgs.wl-clipboard]
            ++ lib.optionals cfg.enableVPN [pkgs.glib pkgs.networkmanager]
            ++ lib.optional cfg.enableBrightnessControl pkgs.brightnessctl
            ++ lib.optional cfg.enableColorPicker pkgs.hyprpicker
            ++ lib.optional cfg.enableDynamicTheming pkgs.matugen
            ++ lib.optional cfg.enableAudioWavelength pkgs.cava
            ++ lib.optional cfg.enableCalendarEvents pkgs.khal
            ++ lib.optional cfg.enableSystemSound pkgs.kdePackages.qtmultimedia;
    };
}
