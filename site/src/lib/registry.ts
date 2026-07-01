import { registryData } from './registry.data'

// A fully resolved package record, combining static config from
// packages.json with the auto-generated version/hash from generated.nix.
export interface PackageRecord {
  name: string
  description: string
  descriptionHtml: string
  homepage: string | null
  metadataUrl: string | null
  unfree: boolean
  systems: Array<string>
  isDefault: boolean
  version: string
  url: string
  hash: string
  metadataHash: string | null
  lastUpdated: string
  repoSlug: string
}

export interface Registry {
  packages: Array<PackageRecord>
  default: string | null
  repoSlug: string
}

// The data is baked in at build time by scripts/gen-registry.ts, so this is
// safe to call from anywhere (server prerender or client navigation) with no
// runtime file access.
export function getRegistry(): Registry {
  return registryData
}
