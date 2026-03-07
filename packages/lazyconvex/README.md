# lazyconvex

Zod schema → fullstack app.
One schema, zero boilerplate.

Define a Zod schema once → authenticated CRUD endpoints, typesafe forms with file
upload, real-time queries, pagination, search, conflict detection, soft delete, rate
limiting, org multi-tenancy with ACL — all generated.
Ship a production app in minutes, not days.

## Before / After

A typical user-owned CRUD in raw Convex:

```tsx
export const list = query({
  args: { paginationOpts: paginationOptsValidator },
  handler: async (ctx, { paginationOpts }) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db
      .query('blog')
      .withIndex('by_userId', q => q.eq('userId', userId))
      .order('desc')
      .paginate(paginationOpts)
  }
})

export const create = mutation({
  args: {
    title: v.string(),
    content: v.string(),
    category: v.string(),
    published: v.boolean()
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx)
    if (!userId) throw new Error('Not authenticated')
    return ctx.db.insert('blog', { ...args, userId, updatedAt: Date.now() })
  }
})

export const update = mutation({
  args: {
    id: v.id('blog'),
    title: v.optional(v.string()),
    content: v.optional(v.string())
  },
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

~50 lines for 4 endpoints.
No validation, no pagination options, no file cleanup, no rate limiting, no conflict
detection.

With lazyconvex:

```tsx
export const {
  bulkRm,
  bulkUpdate,
  create,
  pub: { list, read, search },
  rm,
  update
} = crud('blog', owned.blog, {
  rateLimit: { max: 10, window: 60_000 },
  search: 'content'
})
```

3 lines. 8 endpoints.
Auth, ownership, Zod validation, file upload with auto-cleanup, cursor-based pagination,
sliding-window rate limiting, conflict detection, author enrichment, and where-clause
filtering — all included.

## 445 Lines → 87 Endpoints

The entire backend for 4 production apps — blog, chat, org collaboration, and movie
search — is **445 lines of consumer code**. That’s schemas, setup, and endpoint files
combined. Those 445 lines produce **87 fully typed, authenticated, rate-limited
endpoints**.

Here’s a full org-scoped CRUD with per-item editor permissions and soft delete:

```tsx
export const {
  addEditor,
  bulkRm,
  create,
  editors,
  list,
  read,
  removeEditor,
  restore,
  rm,
  setEditors,
  update
} = orgCrud('wiki', orgScoped.wiki, { acl: true, softDelete: true })
```

One line of config. 12 endpoints.
Role-based access, editor ACL, soft delete with restore, bulk operations — all
generated.

> [See all backend code: packages/be/convex/](https://github.com/1qh/lazyconvex/tree/main/packages/be/convex)

## What You Get

| Feature                                                                                                | Lines of code |
| ------------------------------------------------------------------------------------------------------ | :-----------: |
| CRUD mutations with auth + ownership                                                                   |       0       |
| Public & auth-gated queries with pagination                                                            |       0       |
| File upload with compression, auto-cleanup, URL resolution                                             |       0       |
| Typesafe forms with Zod validation                                                                     |       0       |
| Conflict detection + resolution dialog                                                                 |       0       |
| Soft delete + undo toast                                                                               |       0       |
| Bulk operations (select all, bulk delete/update)                                                       |       0       |
| Rate limiting (sliding window, per user)                                                               |       0       |
| Where clauses ($gt, $lt, $between, OR, own)                                                            |       0       |
| Org multi-tenancy with roles + ACL + invites                                                           |       0       |
| Optimistic mutations with auto-rollback                                                                |       0       |
| Auto-save with debounce + indicator                                                                    |       0       |
| Multi-step forms with per-step validation                                                              |       0       |
| Singleton per-user data (profile, settings)                                                            |       0       |
| External API cache with TTL + auto-refresh                                                             |       0       |
| Branded types — compile-time factory mismatch prevention                                               |       0       |
| Swift codegen — typed native APIs from the same schema                                                 |       0       |
| Typed error handling with discriminated result unions                                                  |       0       |
| Rich error metadata (retryAfter, limit) for rate limiting                                              |       0       |
| Unified CLI — 8 commands (`init`, `add`, `check`, `doctor`, `codegen-swift`, `docs`, `migrate`, `viz`) |       0       |
| Project health score (`lazyconvex check --health`)                                                     |       0       |
| Schema preview (`lazyconvex check --schema`)                                                           |       0       |
| Browser devtools panel (subscriptions, mutations, cache, errors)                                       |       0       |
| Interactive schema playground component                                                                |       0       |
| JSDoc on all public exports                                                                            |       0       |
| Auto-derived field labels from field name                                                              |       0       |
| Default error toasts with smart routing (auth, rate-limit)                                             |       0       |
| Auto-mount devtools in dev mode (inside forms)                                                         |       0       |
| File upload auto-detection + dev warning                                                               |       0       |
| Guarded API wrapper — runtime typo detection                                                           |       0       |
| Test utilities (`discoverModules`, `createTestContext`)                                                |       0       |
| CLI scaffold with best-practice defaults                                                               |       0       |
| CLI table scaffolding (`lazyconvex add`)                                                               |       0       |
| Live subscription data tracking in devtools                                                            |       0       |
| Descriptive branded type error messages (`AssertSchema`, `SchemaTypeError`)                            |       0       |
| ESLint plugin — 16 rules (`api-casing`, `form-field-exists`, `require-rate-limit`, ...)                |       0       |
| Pre-built components (ConflictDialog, AutoSaveIndicator, OfflineIndicator, PermissionGuard)            |       0       |
| React hooks (`useSearch`, `usePresence`, `useBulkSelection`, `useInfiniteList`, ...)                   |       0       |
| Server middleware (`composeMiddleware`, `inputSanitize`, `auditLog`, `slowQueryWarn`)                  |       0       |
| Next.js server utilities (`getToken`, `setActiveOrgCookie`, `makeImageRoute`)                          |       0       |
| Real-time presence tracking (`usePresence`, `makePresence`, `presenceTable`)                           |       0       |
| Seed data generation (`generateOne`, `generateSeed`)                                                   |       0       |
| Retry with exponential backoff (`withRetry`, `fetchWithRetry`)                                         |       0       |
| Zod introspection (`unwrapZod`, `cvFileKindOf`, `defaultValues`, `enumToOptions`, ...)                 |       0       |

## Developer Tools

### Type Error Messages

Schema mismatches surface as clear compile-time errors with descriptive messages:

```tsx
// Without lazyconvex branded types:
//   "Type 'ZodObject<...>' is not assignable to 'ZodObject<...>'"

