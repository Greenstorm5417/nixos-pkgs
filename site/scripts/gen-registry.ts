// Build-time generator: reads packages.json + each packages/<name>/generated.nix
// from the repo and writes src/lib/registry.data.ts. Baking the data into a
// plain TS module keeps the site fully static - no server function or fs
// access is needed at runtime, so it works on GitHub Pages and on client-side
// navigation alike.
import { existsSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { marked } from 'marked'

const REPO_ROOT = resolve(process.cwd(), '..')
const REPO_SLUG = 'Greenstorm5417/nixos-pkgs'
const OUT_FILE = resolve(process.cwd(), 'src', 'lib', 'registry.data.ts')

function extractField(source: string, key: string, required = true): string | undefined {
  const stringMatch = source.match(new RegExp(`${key}\\s*=\\s*"([^"]*)"\\s*;`))
  if (stringMatch) return stringMatch[1]

  const bareMatch = source.match(new RegExp(`${key}\\s*=\\s*([^;]+);`))
  if (bareMatch) return bareMatch[1].trim()

  if (required) throw new Error(`generated.nix is missing required field "${key}"`)
  return undefined
}

function parseGenerated(filePath: string) {
  const source = readFileSync(filePath, 'utf8')
  const version = extractField(source, 'version')
  const url = extractField(source, 'url')
  const hash = extractField(source, 'hash')
  const metadataHash = extractField(source, 'metadataHash', false)

  if (!version || !url || !hash) {
    throw new Error(`generated.nix at ${filePath} is missing required fields`)
  }
  return { version, url, hash, metadataHash: metadataHash || null }
}

const registry = JSON.parse(
  readFileSync(resolve(REPO_ROOT, 'packages.json'), 'utf8'),
) as { default?: string; packages?: Record<string, any> }

const names = Object.keys(registry.packages ?? {})

const packages = names.map((name) => {
  const cfg = registry.packages![name]
  const generatedPath = resolve(REPO_ROOT, 'packages', name, 'generated.nix')

  if (!existsSync(generatedPath)) {
    throw new Error(
      `Missing packages/${name}/generated.nix. Run scripts/update-packages.sh before building the site.`,
    )
  }

  const generated = parseGenerated(generatedPath)
  const stat = statSync(generatedPath)
  const description: string = cfg.description || ''
  const systems: Array<string> = Array.isArray(cfg.systems)
    ? cfg.systems
    : cfg.system
      ? [cfg.system]
      : []

  return {
    name,
    description,
    descriptionHtml: marked.parseInline(description) as string,
    homepage: cfg.homepage || null,
    metadataUrl: cfg.metadataUrl || null,
    unfree: Boolean(cfg.unfree),
    systems,
    isDefault: registry.default === name,
    version: generated.version,
    url: generated.url,
    hash: generated.hash,
    metadataHash: generated.metadataHash,
    lastUpdated: stat.mtime.toISOString(),
    repoSlug: REPO_SLUG,
  }
})

const data = {
  packages,
  default: registry.default || names[0] || null,
  repoSlug: REPO_SLUG,
}

const contents = `// GENERATED FILE - do not edit by hand.
// Produced by scripts/gen-registry.ts from packages.json + generated.nix.
import type { Registry } from './registry'

export const registryData: Registry = ${JSON.stringify(data, null, 2)}
`

writeFileSync(OUT_FILE, contents)
console.log(`Wrote ${OUT_FILE} with ${packages.length} package(s).`)
