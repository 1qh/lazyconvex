# Building Forms with lazyconvex

This tutorial walks through building a blog post editor, starting simple and adding
features incrementally.
Each section builds on the previous one.

## 1. A basic create form

You have a blog schema and a `crud('blog', owned.blog)` call.
Let’s build a form to create posts.

```tsx
import { Form, useForm } from 'lazyconvex/components'
import { useMutation } from 'convex/react'
import { api } from '../../convex/_generated/api'
import { owned } from '../../convex/t'

const CreatePost = () => {
  const create = useMutation(api.blog.create)
  const form = useForm({
    schema: owned.blog,
    onSubmit: async d => {
      await create({ ...d, published: false })
      return d
    }
  })

  return (
    <Form
      form={form}
      render={({ Text, Choose, Toggle, Submit }) => (
        <>
          <Text name="title" label="Title" />
          <Text name="content" label="Content" multiline />
          <Choose name="category" label="Category" />
          <Toggle name="published" label="Published" />
          <Submit>Create</Submit>
        </>
      )}
    />
  )
}
```

What’s happening:

- `useForm` takes your Zod schema and generates typed field props
- `name='title'` is checked at compile time — `name='titl'` is a type error
- `Choose` auto-generates options from the Zod enum
- `Toggle` knows `published` is a boolean field — using `<Text name='published' />`
  would be a type error
- Zod validation runs on submit — `title.min(1)` enforces non-empty

![Field type errors](assets/field-errors.png)

## 2. Add file upload

Your schema has `coverImage: cvFile().nullable().optional()`. The `File` field handles
upload automatically:

```tsx
<Form
  form={form}
  render={({ Text, Choose, File, Submit }) => (
    <>
      <Text name="title" label="Title" />
      <Text name="content" label="Content" multiline />
      <Choose name="category" label="Category" />
      <File name="coverImage" label="Cover Image" accept="image/*" />
      <Submit>Create</Submit>
    </>
  )}
/>
```

- `<File name='coverImage' />` compiles because `coverImage` is a `cvFile()` field
- `<File name='title' />` is a compile error — `title` is a string, not a file
- Upload happens on file selection, form submission sends the storage ID
- On delete, lazyconvex auto-cleans the uploaded file from storage

## 3. Edit an existing post

Switch to `useFormMutation` which wires up the mutation and pre-fills values:

```tsx
import { useFormMutation } from 'lazyconvex/react'
import { pickValues } from 'lazyconvex/zod'

const EditPost = ({ post }: { post: Doc<'blog'> }) => {
  const form = useFormMutation({
    mutation: api.blog.update,
    schema: owned.blog,
    values: pickValues(owned.blog, post),
    transform: d => ({ ...d, id: post._id }),
    onSuccess: () => toast.success('Saved')
  })

  return (
    <Form
      form={form}
      render={({ Text, Choose, File, Submit }) => (
        <>
          <Text name="title" label="Title" />
          <Text name="content" label="Content" multiline />
          <Choose name="category" label="Category" />
          <File name="coverImage" label="Cover Image" accept="image/*" />
          <Submit>Save</Submit>
        </>
      )}
    />
  )
}
```

- `pickValues` extracts schema-matching fields from the doc (ignores `_id`,
  `_creationTime`, `userId`)
- `transform` adds the `id` field before submitting — the schema doesn’t have `id` but
  the mutation needs it
- Empty optional strings auto-coerce to `undefined`

## 4. Add conflict detection

If two users edit the same post simultaneously, detect the conflict:

```tsx
const form = useFormMutation({
  mutation: api.blog.update,
  schema: owned.blog,
  values: pickValues(owned.blog, post),
  transform: d => ({ ...d, id: post._id, expectedUpdatedAt: post.updatedAt }),
  onSuccess: () => toast.success('Saved')
})
```

When the server detects a stale `expectedUpdatedAt`, a `ConflictDialog` appears
automatically with three options:

- **Cancel** — discard your changes
- **Reload** — fetch the latest version
- **Overwrite** — force your changes through

No extra UI code needed — the dialog is built into the `Form` component.

## 5. Add auto-save

For a document editor experience, enable auto-save with debounce:

```tsx
const form = useForm({
  schema: owned.blog,
  onSubmit: d => update({ id: post._id, ...d }),
  autoSave: { enabled: true, debounceMs: 1000 }
})
```

Add a save indicator:

```tsx
import { AutoSaveIndicator } from 'lazyconvex/components'
;<AutoSaveIndicator lastSaved={form.lastSaved} />
```

This shows “Saved 5s ago” that updates in real-time.

## 6. Add async validation

