{
    description = "Dank Material Shell";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
        dgop,
        dms-cli,
        ...
    }: let
        forEachSystem = fn:
            nixpkgs.lib.genAttrs
            ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"]
            (system: fn system nixpkgs.legacyPackages.${system});
        buildDmsPkgs = pkgs: {
            dmsCli = dms-cli.packages.${pkgs.stdenv.hostPlatform.system}.default;
            dgop = dgop.packages.${pkgs.stdenv.hostPlatform.system}.dgop;
            dankMaterialShell = self.packages.${pkgs.stdenv.hostPlatform.system}.dankMaterialShell;
        };
    in {
        formatter = forEachSystem (_: pkgs: pkgs.alejandra);

        packages = forEachSystem (system: pkgs: {
            dankMaterialShell = let
                mkDate = longDate: pkgs.lib.concatStringsSep "-" [
                    (builtins.substring 0 4 longDate)
                    (builtins.substring 4 2 longDate)
                    (builtins.substring 6 2 longDate)
                ];
            in pkgs.stdenvNoCC.mkDerivation {
                pname = "dankMaterialShell";
                version = pkgs.lib.removePrefix "v" (pkgs.lib.trim (builtins.readFile ./VERSION))
                    + "+date=" + mkDate (self.lastModifiedDate or "19700101")
                    + "_" + (self.shortRev or "dirty");
                src = pkgs.lib.cleanSourceWith {
                    src = ./.;
                    filter = path: type:
                        !(builtins.any (prefix: pkgs.lib.path.hasPrefix (./. + prefix) (/. + path)) [
                            /.github
                            /.gitignore
                            /dms.spec
                            /dms-greeter.spec
                            /nix
                            /flake.nix
                            /flake.lock
                            /alejandra.toml
                        ]);
                };
                installPhase = ''
                    mkdir -p $out/etc/xdg/quickshell/dms
                    cp -r . $out/etc/xdg/quickshell/dms
                '';
            };

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
