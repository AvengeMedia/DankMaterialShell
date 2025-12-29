{
  description = "Dank Material Shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell?rev=41828c4180fb921df7992a5405f5ff05d2ac2fff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      quickshell,
      ...
    }:
    let
      forEachSystem =
        fn:
        nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ] (
          system: fn system nixpkgs.legacyPackages.${system}
        );
      buildDmsPkgs = pkgs: {
        dms-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        quickshell = quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
      mkModuleWithDmsPkgs =
        modulePath:
        args@{ pkgs, ... }:
        {
          imports = [
            (import modulePath (args // { dmsPkgs = buildDmsPkgs pkgs; }))
          ];
        };
      mkQmlImportPath =
        pkgs: qmlPkgs:
        pkgs.lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtQmlPrefix}") qmlPkgs);

      mkQtPluginPath =
        pkgs: qtPkgs:
        pkgs.lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtPluginPrefix}") qtPkgs);

      qmlPkgs =
        pkgs: with pkgs.kdePackages; [
          kirigami.unwrapped
          sonnet
          qtmultimedia
        ];
    in
    {
      packages = forEachSystem (
        system: pkgs:
        let
          mkDate =
            longDate:
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
        in
        {
          dms-shell = pkgs.buildGoModule (
            let
              rootSrc = ./.;
            in
            {
              inherit version;
              pname = "dms-shell";
              src = ./core;
              vendorHash = "sha256-DINaA5LCOWoxBIewuc39Rnwj6NdZoET7Q++B11Qg5rI=";

              subPackages = [ "cmd/dms" ];

              ldflags = [
                "-s"
                "-w"
                "-X main.Version=${version}"
              ];

              nativeBuildInputs = with pkgs; [
                installShellFiles
                makeWrapper
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

                wrapProgram $out/bin/dms \
                  --add-flags "-c $out/share/quickshell/dms" \
                  --prefix "NIXPKGS_QT6_QML_IMPORT_PATH" ":" "${mkQmlImportPath pkgs (qmlPkgs pkgs)}" \
                  --prefix "QT_PLUGIN_PATH" ":" "${mkQtPluginPath pkgs (qmlPkgs pkgs)}"

                install -Dm644 ${rootSrc}/assets/systemd/dms.service \
                  $out/lib/systemd/user/dms.service

                substituteInPlace $out/lib/systemd/user/dms.service \
                  --replace-fail /usr/bin/dms $out/bin/dms \
                  --replace-fail /usr/bin/pkill ${pkgs.procps}/bin/pkill

                substituteInPlace $out/share/quickshell/dms/Modules/Greetd/assets/dms-greeter \
                  --replace-fail /bin/bash ${pkgs.bashInteractive}/bin/bash

                substituteInPlace $out/share/quickshell/dms/assets/pam/fprint \
                  --replace-fail pam_fprintd.so ${pkgs.fprintd}/lib/security/pam_fprintd.so

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
            }
          );

          quickshell = quickshell.packages.${system}.default;

          default = self.packages.${system}.dms-shell;
        }
      );

      homeModules.dank-material-shell = mkModuleWithDmsPkgs ./distro/nix/home.nix;

      homeModules.default = self.homeModules.dank-material-shell;

      homeModules.niri = import ./distro/nix/niri.nix;

      homeModules.dankMaterialShell.default = builtins.warn "dank-material-shell: flake output `homeModules.dankMaterialShell.default` has been renamed to `homeModules.dank-material-shell`" self.homeModules.dank-material-shell;

      homeModules.dankMaterialShell.niri = builtins.warn "dank-material-shell: flake output `homeModules.dankMaterialShell.niri` has been renamed to `homeModules.niri`" self.homeModules.niri;

      nixosModules.dank-material-shell = mkModuleWithDmsPkgs ./distro/nix/nixos.nix;

      nixosModules.default = self.nixosModules.dank-material-shell;

      nixosModules.greeter = mkModuleWithDmsPkgs ./distro/nix/greeter.nix;

      nixosModules.dankMaterialShell = builtins.warn "dank-material-shell: flake output `nixosModules.dankMaterialShell` has been renamed to `nixosModules.dank-material-shell`" self.nixosModules.dank-material-shell;

      devShells = forEachSystem (
        system: pkgs:
        let
          devQmlPkgs = [
            quickshell.packages.${system}.default
            pkgs.kdePackages.qtdeclarative
          ]
          ++ (qmlPkgs pkgs);
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              with pkgs;
              [
                go_1_24
                gopls
                delve
                go-tools
                gnumake

                prek
                uv # for prek

                # Nix development tools
                nixd
                nil
              ]
              ++ devQmlPkgs;

            shellHook = ''
              touch quickshell/.qmlls.ini 2>/dev/null
              if [ ! -f .git/hooks/pre-commit ]; then prek install; fi
            '';

            QML2_IMPORT_PATH = mkQmlImportPath pkgs devQmlPkgs;
            QT_PLUGIN_PATH = mkQtPluginPath pkgs devQmlPkgs;
          };
        }
      );
    };
}
