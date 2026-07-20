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

  if [ "$kind" != "nixpkgs-override" ] && [ "$kind" != "standalone" ]; then
    echo "[$name] skipping unsupported package kind: $kind" >&2
    continue
  fi

  metadata_url="$(jq -r '.metadataUrl' <<<"$pkg")"
  version_query="$(jq -r '.versionQuery' <<<"$pkg")"
  url_query="$(jq -r '.urlQuery // empty' <<<"$pkg")"
  url_queries="$(jq -c '.urlQueries // null' <<<"$pkg")"

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

  source_systems=()
  source_urls=()
  source_hashes=()

  if [ "$url_queries" != "null" ]; then
    mapfile -t source_systems < <(jq -r '.systems[]' <<<"$pkg")
  else
    source_systems+=("")
  fi

  source_failed=false
  for system in "${source_systems[@]}"; do
    if [ -n "$system" ]; then
      query="$(jq -r --arg system "$system" '.[$system]' <<<"$url_queries")"
    else
      query="$url_query"
    fi

    # A query may match mirrors or archive variants; the first match wins.
    download_url="$(
      printf '%s' "$metadata" | jq -r --arg version "$version" "$query" | head -n 1
    )"
    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
      echo "[$name] could not determine download url${system:+ for $system}" >&2
      source_failed=true
      break
    fi

    if ! prefetch_json="$(nix store prefetch-file --json "$download_url")"; then
      echo "[$name] failed to prefetch download url${system:+ for $system}" >&2
      source_failed=true
      break
    fi
    nix_hash="$(jq -r '.hash' <<<"$prefetch_json")"
    if [ -z "$nix_hash" ] || [ "$nix_hash" = "null" ]; then
      echo "[$name] could not determine nix hash${system:+ for $system}" >&2
      source_failed=true
      break
    fi

    source_urls+=("$download_url")
    source_hashes+=("$nix_hash")
  done

  if [ "$source_failed" = true ]; then
    continue
  fi

  if [ "$url_queries" = "null" ]; then
    cat > "$generated_file" <<EOF
{
  version = "$version";
  url = "${source_urls[0]}";
  hash = "${source_hashes[0]}";
  metadataHash = "$metadata_hash";
}
EOF
  else
    {
      echo '{'
      echo "  version = \"$version\";"
      echo "  url = \"${source_urls[0]}\";"
      echo "  hash = \"${source_hashes[0]}\";"
      echo '  sources = {'
      for index in "${!source_systems[@]}"; do
        echo "    \"${source_systems[$index]}\" = {"
        echo "      url = \"${source_urls[$index]}\";"
        echo "      hash = \"${source_hashes[$index]}\";"
        echo '    };'
      done
      echo '  };'
      echo "  metadataHash = \"$metadata_hash\";"
      echo '}'
    } > "$generated_file"
  fi

  printf '%s' "$metadata_hash" > "$metadata_hash_file"

  echo "[$name] updated to $version"
  for index in "${!source_urls[@]}"; do
    echo "  ${source_systems[$index]:+${source_systems[$index]} }url:  ${source_urls[$index]}"
    echo "  ${source_systems[$index]:+${source_systems[$index]} }hash: ${source_hashes[$index]}"
  done

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
