{
  fetchurl,
  libcap,
  base,
  ...
}:

let
  generated = import ./generated.nix;
in
base.overrideAttrs (old: {
  version = generated.version;

  src = fetchurl {
    url = generated.url;
    hash = generated.hash;
  };

  # The bundled bwrap-linux-x64 helper (used by the kiro-agent extension's
  # sandboxing feature) links against libcap, which isn't otherwise pulled
  # in by the upstream vscode-generic builder. Without it, auto-patchelf
  # fails the build with "could not satisfy dependency libcap.so.2".
  buildInputs = (old.buildInputs or [ ]) ++ [ libcap ];
})
