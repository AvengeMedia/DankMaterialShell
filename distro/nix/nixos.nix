{
  config,
  pkgs,
  lib,
  dmsPkgs,
  ...
}@args:
let
  cfg = config.programs.dank-material-shell;
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
  ];
  options.programs.dank-material-shell.systemd.target = lib.mkOption {
    type = lib.types.str;
    description = "Systemd target to bind to.";
    default = "graphical-session.target";
  };
  config = lib.mkIf cfg.enable {
    systemd.user.services.dms = lib.mkIf cfg.systemd.enable {
      description = "DankMaterialShell";
      path = lib.mkForce [ ];

      partOf = [ cfg.systemd.target ];
      after = [ cfg.systemd.target ];
      wantedBy = [ cfg.systemd.target ];
      restartIfChanged = cfg.systemd.restartIfChanged;

      serviceConfig = {
        ExecStart = lib.getExe dmsPkgs.dms-shell + " run --session";
        Restart = "on-failure";
      };
    };

    environment.systemPackages = [ cfg.quickshell.package ] ++ common.packages;

    environment.etc = lib.mapAttrs' (name: value: {
      name = "xdg/quickshell/dms-plugins/${name}";
      inherit value;
    }) common.plugins;

    services.power-profiles-daemon.enable = lib.mkDefault true;
    services.accounts-daemon.enable = lib.mkDefault true;
  };
}
