{
  fetchurl,
  base,
  ...
}:

let
  generated = import ./generated.nix;
in
base.overrideAttrs (_old: {
  version = generated.version;

  src = fetchurl {
    url = generated.url;
    hash = generated.hash;
  };
})
