{
  self,
  pkgs,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "dms-greeter-niri-module";

  nodes.machine = {
    imports = [
      self.nixosModules.greeter
    ];

    users.groups.greeter = { };
    users.users.greeter = {
      isSystemUser = true;
      group = "greeter";
    };

    services.greetd.settings.default_session.user = "greeter";

    programs.niri.enable = true;

    programs.dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    import re

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("greetd.service")

    machine.succeed("systemctl is-enabled greetd.service")
    machine.succeed("systemctl is-active greetd.service")

    greetd_unit = machine.succeed("cat /etc/systemd/system/greetd.service")
    config_match = re.search(r'--config (/nix/store[^ ]+-greetd.toml)', greetd_unit)
    if config_match is None:
        raise AssertionError(greetd_unit)

    greetd_config_path = config_match.group(1)
    greetd_config = machine.succeed(f"cat {greetd_config_path}")
    t.assertIn("dms-greeter", greetd_config)

    script_match = re.search(r'command\s*=\s*"([^"]+/bin/dms-greeter)"', greetd_config)
    if script_match is None:
        raise AssertionError(greetd_config)

    script_path = script_match.group(1)
    script = machine.succeed(f"cat {script_path}")
    t.assertIn("--command", script)
    t.assertIn("niri", script)
    t.assertIn("/share/quickshell/dms", script)
  '';
}