// With lazyconvex AssertSchema:
//   "Schema mismatch: expected OwnedSchema (from makeOwned()),
//    got OrgSchema (from makeOrgScoped())."
```

Use `AssertSchema<T, Expected>` in your own code to enforce schema brands:

```tsx
import type {
  AssertSchema,
  DetectBrand,
  SchemaTypeError
} from 'lazyconvex/server'

type Validated = AssertSchema<typeof mySchema, 'owned'>
//   ✅ if mySchema is OwnedSchema → resolves to the schema type
//   ❌ if mySchema is OrgSchema → resolves to descriptive error string
```

### Browser Devtools Panel

In dev mode, the devtools panel auto-mounts inside `<Form>` components — no import
needed. The panel tracks:

- **Subscriptions**: Active queries with args, data preview, render count, result count,
  latency
- **Mutations**: Name, args, duration, status (pending/success/error)
- **Cache**: Table, key, hit/miss counts, stale state
- **Errors**: Full error details with retry info and rate limit metadata

Click any subscription row to expand and inspect its current args and data preview.

For standalone usage or customization:

```tsx
import { LazyConvexDevtools } from 'lazyconvex/react'
;<LazyConvexDevtools position="bottom-right" defaultTab="subs" />
```

### Schema Playground

Interactive component for previewing how schemas map to generated endpoints:

```tsx
import { SchemaPlayground } from 'lazyconvex/react'
;<SchemaPlayground className="my-8" />
```

### CLI: `lazyconvex doctor`

Run project-wide diagnostics with a health score:

```bash
lazyconvex doctor --convex-dir=convex --schema-file=t.ts
```

Checks 7 categories: schema consistency, endpoint coverage, index coverage, access
levels, rate limiting, ESLint config, and dependency versions.
Outputs pass/warn/fail for each check with a health score from 0–100.

### CLI: `lazyconvex add`

Scaffold a new table with schema, endpoint, and page component in one command:

```bash
lazyconvex add todo --fields="title:string,done:boolean"
lazyconvex add wiki --type=org --fields="title:string,content:string,status:enum(draft,published)"
lazyconvex add message --type=child --parent=chat --fields="text:string"
lazyconvex add profile --type=singleton --fields="displayName:string,bio:string?"
lazyconvex add movie --type=cache --fields="title:string,tmdb_id:number"
```

Generates 3 files per table: `convex/<name>-schema.ts`, `convex/<name>.ts`,
`src/app/<name>/page.tsx`. Skips existing files.
Supports all 5 table types (owned, org, singleton, cache, child) with field types
`string`, `boolean`, `number`, and `enum()`.

### ESLint Plugin

16 rules to catch common mistakes at lint time:

```js
import { recommended } from 'lazyconvex/eslint'

