{
  fetchurl,
  ripgrep,
  libcap,
  base,
  ...
}:

let
  generated = import ./generated.nix;

  fixRipgrepPatch =
    postPatch:
    let
      parts = builtins.split "\nrm resources/app/node_modules/@vscode/ripgrep/bin/rg\n" postPatch;
    in
    if builtins.length parts > 1 then
      builtins.head parts
      + "\n"
      + ''
        # Replace the bundled rg with the Nix-provided one.
        # Handles both the old (<vscode 1.122) and new (>=1.122) ripgrep layouts.
        for _rg_dir in \
            resources/app/node_modules/@vscode/ripgrep/bin \
            resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64; do
          if [ -d "$_rg_dir" ]; then
            rm -f "$_rg_dir/rg"
            ln -s ${ripgrep}/bin/rg "$_rg_dir/rg"
          fi
        done
      ''
    else
      postPatch;
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

  postPatch = fixRipgrepPatch (old.postPatch or "");
})
