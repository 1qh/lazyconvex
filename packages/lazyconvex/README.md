# lazyconvex

Zod schema → fullstack app. One schema, zero boilerplate.

Define a Zod schema once → authenticated CRUD endpoints, typesafe forms with file upload, real-time queries, pagination, search, conflict detection, soft delete, rate limiting, org multi-tenancy with ACL — all generated. Ship a production app in minutes, not days.

```tsx
// 3 lines. Authenticated CRUD with file handling, pagination, search, ownership checks.
const { create, pub, rm, update } = crud('blog', owned.blog)
export const { list, read, search } = pub
export { create, rm, update }
```

## What you get from one Zod schema

| Feature | Lines of code |
|---------|:---:|
| CRUD mutations (create/update/delete) with auth + ownership | 0 |
| Public & auth-gated queries (list/read/search) | 0 |
| Pagination with cursor-based infinite scroll | 0 |
| File upload with auto-cleanup, compression, URL resolution | 0 |
| Typesafe forms with Zod validation + auto-generated fields | 0 |
| Conflict detection + resolution dialog | 0 |
| Soft delete + undo toast (Gmail/Linear pattern) | 0 |
| Bulk operations (select all, bulk delete) | 0 |
| Rate limiting on mutations | 0 |
| Where clauses ($gt, $lt, $between, OR, own filter) | 0 |
| Org multi-tenancy with roles + ACL + invites + join requests | 0 |
| Optimistic mutations with auto-rollback | 0 |
| Auto-save with debounce + indicator | 0 |
| Async validation (e.g. unique slug check) | 0 |
| Navigation guard (unsaved changes warning) | 0 |
| Multi-step forms with per-step validation + navigation guard | 0 |
| Singleton per-user data (profile, settings, preferences) | 0 |
| External API cache with TTL + auto-refresh | 0 |
| Branded schema types — compile-time factory/table mismatch prevention | 0 |

## Install

```bash
bun add lazyconvex
```

## Type Safety

Every API surface is type-checked at compile time. Typos and mismatches are caught before your code runs.

### Branded schemas prevent factory/table mismatches

Schema wrappers (`makeOwned`, `makeOrgScoped`, `makeBase`, `makeSingleton`) brand types so each factory only accepts its matching brand:

```tsx
const owned = makeOwned({ blog: object({ title: string() }) })
const orgScoped = makeOrgScoped({ wiki: object({ title: string() }) })

crud('blog', owned.blog)         // ✅ compiles
orgCrud('wiki', orgScoped.wiki)  // ✅ compiles
crud('wiki', orgScoped.wiki)     // ❌ compile error — OrgSchema is not OwnedSchema
orgCrud('blog', owned.blog)      // ❌ compile error — OwnedSchema is not OrgSchema
ownedTable(orgScoped.wiki)       // ❌ compile error — wrong brand for table helper
```

### Form fields are type-checked by value type

Field components only accept `name` values matching the correct type. `Text` only accepts string fields, `Toggle` only boolean fields, `File` only storage ID fields:

```tsx
<Text name='title' />       // ✅ title is string
<Text name='published' />   // ❌ compile error — published is boolean, not string
<Toggle name='published' /> // ✅ published is boolean
<File name='coverImage' />  // ✅ coverImage is cvFile()
<File name='title' />       // ❌ compile error — title is not a file field
```

### Multi-step forms have per-step type isolation

Each step's fields are scoped to its own schema. Field names that exist in one step error in another:

```tsx
<StepForm.Step id='profile' render={({ Text }) => (
  <Text name='displayName' />  // ✅ exists in profile schema
  <Text name='slug' />         // ❌ compile error — slug is in org schema, not profile
)} />
<StepForm.Step id='org' render={({ Text }) => (
  <Text name='slug' />         // ✅ exists in org schema
  <Text name='displayName' />  // ❌ compile error — displayName is in profile schema, not org
)} />
```

### Where clauses, search, and cascade are schema-aware

