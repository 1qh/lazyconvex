# lazyconvex

Zod schema → fullstack app. One schema, zero boilerplate.

Define a Zod schema once → authenticated CRUD endpoints, typesafe forms with file upload, real-time queries, pagination, search, conflict detection, soft delete, rate limiting, org multi-tenancy with ACL — all generated. Ship a production app in minutes, not days.

## Before / After

A typical user-owned CRUD in raw Convex:

```tsx
export const list = query({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, { paginationOpts }) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db.query('blog')
      .withIndex('by_userId', q => q.eq('userId', userId))
      .order('desc')
      .paginate(paginationOpts)
  }
})

export const create = mutation({
  args: { title: v.string(), content: v.string(), category: v.string(), published: v.boolean() },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db.insert('blog', { ...args, userId, updatedAt: Date.now() })
  }
})

export const update = mutation({
  args: { id: v.id('blog'), title: v.optional(v.string()), content: v.optional(v.string()) },
  handler: async (ctx, { id, ...fields }) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    const doc = await ctx.db.get(id)
    if (!doc || doc.userId !== userId) throw new Error('Not found')
    await ctx.db.patch(id, { ...fields, updatedAt: Date.now() })
  }
})

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

~50 lines for 4 endpoints. No validation, no pagination options, no file cleanup, no rate limiting, no conflict detection.

With lazyconvex:

```tsx
export const {
  bulkRm, bulkUpdate, create,
  pub: { list, read, search },
  rm, update
} = crud('blog', owned.blog, { rateLimit: { max: 10, window: 60_000 }, search: 'content' })
```

3 lines. 8 endpoints. Auth, ownership, Zod validation, file upload with auto-cleanup, cursor-based pagination, sliding-window rate limiting, conflict detection, author enrichment, and where-clause filtering — all included.

## 445 Lines → 87 Endpoints

The entire backend for 4 production apps — blog, chat, org collaboration, and movie search — is **445 lines of consumer code**. That's schemas, setup, and endpoint files combined. Those 445 lines produce **87 fully typed, authenticated, rate-limited endpoints**.

Here's a full org-scoped CRUD with per-item editor permissions and soft delete:

```tsx
export const { addEditor, bulkRm, create, editors, list, read,
  removeEditor, restore, rm, setEditors, update
} = orgCrud('wiki', orgScoped.wiki, { acl: true, softDelete: true })
```

One line of config. 12 endpoints. Role-based access, editor ACL, soft delete with restore, bulk operations — all generated.

> [See all backend code: packages/be/convex/](https://github.com/1qh/lazyconvex/tree/main/packages/be/convex)

## What You Get

| Feature | Lines of code |
|---------|:---:|
| CRUD mutations with auth + ownership | 0 |
| Public & auth-gated queries with pagination | 0 |
| File upload with compression, auto-cleanup, URL resolution | 0 |
| Typesafe forms with Zod validation | 0 |
| Conflict detection + resolution dialog | 0 |
| Soft delete + undo toast | 0 |
| Bulk operations (select all, bulk delete/update) | 0 |
| Rate limiting (sliding window, per user) | 0 |
| Where clauses ($gt, $lt, $between, OR, own) | 0 |
| Org multi-tenancy with roles + ACL + invites | 0 |
| Optimistic mutations with auto-rollback | 0 |
| Auto-save with debounce + indicator | 0 |
| Multi-step forms with per-step validation | 0 |
| Singleton per-user data (profile, settings) | 0 |
| External API cache with TTL + auto-refresh | 0 |
| Branded types — compile-time factory mismatch prevention | 0 |
| Swift codegen — typed native APIs from the same schema | 0 |

## Install

```bash
bun add lazyconvex
```

## Type Safety

Every API surface is type-checked at compile time. Typos are caught before your code runs.

### Branded schemas prevent mismatches

```tsx
crud('blog', owned.blog)         // ✅ compiles
orgCrud('wiki', orgScoped.wiki)  // ✅ compiles
crud('wiki', orgScoped.wiki)     // ❌ compile error — OrgSchema is not OwnedSchema
orgCrud('blog', owned.blog)      // ❌ compile error — OwnedSchema is not OrgSchema
```

### Form fields are type-checked by value type

```tsx
<Text name='title' />       // ✅ title is string
<Text name='published' />   // ❌ compile error — published is boolean
<Toggle name='published' /> // ✅ published is boolean
<File name='coverImage' />  // ✅ coverImage is cvFile()
<File name='title' />       // ❌ compile error — title is not a file field
```

### Where clauses, search, and cascade are schema-aware

```tsx
crud('blog', owned.blog, { search: 'content' })   // ✅
crud('blog', owned.blog, { search: 'conten' })    // ❌ typo

useList(api.blog.list, { where: { category: 'tech' } })  // ✅
useList(api.blog.list, { where: { categry: 'tech' } })   // ❌ typo
```

## Quick Start

### 1. Define schemas with Zod

> [Real example: packages/be/t.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/t.ts)

```tsx
import { cvFile, makeOwned } from 'lazyconvex/schema'
import { boolean, object, string, enum as zenum } from 'zod/v4'

