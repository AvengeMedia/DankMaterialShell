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
    (lib.mkRemovedOptionModule
      [
        "programs"
        "dank-material-shell"
        "default"
        "settings"
      ]
      "Default settings have been removed and been replaced with programs.dank-material-shell.settings."
    )
    (lib.mkRemovedOptionModule [
      "programs"
      "dank-material-shell"
      "default"
      "session"
    ] "Default session has been removed and been replaced with programs.dank-material-shell.session.")
    (lib.mkRenamedOptionModule
      [ "programs" "dank-material-shell" "enableSystemd" ]
      [ "programs" "dank-material-shell" "systemd" "enable" ]
    )
  ];

  options.programs.dank-material-shell = {
    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "DankMaterialShell configuration settings as an attribute set, to be written to ~/.config/DankMaterialShell/settings.json.";
    };

    clipboardSettings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "DankMaterialShell clipboard settings as an attribute set, to be written to ~/.config/DankMaterialShell/clsettings.json.";
    };

    session = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "DankMaterialShell session settings as an attribute set, to be written to ~/.local/state/DankMaterialShell/session.json.";
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

    xdg.stateFile."DankMaterialShell/session.json" = lib.mkIf (cfg.session != { }) {
      source = jsonFormat.generate "session.json" cfg.session;
    };

    xdg.configFile = {
      "DankMaterialShell/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = jsonFormat.generate "settings.json" cfg.settings;
      };
      "DankMaterialShell/clsettings.json" = lib.mkIf (cfg.clsettings != { }) {
        source = jsonFormat.generate "clsettings.json" cfg.clsettings;
      };
      "DankMaterialShell/plugin_settings.json" = (
        lib.mapAttrs' (name: value: {
          name = "DankMaterialShell/plugins/${name}";
          inherit value;
        }) common.plugins
      );

    };
    home.packages = common.packages;
  };
}
