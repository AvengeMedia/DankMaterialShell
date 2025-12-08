{
    description = "Dank Material Shell";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        dgop = {
            url = "github:AvengeMedia/dgop";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        quickshell = {
            url = "git+https://git.outfoxxed.me/quickshell/quickshell?rev=26531fc46ef17e9365b03770edd3fb9206fcb460";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = {
        self,
        nixpkgs,
        dgop,
        quickshell,
        ...
    }: let
        forEachSystem = fn:
            nixpkgs.lib.genAttrs ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"] (
                system: fn system nixpkgs.legacyPackages.${system}
            );
        buildDmsPkgs = pkgs: {
            dms-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
            dgop = dgop.packages.${pkgs.stdenv.hostPlatform.system}.dgop;
            quickshell = quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
                dms-shell = pkgs.buildGoModule (let
                    rootSrc = ./.;
                in {
                    inherit version;
                    pname = "dms-shell";
                    src = ./core;
                    vendorHash = "sha256-2PCqiW4frxME8IlmwWH5ktznhd/G1bah5Ae4dp0HPTQ=";

                    subPackages = ["cmd/dms"];

                    ldflags = [
                        "-s"
                        "-w"
                        "-X main.Version=${version}"
                    ];

                    nativeBuildInputs = [
                        pkgs.installShellFiles
                        pkgs.makeWrapper
                    ];

                    postInstall = ''
                        mkdir -p $out/share/quickshell/dms
                        cp -r ${rootSrc}/quickshell/. $out/share/quickshell/dms/

                        chmod u+w $out/share/quickshell/dms/VERSION
                        echo "${version}" > $out/share/quickshell/dms/VERSION

                        # Install desktop file and icon
                        install -D ${rootSrc}/assets/dms-open.desktop \
                          $out/share/applications/dms-open.desktop
                        install -D ${rootSrc}/core/assets/danklogo.svg \
                          $out/share/hicolor/scalable/apps/danklogo.svg

                        wrapProgram $out/bin/dms --add-flags "-c $out/share/quickshell/dms"

                        install -Dm644 ${rootSrc}/assets/systemd/dms.service \
                          $out/lib/systemd/user/dms.service

                        substituteInPlace $out/lib/systemd/user/dms.service \
                          --replace-fail /usr/bin/dms $out/bin/dms \
                          --replace-fail /usr/bin/pkill ${pkgs.procps}/bin/pkill

                        substituteInPlace $out/share/quickshell/dms/Modules/Greetd/assets/dms-greeter \
                          --replace-fail /bin/bash ${pkgs.bashInteractive}/bin/bash

                        installShellCompletion --cmd dms \
                          --bash <($out/bin/dms completion bash) \
                          --fish <($out/bin/dms completion fish) \
                          --zsh <($out/bin/dms completion zsh)
                    '';

                    meta = {
                        description = "Desktop shell for wayland compositors built with Quickshell & GO";
                        homepage = "https://danklinux.com";
                        changelog = "https://github.com/AvengeMedia/DankMaterialShell/releases/tag/v${version}";
                        license = pkgs.lib.licenses.mit;
                        mainProgram = "dms";
                        platforms = pkgs.lib.platforms.linux;
                    };
                });

                default = self.packages.${system}.dms-shell;
            }
        );

        homeModules.dankMaterialShell.default = mkModuleWithDmsPkgs ./distro/nix/home.nix;

        homeModules.dankMaterialShell.niri = import ./distro/nix/niri.nix;

        nixosModules.dankMaterialShell = mkModuleWithDmsPkgs ./distro/nix/nixos.nix;

        nixosModules.greeter = mkModuleWithDmsPkgs ./distro/nix/greeter.nix;
    };
}
