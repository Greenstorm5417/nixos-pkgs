import { Link, createFileRoute, notFound } from '@tanstack/react-router'
import type { PackageRecord } from '../lib/registry'
import { getRegistry } from '../lib/registry'

export const Route = createFileRoute('/packages/$name')({
  component: PackageDetail,
  loader: async ({ params }) => {
    const registry = await getRegistry()
    const pkg = registry.packages.find((p) => p.name === params.name)
    if (!pkg) {
      throw notFound()
    }
    return pkg
  },
  notFoundComponent: () => (
    <div className="space-y-4">
      <h1 className="text-3xl font-bold text-white">Package not found</h1>
      <p className="text-slate-400">
        No such package in{' '}
        <code className="rounded bg-slate-800 px-1.5 py-0.5">packages.json</code>.
      </p>
      <Link to="/packages" className="text-sky-400 hover:underline">
        Browse all packages
      </Link>
    </div>
  ),
})

function CodeBlock({ children }: { children: string }) {
  return (
    <pre className="overflow-x-auto rounded-lg border border-slate-800 bg-slate-900 p-4 text-sm text-slate-200">
      <code>{children}</code>
    </pre>
  )
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-1 gap-1 border-b border-slate-800 py-3 sm:grid-cols-[12rem_1fr]">
      <div className="text-sm font-medium text-slate-400">{label}</div>
      <div className="break-words text-sm text-slate-200">{children}</div>
    </div>
  )
}

function PackageDetail() {
  const pkg = Route.useLoaderData() as PackageRecord
  const { repoSlug } = pkg

  const flakeSnippet = `{
  inputs.nixos-pkgs.url = "github:${repoSlug}";
}

# As an overlay:
nixpkgs.overlays = [ nixos-pkgs.overlays.default ];

# Or as a direct package reference:
nixos-pkgs.packages.x86_64-linux.${pkg.name}`

  const configSnippet = `{
  inputs.nixos-pkgs.url = "github:${repoSlug}";
}

# In your NixOS or Home Manager module:
nixpkgs.overlays = [ nixos-pkgs.overlays.default ];
${pkg.unfree ? 'nixpkgs.config.allowUnfree = true;\n' : ''}
environment.systemPackages = [
  nixos-pkgs.packages.x86_64-linux.${pkg.name}
];`

  return (
    <div className="space-y-8">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold text-white">{pkg.name}</h1>
        {pkg.description ? (
          <p
            className="text-slate-300"
            dangerouslySetInnerHTML={{ __html: pkg.descriptionHtml }}
          />
        ) : null}
      </div>

      <section className="rounded-lg border border-slate-800 bg-slate-900/40 px-5">
        <Row label="Version">
          <span className="font-mono">{pkg.version}</span>
        </Row>
        <Row label="Source URL">
          <a href={pkg.url} className="font-mono text-sky-400 hover:underline">
            {pkg.url}
          </a>
        </Row>
        {pkg.homepage ? (
          <Row label="Homepage">
            <a href={pkg.homepage} className="text-sky-400 hover:underline">
              {pkg.homepage}
            </a>
          </Row>
        ) : null}
        {pkg.metadataUrl ? (
          <Row label="Metadata URL">
            <a
              href={pkg.metadataUrl}
              className="font-mono text-sky-400 hover:underline"
            >
              {pkg.metadataUrl}
            </a>
          </Row>
        ) : null}
        <Row label="Nix hash">
          <span className="font-mono">{pkg.hash}</span>
        </Row>
        <Row label="Last updated">
          <time dateTime={pkg.lastUpdated}>{pkg.lastUpdated}</time>
        </Row>
        <Row label="License">
          {pkg.unfree
            ? 'Unfree (requires nixpkgs.config.allowUnfree = true)'
            : 'Free'}
        </Row>
        <Row label="Supported systems">{pkg.systems.join(', ') || '—'}</Row>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold text-white">Usage</h2>

        <div className="space-y-2">
          <h3 className="text-sm font-medium text-slate-300">
            Install without flakes
          </h3>
          <CodeBlock>{`nix-channel --add https://github.com/${repoSlug}/archive/refs/heads/main.tar.gz nixos-pkgs
nix-channel --update nixos-pkgs
nix-env -iA nixos-pkgs.${pkg.name}`}</CodeBlock>
        </div>

        <div className="space-y-2">
          <h3 className="text-sm font-medium text-slate-300">
            Run directly with Nix
          </h3>
          <CodeBlock>{`nix run github:${repoSlug}#${pkg.name}`}</CodeBlock>
        </div>

        <div className="space-y-2">
          <h3 className="text-sm font-medium text-slate-300">Use in a flake</h3>
          <CodeBlock>{flakeSnippet}</CodeBlock>
        </div>

        <div className="space-y-2">
          <h3 className="text-sm font-medium text-slate-300">
            NixOS / Home Manager configuration
          </h3>
          <CodeBlock>{configSnippet}</CodeBlock>
        </div>
      </section>

      <p className="text-sm text-slate-400">
        See{' '}
        <a
          href={`https://github.com/${repoSlug}/blob/main/packages/${pkg.name}/example-flake.nix`}
          className="text-sky-400 hover:underline"
        >
          packages/{pkg.name}/example-flake.nix
        </a>{' '}
        for a complete example.
      </p>
    </div>
  )
}
