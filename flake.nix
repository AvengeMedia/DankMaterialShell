{
    description = "Dank Material Shell";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        dgop = {
            url = "github:AvengeMedia/dgop";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = {
        self,
        nixpkgs,
        dgop,
        ...
    }: let
        forEachSystem = fn:
            nixpkgs.lib.genAttrs ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"] (
                system: fn system nixpkgs.legacyPackages.${system}
            );
        buildDmsPkgs = pkgs: {
            dmsCli = self.packages.${pkgs.stdenv.hostPlatform.system}.dmsCli;
            dgop = dgop.packages.${pkgs.stdenv.hostPlatform.system}.dgop;
            dankMaterialShell = self.packages.${pkgs.stdenv.hostPlatform.system}.dankMaterialShell;
        };
    in {
        formatter = forEachSystem (_: pkgs: pkgs.alejandra);

        packages = forEachSystem (
            system: pkgs: let
                mkDate = longDate:
                    pkgs.lib.concatStringsSep "-" [
                        (builtins.substring 0 4 longDate)
                        (builtins.substring 4 2 longDate)
                        (builtins.substring 6 2 longDate)
                    ];
                version =
                    pkgs.lib.removePrefix "v" (pkgs.lib.trim (builtins.readFile ./quickshell/VERSION))
                    + "+date="
                    + mkDate (self.lastModifiedDate or "19700101")
                    + "_"
                    + (self.shortRev or "dirty");
            in {
                dmsCli = pkgs.buildGoModule (finalAttrs: {
                    inherit version;

                    pname = "dmsCli";
                    src = ./core;
                    vendorHash = "sha256-XbCg6qQwD4g4R/hBReLGE4NOq9uv0LBqogmfpBs//Ic=";

                    subPackages = ["cmd/dms"];

                    ldflags = [
                        "-s"
                        "-w"
                        "-X main.Version=${finalAttrs.version}"
                    ];

                    meta = {
                        description = "DankMaterialShell Command Line Interface";
                        homepage = "https://github.com/AvengeMedia/danklinux";
                        mainProgram = "dms";
                        license = pkgs.lib.licenses.mit;
                        platforms = pkgs.lib.platforms.unix;
                    };
                });

                dankMaterialShell = pkgs.stdenvNoCC.mkDerivation {
                    inherit version;

                    pname = "dankMaterialShell";
                    src = ./quickshell;
                    installPhase = ''
                        mkdir -p $out/etc/xdg/quickshell
                        cp -r ./ $out/etc/xdg/quickshell/dms
                    '';
                };

                default = self.packages.${system}.dmsCli;
            }
        );

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
