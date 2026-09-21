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
      target = "rm resources/app/node_modules/@vscode/ripgrep/bin/rg";
      marker = "# nixos-pkgs: kiro ripgrep relink";
      replacement = ''
        ${marker}
        if [ -d resources/app/node_modules/@vscode/ripgrep-universal/bin ]; then
          rm -f resources/app/node_modules/@vscode/ripgrep-universal/bin/rg
          while IFS= read -r -d "" _rg_dir; do
            rm -f "$_rg_dir/rg"
            ln -sf ${ripgrep}/bin/rg "$_rg_dir/rg"
          done < <(find resources/app/node_modules/@vscode/ripgrep-universal/bin -mindepth 1 -maxdepth 1 -type d -print0)
          ln -sf ${ripgrep}/bin/rg resources/app/node_modules/@vscode/ripgrep-universal/bin/rg
        fi
        mkdir -p resources/app/node_modules/@vscode/ripgrep/bin
        rm -f resources/app/node_modules/@vscode/ripgrep/bin/rg
        ln -sf ${ripgrep}/bin/rg resources/app/node_modules/@vscode/ripgrep/bin/rg
      '';
      hasMarker = postPatch != builtins.replaceStrings [ marker ] [ "" ] postPatch;
      patched = builtins.replaceStrings
        [ target ]
        [ replacement ]
        postPatch;
    in
    if postPatch == "" then
      replacement
    else if postPatch == patched then
      if hasMarker then postPatch else postPatch + "\n" + replacement
    else
      patched;
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
