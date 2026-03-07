# Testing

lazyconvex exports test utilities for writing backend tests with
[convex-test](https://docs.convex.dev/testing).

## Setup

```bash
bun add -d convex-test
```

```tsx
import { makeTestAuth } from 'lazyconvex/test'
import { getAuthUserId } from '@convex-dev/auth/server'
import { mutation, query } from './_generated/server'

const t = makeTestAuth({ getAuthUserId, mutation, query })
export const {
  ensureTestUser,
  getTestUser,
  cleanupTestUsers,
  getAuthUserIdOrTest
} = t
```

## Writing Tests

```tsx
import { convexTest } from 'convex-test'
import { describe, expect, test } from 'bun:test'
import schema from './schema'
import { api } from './_generated/api'

const modules = {
  './_generated/api.js': async () => import('./_generated/api'),
  './_generated/server.js': async () => import('./_generated/server'),
  './blog.ts': async () => import('./blog')
}

describe('blog CRUD', () => {
  test('create and read a blog post', async () => {
    const ctx = convexTest(schema, modules)
    const userId = await ctx.run(async c =>
      c.db.insert('users', {
        email: 'test@example.com',
        emailVerificationTime: Date.now()
      })
    )
    const asUser = ctx.withIdentity({
      subject: userId,
      tokenIdentifier: `test|${userId}`
    })
    const postId = await asUser.mutation(api.blog.create, {
      title: 'Hello',
      content: 'World',
      category: 'tech',
      published: true
    })
    const post = await asUser.query(api.blog.read, { id: postId })
    expect(post?.title).toBe('Hello')
  })
})
```

## Testing Org-Scoped Endpoints

`makeOrgTestCrud` creates test helpers for org tables with membership and ACL checks:

```tsx
import { makeOrgTestCrud } from 'lazyconvex/test'

export const wikiTest = makeOrgTestCrud({
  acl: true,
  mutation,
  query,
  table: 'wiki'
})
```

```tsx
const orgId = await ctx.run(async c =>
  c.db.insert('org', {
    name: 'Acme',
    slug: 'acme',
    updatedAt: Date.now(),
    userId: ownerId
  })
)
const memberId = await ctx.run(async c =>
  c.db.insert('orgMember', {
    isAdmin: false,
    orgId,
    updatedAt: Date.now(),
    userId: memberUserId
  })
)

let threw = false
try {
  await asMember.mutation(api.wiki.update, {
    id: wikiId,
    orgId,
    title: 'Hacked'
  })
} catch (error) {
  threw = true
  expect(String(error)).toContain('EDITOR_REQUIRED')
}
expect(threw).toBe(true)
```

## Environment

Set `CONVEX_TEST_MODE=true` when running tests:

```json
{
  "scripts": {
    "test": "CONVEX_TEST_MODE=true bun with-env bun test"
  }
}
```

## Testing Soft Delete and Restore

Tables with `softDelete: true` don’t delete documents — they set `deletedAt`. The
`restore` endpoint reverses this.

```tsx
test('soft delete and restore', async () => {
  const ctx = convexTest(schema, modules)
  const userId = await ctx.run(async c =>
    c.db.insert('users', {
      email: 'test@example.com',
      emailVerificationTime: Date.now()
    })
  )
  const asUser = ctx.withIdentity({
    subject: userId,
    tokenIdentifier: `test|${userId}`
  })

  const id = await asUser.mutation(api.wiki.create, {
    orgId,
    slug: 'test',
    status: 'draft',
    title: 'Test'
  })

  await asUser.mutation(api.wiki.rm, { id, orgId })

  const deleted = await asUser.query(api.wiki.read, { id, orgId })
  expect(deleted.deletedAt).toBeDefined()

  await asUser.mutation(api.wiki.restore, { id, orgId })

  const restored = await asUser.query(api.wiki.read, { id, orgId })
  expect(restored.deletedAt).toBeUndefined()
})
```

## Testing Rate Limiting

Rate limiting is skipped when `CONVEX_TEST_MODE=true`. To test rate limits, either unset
the env var or test against a deployed backend.

```tsx
test('rate limit blocks excessive requests', async () => {
  const ctx = convexTest(schema, modules)
  const userId = await ctx.run(async c =>
    c.db.insert('users', {
      email: 'test@example.com',
      emailVerificationTime: Date.now()
    })
  )
  const asUser = ctx.withIdentity({
    subject: userId,
    tokenIdentifier: `test|${userId}`
  })

  for (let i = 0; i < 10; i++) {
    await asUser.mutation(api.blog.create, {
      title: `Post ${String(i)}`,
      content: 'Content',
      category: 'tech',
      published: true
    })
  }

  let threw = false
  try {
    await asUser.mutation(api.blog.create, {
      title: 'One too many',
      content: 'Content',
      category: 'tech',
      published: true
    })
  } catch (error) {
    threw = true
    expect(String(error)).toContain('RATE_LIMITED')
  }
  expect(threw).toBe(true)
})
```

Note: this test only works when `CONVEX_TEST_MODE` is NOT set.
`isTestMode()` bypasses rate limits, so the 11th request will succeed in test mode.

## Testing Search

Search tests require the `searchIndex` to be defined in your schema.
`convex-test` supports search indexes — results match the same behavior as production.

```tsx
test('search returns matching results', async () => {
  const ctx = convexTest(schema, modules)
  const userId = await ctx.run(async c =>
    c.db.insert('users', {
      email: 'test@example.com',
      emailVerificationTime: Date.now()
    })
  )
  const asUser = ctx.withIdentity({
    subject: userId,
    tokenIdentifier: `test|${userId}`
  })

  await asUser.mutation(api.blog.create, {
    title: 'TypeScript Guide',
    content: 'Learn TypeScript basics',
    category: 'tech',
    published: true
  })
  await asUser.mutation(api.blog.create, {
    title: 'Cooking Tips',
    content: 'Best pasta recipes',
    category: 'life',
    published: true
  })

  const results = await asUser.query(api.blog.search, { query: 'TypeScript' })
  expect(results.length).toBe(1)
  expect(results[0]?.title).toBe('TypeScript Guide')
})
```

## Testing Error Cases

Test both authorization (wrong user) and authentication (no user) failures to ensure
your endpoints reject invalid access.

```tsx
test('update fails on non-owned document', async () => {
  const ctx = convexTest(schema, modules)
  const owner = await ctx.run(async c =>
    c.db.insert('users', {
      email: 'owner@test.com',
      emailVerificationTime: Date.now()
    })
  )
  const other = await ctx.run(async c =>
    c.db.insert('users', {
      email: 'other@test.com',
      emailVerificationTime: Date.now()
    })
  )

  const asOwner = ctx.withIdentity({
    subject: owner,
    tokenIdentifier: `test|${owner}`
  })
  const asOther = ctx.withIdentity({
    subject: other,
    tokenIdentifier: `test|${other}`
  })

  const id = await asOwner.mutation(api.blog.create, {
    title: 'My Post',
    content: 'Content',
    category: 'tech',
    published: true
  })

  let threw = false
  try {
    await asOther.mutation(api.blog.update, { id, title: 'Hacked' })
  } catch (error) {
    threw = true
    expect(String(error)).toContain('NOT_FOUND')
  }
  expect(threw).toBe(true)
})

test('unauthenticated access throws', async () => {
  const ctx = convexTest(schema, modules)
  let threw = false
  try {
    await ctx.mutation(api.blog.create, {
      title: 'No Auth',
      content: 'Content',
      category: 'tech',
      published: true
    })
  } catch (error) {
    threw = true
    expect(String(error)).toContain('NOT_AUTHENTICATED')
  }
  expect(threw).toBe(true)
})
```

## Testing Conflict Detection

Pass `expectedUpdatedAt` to detect when another user has modified a document since you
loaded it. The server returns `CONFLICT` if the timestamp doesn’t match.

```tsx
test('concurrent edit triggers conflict', async () => {
  const ctx = convexTest(schema, modules)
  const userId = await ctx.run(async c =>
    c.db.insert('users', {
      email: 'test@example.com',
      emailVerificationTime: Date.now()
    })
  )
  const asUser = ctx.withIdentity({
    subject: userId,
    tokenIdentifier: `test|${userId}`
  })

  const id = await asUser.mutation(api.blog.create, {
    title: 'Original',
    content: 'Content',
    category: 'tech',
    published: true
  })
  const post = await asUser.query(api.blog.read, { id })
  const staleTimestamp = post?.updatedAt

  await asUser.mutation(api.blog.update, { id, title: 'Updated by user A' })

  let threw = false
  try {
    await asUser.mutation(api.blog.update, {
      id,
      title: 'Updated by user B',
      expectedUpdatedAt: staleTimestamp
    })
  } catch (error) {
    threw = true
    expect(String(error)).toContain('CONFLICT')
  }
  expect(threw).toBe(true)
})
```
