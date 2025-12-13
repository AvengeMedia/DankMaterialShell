{
  config,
  pkgs,
  lib,
  dmsPkgs,
  ...
}@args:
let
  cfg = config.programs.dank-material-shell;
  jsonFormat = pkgs.formats.json { };
  common = import ./common.nix {
    inherit
      config
      pkgs
      lib
      dmsPkgs
      ;
  };
in
{
  imports = [
    (import ./options.nix args)
    (lib.mkRemovedOptionModule [
      "programs"
      "dank-material-shell"
      "enableNightMode"
    ] "Night mode is now always available.")
    (lib.mkRenamedOptionModule
      [ "programs" "dank-material-shell" "enableSystemd" ]
      [ "programs" "dank-material-shell" "systemd" "enable" ]
    )
  ];

  options.programs.dank-material-shell = with lib.types; {
    default = {
      settings = lib.mkOption {
        type = jsonFormat.type;
        default = { };
        description = "The default settings are only read if the settings.json file don't exist";
      };
      session = lib.mkOption {
        type = jsonFormat.type;
        default = { };
        description = "The default session are only read if the session.json file don't exist";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.quickshell = {
      enable = true;
      inherit (cfg.quickshell) package;
    };

    systemd.user.services.dms = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "DankMaterialShell";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };

      Service = {
        ExecStart = lib.getExe dmsPkgs.dms-shell + " run --session";
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    xdg.stateFile."DankMaterialShell/default-session.json" = lib.mkIf (cfg.default.session != { }) {
      source = jsonFormat.generate "default-session.json" cfg.default.session;
    };

    xdg.configFile = lib.mkMerge [
      (lib.mapAttrs' (name: value: {
        name = "DankMaterialShell/plugins/${name}";
        inherit value;
      }) common.plugins)
      {
        "DankMaterialShell/default-settings.json" = lib.mkIf (cfg.default.settings != { }) {
          source = jsonFormat.generate "default-settings.json" cfg.default.settings;
        };
      }
    ];

    home.packages = common.packages;
  };
}
