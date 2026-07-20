{
  pkgs ? import <nixpkgs> { },
}:

let
  packagesConfig = builtins.fromJSON (builtins.readFile ./packages.json);
  system = pkgs.stdenv.hostPlatform.system;
  names = builtins.filter (
    name:
    let
      cfg = packagesConfig.packages.${name};
    in
    builtins.elem system (cfg.systems or [ cfg.system ])
  ) (builtins.attrNames packagesConfig.packages);

  buildPackage =
    name:
    let
      cfg = packagesConfig.packages.${name};
    in
    if (cfg.kind or "nixpkgs-override") == "standalone" then
      import (./packages + "/${name}") { inherit pkgs; }
    else
      import (./packages + "/${name}") {
        inherit (pkgs) fetchurl libcap;
        base = pkgs.${cfg.baseAttr};
      };
in
builtins.listToAttrs (
  map (name: {
    inherit name;
    value = buildPackage name;
  }) names
)
