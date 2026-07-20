{
  description = "Generic, auto-updated Nix package framework (see packages.json)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:

    let
      packagesConfig = builtins.fromJSON (builtins.readFile ./packages.json);
      packageNames = builtins.attrNames packagesConfig.packages;
      systems = nixpkgs.lib.unique (
        builtins.concatMap (
          name:
          let
            cfg = packagesConfig.packages.${name};
          in
          cfg.systems or [ cfg.system ]
        ) packageNames
      );

      forAllSystems = nixpkgs.lib.genAttrs systems;

      supportsSystem = name: system:
        let
          cfg = packagesConfig.packages.${name};
        in
        builtins.elem system (cfg.systems or [ cfg.system ]);

      # Every package directory under ./packages is built by importing its
      # default.nix with the inputs described by its packages.json entry.
      buildPackage =
        prev: name:
        let
          cfg = packagesConfig.packages.${name};
        in
        if (cfg.kind or "nixpkgs-override") == "standalone" then
          import (./packages + "/${name}") { pkgs = prev; }
        else
          import (./packages + "/${name}") {
            inherit (prev) fetchurl libcap;
            base = prev.${cfg.baseAttr};
          };
    in
    {
      # Adds `<name>-auto` to nixpkgs for every package in packages.json,
      # each overriding the upstream package with the latest fetched
      # version/hash from packages/<name>/generated.nix.
      overlays.default =
        final: prev:
        builtins.listToAttrs (
          map (name: {
            name = "${name}-auto";
            value = buildPackage prev name;
          }) (builtins.filter (name: supportsSystem name prev.stdenv.hostPlatform.system) packageNames)
        );

      packages = forAllSystems (
        system:
        let
          systemPackageNames = builtins.filter (name: supportsSystem name system) packageNames;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };

          entries = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = pkgs."${name}-auto";
            }) systemPackageNames
          );
          configuredDefault = packagesConfig.default or null;
          defaultName =
            if configuredDefault != null && builtins.elem configuredDefault systemPackageNames then
              configuredDefault
            else
              builtins.head systemPackageNames;
        in
        entries
        // (
          if systemPackageNames == [ ] then
            { }
          else
            { default = entries.${defaultName}; }
        )
      );

      # `nix flake check` builds every package as a check, so a broken
      # generated package fails CI before it can be merged/pushed.
      checks = forAllSystems (
        system:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = self.packages.${system}.${name};
          }) (builtins.filter (name: supportsSystem name system) packageNames)
        )
      );

      # `nix fmt` formats all Nix files in the repo with nixfmt.
      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt-rfc-style);

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nix
              jq
              curl
              git
              nixfmt-rfc-style
            ];
          };
        }
      );
    };
}
