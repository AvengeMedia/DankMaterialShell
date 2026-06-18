{
  self,
  pkgs,
  ...
}:
let
  homeManagerNixosModule =
    (fetchTarball {
      url = "https://github.com/nix-community/home-manager/archive/e82d4a4ecd18363aa2054cbaa3e32e4134c3dbf4.tar.gz";
      sha256 = "sha256-ZTYDofOM3/PJhRF1EuBh6uibm+DmkhU7Wor6mMN7YTc=";
    })
    + "/nixos";
in
pkgs.testers.runNixOSTest {
  name = "dms-home-manager-module";

  nodes.machine = {
    ...
  }: {
    imports = [
      homeManagerNixosModule
    ];

    users.users.danklinux = {
      isNormalUser = true;
      createHome = true;
      home = "/home/danklinux";
      extraGroups = [ "wheel" ];
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    home-manager.users.danklinux = {
      pkgs,
      ...
    }: {
      imports = [
        self.homeModules.dank-material-shell
      ];

      home.username = "danklinux";
      home.homeDirectory = "/home/danklinux";
      home.stateVersion = "25.11";

      programs.dank-material-shell = {
        enable = true;
        systemd = {
          enable = true;
          target = "default.target";
        };

        settings = {
          theme = "integration-test";
        };

        clipboardSettings = {
          maxItems = 10;
        };

        session = {
          startedFrom = "nixos-test";
        };

        plugins.TestPlugin = {
          enable = true;
          src = pkgs.runCommand "dms-test-plugin" { } ''
            mkdir -p "$out"
            echo plugin > "$out/plugin.txt"
          '';
          settings = {
            enabled = true;
            source = "test";
          };
        };
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")

    machine.succeed("su -- danklinux -c 'command -v dms'")
    machine.succeed("su -- danklinux -c 'test -f ~/.config/DankMaterialShell/settings.json'")
    machine.succeed("su -- danklinux -c 'test -f ~/.config/DankMaterialShell/clsettings.json'")
    machine.succeed("su -- danklinux -c 'test -f ~/.config/DankMaterialShell/plugin_settings.json'")
    machine.succeed("su -- danklinux -c 'test -e ~/.config/DankMaterialShell/plugins/TestPlugin'")
    machine.succeed("su -- danklinux -c 'test -f ~/.local/state/DankMaterialShell/session.json'")

    settings = json.loads(machine.succeed("su -- danklinux -c 'cat ~/.config/DankMaterialShell/settings.json'"))
    clipboard = json.loads(machine.succeed("su -- danklinux -c 'cat ~/.config/DankMaterialShell/clsettings.json'"))
    session = json.loads(machine.succeed("su -- danklinux -c 'cat ~/.local/state/DankMaterialShell/session.json'"))
    plugins = json.loads(machine.succeed("su -- danklinux -c 'cat ~/.config/DankMaterialShell/plugin_settings.json'"))
    doctor = json.loads(machine.succeed("su -- danklinux -c 'dms doctor --json'"))

    t.assertEqual(settings["theme"], "integration-test")
    t.assertEqual(clipboard["maxItems"], 10)
    t.assertEqual(session["startedFrom"], "nixos-test")
    t.assertTrue(plugins["TestPlugin"]["enabled"])
    t.assertEqual(plugins["TestPlugin"]["source"], "test")
    t.assertIsInstance(doctor.get("results"), list)
  '';
}