export default [recommended]
```

| Rule                               | Severity | What it catches                                    |
| ---------------------------------- | -------- | -------------------------------------------------- |
| `api-casing`                       | error    | Wrong casing in `api.moduleName` references        |
| `discovery-check`                  | warn     | Could not find convex/ directory or schema file    |
| `consistent-crud-naming`           | error    | CRUD export name doesn’t match table               |
| `form-field-exists`                | error    | `<Text name='typo' />` — field not in schema       |
| `form-field-kind`                  | warn     | `<Text>` on boolean field (should be `<Toggle>`)   |
| `no-duplicate-crud`                | error    | Same table registered in two `crud()` calls        |
| `no-empty-search-config`           | error    | `search: {}` with no field or index                |
| `no-raw-fetch-in-server-component` | warn     | `fetch()` in server component (use action)         |
| `no-unlimited-file-size`           | warn     | File upload without size limit                     |
| `no-unprotected-mutation`          | warn     | Mutation without rate limiting                     |
| `no-unsafe-api-cast`               | warn     | `api as typeof api` bypassing guard                |
| `prefer-useList`                   | warn     | Raw `useQuery` where `useList` fits                |
| `prefer-useOrgQuery`               | warn     | `useQuery` where `useOrgQuery` fits                |
| `require-connection`               | error    | Missing `await connection()` before `preloadQuery` |
| `require-error-boundary`           | warn     | Page without `<ConvexErrorBoundary>`               |
| `require-rate-limit`               | warn     | `crud()` without `rateLimit` option                |

## Install

```bash
bun add lazyconvex
```

## Entry Points

| Import                  | What’s inside                                                                                                                                                                                                                           |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lazyconvex`            | `guardApi`, `strictApi`                                                                                                                                                                                                                 |
| `lazyconvex/schema`     | `makeOwned`, `makeOrgScoped`, `makeBase`, `makeSingleton`, `child`, `cvFile`, `cvFiles`, `orgSchema`                                                                                                                                    |
| `lazyconvex/server`     | `setup`, table helpers, `makeOrg`, `makePresence`, `makeFileUpload`, middleware, error handling                                                                                                                                         |
| `lazyconvex/react`      | `useList`, `useSearch`, `usePresence`, `useBulkSelection`, `useMutate`, `useInfiniteList`, `useUpload`, `useSoftDelete`, `useCacheEntry`, `useOptimisticMutation`, `useErrorToast`, `LazyConvexDevtools`, `SchemaPlayground`, org hooks |
| `lazyconvex/components` | `Form`, `ConflictDialog`, `AutoSaveIndicator`, `OfflineIndicator`, `PermissionGuard`, `ConvexErrorBoundary`, `FileApiProvider`, `OrgAvatar`, `RoleBadge`, `EditorsSection`, `defineSteps`                                               |
| `lazyconvex/next`       | `getToken`, `isAuthenticated`, `setActiveOrgCookie`, `clearActiveOrgCookie`, `getActiveOrg`, `makeImageRoute`                                                                                                                           |
| `lazyconvex/eslint`     | `plugin`, `recommended`, 16 lint rules                                                                                                                                                                                                  |
| `lazyconvex/zod`        | `unwrapZod`, `cvFileKindOf`, `defaultValues`, `enumToOptions`, `pickValues`, `coerceOptionals`                                                                                                                                          |
| `lazyconvex/test`       | `discoverModules`, `createTestContext`, `makeTestAuth`, `makeOrgTestCrud`                                                                                                                                                               |
| `lazyconvex/seed`       | `generateOne`, `generateSeed`, `generateFieldValue`                                                                                                                                                                                     |
| `lazyconvex/retry`      | `withRetry`, `fetchWithRetry`                                                                                                                                                                                                           |

