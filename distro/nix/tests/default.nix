{
  self,
  pkgs,
  ...
}:
rec {
  all = pkgs.symlinkJoin {
    name = "dms-nixos-tests";
    paths = [
      nixos-module
      nixos-service-start-module
      greeter-niri-module
      niri-home-module
      home-manager-module
    ];
  };

  nixos-module = import ./nixos-module.nix {
    inherit
      self
      pkgs
      ;
  };

  nixos-service-start-module = import ./nixos-service-start-module.nix {
    inherit
      self
      pkgs
      ;
  };

  greeter-niri-module = import ./greeter-niri-module.nix {
    inherit
      self
      pkgs
      ;
  };

  niri-home-module = import ./niri-home-module.nix {
    inherit
      self
      pkgs
      ;
  };

  home-manager-module = import ./home-manager-module.nix {
    inherit
      self
      pkgs
      ;
  };
}
