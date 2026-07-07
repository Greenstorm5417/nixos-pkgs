# Example flake showing how to consume the auto-updated `windsurf` package from
# another NixOS system or Home Manager configuration.
#
# Copy the relevant bits into your own flake.nix.
{
  description = "Example consumer of nixos-pkgs' windsurf package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-pkgs.url = "github:Greenstorm5417/nixos-pkgs";
  };

  outputs =
    { nixpkgs, nixos-pkgs, ... }:
    {
      # --- NixOS system configuration -----------------------------------
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          {
            nixpkgs.overlays = [ nixos-pkgs.overlays.default ];
            nixpkgs.config.allowUnfree = true;

            environment.systemPackages = [
              # tracks the latest upstream windsurf release automatically.
              nixos-pkgs.packages.x86_64-linux.windsurf
            ];
          }
        ];
      };

      # --- Home Manager configuration ------------------------------------
      # homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
      #   pkgs = import nixpkgs {
      #     system = "x86_64-linux";
      #     overlays = [ nixos-pkgs.overlays.default ];
      #     config.allowUnfree = true;
      #   };
      #   modules = [
      #     {
      #       home.packages = [ nixos-pkgs.packages.x86_64-linux.windsurf ];
      #     }
      #   ];
      # };
    };
}
