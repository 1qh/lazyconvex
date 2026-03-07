# Migration Guide

Adopt lazyconvex incrementally.
No big bang required — convert one table at a time while keeping existing Convex code
untouched.

## Step 1: Install

```bash
bun add lazyconvex
```

Peer dependencies: `convex`, `convex-helpers`, `zod`, `@tanstack/react-form`, `react`.

## Step 2: Define One Schema

Pick your simplest user-owned table.
Define a Zod schema with `makeOwned`:

```tsx
import { makeOwned } from 'lazyconvex/schema'
import { boolean, object, string } from 'zod/v4'

const owned = makeOwned({
  note: object({
    title: string().min(1),
    content: string(),
    archived: boolean()
  })
})
```

## Step 3: Register the Table

Add the table alongside your existing schema.
`ownedTable()` returns a standard Convex table definition:

```tsx
import { defineSchema, defineTable } from 'convex/server'
import { ownedTable } from 'lazyconvex/server'

export default defineSchema({
  // Existing tables — untouched
  posts: defineTable({
    title: v.string(),
    body: v.string(),
    userId: v.id('users')
  }),
  comments: defineTable({ postId: v.id('posts'), text: v.string() }),

  // New lazyconvex table
  note: ownedTable(owned.note)
})
```

## Step 4: Setup and Generate Endpoints

Create a setup file (or add to an existing one):

```tsx
import { setup } from 'lazyconvex/server'
import { getAuthUserId } from '@convex-dev/auth/server'
import {
  action,
  internalMutation,
  internalQuery,
  mutation,
  query
} from './_generated/server'

const { crud, pq, q, m } = setup({
  query,
  mutation,
  action,
  internalQuery,
  internalMutation,
  getAuthUserId
})
```

Then generate endpoints for your new table:

```tsx
export const { create, list, read, rm, update } = crud('note', owned.note)
```

Your existing `posts` and `comments` endpoints continue working.
The new `note` endpoints live alongside them.

## Step 5: Use in React

```tsx
import { useList } from 'lazyconvex/react'
import { api } from '../convex/_generated/api'

const { items: notes, loadMore, status } = useList(api.note.list)
```

## Converting Tables One at a Time

### Before (raw Convex)

```tsx
// convex/posts.ts — 60 lines
export const list = query({
  args: {},
  handler: async ctx => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db
      .query('posts')
      .filter(q => q.eq(q.field('userId'), userId))
      .order('desc')
      .collect()
  }
})

export const create = mutation({
  args: { title: v.string(), body: v.string() },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db.insert('posts', { ...args, userId })
  }
})

// ... update, remove, read — another 40 lines
```

### After (lazyconvex)

```tsx
// convex/post.ts — 3 lines
export const { create, list, read, rm, update } = crud('post', owned.post)
```

### Coexistence

Both patterns work simultaneously.
You can have:

```
convex/
  posts.ts      ← raw Convex (existing, untouched)
  comments.ts   ← raw Convex (existing, untouched)
  note.ts       ← lazyconvex crud()
  wiki.ts       ← lazyconvex orgCrud()
  setup.ts      ← lazyconvex setup()
```

## Mixing crud() with Custom Endpoints

Generated CRUD covers standard operations.
For custom logic, use `pq`, `q`, `m` from setup:

```tsx
export const { create, list, read, rm, update } = crud('note', owned.note)

export const archive = m({
  args: { id: zid('note') },
  handler: async (c, { id }) => {
    const doc = await c.get(id)
    await c.patch(id, { archived: true })
    return doc
  }
})
```

Both `crud()` endpoints and custom `m()` endpoints export from the same file and appear
on the same `api.note` namespace.

## Adding Features Incrementally

Start simple, add features as needed:

```tsx
// Week 1: Basic CRUD
export const { create, list, read, rm, update } = crud('note', owned.note)

// Week 2: Add rate limiting
export const { create, list, read, rm, update } = crud('note', owned.note, {
  rateLimit: { max: 10, window: 60_000 }
})

// Week 3: Add public read access and search
export const {
  create,
  rm,
  update,
  pub: { list, read, search }
} = crud('note', owned.note, {
  rateLimit: { max: 10, window: 60_000 },
  search: 'content'
})
```

## Org-Scoped Tables

When you need multi-tenancy, use `makeOrgScoped` + `orgCrud`:

```tsx
import { makeOrgScoped } from 'lazyconvex/schema'
import { orgTables } from 'lazyconvex/server'

const orgScoped = makeOrgScoped({
  wiki: object({
    title: string().min(1),
    content: string(),
    status: zenum(['draft', 'published'])
  })
})

// Add org infrastructure tables to your schema
export default defineSchema({
  ...orgTables(),
  wiki: orgTable(orgScoped.wiki)
  // existing tables...
})
```

```tsx
export const { create, list, read, rm, update } = orgCrud(
  'wiki',
  orgScoped.wiki
)
```

## ESLint Plugin

Add the lazyconvex ESLint plugin to catch common mistakes at dev time:

```tsx
import lazyconvex from 'lazyconvex/eslint'
import { defineConfig } from 'eslint/config'

export default defineConfig([lazyconvex.recommended])
```

This catches wrong API casing (`api.blogprofile` vs `api.blogProfile`), form field
typos, missing `await connection()` in Server Components, and more.

## Type Safety with strictApi

Convex’s generated `api` object has runtime `anyApi` proxy that accepts any property
name. Use `strictApi` to strip the index signature:

```tsx
import { strictApi } from 'lazyconvex'
import { api as rawApi } from '../convex/_generated/api'

const api = strictApi(rawApi)
api.note.list // ✅ works
api.noet.list // ❌ compile error — catches typos
```

## Checklist

| Step                                                       | Status |
| ---------------------------------------------------------- | ------ |
| Install `lazyconvex`                                       |        |
| Define first Zod schema with `makeOwned` / `makeOrgScoped` |        |
| Add table to schema with `ownedTable` / `orgTable`         |        |
| Call `setup()` in a convex file                            |        |
| Generate endpoints with `crud()` / `orgCrud()`             |        |
| Use `useList`, `useForm` in React                          |        |
| Add ESLint plugin                                          |        |
| Wrap `api` with `strictApi`                                |        |
| Convert remaining tables one at a time                     |        |
