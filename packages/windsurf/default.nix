{
  fetchurl,
  ripgrep,
  base,
  ...
}:

let
  generated = import ./generated.nix;

  # The nixpkgs devin-desktop postPatch computes the bundled-rg path from
  # vscodeVersion (read from nixpkgs's own info.json).  When we override the
  # source tarball independently the nixpkgs vscodeVersion may lag behind the
  # actual release, causing it to look for @vscode/ripgrep/bin/rg while the
  # tarball already ships @vscode/ripgrep-universal/bin/linux-x64/rg (VSCode
  # >= 1.122.0).
  #
  # Fix: strip the upstream rm+ln-s ripgrep block from postPatch and replace it
  # with a shell loop that handles both path layouts gracefully.
  fixRipgrepPatch =
    postPatch:
    let
      # Split on the old-layout rm line (present when vscodeVersion < 1.122.0).
      # builtins.split uses ERE; literal dots in the path are harmless here
      # because the surrounding path is unique within postPatch.
      parts = builtins.split "\nrm resources/app/node_modules/@vscode/ripgrep/bin/rg\n" postPatch;
    in
    if builtins.length parts > 1 then
      # Drop the upstream rm + ln-s lines (the "after" segment of the split).
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

  postPatch = fixRipgrepPatch (old.postPatch or "");
})
