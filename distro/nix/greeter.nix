{
  lib,
  config,
  pkgs,
  dmsPkgs,
  ...
}:
let
  inherit (lib) types;
  cfg = config.programs.dank-material-shell.greeter;

  inherit (config.services.greetd.settings.default_session) user;

  compositorPackage =
    let
      configured = lib.attrByPath [ "programs" cfg.compositor.name "package" ] null config;
    in
    if configured != null then configured else builtins.getAttr cfg.compositor.name pkgs;

  cacheDir = "/var/lib/dms-greeter";
  greeterScript = pkgs.writeShellScriptBin "dms-greeter" ''
    export PATH=$PATH:${
      lib.makeBinPath [
        cfg.quickshell.package
        compositorPackage
      ]
    }
    ${
      lib.escapeShellArgs (
        [
          "sh"
          "${../../quickshell/Modules/Greetd/assets/dms-greeter}"
          "--cache-dir"
          cacheDir
          "--command"
          cfg.compositor.name
          "-p"
          "${dmsPkgs.dms-shell}/share/quickshell/dms"
        ]
        ++ lib.optionals (cfg.compositor.customConfig != "") [
          "-C"
          "${pkgs.writeText "dmsgreeter-compositor-config" cfg.compositor.customConfig}"
        ]
      )
    } ${lib.optionalString cfg.logs.save "> ${cfg.logs.path} 2>&1"}
  '';

  jq = lib.getExe pkgs.jq;
in
{
  imports =
    let
      msg = "The option 'programs.dank-material-shell.greeter.compositor.extraConfig' is deprecated. Please use 'programs.dank-material-shell.greeter.compositor.customConfig' instead.";
    in
    [
      (lib.mkRemovedOptionModule [
        "programs"
        "dank-material-shell"
        "greeter"
        "compositor"
        "extraConfig"
      ] msg)
      ./dms-rename.nix
    ];

  options.programs.dank-material-shell.greeter = {
    enable = lib.mkEnableOption "DankMaterialShell greeter";
    compositor.name = lib.mkOption {
      type = types.enum [
        "niri"
        "hyprland"
        "sway"
        "labwc"
      ];
      description = "Compositor to run greeter in";
    };
    compositor.customConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Custom compositor config";
    };
    configFiles = lib.mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Config files to copy into data directory";
      example = [
        "/home/user/.config/DankMaterialShell/settings.json"
      ];
    };
    configHome = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/home/user";
      description = ''
        User home directory to copy configurations for greeter
        If DMS config files are in non-standard locations then use the configFiles option instead
      '';
    };
    quickshell = {
      package = lib.mkPackageOption dmsPkgs "quickshell" {
        extraDescription = "The quickshell package to use (defaults to be built from source, in the commit 26531f due to unreleased features used by DMS).";
      };
    };
    logs.save = lib.mkEnableOption "saving logs from DMS greeter to file";
    logs.path = lib.mkOption {
      type = types.path;
      default = "/tmp/dms-greeter.log";
      description = ''
        File path to save DMS greeter logs to
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (config.users.users.${user} or { }) != { };
        message = ''
          dmsgreeter: user set for greetd default_session ${user} does not exist. Please create it before referencing it.
        '';
      }
    ];
    services.greetd = {
      enable = lib.mkDefault true;
      settings.default_session.command = lib.mkDefault (lib.getExe greeterScript);
    };
    fonts.packages = with pkgs; [
      fira-code
      inter
      material-symbols
    ];
    systemd.tmpfiles.settings."10-dmsgreeter" = {
      ${cacheDir}.d = {
        inherit user;
        group =
          if config.users.users.${user}.group != "" then config.users.users.${user}.group else "greeter";
        mode = "0750";
      };
    };
    systemd.services.greetd.preStart = ''
      cd ${cacheDir}
      ${lib.concatStringsSep "\n" (
        lib.map (f: ''
          if [ -f "${f}" ]; then
              cp "${f}" .
          fi
        '') cfg.configFiles
      )}

      if [ -f session.json ]; then
          copy_wallpaper() {
              local path=$(${jq} -r ".$1 // empty" session.json)
              if [ -f "$path" ]; then
                  cp "$path" "$2"
                  ${jq} ".$1 = \"${cacheDir}/$2\"" session.json > session.tmp
                  mv session.tmp session.json
              fi
          }

          copy_monitor_wallpapers() {
              ${jq} -r ".$1 // {} | to_entries[] | .key + \":\" + .value" session.json 2>/dev/null | while IFS=: read monitor path; do
                  local dest="$2-$(echo "$monitor" | tr -c '[:alnum:]' '-')"
                  if [ -f "$path" ]; then
                      cp "$path" "$dest"
                      ${jq} --arg m "$monitor" --arg p "${cacheDir}/$dest" ".$1[\$m] = \$p" session.json > session.tmp
                      mv session.tmp session.json
                  fi
              done
          }

          copy_wallpaper "wallpaperPath" "wallpaper"
          copy_wallpaper "wallpaperPathLight" "wallpaper-light"
          copy_wallpaper "wallpaperPathDark" "wallpaper-dark"
          copy_monitor_wallpapers "monitorWallpapers" "wallpaper-monitor"
          copy_monitor_wallpapers "monitorWallpapersLight" "wallpaper-monitor-light"
          copy_monitor_wallpapers "monitorWallpapersDark" "wallpaper-monitor-dark"
      fi

      if [ -f settings.json ]; then
          if cp "$(${jq} -r '.customThemeFile' settings.json)" custom-theme.json; then
              mv settings.json settings.orig.json
              ${jq} '.customThemeFile = "${cacheDir}/custom-theme.json"' settings.orig.json > settings.json
          fi
      fi

      mv dms-colors.json colors.json || :
      chown ${user}: * || :
    '';
    programs.dank-material-shell.greeter.configFiles = lib.mkIf (cfg.configHome != null) [
      "${cfg.configHome}/.config/DankMaterialShell/settings.json"
      "${cfg.configHome}/.local/state/DankMaterialShell/session.json"
      "${cfg.configHome}/.cache/DankMaterialShell/dms-colors.json"
    ];
  };
}
