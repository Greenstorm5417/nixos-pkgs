{
  description = "Zoeken from nixos-pkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-pkgs.url = "github:Greenstorm5417/nixos-pkgs";
  };

  outputs =
    { nixpkgs, nixos-pkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nixos-pkgs.overlays.default ];
      };
    in
    {
      packages.${system}.default = nixos-pkgs.packages.${system}.zoeken;

      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            environment.systemPackages = [ nixos-pkgs.packages.${system}.zoeken ];
          }
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ nixos-pkgs.packages.${system}.zoeken ];
      };
    };
}
