# Custom Queries (Escape Hatches)

`setup()` returns `pq`, `q`, and `m` — thin wrappers around Convex's query/mutation builders that inject auth context and helpers. Use them when generated CRUD isn't enough.

| Builder | Auth | Context provides |
|---------|------|-----------------|
| `pq` | Optional | `viewerId` (null if anon), `withAuthor` |
| `q` | Required | `user`, `viewerId`, `withAuthor`, `get` (ownership-checked) |
| `m` | Required | `user`, `get`, `create`, `patch` (with conflict detection), `delete` |

## pq — Public Query (No Auth Required)

```tsx
const bySlug = pq({
  args: { slug: z.string() },
  handler: async (c, { slug }) => {
    const doc = await c.db.query('blog').withIndex('by_slug', q => q.eq('slug', slug)).unique()
    return doc ? (await c.withAuthor([doc]))[0] : null
  }
})
```

## q — Authenticated Query

```tsx
const listDeleted = q({
  args: { orgId: zid('org') },
  handler: async (c, { orgId }) => {
    await requireOrgMember({ db: c.db, orgId, userId: c.user._id })
    const docs = await c.db.query('wiki').filter(f => f.eq(f.field('orgId'), orgId)).order('desc').collect()
    const deleted: typeof docs = []
    for (const d of docs) if (d.deletedAt !== undefined) deleted.push(d)
    return deleted
  }
})
```

## m — Authenticated Mutation

```tsx
const archive = m({
  args: { id: z.string() },
  handler: async (c, { id }) => c.patch(id, { archived: true })
})
```

`c.patch` includes conflict detection — pass `expectedUpdatedAt` as the third argument.

## Mixing Custom and Generated Endpoints

Custom endpoints live in the same file as generated CRUD:

> [Real example: packages/be/convex/wiki.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/wiki.ts)

```tsx
import { orgCrud, q, uniqueCheck } from '../lazy'
import { orgScoped } from '../t'

export const {
    addEditor, bulkRm, create, list, read, rm, update
  } = orgCrud('wiki', orgScoped.wiki, { acl: true, softDelete: true }),
  listDeleted = q({ args: { orgId: zid('org') }, handler: async (c, { orgId }) => { /* ... */ } }),
  isSlugAvailable = uniqueCheck(orgScoped.wiki, 'wiki', 'slug')
```

You can also drop to raw Convex `action`/`mutation`/`query` when you don't need lazyconvex's auth context:

> [Real example: packages/be/convex/movie.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/movie.ts)

```tsx
import { action } from './_generated/server'

export const search = action({
    args: { query: v.string() },
    handler: async (_, { query }) => { /* call external API */ }
  }),
  { all, get, load, refresh } = cacheCrud({ /* ... */ })
```

## Outgrowing `crud()` — Migration to Custom Queries

The generated `where` clauses (`$gt`, `$lt`, `$between`, `or`) use runtime `.filter()` after fetching documents. This works well for tables under ~1,000 documents. When a table grows past that, you'll see the `RUNTIME_FILTER_WARN_THRESHOLD` warning in logs.

### Strict Filter Mode

Pass `strictFilter: true` to `setup()` to throw instead of warn:

```tsx
const { crud, ... } = setup({
  query, mutation, action, internalQuery, internalMutation,
  getAuthUserId,
  strictFilter: true,
})
```

### Step 1: Add a Convex Index

```tsx
blog: ownedTable(owned.blog)
  .index('by_category', ['category'])
  .index('by_published_date', ['published', '_creationTime'])
```

### Step 2: Write a Custom Query

```tsx
export const listByCategory = pq({
  args: { category: z.string(), paginationOpts: z.object({ cursor: z.string().nullable(), numItems: z.number() }) },
  handler: async (c, { category, paginationOpts }) => {
    const results = await c.db
      .query('blog')
      .withIndex('by_category', q => q.eq('category', category))
      .order('desc')
      .paginate(paginationOpts)
    return { ...results, page: await c.withAuthor(results.page) }
  }
})
```

### Step 3: Replace the Frontend Call

```tsx
// Before (runtime filtering)
const { items } = useList(api.blog.list, { where: { category: 'tech' } })

// After (index-backed)
const results = usePaginatedQuery(api.blog.listByCategory, { category: 'tech' }, { initialNumItems: 20 })
```

