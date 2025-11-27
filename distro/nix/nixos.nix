{
    config,
    pkgs,
    lib,
    dmsPkgs,
    ...
}: let
    cfg = config.programs.dankMaterialShell;
    common = import ./common.nix {inherit config pkgs lib dmsPkgs;};
in {
    imports = [
        ./options.nix
    ];

    config = lib.mkIf cfg.enable
    {
        environment.etc."xdg/quickshell/dms".source = "${dmsPkgs.dankMaterialShell}/etc/xdg/quickshell/dms";

        systemd.user.services.dms = lib.mkIf cfg.systemd.enable {
            description = "DankMaterialShell";
            path = lib.mkForce [];

            partOf = ["graphical-session.target"];
            after = ["graphical-session.target"];
            wantedBy = ["graphical-session.target"];
            restartTriggers = lib.optional cfg.systemd.restartIfChanged common.qmlPath;

            serviceConfig = {
                ExecStart = lib.getExe dmsPkgs.dmsCli + " run --session";
                Restart = "on-failure";
            };
        };

        environment.systemPackages = [cfg.quickshell.package] ++ common.packages;
    };
}
