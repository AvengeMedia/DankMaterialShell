{
    config,
    pkgs,
    lib,
    dmsPkgs,
    ...
}: let
    cfg = config.programs.dankMaterialShell;
in {
    options.programs.dankMaterialShell = with lib.types; {
        enable = lib.mkEnableOption "DankMaterialShell";

        enableSystemd = lib.mkEnableOption "DankMaterialShell systemd startup";
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
        plugins = lib.mkOption {
            type = attrsOf (types.submodule ({ config, ... }: {
                options = {
                    enable = lib.mkOption {
                        type = types.bool;
                        default = true;
                        description = "Whether to link this plugin";
                    };
                    src = lib.mkOption {
                        type = types.path;
                        description = "Source to link to DMS plugins directory";
                    };
                };
            }));
            default = {};
            description = "DMS Plugins to install";
        };
    };

    config = lib.mkIf cfg.enable
    {
        programs.quickshell = {
            enable = true;
            package = cfg.quickshell.package;

            configs.dms = "${
                dmsPkgs.dankMaterialShell
            }/etc/xdg/quickshell/DankMaterialShell";
            activeConfig = lib.mkIf cfg.enableSystemd "dms";

            systemd = lib.mkIf cfg.enableSystemd {
                enable = true;
                target = "graphical-session.target";
            };
        };

        xdg.configFile = lib.mapAttrs' (name: plugin: {
            name = "DankMaterialShell/plugins/${name}";
            value.source = plugin.src;
        }) (lib.filterAttrs (n: v: v.enable) cfg.plugins);

        home.packages =
            [
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
            ++ lib.optional cfg.enableNightMode pkgs.gammastep
            ++ lib.optional cfg.enableDynamicTheming pkgs.matugen
            ++ lib.optional cfg.enableAudioWavelength pkgs.cava
            ++ lib.optional cfg.enableCalendarEvents pkgs.khal;
    };
}