```tsx
crud('blog', owned.blog, {
  search: 'content',                                    // ✅ 'content' is a field
  search: 'conten',                                     // ❌ compile error — typo
  pub: { where: { published: true } },                  // ✅ correct field + type
  pub: { where: { publishd: true } },                   // ❌ compile error — typo
})

orgCrud('project', orgScoped.project, {
  cascade: orgCascade(orgScoped.task, { foreignKey: 'projectId', table: 'task' })  // ✅
  cascade: orgCascade(orgScoped.task, { foreignKey: 'projctId', table: 'task' })   // ❌ typo
})

useList(api.blog.list, { where: { category: 'tech' } })   // ✅
useList(api.blog.list, { where: { categry: 'tech' } })    // ❌ compile error
```

## 5-Minute Setup

### 1. Define schemas with Zod

> [Real example: packages/be/t.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/t.ts)

```tsx
import { cvFile, cvFiles, makeOwned } from 'lazyconvex/schema'
import { array, boolean, object, string, enum as zenum } from 'zod/v4'

const owned = makeOwned({
  blog: object({
    title: string().min(1),
    content: string().min(3),
    category: zenum(['tech', 'life', 'tutorial']),
    published: boolean(),
    coverImage: cvFile().nullable().optional(),
    attachments: cvFiles().max(5).optional(),
    tags: array(string()).max(5).optional()
  })
})
```

Every field name, every constraint, every type — defined once, enforced everywhere (backend validation, frontend form, TypeScript types). A typo like `titl` raises a compile error.

Schema wrappers (`makeOwned`, `makeOrgScoped`, `makeBase`, `makeSingleton`) brand your schemas at the type level. Passing an owned schema to `orgCrud()` or a singleton schema to `crud()` is a compile error — no runtime surprises.

### 2. Register tables

> [Real example: packages/be/convex/schema.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/schema.ts)

```tsx
import { defineSchema } from 'convex/server'
import { orgTable, orgTables, ownedTable, rateLimitTable, uploadTables } from 'lazyconvex/server'

export default defineSchema({
  ...uploadTables(),
  ...rateLimitTable(),
  blog: ownedTable(owned.blog),
})
```

### 3. Initialize

> [Real example: packages/be/lazy.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/lazy.ts)

```tsx
import { setup } from 'lazyconvex/server'

const { crud, orgCrud, childCrud, cacheCrud, singletonCrud, uniqueCheck, pq, q, m } = setup({
  query, mutation, action, internalQuery, internalMutation,
  getAuthUserId,
})
```

### 4. Generate endpoints

> [Real example: packages/be/convex/blog.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/blog.ts)

```tsx
export const {
  bulkRm, bulkUpdate, create,
  pub: { list, read, search },
  rm, update
} = crud('blog', owned.blog, { rateLimit: { max: 10, window: 60_000 }, search: 'content' })
```

That's it. You now have 8 fully typed, authenticated, rate-limited endpoints.

### 5. Use in React

```tsx
const { items: blogs, loadMore } = useList(api.blog.list, { where: { published: true } })
const drafts = usePaginatedQuery(api.blog.list, { where: { own: true, published: false } }, { initialNumItems: 20 })
```

## Typesafe Forms

Forms are auto-generated from your Zod schema. Field components (`Text`, `Num`, `Choose`, `Toggle`, `File`, `Files`, `Arr`, `Datepick`, `Combobox`, etc.) are type-checked — `name='titl'` is a compile error.

