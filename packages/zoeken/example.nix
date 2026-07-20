{
  pkgs ? import <nixpkgs> { },
}:

(import ../.. { inherit pkgs; }).zoeken
