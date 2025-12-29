{
  config,
  lib,
  pkgs,
  dmsPkgs,
  ...
}:
let
  cfg = config.programs.dank-material-shell;
in
{
  packages = [
    dmsPkgs.dms-shell
  ]
  ++ lib.optional cfg.enableSystemMonitoring cfg.dgop.package
  ++ lib.optionals cfg.enableVPN [
    pkgs.glib
    pkgs.networkmanager
  ]
  ++ lib.optional cfg.enableDynamicTheming pkgs.matugen
  ++ lib.optional cfg.enableAudioWavelength pkgs.cava
  ++ lib.optional cfg.enableCalendarEvents pkgs.khal;

  plugins = lib.mapAttrs (name: plugin: {
    source = plugin.src;
  }) (lib.filterAttrs (n: v: v.enable) cfg.plugins);
}
