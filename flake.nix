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
            inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) dmsCli dankMaterialShell;
            dgop = dgop.packages.${pkgs.stdenv.hostPlatform.system}.dgop;
        };
        mkModuleWithDmsPkgs = path: args @ {pkgs, ...}: {
            imports = [
                (import path (args // {dmsPkgs = buildDmsPkgs pkgs;}))
            ];
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
                    vendorHash = "sha256-2PCqiW4frxME8IlmwWH5ktznhd/G1bah5Ae4dp0HPTQ=";

                    subPackages = ["cmd/dms"];

                    ldflags = [
                        "-s"
                        "-w"
                        "-X main.Version=${finalAttrs.version}"
                    ];

                    nativeBuildInputs = [pkgs.installShellFiles];

                    postInstall = ''
                        installShellCompletion --cmd dms \
                          --bash <($out/bin/dms completion bash) \
                          --fish <($out/bin/dms completion fish ) \
                          --zsh <($out/bin/dms completion zsh)
                    '';

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

                        # Create DMS Version file
                        echo "${version}" > $out/etc/xdg/quickshell/dms/VERSION

                        # Install desktop file
                        mkdir -p $out/share/applications
                        cp ${./assets/dms-open.desktop} $out/share/applications/dms-open.desktop

                        # Install icon
                        mkdir -p $out/share/icons/hicolor/scalable/apps
                        cp ${./core/assets/danklogo.svg} $out/share/icons/hicolor/scalable/apps/danklogo.svg
                    '';
                };

                default = self.packages.${system}.dmsCli;
            }
        );

        homeModules.dankMaterialShell.default = mkModuleWithDmsPkgs ./distro/nix/home.nix;

        homeModules.dankMaterialShell.niri = import ./distro/nix/niri.nix;

        nixosModules.dankMaterialShell = mkModuleWithDmsPkgs ./distro/nix/nixos.nix;

        nixosModules.greeter = mkModuleWithDmsPkgs ./distro/nix/greeter.nix;
    };
}
