# Testing

lazyconvex exports test utilities for writing backend tests with [convex-test](https://docs.convex.dev/testing).

## Setup

```bash
bun add -d convex-test
```

```tsx
import { makeTestAuth } from 'lazyconvex/test'
import { getAuthUserId } from '@convex-dev/auth/server'
import { mutation, query } from './_generated/server'

const t = makeTestAuth({ getAuthUserId, mutation, query })
export const { ensureTestUser, getTestUser, cleanupTestUsers, getAuthUserIdOrTest } = t
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
  './blog.ts': async () => import('./blog'),
}

describe('blog CRUD', () => {
  test('create and read a blog post', async () => {
    const ctx = convexTest(schema, modules)
    const userId = await ctx.run(async c =>
      c.db.insert('users', { email: 'test@example.com', emailVerificationTime: Date.now() })
    )
    const asUser = ctx.withIdentity({ subject: userId, tokenIdentifier: `test|${userId}` })
    const postId = await asUser.mutation(api.blog.create, {
      title: 'Hello', content: 'World', category: 'tech', published: true
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
  c.db.insert('org', { name: 'Acme', slug: 'acme', updatedAt: Date.now(), userId: ownerId })
)
const memberId = await ctx.run(async c =>
  c.db.insert('orgMember', { isAdmin: false, orgId, updatedAt: Date.now(), userId: memberUserId })
)

let threw = false
try {
  await asMember.mutation(api.wiki.update, { id: wikiId, orgId, title: 'Hacked' })
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
