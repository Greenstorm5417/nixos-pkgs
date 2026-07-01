import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// The repo root is one level up from the site directory. packages.json is
// the source of truth for which package detail pages must be prerendered.
const repoRoot = resolve(process.cwd(), '..')
const registry = JSON.parse(
  readFileSync(resolve(repoRoot, 'packages.json'), 'utf8'),
) as { packages?: Record<string, unknown> }

const packageNames = Object.keys(registry.packages ?? {})

const prerenderPages = [
  { path: '/' },
  { path: '/packages' },
  ...packageNames.map((name) => ({ path: `/packages/${name}` })),
]

const config = defineConfig({
  base: '/nixos-pkgs/',
  resolve: { tsconfigPaths: true },
  plugins: [
    tailwindcss(),
    tanstackStart({
      prerender: {
        enabled: true,
        crawlLinks: true,
        failOnError: true,
      },
      pages: prerenderPages,
    }),
    viteReact(),
  ],
})

export default config
