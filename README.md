# nixos-pkgs

A generic, extensible framework for auto-updating Nix packages whose
upstreams don't publish timely Nix packaging themselves. Packages can either
override an existing nixpkgs derivation or consume standalone release archives.

Live site: <https://greenstorm5417.github.io/nixos-pkgs/>

## How it works

- **`packages.json`** is the single source of truth. Each entry describes one
  package: where to fetch its release metadata, how to pull the version and
  download URL(s) out of that metadata (as `jq` filters), supported systems,
  package kind, and whether it's unfree.
- **`packages/<name>/`** holds the generated/derived files for that package:
  - `generated.nix` — current version, download URL, Nix store hash, and a
    hash of the upstream metadata (used for change detection). Written by the
    updater; don't hand-edit.
  - `metadata.sha256` — the last-seen metadata hash, used to make updates
    idempotent (no-op when upstream hasn't changed).
  - `default.nix` — takes the generated data and overrides the corresponding
    nixpkgs package's `version`/`src`.
  - `example.nix` / `example-flake.nix` — standalone consumption examples.
- **`scripts/update-packages.sh`** loops over every package, checks whether
  upstream metadata changed, and if so fetches the new version, prefetches its
  Nix store hash, and rewrites `generated.nix`.
- **`flake.nix`** dynamically builds an output for every package listed in
  `packages.json` — no per-package wiring needed.
- **`default.nix`** exposes the same rolling packages to channels and other
  non-flake consumers.
- **`site/`** is a [TanStack Start](https://tanstack.com/start) + Bun +
  TypeScript app that is **prerendered to fully static HTML** for GitHub Pages.

## Adding a new package

1. Add an entry to `packages.json`:

   ```json
   "my-package": {
     "description": "Short description (markdown allowed)",
     "homepage": "https://example.com",
     "kind": "nixpkgs-override",
     "baseAttr": "my-package",
     "system": "x86_64-linux",
     "unfree": true,
     "metadataUrl": "https://example.com/metadata.json",
     "versionQuery": ".currentRelease",
     "urlQuery": ".releases[] | select(.version == $version) | .url"
   }
   ```

2. Create `packages/my-package/default.nix` (copy `packages/kiro/default.nix`),
   plus the `example.nix` / `example-flake.nix` examples.

3. Run the updater locally to populate `generated.nix` and `metadata.sha256`.

4. Run `nix flake check` to confirm it builds.

No changes to `flake.nix`, the workflows, CI, or the site are required — the
site reads `packages.json` and each `generated.nix` at build time.

## Running the updater locally

```console
$ nix develop        # nix, jq, curl, git, nixfmt
$ ./scripts/update-packages.sh
```

The script updates `packages/<name>/generated.nix` and `metadata.sha256` in
place for every package whose upstream metadata changed. It's safe to re-run
(no-op when nothing changed) and self-heals a placeholder/invalid hash by
re-fetching, so CI never fails on a stale hash.

## Formatting and checks

```console
$ nix fmt -- $(git ls-files '*.nix')          # format every Nix file
$ nix fmt -- --check $(git ls-files '*.nix')  # verify formatting
$ nix flake check -L                          # evaluate + build every package
$ nix build .#kiro -L                         # build a specific package
```

## The website (`site/`)

The site is a TanStack Start app, prerendered to static files so GitHub Pages
can serve it with no Node/Bun server at runtime.

- Data is baked in at build time: `bun run gen:registry` reads `packages.json`
  and each `packages/<name>/generated.nix` and writes
  `src/lib/registry.data.ts`. This runs automatically before `dev` and `build`.
- Routes:
  - `/` — overview with a card per package and a quick-start command
  - `/packages` — full table
  - `/packages/:name` — detail page (version, source URL, homepage, metadata
    URL, Nix hash, last updated, license/unfree, systems, and ready-to-copy
    `nix run` / flake / NixOS–Home-Manager snippets)
- The site is served under the `/nixos-pkgs/` base path (configured in
  `vite.config.ts` and the router `basepath`) to match the GitHub Pages URL.
- The build **fails loudly** if a package is missing its `generated.nix` or
  required fields, so incomplete metadata can't be published.

Develop and build locally:

```console
$ cd site
$ bun install
$ bun run dev     # http://localhost:3000/nixos-pkgs/
$ bun run build   # static output in site/dist/client
```

## Consuming packages from this repo

### Without flakes

Install the rolling channel once, then install or update packages without
specifying a version:

```console
$ nix-channel --add https://github.com/Greenstorm5417/nixos-pkgs/archive/refs/heads/main.tar.gz nixos-pkgs
$ nix-channel --update nixos-pkgs
$ nix-env -iA nixos-pkgs.zoeken
```

For a non-flake NixOS configuration:

```nix
{ pkgs, ... }:

let
  nixos-pkgs = import (builtins.fetchTarball
    "https://github.com/Greenstorm5417/nixos-pkgs/archive/refs/heads/main.tar.gz") {
    inherit pkgs;
  };
in
{
  environment.systemPackages = [ nixos-pkgs.zoeken ];
}
```

Both forms follow `main`; updating the channel or rebuilding after upstream
metadata changes picks up the current package.

### With flakes

Run or install a rolling package without creating your own flake:

```console
$ nix run github:Greenstorm5417/nixos-pkgs#zoeken
$ nix profile install github:Greenstorm5417/nixos-pkgs#zoeken
```

```nix
{
  inputs.nixos-pkgs.url = "github:Greenstorm5417/nixos-pkgs";
}
```

Use the overlay:

```nix
nixpkgs.overlays = [ nixos-pkgs.overlays.default ];
nixpkgs.config.allowUnfree = true; # required for unfree packages such as kiro
```

or reference a package output directly:

```nix
environment.systemPackages = [
  nixos-pkgs.packages.x86_64-linux.kiro
];
```

See `packages/zoeken/example-flake.nix` for a complete example.

## Automation

- **`update-packages.yml`** runs every 15 minutes (and on demand). It checks
  every configured package for upstream changes; if anything changed it
  formats the generated files, validates the flake (`nix flake check`),
  commits directly to `main`, and then **deploys the Pages site** in a
  dependent job. Pages therefore deploys right after an update lands — not on
  arbitrary pushes.
- **`ci.yml`** runs on every pull request and push to `main`: a `nix` job
  (formatting check + `nix flake check`, which builds every package) and a
  `site` job (Bun build + type-check) that only runs after `nix` passes, so
  missing/invalid metadata or a bad hash fails CI before the site is built.

All workflows that need Nix install it with
[`DeterminateSystems/determinate-nix-action`](https://github.com/DeterminateSystems/determinate-nix-action).
