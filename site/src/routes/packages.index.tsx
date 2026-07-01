import { Link, createFileRoute } from '@tanstack/react-router'
import { getRegistry } from '../lib/registry'

export const Route = createFileRoute('/packages/')({
  component: Packages,
  loader: async () => getRegistry(),
})

function Packages() {
  const { packages } = Route.useLoaderData()

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-white">Packages</h1>

      <div className="overflow-x-auto rounded-lg border border-slate-800">
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-900 text-slate-300">
            <tr>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Version</th>
              <th className="px-4 py-3 font-medium">Systems</th>
              <th className="px-4 py-3 font-medium">Unfree</th>
              <th className="px-4 py-3 font-medium">Last updated</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800">
            {packages.map((pkg) => (
              <tr key={pkg.name} className="hover:bg-slate-900/50">
                <td className="px-4 py-3">
                  <Link
                    to="/packages/$name"
                    params={{ name: pkg.name }}
                    className="font-medium text-sky-400 hover:underline"
                  >
                    {pkg.name}
                  </Link>
                </td>
                <td className="px-4 py-3 font-mono text-slate-300">{pkg.version}</td>
                <td className="px-4 py-3 text-slate-400">
                  {pkg.systems.join(', ') || '—'}
                </td>
                <td className="px-4 py-3 text-slate-400">
                  {pkg.unfree ? 'yes' : 'no'}
                </td>
                <td className="px-4 py-3 text-slate-400">
                  <time dateTime={pkg.lastUpdated}>
                    {pkg.lastUpdated.slice(0, 10)}
                  </time>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