## Type Safety

Every API surface is type-checked at compile time.
Typos are caught before your code runs.

### Branded schemas prevent mismatches

```tsx
crud('blog', owned.blog) // ✅ compiles
orgCrud('wiki', orgScoped.wiki) // ✅ compiles
crud('wiki', orgScoped.wiki) // ❌ compile error — OrgSchema is not OwnedSchema
orgCrud('blog', owned.blog) // ❌ compile error — OwnedSchema is not OrgSchema
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
crud('blog', owned.blog, { search: 'content' }) // ✅
crud('blog', owned.blog, { search: 'conten' }) // ❌ typo

useList(api.blog.list, { where: { category: 'tech' } }) // ✅
useList(api.blog.list, { where: { categry: 'tech' } }) // ❌ typo
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
export default defineSchema({
  ...uploadTables(),
  ...rateLimitTable(),
  blog: ownedTable(owned.blog)
})
```

```tsx
const { crud, orgCrud, childCrud, cacheCrud, singletonCrud, pq, q, m } = setup({
  query,
  mutation,
  action,
  internalQuery,
  internalMutation,
  getAuthUserId
})
```

### 3. Generate endpoints

```tsx
export const {
  bulkRm,
  bulkUpdate,
  create,
  pub: { list, read, search },
  rm,
  update
} = crud('blog', owned.blog, {
  rateLimit: { max: 10, window: 60_000 },
  search: 'content'
})
```

### 4. Use in React

```tsx
const { items: blogs, loadMore } = useList(api.blog.list, {
  where: { published: true }
})
```

## Zero-Config Defaults

Everything works out of the box.
Opt out only when needed.

| Default             | What it does                                             | Opt out                                         |
| ------------------- | -------------------------------------------------------- | ----------------------------------------------- |
| Auto-derived labels | `coverImage` renders as “Cover Image”                    | `label={false}` or `label="Custom"`             |
| Error toasts        | `useMutate` and forms show toast on error                | `onError: false`                                |
| Devtools panel      | Auto-mounts in dev mode inside forms                     | Manual `<LazyConvexDevtools>` for customization |
| File upload warning | Console warning if file fields lack `<FileApiProvider>`  | Add the provider                                |
| Form data return    | Forms auto-return submitted data for reset               | Return custom data from `onSubmit`              |
| Devtools tracking   | Mutations, subscriptions, and cache tracked in dev panel | Dev mode only                                   |

`bunx lazyconvex init` scaffolds new projects with all defaults pre-configured: guarded
API wrapper, `FileApiProvider`, `ConvexErrorBoundary`, and commented middleware
examples.

## 5 Table Types

| Type        | Schema            | Factory           | Use Case                               |
| ----------- | ----------------- | ----------------- | -------------------------------------- |
| `owned`     | `makeOwned()`     | `crud()`          | User-owned data (blog posts, chats)    |
| `orgScoped` | `makeOrgScoped()` | `orgCrud()`       | Org-scoped data (wikis, projects)      |
| `children`  | `child()`         | `childCrud()`     | Nested under parent (messages in chat) |
| `base`      | `makeBase()`      | `cacheCrud()`     | External API cache with TTL            |
| `singleton` | `makeSingleton()` | `singletonCrud()` | 1:1 per-user data (profile, settings)  |

