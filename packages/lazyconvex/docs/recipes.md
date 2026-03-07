# Recipes

7 real-world composition patterns.
Each recipe shows schema → backend → frontend.

## Recipe 1: Blog with Auth + File Upload + Pagination + Search

**Features:** owned CRUD · file upload · rate limiting · search · where clauses

### Schema

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

### Backend

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

### Frontend

```tsx
import { useList } from 'lazyconvex/react'
import { Form, useForm } from 'lazyconvex/components'

const BlogPage = () => {
  const { items, loadMore, status } = useList(api.blog.list, {
    where: { published: true }
  })
  const searched = useList(api.blog.search, { query: 'react hooks' })

  return (
    <ul>
      {items.map(b => (
        <li key={b._id}>
          {b.coverImageUrl && <img src={b.coverImageUrl} alt="" />}
          <h2>{b.title}</h2>
        </li>
      ))}
      {status === 'CanLoadMore' && (
        <button onClick={loadMore}>Load more</button>
      )}
    </ul>
  )
}

const CreateBlog = () => {
  const form = useForm({
    schema: owned.blog,
    onSubmit: async d => {
      await create(d)
      return d
    }
  })

  return (
    <Form
      form={form}
      render={({ Text, Choose, Toggle, File, Submit }) => (
        <>
          <Text name="title" />
          <Text name="content" multiline />
          <Choose name="category" />
          <Toggle name="published" />
          <File name="coverImage" accept="image/*" />
          <Submit>Publish</Submit>
        </>
      )}
    />
  )
}
```

---

## Recipe 2: Org CRUD + ACL + Cascade Delete

**Features:** org multi-tenancy · per-item ACL · soft delete · cascade · permission
guard

### Schema

```tsx
import { makeOrgScoped } from 'lazyconvex/schema'
import { array, number, object, string, enum as zenum } from 'zod/v4'

const orgScoped = makeOrgScoped({
  project: object({
    name: string().min(1),
    description: string(),
    status: zenum(['active', 'archived']),
    editors: array(zid('users')).optional()
  }),
  task: object({
    projectId: zid('project'),
    title: string().min(1),
    priority: number(),
    done: boolean(),
    deletedAt: number().optional()
  })
})
```

### Backend

```tsx
import { orgCascade } from 'lazyconvex/server'

export const {
  addEditor,
  bulkRm,
  create,
  editors,
  list,
  read,
  removeEditor,
  rm,
  setEditors,
  update
} = orgCrud('project', orgScoped.project, {
  acl: true,
  cascade: orgCascade(orgScoped.task, {
    foreignKey: 'projectId',
    table: 'task'
  })
})

export const {
  create: createTask,
  list: listTasks,
  rm: rmTask,
  update: updateTask,
  restore
} = orgCrud('task', orgScoped.task, {
  aclFrom: { field: 'projectId', table: 'project' },
  softDelete: true
})
```

### Frontend

```tsx
import { useOrgQuery, useOrgMutation } from 'lazyconvex/react'
import { EditorsSection, PermissionGuard } from 'lazyconvex/components'

const ProjectPage = ({ projectId }: { projectId: Id<'project'> }) => {
  const project = useOrgQuery(api.project.read, { id: projectId })
  const tasks = useOrgQuery(api.task.list, {
    paginationOpts: { cursor: null, numItems: 50 }
  })
  const remove = useOrgMutation(api.project.rm)

  return (
    <>
      <PermissionGuard doc={project} fallback={<p>View only</p>}>
        <button onClick={() => remove({ id: projectId })}>Delete</button>
      </PermissionGuard>
      <EditorsSection docId={projectId} api={api.project} />
      <ul>
        {tasks?.page.map(t => (
          <li key={t._id}>{t.title}</li>
        ))}
      </ul>
    </>
  )
}
```

---

## Recipe 3: Custom Queries Alongside CRUD

**Features:** pq/q/m escape hatches · typed args · coexistence with CRUD

### Backend