const owned = makeOwned({
  blog: object({
    title: string().min(1),
    content: string().min(3),
    category: zenum(['tech', 'life', 'tutorial']),
    published: boolean(),
    coverImage: cvFile().nullable().optional()
  })
})
```

### 2. Register tables + initialize

```tsx
export default defineSchema({ ...uploadTables(), ...rateLimitTable(), blog: ownedTable(owned.blog) })
```

```tsx
const { crud, orgCrud, childCrud, cacheCrud, singletonCrud, pq, q, m } = setup({
  query, mutation, action, internalQuery, internalMutation, getAuthUserId
})
```

### 3. Generate endpoints

```tsx
export const {
  bulkRm, bulkUpdate, create,
  pub: { list, read, search },
  rm, update
} = crud('blog', owned.blog, { rateLimit: { max: 10, window: 60_000 }, search: 'content' })
```

### 4. Use in React

```tsx
const { items: blogs, loadMore } = useList(api.blog.list, { where: { published: true } })
```

## 5 Table Types

| Type | Schema | Factory | Use Case |
|------|--------|---------|----------|
| `owned` | `makeOwned()` | `crud()` | User-owned data (blog posts, chats) |
| `orgScoped` | `makeOrgScoped()` | `orgCrud()` | Org-scoped data (wikis, projects) |
| `children` | `child()` | `childCrud()` | Nested under parent (messages in chat) |
| `base` | `makeBase()` | `cacheCrud()` | External API cache with TTL |
| `singleton` | `makeSingleton()` | `singletonCrud()` | 1:1 per-user data (profile, settings) |

Each wrapper brands schemas at the type level. Passing an owned schema to `orgCrud()` is a compile error.

## Demo Apps

4 apps × 3 platforms = 12 real-world demos with **1,138 tests** across all platforms:

| App | What it shows | Backend |
|-----|---------------|---------|
| [Movie](https://github.com/1qh/lazyconvex/tree/main/apps/movie) | Cache factory, TMDB integration, no-auth | [movie.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/movie.ts) |
| [Blog](https://github.com/1qh/lazyconvex/tree/main/apps/blog) | Owned CRUD, forms, file upload, pagination, profile | [blog.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/blog.ts) |
| [Chat](https://github.com/1qh/lazyconvex/tree/main/apps/chat) | Child CRUD, public/auth split, AI streaming | [chat.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/chat.ts) |
| [Org](https://github.com/1qh/lazyconvex/tree/main/apps/org) | Multi-tenancy, ACL, soft delete, invites, onboarding | [wiki.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/wiki.ts) |

### Test Coverage

| Platform | Framework | Tests |
|----------|-----------|------:|
| Web | Playwright E2E | 220 |
| Desktop | XCUITest (SwiftCrossUI) | 223 |
| Mobile | Maestro (Skip) | 84 |
| Backend | convex-test | 215 |
| Library | bun:test | 396 |

### Native Apps

The same Zod schemas that power your TypeScript backend also generate typed Swift APIs:

```swift
try await BlogAPI.create(client, category: .tech, content: "Hello", published: true, title: "Post")
try await WikiAPI.update(client, orgId: orgId, id: wikiId, status: .published)
let subID = BlogAPI.subscribePaginated(onUpdate: { result in ... }, onError: { error in ... })
```

A typo in a field name or wrong enum value is a Swift compile error. Zero `[String: Any]` dictionaries.

```bash
bunx lazyconvex-codegen-swift --schema packages/be/t.ts --convex packages/be/convex \
  --output Generated.swift --mobile-output MobileAPI.swift
```

## Documentation

| Guide | What's covered |
|-------|---------------|
| [Forms](docs/forms.md) | Typesafe forms, multi-step wizards, auto-save, conflict detection, async validation |
| [Data Fetching](docs/data-fetching.md) | pub/auth queries, where clauses, pagination, search |
| [Organizations](docs/organizations.md) | orgCrud, ACL, cascade delete, invites, join requests, org hooks |
| [Custom Queries](docs/custom-queries.md) | pq/q/m escape hatches, mixing with CRUD, migration guide |
| [Native Apps](docs/native-apps.md) | Swift codegen, ConvexClientProtocol, mobile (Skip), desktop (SwiftCrossUI) |
| [Testing](docs/testing.md) | makeTestAuth, makeOrgTestCrud, convex-test patterns |
| [API Reference](docs/api-reference.md) | All exports, error codes, file upload, rate limiting, known limitations |
| [Migration](docs/migration.md) | Incremental adoption, convert one table at a time, coexistence with raw Convex |
| [Schema Evolution](docs/schema-evolution.md) | Adding, renaming, removing fields, type changes, deployment strategies |

## Contributing

The library is independently testable without the demo apps:

```bash
cd packages/lazyconvex
bun test          # 396 library-only tests, no Convex needed
bun lint          # library-scoped linting
bun typecheck     # library-only type checking
```

Repo-wide commands (`bun fix`, `bun test:all`) include all 4 demo apps and take longer. For library-only changes, the commands above are sufficient.

Run `bunx lazyconvex-check` from any consumer project to validate schema/factory consistency.
