{
    description = "Dank Material Shell";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
        quickshell = {
            url = "git+https://git.outfoxxed.me/quickshell/quickshell";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        dgop = {
            url = "github:AvengeMedia/dgop";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        dms-cli = {
            url = "github:AvengeMedia/danklinux";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = {
        self,
        nixpkgs,
        quickshell,
        dgop,
        dms-cli,
        ...
    }: let
        forEachSystem = fn:
            nixpkgs.lib.genAttrs
            ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"]
            (system: fn system nixpkgs.legacyPackages.${system});
        buildDmsPkgs = pkgs: {
            dmsCli = dms-cli.packages.${pkgs.system}.default;
            dgop = dgop.packages.${pkgs.system}.dgop;
            dankMaterialShell = self.packages.${pkgs.system}.dankMaterialShell;
        };
    in {
        formatter = forEachSystem (_: pkgs: pkgs.alejandra);

        packages = forEachSystem (system: pkgs: {
            dankMaterialShell = pkgs.stdenvNoCC.mkDerivation {
                name = "dankMaterialShell";
                src = ./.;
                installPhase = ''
                    mkdir -p $out/etc/xdg/quickshell/DankMaterialShell
                    cp -r . $out/etc/xdg/quickshell/DankMaterialShell
                    ln -s $out/etc/xdg/quickshell/DankMaterialShell $out/etc/xdg/quickshell/dms
                '';
            };

            quickshell = quickshell.packages.${system}.default;

            default = self.packages.${system}.dankMaterialShell;
        });

        homeModules.dankMaterialShell.default = {pkgs, ...}: let
            dmsPkgs = buildDmsPkgs pkgs;
        in {
            imports = [./nix/default.nix];
            _module.args.dmsPkgs = dmsPkgs;
        };

        homeModules.dankMaterialShell.niri = import ./nix/niri.nix;

        nixosModules.greeter = {pkgs, ...}: let
            dmsPkgs = buildDmsPkgs pkgs;
        in {
            imports = [./nix/greeter.nix];
            _module.args.dmsPkgs = dmsPkgs;
        };
    };
}
