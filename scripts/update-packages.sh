#!/usr/bin/env bash
# Generic updater for every package declared in packages.json.
#
# For each package this script:
#   1. Fetches the package's metadata URL.
#   2. Compares its hash against the last known hash stored in
#      packages/<name>/metadata.sha256 (idempotency / change detection).
#   3. If the metadata changed, extracts the new version and download URL
#      using the package's configured jq queries, prefetches the Nix store
#      hash for the download, and regenerates packages/<name>/generated.nix.
#
# Nothing is committed by this script - it only writes files to the
# working tree and reports what changed via $GITHUB_OUTPUT (when set) so
# that a calling workflow can decide whether to format, validate, and open
# a pull request.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
packages_json="$repo_root/packages.json"

if [ ! -f "$packages_json" ]; then
  echo "packages.json not found at $packages_json" >&2
  exit 1
fi

mapfile -t names < <(jq -r '.packages | keys[]' "$packages_json")

changed_names=()
changed_summary=()

for name in "${names[@]}"; do
  pkg="$(jq -c --arg name "$name" '.packages[$name]' "$packages_json")"
  kind="$(jq -r '.kind // "nixpkgs-override"' <<<"$pkg")"

  if [ "$kind" != "nixpkgs-override" ]; then
    echo "[$name] skipping unsupported package kind: $kind" >&2
    continue
  fi

  metadata_url="$(jq -r '.metadataUrl' <<<"$pkg")"
  version_query="$(jq -r '.versionQuery' <<<"$pkg")"
  url_query="$(jq -r '.urlQuery' <<<"$pkg")"

  pkg_dir="$repo_root/packages/$name"
  mkdir -p "$pkg_dir"

  generated_file="$pkg_dir/generated.nix"
  metadata_hash_file="$pkg_dir/metadata.sha256"

  echo "[$name] fetching metadata from $metadata_url"
  if ! metadata="$(curl -fsSL "$metadata_url")"; then
    echo "[$name] failed to fetch metadata; skipping this package" >&2
    continue
  fi
  metadata_hash="$(printf '%s' "$metadata" | sha256sum | awk '{print $1}')"

  old_metadata_hash=""
  if [ -f "$metadata_hash_file" ]; then
    old_metadata_hash="$(cat "$metadata_hash_file" || true)"
  fi

  # Fast path: skip all expensive work when the upstream metadata is
  # unchanged AND the generated file already holds a real (non-placeholder)
  # hash. If the generated file is missing or still carries the fake
  # placeholder hash, force a regeneration so CI never fails on a bad hash -
  # we repair it automatically instead.
  needs_update=false
  current_hash="$(sed -n 's/^[[:space:]]*hash = "\([^"]*\)".*/\1/p' "$generated_file" 2>/dev/null | head -n1 || true)"
  if [ ! -f "$generated_file" ]; then
    needs_update=true
  elif [ -z "$current_hash" ] || printf '%s' "$current_hash" | grep -q 'AAAAAAAAAAAA'; then
    echo "[$name] generated.nix hash is blank/placeholder; forcing refresh"
    needs_update=true
  elif [ "$metadata_hash" != "$old_metadata_hash" ]; then
    needs_update=true
  fi

  if [ "$needs_update" = false ]; then
    echo "[$name] metadata unchanged: $metadata_hash"
    continue
  fi

  version="$(printf '%s' "$metadata" | jq -r "$version_query")"
  if [ -z "$version" ] || [ "$version" = "null" ]; then
    echo "[$name] could not determine version from metadata" >&2
    continue
  fi

  # urlQuery may legitimately match more than one asset (e.g. multiple
  # mirrors or archive formats for the same release); the first match is
  # used intentionally. Write a urlQuery that resolves to a single, stable
  # asset if this matters for your package.
  download_url="$(
    printf '%s' "$metadata" | jq -r --arg version "$version" "$url_query" | head -n 1
  )"
  if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
    echo "[$name] could not determine download url from metadata" >&2
    continue
  fi

  if ! prefetch_json="$(nix store prefetch-file --json "$download_url")"; then
    echo "[$name] failed to prefetch download url; skipping this package" >&2
    continue
  fi
  nix_hash="$(jq -r '.hash' <<<"$prefetch_json")"
  if [ -z "$nix_hash" ] || [ "$nix_hash" = "null" ]; then
    echo "[$name] could not determine nix hash from prefetch output" >&2
    continue
  fi

  cat > "$generated_file" <<EOF
{
  version = "$version";
  url = "$download_url";
  hash = "$nix_hash";
  metadataHash = "$metadata_hash";
}
EOF

  printf '%s' "$metadata_hash" > "$metadata_hash_file"

  echo "[$name] updated to $version"
  echo "  url:  $download_url"
  echo "  hash: $nix_hash"

  changed_names+=("$name")
  changed_summary+=("- **$name**: $version")
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  if [ "${#changed_names[@]}" -eq 0 ]; then
    {
      echo "changed=false"
      echo "packages="
    } >> "$GITHUB_OUTPUT"
  else
    packages_csv="$(IFS=,; echo "${changed_names[*]}")"
    {
      echo "changed=true"
      echo "packages=$packages_csv"
      echo "summary<<UPDATE_SUMMARY_EOF"
      printf '%s\n' "${changed_summary[@]}"
      echo "UPDATE_SUMMARY_EOF"
    } >> "$GITHUB_OUTPUT"
  fi
fi

if [ "${#changed_names[@]}" -eq 0 ]; then
  echo "No package updates found."
else
  echo "Updated packages: ${changed_names[*]}"
fi
