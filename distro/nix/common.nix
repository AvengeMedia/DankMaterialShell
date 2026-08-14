{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dank-material-shell;
in
{
  packages = [
    cfg.package
  ]
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
