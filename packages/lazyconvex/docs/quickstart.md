# Quickstart

From zero to a running app with authenticated CRUD in 5 minutes.

## Prerequisites

- [Bun](https://bun.sh) installed
- A [Convex](https://convex.dev) account (free tier works)

## 1. Create a Next.js app

```bash
bunx create-next-app@latest my-app --ts --tailwind --app --src-dir --use-bun
cd my-app
```

## 2. Install dependencies

```bash
bun add lazyconvex convex @convex-dev/auth zod
```

## 3. Initialize Convex

```bash
bunx convex dev --once
```

This creates the `convex/` directory with `_generated/` files.

## 4. Scaffold lazyconvex files

```bash
bunx lazyconvex init
```

This generates four files:

| File | Purpose |
|------|---------|
| `convex/t.ts` | Zod schemas wrapped with `makeOwned` |
| `convex/schema.ts` | `defineSchema` with table registrations |
| `convex/lazy.ts` | `setup()` call that creates factories |
| `convex/blog.ts` | CRUD endpoints from one `crud()` call |

## 5. Set up auth

Follow the [Convex Auth guide](https://docs.convex.dev/auth) to configure authentication. lazyconvex requires `@convex-dev/auth` — every factory enforces auth by default.

## 6. Start developing

```bash
bunx convex dev &
bun dev
```

Open `http://localhost:3000`. Your backend is live.

## 7. Use the endpoints

### Query data (React)

```tsx
'use client'
import { useList } from 'lazyconvex/react'
import { api } from '../convex/_generated/api'

const BlogList = () => {
  const { items, loadMore, status } = useList(api.blog.list)
  return (
    <ul>
      {items.map(b => (
        <li key={b._id}>{b.title}</li>
      ))}
      {status === 'CanLoadMore' && <button onClick={loadMore}>Load more</button>}
    </ul>
  )
}

export default BlogList
```

### Create data

```tsx
import { useMutation } from 'convex/react'
import { api } from '../convex/_generated/api'

const CreateBlog = () => {
  const create = useMutation(api.blog.create)
  return (
    <button onClick={() => create({ title: 'Hello', content: 'World', category: 'tech', published: true })}>
      New post
    </button>
  )
}
```

### Typesafe forms

```tsx
import { Form, Text, Toggle, Choose } from 'lazyconvex/components'
import { useFormMutation } from 'lazyconvex/react'
import { api } from '../convex/_generated/api'
import { owned } from '../convex/t'

const BlogForm = () => {
  const form = useFormMutation(api.blog.create, owned.blog)
  return (
    <Form {...form}>
      <Text name='title' />
      <Text name='content' />
      <Choose name='category' />
      <Toggle name='published' />
      <button type='submit'>Create</button>
    </Form>
  )
}
```

## What you get for free

From that single `crud('blog', owned.blog)` call:

- `list` — Paginated query with `where` clause support
- `read` — Single doc by ID with ownership check
- `create` — Validated insert with auth + rate limiting
- `update` — Partial patch with conflict detection
- `rm` — Ownership-checked delete with file cleanup

## Next steps

- [Custom queries](./custom-queries.md) — escape hatches when CRUD isn't enough
- [Organizations](./organizations.md) — multi-tenant apps with `orgCrud`
- [Schema evolution](./schema-evolution.md) — safe field changes in production
- [Forms](./forms.md) — typesafe form components
- [Testing](./testing.md) — test helpers with `convex-test`
