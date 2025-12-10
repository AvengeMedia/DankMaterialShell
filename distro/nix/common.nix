{
  config,
  lib,
  pkgs,
  dmsPkgs,
  ...
}:
let
  cfg = config.programs.dankMaterialShell;
in
{
  qmlPath = "${dmsPkgs.dms-shell}/share/quickshell/dms";

  packages = [
    dmsPkgs.dms-shell
  ]
  ++ lib.optional cfg.enableSystemMonitoring dmsPkgs.dgop
  ++ lib.optionals cfg.enableClipboard [
    pkgs.cliphist
    pkgs.wl-clipboard
  ]
  ++ lib.optionals cfg.enableVPN [
    pkgs.glib
    pkgs.networkmanager
  ]
  ++ lib.optional cfg.enableDynamicTheming pkgs.matugen
  ++ lib.optional cfg.enableAudioWavelength pkgs.cava
  ++ lib.optional cfg.enableCalendarEvents pkgs.khal
  ++ lib.optional cfg.enableSystemSound pkgs.kdePackages.qtmultimedia;
}
