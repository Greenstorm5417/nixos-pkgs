import { Link, createFileRoute } from '@tanstack/react-router'
import { getRegistry } from '../lib/registry'
import { SITE_TAGLINE, SITE_TITLE } from '../lib/site'

export const Route = createFileRoute('/')({
  component: Home,
  loader: async () => getRegistry(),
})

function Home() {
  const { packages, default: defaultPackage, repoSlug } = Route.useLoaderData()

  return (
    <div className="space-y-10">
      <section className="space-y-3">
        <h1 className="text-4xl font-bold text-white">{SITE_TITLE}</h1>
        <p className="text-lg text-slate-300">{SITE_TAGLINE}</p>
        <p className="text-slate-400">
          <strong className="text-slate-200">{packages.length}</strong> package
          {packages.length === 1 ? '' : 's'} tracked. Browse the{' '}
          <Link to="/packages" className="text-sky-400 hover:underline">
            full list
          </Link>{' '}
          or jump to one below.
        </p>
      </section>

      {defaultPackage ? (
        <section className="space-y-2">
          <h2 className="text-xl font-semibold text-white">Quick start</h2>
          <pre className="overflow-x-auto rounded-lg border border-slate-800 bg-slate-900 p-4 text-sm text-slate-200">
            <code>{`nix run github:${repoSlug}#${defaultPackage}`}</code>
          </pre>
        </section>
      ) : null}

      <section className="grid gap-4 sm:grid-cols-2">
        {packages.map((pkg) => (
          <Link
            key={pkg.name}
            to="/packages/$name"
            params={{ name: pkg.name }}
            className="group rounded-lg border border-slate-800 bg-slate-900/50 p-5 transition hover:border-sky-500/60 hover:bg-slate-900"
          >
            <div className="flex items-baseline justify-between gap-3">
              <span className="text-lg font-semibold text-white group-hover:text-sky-400">
                {pkg.name}
              </span>
              <span className="rounded bg-slate-800 px-2 py-0.5 font-mono text-xs text-slate-300">
                v{pkg.version}
              </span>
            </div>
            {pkg.description ? (
              <p
                className="mt-2 text-sm text-slate-400"
                dangerouslySetInnerHTML={{ __html: pkg.descriptionHtml }}
              />
            ) : null}
          </Link>
        ))}
      </section>
    </div>
  )
}