```tsx
import { z } from 'zod/v4'

export const { create, list, read, rm, update } = crud('blog', owned.blog, {
    rateLimit: { max: 10, window: 60_000 }
  }),
  stats = pq({
    args: { category: z.string().optional() },
    handler: async (c, { category }) => {
      const docs = await c.db.query('blog').collect()
      let total = 0
      let published = 0
      for (const d of docs) {
        if (category && d.category !== category) continue
        total++
        if (d.published) published++
      }
      return { total, published, draft: total - published }
    }
  }),
  bySlug = pq({
    args: { slug: z.string() },
    handler: async (c, { slug }) => {
      const doc = await c.db
        .query('blog')
        .withIndex('by_slug', q => q.eq('slug', slug))
        .unique()
      return doc ? (await c.withAuthor([doc]))[0] : null
    }
  }),
  archive = m({
    args: { id: z.string() },
    handler: async (c, { id }) => c.patch(id, { published: false })
  })
```

### Frontend

```tsx
import { useQuery } from 'convex/react'
import { useList } from 'lazyconvex/react'

const Dashboard = () => {
  const stats = useQuery(api.blog.stats, { category: 'tech' })
  const { items } = useList(api.blog.list)

  return (
    <>
      <p>
        {stats?.published} published / {stats?.draft} drafts
      </p>
      <ul>
        {items.map(b => (
          <li key={b._id}>{b.title}</li>
        ))}
      </ul>
    </>
  )
}
```

---

## Recipe 4: Real-Time Presence Tracking

**Features:** presence · cursor tracking · online status · typing indicators

### Schema

```tsx
import { presenceTable } from 'lazyconvex/server'

export default defineSchema({
  ...presenceTable()
})
```

### Backend

```tsx
import { makePresence } from 'lazyconvex/server'

export const { heartbeat, list: listPresence } = makePresence({
  mutation,
  query
})
```

### Frontend

```tsx
import { usePresence } from 'lazyconvex/react'

const CollaborativeEditor = ({ docId }: { docId: string }) => {
  const { others, updatePresence } = usePresence(api.presence, {
    room: docId,
    initialData: { cursor: { x: 0, y: 0 }, status: 'viewing' as const }
  })

  const handleMouseMove = (e: React.MouseEvent) => {
    updatePresence({
      cursor: { x: e.clientX, y: e.clientY },
      status: 'editing'
    })
  }

  return (
    <div onMouseMove={handleMouseMove}>
      {others.map(p => (
        <div
          key={p.id}
          className="absolute size-4 rounded-full bg-blue-500"
          style={{ left: p.data.cursor.x, top: p.data.cursor.y }}
        />
      ))}
    </div>
  )
}
```

---

## Recipe 5: Multi-Step Onboarding Form

**Features:** defineSteps · per-step validation · typed merged data · step navigation

### Schema

```tsx
import { cvFile } from 'lazyconvex/schema'
import { object, string, enum as zenum } from 'zod/v4'

const profileStep = object({
  displayName: string().min(1),
  avatar: cvFile().nullable().optional()
})

const orgStep = object({
  name: string().min(2),
  slug: string()
    .min(2)
    .regex(/^[a-z0-9-]+$/)
})

const preferencesStep = object({
  theme: zenum(['light', 'dark', 'system']),
  language: zenum(['en', 'es', 'fr', 'de'])
})
```

### Backend

```tsx
export const { upsert } = singletonCrud('profile', singleton.profile)

export const { create: createOrg } = orgFns({
  mutation,
  query,
  internalMutation,
  internalQuery
})
```

### Frontend