### What Stays, What Changes

| Concern | Generated `crud()` | Custom `pq`/`q`/`m` |
|---------|-------------------|---------------------|
| Auth + ownership | Automatic | `c.user`, `c.get(id)` |
| File cleanup | Automatic | Manual (call `storage.delete`) |
| Where clauses | Runtime `.filter()` | Convex `.withIndex()` |
| Conflict detection | `expectedUpdatedAt` | `c.patch(id, data, expectedUpdatedAt)` |
| Author enrichment | Automatic | `c.withAuthor(docs)` |
| Rate limiting | `rateLimit` option | Manual (`checkRateLimit` from `lazyconvex/server`) |

Keep generated CRUD for mutations and simple reads, add custom indexed queries only for hot paths.

## Decision Tree: Which Escape Hatch?

```
Need to read data?
  ├─ No auth required → pq
  └─ Auth required → q

Need to write data?
  └─ Always → m (gives conflict detection via c.patch)

Need to call an external API?
  └─ Use raw Convex action (not a lazyconvex builder)

Can generated crud() handle it?
  ├─ Yes → Keep crud(). Don't write custom code.
  └─ No → Add custom alongside crud() in the same file
```

## Type Safety in Custom Handlers

The `c` context object is fully typed. Here's what each builder gives you:

### pq context

```tsx
handler: async (c, args) => {
  c.db         // full Convex DatabaseReader
  c.viewerId   // string | null (authenticated user ID, null for anonymous)
  c.withAuthor // (docs: Doc[]) => Promise<EnrichedDoc[]> — attaches author name/image
}
```

### q context

```tsx
handler: async (c, args) => {
  c.db         // full Convex DatabaseReader
  c.user       // Doc<'users'> — guaranteed non-null (throws if not authenticated)
  c.viewerId   // string — always present
  c.get        // (id: Id<T>) => Doc<T> — ownership-checked, throws if not owner
  c.withAuthor // same as pq
}
```

### m context

```tsx
handler: async (c, args) => {
  c.db         // full Convex DatabaseWriter
  c.user       // Doc<'users'>
  c.get        // ownership-checked get
  c.create     // (table, data) => Id — sets userId + updatedAt automatically
  c.patch      // (id, data, expectedUpdatedAt?) => void — conflict detection built-in
  c.delete     // (id) => void — ownership-checked, cleans up files
}
```

## Coexistence Patterns

### Pattern 1: Custom query alongside generated CRUD

The most common pattern. Keep `crud()` for standard operations, add custom endpoints for specialized reads:

```tsx
export const {
    create, list, read, rm, update
  } = crud('blog', owned.blog),
  bySlug = pq({ args: { slug: z.string() }, handler: async (c, { slug }) => {
    return c.db.query('blog').withIndex('by_slug', q => q.eq('slug', slug)).unique()
  }}),
  trending = pq({ args: {}, handler: async (c) => {
    return c.db.query('blog').withIndex('by_views').order('desc').take(10)
  }})
```

All endpoints — generated and custom — are exported from the same file. The frontend imports them all from `api.blog`:

```tsx
api.blog.list          // generated
api.blog.bySlug        // custom
api.blog.trending      // custom
api.blog.create        // generated
```

### Pattern 2: Custom mutation extending generated CRUD

Add a custom mutation that reuses the context helpers:

```tsx
export const {
    create, list, read, rm, update
  } = crud('blog', owned.blog),
  publish = m({ args: { id: z.string() }, handler: async (c, { id }) => {
    const doc = await c.get(id)  // ownership check included
    await c.patch(id, { published: true })
  }})
```

### Pattern 3: Gradual replacement

Replace a single generated endpoint while keeping the rest:

```tsx
export const {
    create, read, rm, update  // keep these
  } = crud('blog', owned.blog),
  list = pq({  // replace generated list with indexed version
    args: { category: z.string().optional() },
    handler: async (c, { category }) => {
      if (category)
        return c.db.query('blog').withIndex('by_category', q => q.eq('category', category)).collect()
      return c.db.query('blog').order('desc').collect()
    }
  })
```

The frontend code doesn't change — it still imports `api.blog.list`.