> [Real example: apps/blog/src/app/common.tsx — Create dialog](https://github.com/1qh/lazyconvex/blob/main/apps/blog/src/app/common.tsx)

```tsx
const form = useForm({
  schema: createBlog,
  onSubmit: async d => { await create({ ...d, published: false }); return d },
  onSuccess: () => toast.success('Created'),
})

<Form form={form} render={({ Text, Choose, File, Files, Arr, Submit }) => (
  <>
    <Text name='title' label='Title' />
    <Choose name='category' label='Category' />
    <Text name='content' label='Content' multiline />
    <File name='coverImage' label='Cover Image' accept='image/*' />
    <Files name='attachments' label='Attachments' />
    <Arr name='tags' label='Tags' transform={s => s.toLowerCase()} />
    <Submit>Create</Submit>
  </>
)} />
```

### Edit forms with `useFormMutation`

> [Real example: apps/org/src/app/wiki/\[wikiId\]/edit/page.tsx](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/wiki/%5BwikiId%5D/edit/page.tsx)

```tsx
const form = useFormMutation({
  mutation: api.wiki.update,
  schema: orgScoped.wiki,
  values: wiki ? pickValues(orgScoped.wiki, wiki) : undefined,
  transform: d => ({ ...d, id: wikiId, orgId: org._id }),
  onSuccess: () => toast.success('Updated'),
})
```

`pickValues` extracts schema-matching fields from an existing doc. Empty optional strings auto-coerce to `undefined`.

### Conflict detection

```tsx
onSubmit: d => update({ id, ...d, expectedUpdatedAt: doc?.updatedAt })
```

If another user edited the record, a conflict dialog appears with Cancel / Reload / Overwrite options.

### Auto-save

```tsx
const form = useForm({
  schema: owned.blog,
  onSubmit: d => update({ id, ...d }),
  autoSave: { enabled: true, debounceMs: 1000 }
})
<AutoSaveIndicator lastSaved={form.lastSaved} />
```

### Async validation

```tsx
export const isSlugAvailable = uniqueCheck(orgScoped.wiki, 'wiki', 'slug')


<Text name='slug' asyncValidate={async v => {
  const ok = await isSlugAvailable({ value: v, exclude: id })
  return ok ? undefined : 'Slug already taken'
}} asyncDebounceMs={500} />
```

## Multi-Step Forms

`defineSteps` creates a typed multi-step form wizard with per-step validation, step navigation, and a built-in navigation guard. Each step gets its own Zod schema and isolated typed fields.

> [Real example: apps/org/src/app/onboarding/page.tsx](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/onboarding/page.tsx)

```tsx
import { defineSteps } from 'lazyconvex/components'

const { StepForm, useStepper } = defineSteps(
  { id: 'profile', label: 'Profile', schema: profileStep },
  { id: 'org', label: 'Organization', schema: orgStep },
  { id: 'appearance', label: 'Appearance', schema: appearanceStep },
  { id: 'preferences', label: 'Preferences', schema: preferencesStep }
)
```

Use `useStepper` to wire up submit logic and initial values:

```tsx
const stepper = useStepper({
  onSubmit: async d => {
    await upsert({ ...d.profile, ...d.preferences })
    await create({ name: d.org.name, slug: d.org.slug })
  },
  onSuccess: () => toast.success('Done!'),
  values: existingData ? { profile: { ... }, preferences: { ... } } : undefined
})
```

Render with `StepForm` and `StepForm.Step` — field names are type-checked per step:

```tsx
<StepForm stepper={stepper} submitLabel='Complete'>
  <StepForm.Step id='profile' render={({ Text, File }) => (
    <>
      <Text name='displayName' label='Name' />
      <File name='avatar' label='Avatar' accept='image/*' />
    </>
  )} />
  <StepForm.Step id='org' render={({ Text }) => (
    <>
      <Text name='name' label='Org Name' />
      <Text name='slug' label='URL Slug' />
    </>
  )} />
</StepForm>
```

Features:

- Per-step Zod validation — each step validates independently before advancing
- Type-isolated fields — `name='displayName'` compiles on the profile step but errors on the org step
- Navigation guard — warns on unsaved changes, auto-disables after successful submit
- Step indicators with clickable navigation (previous steps only)
- Supports all field types: `Text`, `Num`, `Choose`, `Toggle`, `File`, `Files`, `Arr`, etc.

## File Upload

`cvFile()` for single file, `cvFiles()` for arrays. Everything is automatic:

- Image compression (max 1920px, 0.8 quality) — disable with `compressImg={false}`
- Auto-cleanup on doc update/delete (orphaned files removed)
- URL resolution — `photo` (storage ID) → `photoUrl` (URL string) in query results
- Rate limited (10 uploads/min), max 10MB per file

## Soft Delete + Undo Toast

> [Real example: apps/org/src/app/wiki/page.tsx — bulk delete with undo](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/wiki/page.tsx)

```tsx
const { remove } = useSoftDelete({
  rm: useOrgMutation(api.wiki.rm),
  restore: useOrgMutation(api.wiki.restore),
  toast, label: 'wiki page',
})
await remove({ id: wikiId }) // Shows "Wiki page deleted" toast with Undo button
```

Bulk version:

```tsx
const { handleBulkDelete, selected, toggleSelect } = useBulkSelection({
  bulkRm: useMutation(api.wiki.bulkRm),
  items: wikis?.page ?? [],
  orgId: org._id,
  restore: useOrgMutation(api.wiki.restore),
  toast, undoLabel: 'wiki page',
})
```

Enable soft delete on any table by adding `deletedAt: number().optional()` to the schema and `softDelete: true` to the factory:

```tsx
orgCrud('wiki', orgScoped.wiki, { acl: true, softDelete: true })
```

## Optimistic Mutations

> [Real example: apps/blog/src/app/common.tsx — Delete component](https://github.com/1qh/lazyconvex/blob/main/apps/blog/src/app/common.tsx)

```tsx
const { execute, isPending } = useOptimisticMutation({
  mutation: api.blog.rm,
  onOptimistic: () => onOptimisticRemove?.(),
  onRollback: () => toast.error('Failed to delete'),
  onSuccess: () => toast.success('Deleted'),
})
```

## Data Fetching

### `pub` vs `auth` — easy access control switching

Every `crud()` call generates two sets of read endpoints: `pub` (public, no auth required) and `auth` (requires authentication). Both have the same API — `list`, `read`, and optionally `search`.

```tsx
const { pub, auth, create, rm, update } = crud('blog', owned.blog)

// Export public reads — anyone can list/read blogs
export const { list, read } = pub

// Or switch to auth reads — only logged-in users see blogs
export const { list, read } = auth
```

This makes it trivial to change access control. A blog that starts public can become auth-gated by changing one destructure line — no endpoint rewriting, no middleware changes. Both `pub` and `auth` support the same `where` clauses:

```tsx
const { pub, auth } = crud('blog', owned.blog, {
  pub: { where: { published: true } },    // public readers only see published
  auth: { where: { published: false } },   // logged-in users see drafts
})
```

### Where clauses and pagination

```tsx
const { items: mine, loadMore, isDone } = useList(api.blog.list, { where: { own: true } })
const published = usePaginatedQuery(api.blog.list, { where: { published: true } }, { initialNumItems: 20 })
const expensive = usePaginatedQuery(api.product.list, { where: { price: { $gte: 100 } } }, { initialNumItems: 20 })
const either = usePaginatedQuery(api.blog.list, { where: { or: [{ category: 'tech' }, { category: 'life' }] } }, { initialNumItems: 20 })
```

`{ own: true }` uses the `by_user` index automatically. Default where clauses can be set at the factory level:

```tsx
crud('blog', owned.blog, { pub: { where: { published: true } } })
```

### Search configuration

Search is generated only when `search` is configured on `crud(...)`. Three forms:

```tsx
crud('blog', owned.blog, { search: true })            // defaults: field='text', index='search_field'
crud('blog', owned.blog, { search: 'content' })       // shorthand: search on 'content' field
crud('blog', owned.blog, { search: { field: 'content', index: 'my_index' } })  // full config
```

The string shorthand is typesafe — `search: 'conten'` is a compile error if `conten` is not a field in your schema.

You must add a matching `searchIndex` to your schema table.

## Rate Limiting

Built-in sliding window rate limiting on mutations:

```tsx
crud('blog', owned.blog, { rateLimit: { max: 10, window: 60_000 } })
```

`max` requests per `window` (ms) per authenticated user. Uses a single-row sliding window counter per user+table (no write amplification). Returns `RATE_LIMITED` error code when exceeded. Requires `...rateLimitTable()` in schema.

## External API Cache

> [Real example: packages/be/convex/movie.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/movie.ts)

```tsx
const c = cacheCrud({
  table: 'movie', schema: base.movie, key: 'tmdb_id',
  fetcher: async (_, tmdbId) => {
    const { id, ...rest } = await tmdb(`/movie/${tmdbId}`, {}).json<TmdbMovie>()
    return { ...rest, tmdb_id: id }
  },
  rateLimit: { max: 30, window: 60_000 },
})
export const { all, get, load, refresh, invalidate, purge } = c
```

`load` returns cached or fetches. `refresh` force-refreshes. `purge` cleans expired entries.

## Singleton CRUD

For 1:1 per-user data — profiles, settings, preferences. Each user gets exactly one record.

> [Real example: packages/be/convex/blogprofile.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/blogprofile.ts)

```tsx
import { makeSingleton } from 'lazyconvex/schema'

const singleton = makeSingleton({
  blogProfile: object({
    avatar: cvFile().nullable().optional(),
    bio: string().max(500).optional(),
    displayName: string().min(1),
    notifications: boolean(),
    theme: zenum(['light', 'dark', 'system'])
  })
})
```

Register the table and generate endpoints:

```tsx
// schema
blogProfile: singletonTable(singleton.blogProfile)

// endpoint (convex/blogprofile.ts)
const { get, upsert } = singletonCrud('blogProfile', singleton.blogProfile)
export { get, upsert }
```

Two endpoints, fully typed:

- `get` — returns the current user's record (or `null`), with file URLs resolved
- `upsert` — creates on first call, partial-updates on subsequent calls. Handles file cleanup when replacing/removing files

```tsx
const profile = useQuery(api.blogprofile.get)
const upsert = useMutation(api.blogprofile.upsert)
await upsert({ displayName: 'Jane', theme: 'dark' })
await upsert({ bio: 'Updated bio' }) // merges — displayName and theme preserved
```

Supports rate limiting (`rateLimit`) and conflict detection (`expectedUpdatedAt`), same as `crud`.

## Child CRUD

> [Real example: packages/be/convex/message.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/message.ts)

```tsx
const children = {
  message: child({ parent: 'chat', foreignKey: 'chatId', parentSchema: owned.chat, schema: messageSchema })
}
export const { create, list, update } = childCrud('message', children.message)
```

Parent ownership verified automatically. Add `cascade` on the parent's `crud()` call to cascade deletes:

```tsx
crud('chat', owned.chat, { cascade: [{ foreignKey: 'chatId', table: 'message' }] })
```

### Public access for child resources

Pass `pub` to generate unauthenticated `pub.list` and `pub.get` queries. Access is gated on a boolean field from the parent schema:

```tsx
const ops = childCrud('message', children.message, { pub: { parentField: 'isPublic' } })
export const { list: pubList, get: pubGet } = ops.pub
```

`pub.list` and `pub.get` check that the parent document's `isPublic` field is `true` before returning data.

## Organizations

Full multi-tenant system with roles, invites, join requests, and per-item ACL.

### One line for org-scoped CRUD

> [Real example: packages/be/convex/wiki.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/wiki.ts)

```tsx
export const { addEditor, bulkRm, create, editors, list, read,
  removeEditor, restore, rm, setEditors, update
} = orgCrud('wiki', orgScoped.wiki, { acl: true, softDelete: true })
```

### ACL (per-item editor permissions)

Pass `acl: true` → get `addEditor`, `removeEditor`, `setEditors`, `editors` endpoints. Add `editors: array(zid('users')).optional()` to schema.

| Role | Can edit? |
|------|-----------|
| Org owner/admin | Always |
| Item creator | Always (own docs) |
| In `editors[]` | Yes |
| Regular member | View only |

Child tables inherit ACL from parents:

```tsx
orgCrud('task', orgScoped.task, { aclFrom: { field: 'projectId', table: 'project' } })
```

### Cascade delete

> [Real example: packages/be/convex/project.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/project.ts)

```tsx
orgCrud('project', orgScoped.project, {
  acl: true,
  cascade: orgCascade(orgScoped.task, { foreignKey: 'projectId', table: 'task' })
})
```

Both `foreignKey` and `table` are type-checked — typos are compile errors.

### Frontend org hooks

```tsx
const { useOrg, useActiveOrg, useMyOrgs } = createOrgHooks(api.org)

<OrgProvider membership={membership} org={org} role={role}>
  {children}
</OrgProvider>

const { org, role, isAdmin, isOwner } = useOrg()
const projects = useOrgQuery(api.project.list, { paginationOpts: { cursor: null, numItems: 20 } })
const remove = useOrgMutation(api.project.rm)
await remove({ id: projectId }) // orgId auto-injected
```

### Org API

Management: `create`, `update`, `get`, `getBySlug`, `myOrgs`, `remove`
Membership: `membership`, `members`, `setAdmin`, `removeMember`, `leave`, `transferOwnership`
Invites: `invite`, `acceptInvite`, `revokeInvite`, `pendingInvites`
Join requests: `requestJoin`, `approveJoinRequest`, `rejectJoinRequest`, `pendingJoinRequests`

### Pre-built components

```tsx
import { EditorsSection, PermissionGuard, OrgAvatar, RoleBadge, OfflineIndicator } from 'lazyconvex/components'
```

> [Real example: apps/org/src/app/wiki/\[wikiId\]/edit/page.tsx — PermissionGuard + EditorsSection](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/wiki/%5BwikiId%5D/edit/page.tsx)

## Custom Queries (Escape Hatches)

`setup()` returns `pq`, `q`, and `m` — thin wrappers around Convex's query/mutation builders that inject auth context and helpers. Use them when generated CRUD isn't enough.

| Builder | Auth | Context provides |
|---------|------|-----------------|
| `pq` | Optional | `viewerId` (null if anon), `withAuthor` |
| `q` | Required | `user`, `viewerId`, `withAuthor`, `get` (ownership-checked) |
| `m` | Required | `user`, `get`, `create`, `patch` (with conflict detection), `delete` |

### pq — public query (no auth required)

```tsx
const bySlug = pq({
  args: { slug: z.string() },
  handler: async (c, { slug }) => {
    const doc = await c.db.query('blog').withIndex('by_slug', q => q.eq('slug', slug)).unique()
    return doc ? (await c.withAuthor([doc]))[0] : null
  }
})
```

### q — authenticated query

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

### m — authenticated mutation

```tsx
const archive = m({
  args: { id: z.string() },
  handler: async (c, { id }) => c.patch(id, { archived: true })
})
```

`c.patch` includes conflict detection — pass `expectedUpdatedAt` as the third argument.

### Mixing custom and generated endpoints

Custom endpoints live in the same file as generated CRUD. They're just additional exports:

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

### Strict filter mode

By default, exceeding the threshold logs a warning. Pass `strictFilter: true` to `setup()` to throw instead — useful in development to force index migration before it becomes a production issue:

```tsx
const { crud, ... } = setup({
  query, mutation, action, internalQuery, internalMutation,
  getAuthUserId,
  strictFilter: true, // throws Error instead of warning when >1000 docs filtered at runtime
})
```

### Step 1: Add a Convex index

```tsx
// convex/schema.ts
blog: ownedTable(owned.blog)
  .index('by_category', ['category'])
  .index('by_published_date', ['published', '_creationTime'])
```

### Step 2: Write a custom query using the index

```tsx
// convex/blog.ts — keep generated CRUD, add indexed query alongside it
export const { create, rm, update, pub: { read, search } } = crud('blog', owned.blog, { search: 'content' })

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

### Step 3: Replace the frontend call

```tsx
// Before (runtime filtering)
const { items } = useList(api.blog.list, { where: { category: 'tech' } })

// After (index-backed)
const results = usePaginatedQuery(api.blog.listByCategory, { category: 'tech' }, { initialNumItems: 20 })
```

### What stays, what changes

| Concern | Generated `crud()` | Custom `pq`/`q`/`m` |
|---------|-------------------|---------------------|
| Auth + ownership | Automatic | `c.user`, `c.get(id)` |
| File cleanup | Automatic | Manual (call `storage.delete`) |
| Where clauses | Runtime `.filter()` | Convex `.withIndex()` |
| Conflict detection | `expectedUpdatedAt` | `c.patch(id, data, expectedUpdatedAt)` |
| Author enrichment | Automatic | `c.withAuthor(docs)` |
| Rate limiting | `rateLimit` option | Manual (`checkRateLimit` from `lazyconvex/server`) |

You don't need to migrate everything at once. Keep generated CRUD for mutations and simple reads, add custom indexed queries only for the hot paths.

## Error Handling

| Code | Meaning |
|------|---------|
| `NOT_AUTHENTICATED` | Not logged in |
| `NOT_FOUND` | Doesn't exist or not owned |
| `NOT_AUTHORIZED` | No permission |
| `CONFLICT` | Concurrent edit detected |
| `RATE_LIMITED` | Too many requests |
| `EDITOR_REQUIRED` | ACL edit permission required |

```tsx
import { handleConvexError } from 'lazyconvex/server'

handleConvexError(error, {
  NOT_AUTHENTICATED: () => router.push('/login'),
  CONFLICT: () => toast.error('Someone else edited this'),
  default: () => toast.error('Something went wrong')
})
```

## Table Types

| Type | Wrapper | Factory | Table Helper | Use Case |
|------|---------|---------|--------------|----------|
| `owned` | `makeOwned()` | `crud()` | `ownedTable()` | User-owned data (has `userId`) |
| `orgScoped` | `makeOrgScoped()` | `orgCrud()` | `orgTable()` | Org-scoped data (membership check) |
| `children` | `child()` | `childCrud()` | `childTable()` | Nested under parent (e.g. messages in chat) |
| `base` | `makeBase()` | `cacheCrud()` | `baseTable()` | External API cache with TTL |
| `singleton` | `makeSingleton()` | `singletonCrud()` | `singletonTable()` | 1:1 per-user data (profile, settings) |

Wrappers brand schemas at the type level. Each factory and table helper only accepts its matching brand — mismatches are compile errors.

## Demo Apps

4 demo apps showing every feature in production-like code:

| App | Features | Code |
|-----|----------|------|
| [Movie](https://github.com/1qh/lazyconvex/tree/main/apps/movie) | Cache factory, TMDB integration, no-auth | [packages/be/convex/movie.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/movie.ts) |
| [Blog](https://github.com/1qh/lazyconvex/tree/main/apps/blog) | Owned CRUD, forms, file upload, optimistic deletes, pagination, singleton profile | [packages/be/convex/blog.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/blog.ts) |
| [Chat](https://github.com/1qh/lazyconvex/tree/main/apps/chat) | Child CRUD, public/auth split, AI streaming | [packages/be/convex/chat.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/chat.ts) |
| [Org](https://github.com/1qh/lazyconvex/tree/main/apps/org) | Org multi-tenancy, ACL, soft delete, bulk ops, invites, multi-step onboarding | [packages/be/convex/wiki.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/wiki.ts) |

## Imports

| Module | Key Exports |
|--------|------------|
| `lazyconvex/server` | `setup`, `ownedTable`, `orgTable`, `baseTable`, `singletonTable`, `orgChildTable`, `orgTables`, `uploadTables`, `rateLimitTable`, `orgCascade`, `canEdit`, `getOrgMember`, `getOrgRole`, `requireOrgMember`, `requireOrgRole`, `handleConvexError`, `getErrorCode`, `getErrorMessage`, `makeOrg`, `makeFileUpload`, `makeTestAuth` |
| `lazyconvex/react` | `createOrgHooks`, `useForm`, `useFormMutation`, `useList`, `useOptimisticMutation`, `useSoftDelete`, `useUpload`, `useBulkSelection`, `useOnlineStatus`, `OrgProvider`, `useOrg`, `useOrgQuery`, `useOrgMutation`, `canEditResource` |
| `lazyconvex/components` | `Form`, `defineSteps`, `EditorsSection`, `PermissionGuard`, `OfflineIndicator`, `OrgAvatar`, `RoleBadge`, `AutoSaveIndicator`, `ConflictDialog`, `FileApiProvider` |
| `lazyconvex/schema` | `child`, `cvFile`, `cvFiles`, `makeBase`, `makeOrgScoped`, `makeOwned`, `makeSingleton`, `orgSchema` |
| `lazyconvex/zod` | `pickValues`, `defaultValues`, `enumToOptions` |
| `lazyconvex/next` | `getActiveOrg`, `setActiveOrgCookie`, `clearActiveOrgCookie`, `getToken`, `isAuthenticated`, `makeImageRoute` |
| `lazyconvex/retry` | `withRetry`, `fetchWithRetry` |

## Testing

lazyconvex exports test utilities for writing backend tests with [convex-test](https://docs.convex.dev/testing).

### Setup

```bash
bun add -d convex-test
```

```tsx
// convex/testauth.ts
import { makeTestAuth } from 'lazyconvex/server'
import { getAuthUserId } from '@convex-dev/auth/server'
import { mutation, query } from './_generated/server'

const t = makeTestAuth({ getAuthUserId, mutation, query })
export const { ensureTestUser, getTestUser, cleanupTestUsers, getAuthUserIdOrTest } = t
```

### Writing tests

```tsx
import { convexTest } from 'convex-test'
import { describe, expect, test } from 'bun:test' // or vitest
import schema from './schema'
import { api } from './_generated/api'

const modules = {
  './_generated/api.js': async () => import('./_generated/api'),
  './_generated/server.js': async () => import('./_generated/server'),
  './blog.ts': async () => import('./blog'),
  // ... all convex function files
}

describe('blog CRUD', () => {
  test('create and read a blog post', async () => {
    const ctx = convexTest(schema, modules)

    // Create a test user
    const userId = await ctx.run(async c =>
      c.db.insert('users', { email: 'test@example.com', emailVerificationTime: Date.now() })
    )

    // Authenticate as user
    const asUser = ctx.withIdentity({ subject: userId, tokenIdentifier: `test|${userId}` })

    // Create via generated endpoint
    const postId = await asUser.mutation(api.blog.create, {
      title: 'Hello', content: 'World', category: 'tech', published: true
    })

    // Read back
    const post = await asUser.query(api.blog.read, { id: postId })
    expect(post?.title).toBe('Hello')
  })
})
```

### Testing org-scoped endpoints

`makeOrgTestCrud` creates test helpers for org tables with membership and ACL checks:

```tsx
import { makeOrgTestCrud } from 'lazyconvex/server'

// In convex/testauth.ts
export const wikiTest = makeOrgTestCrud({
  acl: true,
  mutation,
  query,
  table: 'wiki'
})
```

```tsx
// In tests
const orgId = await ctx.run(async c =>
  c.db.insert('org', { name: 'Acme', slug: 'acme', updatedAt: Date.now(), userId: ownerId })
)
const memberId = await ctx.run(async c =>
  c.db.insert('orgMember', { isAdmin: false, orgId, updatedAt: Date.now(), userId: memberUserId })
)

// Test ACL: non-editor cannot update
let threw = false
try {
  await asMember.mutation(api.wiki.update, { id: wikiId, orgId, title: 'Hacked' })
} catch (error) {
  threw = true
  expect(String(error)).toContain('EDITOR_REQUIRED')
}
expect(threw).toBe(true)
```

### Environment

Set `CONVEX_TEST_MODE=true` when running tests. This enables `makeTestAuth`'s identity resolution for test contexts:

```json
{
  "scripts": {
    "test": "CONVEX_TEST_MODE=true bun with-env bun test"
  }
}
```

## Known Limitations

- **Where clauses use runtime filtering** — `$gt`, `$lt`, `$between`, `or` use `.filter()`, not index lookups. Fine for <1,000 docs. For high-volume tables, use `pubIndexed`/`authIndexed` with Convex indexes. Pass `strictFilter: true` to `setup()` to throw instead of warn.
- **Search requires schema index setup** — define `search` in `crud(...)` and add a matching `searchIndex` to the table schema.
- **Bulk operations cap at 100 items** per call.
- **CRUD factories use `as never` casts** at the Zod↔Convex type boundary internally. Consumer code is fully typesafe.
- **`anyApi` Proxy accepts arbitrary property names at runtime** — Convex's generated `api` object is typed as `FilterApi<typeof fullApi, ...>` (strict), but the runtime value is `anyApi` — a `Proxy` with type `Record<string, Record<string, { [key: string]: ... }>>`. TypeScript won't flag `api.blogprofile` (wrong casing) even if only `api.blogProfile` exists, because the `[key: string]` index signature permits any property name. Typos in module paths silently construct invalid function references that crash at runtime with "Could not find public function". Rely on E2E tests and Convex deploy errors to catch these — the type system cannot prevent them.
