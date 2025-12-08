{
    config,
    pkgs,
    lib,
    dmsPkgs,
    ...
} @ args: let
    cfg = config.programs.dankMaterialShell;
    jsonFormat = pkgs.formats.json {};
    common = import ./common.nix {inherit config pkgs lib dmsPkgs;};
in {
    imports = [
        (import ./options.nix args)
        (lib.mkRemovedOptionModule ["programs" "dankMaterialShell" "enableNightMode"] "Night mode is now always available.")
        (lib.mkRenamedOptionModule ["programs" "dankMaterialShell" "enableSystemd"] ["programs" "dankMaterialShell" "systemd" "enable"])
    ];

    options.programs.dankMaterialShell = with lib.types; {
        default = {
            settings = lib.mkOption {
                type = jsonFormat.type;
                default = {};
                description = "The default settings are only read if the settings.json file don't exist";
            };
            session = lib.mkOption {
                type = jsonFormat.type;
                default = {};
                description = "The default session are only read if the session.json file don't exist";
            };
        };

        plugins = lib.mkOption {
            type = attrsOf (types.submodule ({config, ...}: {
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

            configs.dms = common.qmlPath;
        };

        systemd.user.services.dms = lib.mkIf cfg.systemd.enable {
            Unit = {
                Description = "DankMaterialShell";
                PartOf = [config.wayland.systemd.target];
                After = [config.wayland.systemd.target];
                X-Restart-Triggers = lib.optional cfg.systemd.restartIfChanged common.qmlPath;
            };

            Service = {
                ExecStart = lib.getExe dmsPkgs.dms-shell + " run --session";
                Restart = "on-failure";
            };

            Install.WantedBy = [config.wayland.systemd.target];
        };

        xdg.stateFile."DankMaterialShell/default-session.json" = lib.mkIf (cfg.default.session != {}) {
            source = jsonFormat.generate "default-session.json" cfg.default.session;
        };

        xdg.configFile = lib.mkMerge [
            (lib.mapAttrs' (name: plugin: {
                name = "DankMaterialShell/plugins/${name}";
                value.source = plugin.src;
            }) (lib.filterAttrs (n: v: v.enable) cfg.plugins))
            {
                "DankMaterialShell/default-settings.json" = lib.mkIf (cfg.default.settings != {}) {
                    source = jsonFormat.generate "default-settings.json" cfg.default.settings;
                };
            }
        ];

        home.packages = common.packages;
    };
}
