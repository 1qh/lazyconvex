# Ejecting from lazyconvex

lazyconvex is designed for incremental ejection.
You can replace one factory at a time while the rest of your app keeps running.

## Why eject?

- You need a query pattern that `crud()` can’t express (complex joins, aggregations,
  graph traversals)
- You want to remove the dependency entirely
- You need behavior that conflicts with lazyconvex’s conventions (custom auth,
  non-standard ownership)

## The spectrum

You don’t have to eject everything.
Most apps settle somewhere in the middle:

```
Full lazyconvex ←───────────────────────────→ Full raw Convex

crud() for all   crud() + custom    custom only,     no lazyconvex
tables           queries on hot     keep schemas     at all
                 paths
```

## Step 1: Identify what to eject

Replace a `crud()` call only when you need behavior it doesn’t support.
Keep it for tables where standard CRUD is sufficient.

Signs a table needs ejecting:

- You’re using `pq`/`q`/`m` for most operations on that table
- The runtime filter warning (`RUNTIME_FILTER_WARN_THRESHOLD`) fires consistently
- You need transactions spanning multiple tables
- You need custom subscriptions or real-time patterns

## Step 2: Write raw Convex equivalents

For each generated endpoint you want to replace, write the raw Convex version.
Here’s `crud('blog', owned.blog)` fully ejected:

### list → query

```tsx
import { paginationOptsValidator } from 'convex/server'
import { v } from 'convex/values'

import { query } from './_generated/server'

export const list = query({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, { paginationOpts }) => {
    return ctx.db.query('blog').order('desc').paginate(paginationOpts)
  }
})
```

### create → mutation

```tsx
import { v } from 'convex/values'

import { mutation } from './_generated/server'

export const create = mutation({
  args: {
    category: v.string(),
    content: v.string(),
    published: v.boolean(),
    title: v.string()
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db.insert('blog', { ...args, userId, updatedAt: Date.now() })
  }
})
```

### update → mutation

```tsx
export const update = mutation({
  args: {
    content: v.optional(v.string()),
    id: v.id('blog'),
    title: v.optional(v.string())
  },
  handler: async (ctx, { id, ...fields }) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    const doc = await ctx.db.get(id)
    if (!doc || doc.userId !== userId) throw new Error('Not found')
    await ctx.db.patch(id, { ...fields, updatedAt: Date.now() })
  }
})
```

### rm → mutation

```tsx
export const rm = mutation({
  args: { id: v.id('blog') },
  handler: async (ctx, { id }) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    const doc = await ctx.db.get(id)
    if (!doc || doc.userId !== userId) throw new Error('Not found')
    await ctx.db.delete(id)
  }
})
```

## Step 3: Replace one at a time

Don’t replace everything at once.
Replace one endpoint, verify the frontend still works, then proceed.

```tsx
import { crud } from './lazy'
import { owned } from './t'

export const {
    create,
    rm,
    update // keep these generated
  } = crud('blog', owned.blog),
  // replace list with a custom indexed version
  list = query({
    args: { paginationOpts: paginationOptsValidator },
    handler: async (ctx, { paginationOpts }) =>
      ctx.db
        .query('blog')
        .withIndex('by_published_date')
        .order('desc')
        .paginate(paginationOpts)
  })
```

The frontend doesn’t change — it still imports `api.blog.list`.

## Step 4: Remove the schema wrapper (optional)

If you eject all factories for a table, you can also replace the branded schema with a
plain Convex table definition:

```tsx
// Before (lazyconvex)
import { ownedTable } from 'lazyconvex/server'
import { owned } from './t'
blog: ownedTable(owned.blog)

// After (raw Convex)
import { defineTable } from 'convex/server'
import { v } from 'convex/values'
blog: defineTable({
  category: v.string(),
  content: v.string(),
  coverImage: v.optional(
    v.union(v.null(), v.object({ storageId: v.string() }))
  ),
  published: v.boolean(),
  title: v.string(),
  updatedAt: v.float64(),
  userId: v.string()
}).index('by_userId', ['userId'])
```

Note: `ownedTable` adds `userId`, `updatedAt`, and the `by_userId` index automatically.
When ejecting, you must add these yourself.

## Step 5: Remove frontend utilities (optional)

Replace lazyconvex React hooks with Convex equivalents:

| lazyconvex                                     | Raw Convex                                                      |
| ---------------------------------------------- | --------------------------------------------------------------- |
| `useList(api.blog.list)`                       | `usePaginatedQuery(api.blog.list, {}, { initialNumItems: 50 })` |
| `useFormMutation(api.blog.create, owned.blog)` | `useMutation(api.blog.create)` + manual form state              |
| `useSoftDelete(api.blog.rm)`                   | `useMutation(api.blog.rm)` + manual undo toast                  |
| `useOptimisticMutation(...)`                   | `useMutation(...)` + `optimisticUpdate` option                  |

## What you lose

| Feature                                  | Ejected equivalent                                  |
| ---------------------------------------- | --------------------------------------------------- |
| Zod validation on every mutation         | Manual `v.` validators or no validation             |
| Automatic file cleanup on delete/update  | Manual `storage.delete()` calls                     |
| Conflict detection (`expectedUpdatedAt`) | Manual timestamp comparison                         |
| Rate limiting                            | Manual `rateLimiter` integration                    |
| Author enrichment (`withAuthor`)         | Manual user join                                    |
| Where clause filtering                   | Manual `.filter()` or `.withIndex()`                |
| Branded type safety                      | Standard TypeScript (still typed, just not branded) |

## What you keep

- Your data stays exactly the same — no migration needed
- Other tables using `crud()` keep working
- Frontend code that imports from `api.blog.*` doesn’t change (same export names)
- Schema definitions in `t.ts` can stay as documentation even if unused