Each wrapper brands schemas at the type level.
Passing an owned schema to `orgCrud()` is a compile error.

## Demo Apps

4 apps × 3 platforms = 12 real-world demos with **1,486 tests** across all platforms:

| App                                                             | What it shows                                                                     | Backend                                                                             |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [Movie](https://github.com/1qh/lazyconvex/tree/main/apps/movie) | Cache factory, TMDB integration, no-auth                                          | [movie.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/movie.ts) |
| [Blog](https://github.com/1qh/lazyconvex/tree/main/apps/blog)   | Owned CRUD, forms, file upload, pagination, profile, custom pq/q/m escape hatches | [blog.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/blog.ts)   |
| [Chat](https://github.com/1qh/lazyconvex/tree/main/apps/chat)   | Child CRUD, public/auth split, AI streaming                                       | [chat.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/chat.ts)   |
| [Org](https://github.com/1qh/lazyconvex/tree/main/apps/org)     | Multi-tenancy, ACL, soft delete, invites, onboarding                              | [wiki.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/wiki.ts)   |

### Test Coverage

| Platform | Framework              | Tests |
| -------- | ---------------------- | ----: |
| Web      | Playwright E2E         |   220 |
| Desktop  | Swift Testing + XCTest |    32 |
| Mobile   | Maestro (Skip)         |    92 |
| Backend  | convex-test            |   219 |
| Library  | bun:test               |   923 |

### Native Apps

The same Zod schemas that power your TypeScript backend also generate typed Swift APIs:

```swift
try await BlogAPI.create(client, category: .tech, content: "Hello", published: true, title: "Post")
try await WikiAPI.update(client, orgId: orgId, id: wikiId, status: .published)
let subID = BlogAPI.subscribePaginated(onUpdate: { result in ... }, onError: { error in ... })
```

A typo in a field name or wrong enum value is a Swift compile error.
Zero `[String: Any]` dictionaries.

```bash
bunx lazyconvex codegen-swift --schema packages/be/t.ts --convex packages/be/convex \
  --output Generated.swift --mobile-output MobileAPI.swift
```

## Documentation

| Guide                                        | What’s covered                                                                                     |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| [Quickstart](docs/quickstart.md)             | From zero to running app in 5 minutes                                                              |
| [Forms](docs/forms.md)                       | Typesafe forms, multi-step wizards, auto-save, conflict detection, async validation                |
| [Data Fetching](docs/data-fetching.md)       | pub/auth queries, where clauses, pagination, search                                                |
| [Organizations](docs/organizations.md)       | orgCrud, ACL, cascade delete, invites, join requests, org hooks                                    |
| [Custom Queries](docs/custom-queries.md)     | pq/q/m escape hatches, mixing with CRUD, migration guide                                           |
| [Native Apps](docs/native-apps.md)           | Swift codegen, ConvexClientProtocol, mobile (Skip), desktop (SwiftCrossUI)                         |
| [Testing](docs/testing.md)                   | makeTestAuth, makeOrgTestCrud, convex-test patterns                                                |
| [API Reference](docs/api-reference.md)       | All exports, error codes, file upload, rate limiting, known limitations                            |
| [Migration](docs/migration.md)               | Incremental adoption, convert one table at a time, coexistence with raw Convex                     |
| [Schema Evolution](docs/schema-evolution.md) | Adding, renaming, removing fields, type changes, deployment strategies                             |
| [Ejecting](docs/ejecting.md)                 | Gradual replacement of factories with raw Convex, what you lose/keep                               |
| [Recipes](docs/recipes.md)                   | 7 real-world composition patterns: blog+files, org+ACL, custom queries, presence, multi-step forms |

## Contributing

The library is independently testable without the demo apps:

```bash
cd packages/lazyconvex
bun test          # 923 library-only tests, no Convex needed
bun lint          # library-scoped linting
bun typecheck     # library-only type checking
```

Repo-wide commands (`bun fix`, `bun test:all`) include all 4 demo apps and take longer.
For library-only changes, the commands above are sufficient.

Run `bunx lazyconvex check` from any consumer project to validate schema/factory
consistency.
