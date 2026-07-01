import {
  HeadContent,
  Link,
  Scripts,
  createRootRoute,
} from '@tanstack/react-router'

import appCss from '../styles.css?url'
import { GITHUB_URL, SITE_TAGLINE, SITE_TITLE } from '../lib/site'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: `${SITE_TITLE} · Nix package registry` },
      { name: 'description', content: SITE_TAGLINE },
    ],
    links: [{ rel: 'stylesheet', href: appCss }],
  }),
  shellComponent: RootDocument,
})

function RootDocument({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full">
      <head>
        <HeadContent />
      </head>
      <body className="min-h-full bg-slate-950 text-slate-100 antialiased">
        <div className="flex min-h-screen flex-col">
          <SiteHeader />
          <main className="mx-auto w-full max-w-5xl flex-1 px-6 py-10">
            {children}
          </main>
          <SiteFooter />
        </div>
        <Scripts />
      </body>
    </html>
  )
}

function SiteHeader() {
  return (
    <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur">
      <div className="mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-4">
        <Link to="/" className="text-lg font-semibold text-white hover:text-sky-400">
          {SITE_TITLE}
        </Link>
        <nav className="flex items-center gap-6 text-sm">
          <Link
            to="/"
            className="text-slate-300 hover:text-white"
            activeProps={{ className: 'text-white font-medium' }}
            activeOptions={{ exact: true }}
          >
            Home
          </Link>
          <Link
            to="/packages"
            className="text-slate-300 hover:text-white"
            activeProps={{ className: 'text-white font-medium' }}
          >
            Packages
          </Link>
          <a
            href={GITHUB_URL}
            className="text-slate-300 hover:text-white"
            target="_blank"
            rel="noreferrer"
          >
            GitHub
          </a>
        </nav>
      </div>
    </header>
  )
}

function SiteFooter() {
  return (
    <footer className="border-t border-slate-800 bg-slate-900/60">
      <div className="mx-auto w-full max-w-5xl px-6 py-6 text-sm text-slate-400">
        Generated from{' '}
        <code className="rounded bg-slate-800 px-1.5 py-0.5 text-slate-200">
          packages.json
        </code>
        . Source on{' '}
        <a href={GITHUB_URL} className="text-sky-400 hover:underline">
          GitHub
        </a>
        .
      </div>
    </footer>
  )
}
