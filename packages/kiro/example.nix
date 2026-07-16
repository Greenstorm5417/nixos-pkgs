# Example: build the `kiro` package on its own, without pulling in the rest
# of this flake's outputs.
#
# Usage:
#   nix-build example.nix
# or, from a flake:
#   nix build --impure --expr '(import ./example.nix)'

let
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  };

  pkgs = import nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
import ./default.nix {
  inherit (pkgs) fetchurl libcap;
  # `base` is the upstream nixpkgs `kiro` package; default.nix overrides its
  # version/src with the auto-fetched release described in ./generated.nix.
  base = pkgs.kiro;
}