Check if a slug is already taken while the user types:

```tsx
export const isSlugAvailable = uniqueCheck(orgScoped.wiki, 'wiki', 'slug')

<Text name='slug' asyncValidate={async v => {
  const ok = await isSlugAvailable({ value: v, exclude: id })
  return ok ? undefined : 'Slug already taken'
}} asyncDebounceMs={500} />
```

The validation runs 500ms after the user stops typing, and shows inline feedback.

## 7. Build a multi-step wizard

For complex forms like onboarding, use `defineSteps` to split into typed steps:

> [Real example: apps/org/src/app/onboarding/page.tsx](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/onboarding/page.tsx)

```tsx
import { defineSteps } from 'lazyconvex/components'

const { StepForm, useStepper } = defineSteps(
  { id: 'profile', label: 'Profile', schema: profileStep },
  { id: 'org', label: 'Organization', schema: orgStep },
  { id: 'preferences', label: 'Preferences', schema: preferencesStep }
)

const stepper = useStepper({
  onSubmit: async d => {
    await upsert({ ...d.profile, ...d.preferences })
    await createOrg({ name: d.org.name, slug: d.org.slug })
  },
  onSuccess: () => toast.success('Done!')
})

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
  <StepForm.Step id='preferences' render={({ Choose }) => (
    <Choose name='theme' label='Theme' />
  )} />
</StepForm>
```

Each step has:

- Its own Zod schema and independent validation
- Type-isolated fields — `name='displayName'` compiles on the profile step but errors on
  the org step
- Navigation guard — warns on unsaved changes
- Clickable step indicators (previous steps only)

## 8. Add optimistic deletes

For instant-feeling delete buttons:

```tsx
import { useOptimisticMutation } from 'lazyconvex/react'

const { execute, isPending } = useOptimisticMutation({
  mutation: api.blog.rm,
  onOptimistic: () => onOptimisticRemove?.(),
  onRollback: () => toast.error('Failed to delete'),
  onSuccess: () => toast.success('Deleted')
})
```

The item disappears immediately.
If the server rejects, it reappears with an error toast.

## Available field components

| Component  | Zod types                      | Renders                          |
| ---------- | ------------------------------ | -------------------------------- |
| `Text`     | `string()`, `string().email()` | Input or textarea (`multiline`)  |
| `Num`      | `number()`                     | Number input                     |
| `Choose`   | `enum()`                       | Select dropdown                  |
| `Toggle`   | `boolean()`                    | Checkbox or switch               |
| `File`     | `cvFile()`                     | File picker with upload          |
| `Files`    | `cvFiles()`                    | Multi-file picker                |
| `Arr`      | `array(string())`              | Tag input                        |
| `Datepick` | `date()`                       | Date picker                      |
| `Combobox` | `string()` with options        | Searchable dropdown              |
| `Submit`   | —                              | Submit button with loading state |

All components accept `label`, `placeholder`, `disabled`, and `className` props.

## 9. Error handling

**Validation errors** — Zod validation runs on submit.
Field-level errors appear automatically:

```tsx
const form = useForm({
  schema: owned.blog,
  onSubmit: async d => {
    await create(d)
    return d
  }
})
```

When `title.min(1)` fails, the `<Text name='title' />` field shows “Required” inline —
no manual error wiring needed.

**Mutation errors** — `useMutate` and `useFormMutation` show error toasts by default:

```tsx
const form = useFormMutation({
  mutation: api.blog.create,
  schema: owned.blog
})
```

If the mutation throws, a toast appears automatically.
Customize or disable:

```tsx
const form = useFormMutation({
  mutation: api.blog.create,
  schema: owned.blog,
  onError: e => toast.error(`Failed: ${e.message}`)
})

const form = useFormMutation({
  mutation: api.blog.create,
  schema: owned.blog,
  onError: false
})
```

**Rate limit errors** — When `RATE_LIMITED` is returned, the default error toast shows
“Too many requests”.
For custom UX:

```tsx
import { handleConvexError } from 'lazyconvex/server'

const form = useFormMutation({
  mutation: api.blog.create,
  schema: owned.blog,
  onError: e =>
    handleConvexError(e, {
      RATE_LIMITED: () => toast.error('Slow down — try again in a minute'),
      CONFLICT: () => toast.error('Someone else edited this'),
      default: () => toast.error('Something went wrong')
    })
})
```

**Error boundary** — Wrap pages with `ConvexErrorBoundary` to catch unhandled errors:

```tsx
import { ConvexErrorBoundary } from 'lazyconvex/components'
;<ConvexErrorBoundary>
  <BlogEditor />
</ConvexErrorBoundary>
```
