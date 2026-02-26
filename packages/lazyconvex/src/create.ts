#!/usr/bin/env bun

import { existsSync, mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const SCHEMA_TS = `import { ownedTable, rateLimitTable, uploadTables } from 'lazyconvex/server'
import { defineSchema } from 'convex/server'
import { owned } from './t'

export default defineSchema({
  ...uploadTables(),
  ...rateLimitTable(),
  blog: ownedTable(owned.blog)
})
`,
  T_TS = `import { cvFile, makeOwned } from 'lazyconvex/schema'
import { boolean, object, string, enum as zenum } from 'zod/v4'

const owned = makeOwned({
  blog: object({
    title: string().min(1),
    content: string(),
    category: zenum(['tech', 'life', 'tutorial']),
    published: boolean(),
    coverImage: cvFile().nullable().optional()
  })
})

export { owned }
`,
  LAZY_TS = `import { getAuthUserId } from '@convex-dev/auth/server'
import { setup } from 'lazyconvex/server'

import { action, internalMutation, internalQuery, mutation, query } from './_generated/server'

const { crud, pq, q, m } = setup({
  action,
  getAuthUserId: getAuthUserId as (ctx: unknown) => Promise<null | string>,
  internalMutation,
  internalQuery,
  mutation,
  query
})

export { crud, m, pq, q }
`,
  BLOG_TS = `import { crud } from './lazy'
import { owned } from './t'

export const {
  create, list, read, rm, update
} = crud('blog', owned.blog)
`,
  FILES: [string, string][] = [
    ['schema.ts', SCHEMA_TS],
    ['t.ts', T_TS],
    ['lazy.ts', LAZY_TS],
    ['blog.ts', BLOG_TS]
  ],
  writeFiles = (absDir: string, targetDir: string) => {
    let created = 0,
      skipped = 0
    for (const [name, content] of FILES) {
      const path = join(absDir, name)
      if (existsSync(path)) {
        process.stdout.write(`  skip ${targetDir}/${name} (exists)\n`)
        skipped += 1
      } else {
        writeFileSync(path, content)
        process.stdout.write(`  create ${targetDir}/${name}\n`)
        created += 1
      }
    }
    return { created, skipped }
  },
  printSummary = ({ created, skipped }: { created: number; skipped: number }) => {
    process.stdout.write('\n')
    if (created > 0) process.stdout.write(`Created ${created} file${created > 1 ? 's' : ''}.\n`)
    if (skipped > 0) process.stdout.write(`Skipped ${skipped} existing file${skipped > 1 ? 's' : ''}.\n`)
    process.stdout.write('\nNext steps:\n')
    process.stdout.write('  bun add lazyconvex convex @convex-dev/auth zod\n')
    process.stdout.write('  bunx convex dev\n\n')
  },
  run = () => {
    const targetDir = process.argv[2] ?? 'convex',
      absDir = join(process.cwd(), targetDir)
    if (!existsSync(absDir)) mkdirSync(absDir, { recursive: true })
    printSummary(writeFiles(absDir, targetDir))
  }

run()
