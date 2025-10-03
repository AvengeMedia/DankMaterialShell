{
    lib,
    config,
    pkgs,
    dmsPkgs,
    ...
}: let
    inherit (lib) types;
    cfg = config.programs.dankMaterialShell.greeter;

    sessionConfigs = {
        niri = pkgs.writeText "niri.kdl" ''
            hotkey-overlay {
                skip-at-startup
            }

            environment {
                DMS_RUN_GREETER "1"
                DMS_GREET_CFG_DIR "/var/lib/dmsgreeter"
            }

            spawn-at-startup "sh" "-c" "${pkgs.quickshell}/bin/qs -p ${dmsPkgs.dankMaterialShell}/etc/xdg/quickshell/dms; niri msg action quit --skip-confirmation"

            debug {
              keep-max-bpc-unchanged
            }

            gestures {
               hot-corners {
                 off
               }
            }
        '';
        hyprland = pkgs.writeText "hyprland.conf" ''
            env = DMS_RUN_GREETER,1
            env = DMS_GREET_CFG_DIR,/var/lib/dmsgreeter

            exec = sh -c "${pkgs.quickshell}/bin/qs -p ${dmsPkgs.dankMaterialShell}/etc/xdg/quickshell/dms; hyprctl dispatch exit"
        '';
    };

    sessionCommands = {
        niri = ''
            ${config.programs.niri.package}/bin/niri -c ${sessionConfigs.niri}
        '';
        hyprland = ''
            ${config.programs.hyprland.package}/bin/hyprland -c ${sessionConfigs.hyprland}
        '';
    };

    greeterScript = pkgs.writeShellScriptBin "dms-greeter" ''
        export QT_QPA_PLATFORM=wayland
        export XDG_SESSION_TYPE=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export EGL_PLATFORM=gbm
        ${sessionCommands.${cfg.compositor}}
    '';
in {
    options.programs.dankMaterialShell.greeter = {
        enable = lib.mkEnableOption "DankMaterialShell greeter";
        compositor = lib.mkOption {
            type = types.enum ["niri" "hyprland"];
            description = "Compositor to run greeter in";
        };
        configFiles = lib.mkOption {
            type = types.listOf types.path;
            default = [];
            description = "Config files to symlink into data directory";
            example = [
                "/home/user/.config/DankMaterialShell/settings.json"
            ];
        };
        configHome = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "/home/user";
            description = ''
                User home directory to symlink configurations for greeter
                If DMS config files are in non-standard locations then use the configFiles option instead
            '';
        };
    };
    config = lib.mkIf cfg.enable {
        services.greetd = {
            enable = lib.mkDefault true;
            settings.default_session.command = lib.mkDefault (lib.getExe greeterScript);
        };
        fonts.packages = with pkgs; [
            fira-code
            inter
            material-symbols
        ];
        environment.systemPackages = with pkgs; [
            fira-code
            inter
            material-symbols
        ];
        systemd.tmpfiles.settings."10-dmsgreeter" = {
            "/var/lib/dmsgreeter".d = {
                user = "greeter";
                group = "greeter";
                mode = "0755";
            };
        };
        systemd.services.greetd.preStart = ''
            ln -f ${lib.concatStringsSep " " cfg.configFiles} /var/lib/dmsgreeter/
        '';
        programs.dankMaterialShell.greeter.configFiles = lib.mkIf (cfg.configHome != null) [
            "${cfg.configHome}/.config/DankMaterialShell/settings.json"
            "${cfg.configHome}/.local/state/DankMaterialShell/session.json"
            "${cfg.configHome}/.cache/quickshell/dankshell/dms-colors.json"
        ];
    };
}