```tsx
import { defineSteps } from 'lazyconvex/components'
import { useMutation } from 'convex/react'

const { StepForm, useStepper } = defineSteps(
  { id: 'profile', label: 'Profile', schema: profileStep },
  { id: 'org', label: 'Organization', schema: orgStep },
  { id: 'preferences', label: 'Preferences', schema: preferencesStep }
)

const Onboarding = () => {
  const upsert = useMutation(api.profile.upsert)
  const createOrg = useMutation(api.org.create)

  const stepper = useStepper({
    onSubmit: async d => {
      await upsert({
        displayName: d.profile.displayName,
        avatar: d.profile.avatar
      })
      await createOrg({ name: d.org.name, slug: d.org.slug })
    },
    onSuccess: () => router.push('/dashboard')
  })

  return (
    <StepForm stepper={stepper} submitLabel="Complete">
      <StepForm.Step
        id="profile"
        render={({ Text, File }) => (
          <>
            <Text name="displayName" />
            <File name="avatar" accept="image/*" />
          </>
        )}
      />
      <StepForm.Step
        id="org"
        render={({ Text }) => (
          <>
            <Text name="name" />
            <Text name="slug" />
          </>
        )}
      />
      <StepForm.Step
        id="preferences"
        render={({ Choose }) => (
          <>
            <Choose name="theme" />
            <Choose name="language" />
          </>
        )}
      />
    </StepForm>
  )
}
```

---

## Recipe 6: Cache with Custom Fetcher (TMDB Pattern)

**Features:** cacheCrud · TTL · external API · load/refresh · rate limiting

### Schema

```tsx
import { makeBase } from 'lazyconvex/schema'
import { number, object, string } from 'zod/v4'

const base = makeBase({
  movie: object({
    tmdb_id: number(),
    title: string(),
    overview: string(),
    poster_path: string().nullable(),
    vote_average: number()
  })
})
```

### Backend

```tsx
export const { all, get, load, refresh, invalidate, purge } = cacheCrud({
  table: 'movie',
  schema: base.movie,
  key: 'tmdb_id',
  ttl: 86400,
  fetcher: async (_, tmdbId) => {
    const res = await fetch(
      `https://api.themoviedb.org/3/movie/${tmdbId}?api_key=${process.env.TMDB_KEY}`
    )
    const { id, title, overview, poster_path, vote_average } = await res.json()
    return { tmdb_id: id, title, overview, poster_path, vote_average }
  },
  rateLimit: { max: 30, window: 60_000 }
})
```

### Frontend

```tsx
import { useQuery, useMutation } from 'convex/react'

const MoviePage = ({ tmdbId }: { tmdbId: number }) => {
  const movie = useQuery(api.movie.get, { key: tmdbId })
  const loadMovie = useMutation(api.movie.load)
  const refreshMovie = useMutation(api.movie.refresh)

  if (movie === undefined) {
    loadMovie({ key: tmdbId })
    return <p>Loading...</p>
  }

  return (
    <>
      <h1>{movie.title}</h1>
      <p>{movie.overview}</p>
      <p>Rating: {movie.vote_average}/10</p>
      <button onClick={() => refreshMovie({ key: tmdbId })}>Refresh</button>
    </>
  )
}
```

---

## Recipe 7: Singleton Profile with File Upload

**Features:** singletonCrud · 1:1 per-user · file upload · upsert

### Schema

```tsx
import { cvFile, makeSingleton } from 'lazyconvex/schema'
import { object, string, enum as zenum } from 'zod/v4'

const singleton = makeSingleton({
  profile: object({
    displayName: string().min(1),
    bio: string().optional(),
    avatar: cvFile().nullable().optional(),
    theme: zenum(['light', 'dark', 'system'])
  })
})
```

### Backend

```tsx
export const { get, upsert } = singletonCrud('profile', singleton.profile)
```

### Frontend

```tsx
import { useQuery } from 'convex/react'
import { Form, useForm } from 'lazyconvex/components'
import { pickValues } from 'lazyconvex/zod'

const ProfilePage = () => {
  const profile = useQuery(api.profile.get)
  const upsert = useMutation(api.profile.upsert)

  const form = useForm({
    schema: singleton.profile,
    values: profile ? pickValues(singleton.profile, profile) : undefined,
    onSubmit: async d => {
      await upsert(d)
      return d
    }
  })

  return (
    <Form
      form={form}
      render={({ Text, File, Choose, Submit }) => (
        <>
          <Text name="displayName" />
          <Text name="bio" multiline />
          <File name="avatar" accept="image/*" />
          <Choose name="theme" />
          <Submit>Save</Submit>
        </>
      )}
    />
  )
}
```
