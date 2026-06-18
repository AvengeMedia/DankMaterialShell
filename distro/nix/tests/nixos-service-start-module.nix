{
  self,
  pkgs,
  ...
}:
let
  fakeDms = pkgs.writeShellScriptBin "dms" ''
    printf '%s\n' "$@" > /tmp/dms-service-args
    exec ${pkgs.coreutils}/bin/sleep 300
  '';
in
pkgs.testers.runNixOSTest {
  name = "dms-nixos-service-start-module";

  nodes.machine = {
    imports = [
      self.nixosModules.dank-material-shell
    ];

    users.users.danklinux = {
      isNormalUser = true;
      linger = true;
      extraGroups = [ "wheel" ];
    };

    programs.dank-material-shell = {
      enable = true;
      package = fakeDms;
      systemd = {
        enable = true;
        target = "default.target";
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    machine.succeed("systemctl --machine=danklinux@ --user start dms.service")
    machine.wait_until_succeeds("systemctl --machine=danklinux@ --user is-active dms.service")
    machine.wait_until_succeeds("test -f /tmp/dms-service-args")
    machine.succeed("grep -Fx run /tmp/dms-service-args")
    machine.succeed("grep -Fx -- --session /tmp/dms-service-args")
  '';
}
