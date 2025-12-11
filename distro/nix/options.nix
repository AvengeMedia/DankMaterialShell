{
  lib,
  dmsPkgs,
  ...
}:
let
  inherit (lib) types;
  path = [
    "programs"
    "dankMaterialShell"
  ];

  builtInRemovedMsg = "This is now built-in in DMS and doesn't need additional dependencies.";
in
{
  imports = [
    (lib.mkRemovedOptionModule (path ++ [ "enableBrightnessControl" ]) builtInRemovedMsg)
    (lib.mkRemovedOptionModule (path ++ [ "enableColorPicker" ]) builtInRemovedMsg)
  ];

  options.programs.dankMaterialShell = {
    enable = lib.mkEnableOption "DankMaterialShell";
    systemd = {
      enable = lib.mkEnableOption "DankMaterialShell systemd startup";
      restartIfChanged = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Auto-restart dms.service when dankMaterialShell changes";
      };
    };
    enableSystemMonitoring = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add needed dependencies to use system monitoring widgets";
    };
    enableClipboard = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add needed dependencies to use the clipboard widget";
    };
    enableVPN = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add needed dependencies to use the VPN widget";
    };
    enableDynamicTheming = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add needed dependencies to have dynamic theming support";
    };
    enableAudioWavelength = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add needed dependencies to have audio wavelength support";
    };
    enableCalendarEvents = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add calendar events support via khal";
    };
    enableSystemSound = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Add needed dependencies to have system sound support";
    };
    quickshell = {
      package = lib.mkPackageOption dmsPkgs "quickshell" {
        extraDescription = "The quickshell package to use (defaults to be built from source, in the commit 26531f due to unreleased features used by DMS).";
      };
    };

    plugins = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = lib.mkOption {
              type = types.bool;
              default = true;
              description = "Whether to enable this plugin";
            };
            src = lib.mkOption {
              type = types.package;
              description = "Source of the plugin package or path";
            };
          };
        }
      );
      default = { };
      description = "DMS Plugins to install and enable";
      example = lib.literalExpression ''
        {
          DockerManager = {
            src = pkgs.fetchFromGitHub {
              owner = "LuckShiba";
              repo = "DmsDockerManager";
              rev = "v1.2.0";
              sha256 = "sha256-VoJCaygWnKpv0s0pqTOmzZnPM922qPDMHk4EPcgVnaU=";
            };
          };
          AnotherPlugin = {
            enable = true;
            src = pkgs.another-plugin;
          };
        }
      '';
    };
  };
}
