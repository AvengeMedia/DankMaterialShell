{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "dankMaterialShell"
      ]
      [
        "programs"
        "dank-material-shell"
      ]
    )
  ];
}
