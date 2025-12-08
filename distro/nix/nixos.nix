{
    config,
    pkgs,
    lib,
    dmsPkgs,
    ...
} @ args: let
    cfg = config.programs.dankMaterialShell;
    common = import ./common.nix {inherit config pkgs lib dmsPkgs;};
in {
    imports = [
        (import ./options.nix args)
    ];

    config = lib.mkIf cfg.enable
    {
        environment.etc."xdg/quickshell/dms".source = "${dmsPkgs.dms-shell}/share/quickshell/dms";

        systemd.user.services.dms = lib.mkIf cfg.systemd.enable {
            description = "DankMaterialShell";
            path = lib.mkForce [];

            partOf = ["graphical-session.target"];
            after = ["graphical-session.target"];
            wantedBy = ["graphical-session.target"];
            restartTriggers = lib.optional cfg.systemd.restartIfChanged common.qmlPath;

            serviceConfig = {
                ExecStart = lib.getExe dmsPkgs.dms-shell + " run --session";
                Restart = "on-failure";
            };
        };

        environment.systemPackages = [cfg.quickshell.package] ++ common.packages;
    };
}
