# Schema Evolution

How to handle schema changes in production without breaking your app.

## Adding a Field

The simplest change. Add the field as optional in your Zod schema:

```tsx
const owned = makeOwned({
  blog: object({
    title: string().min(1),
    content: string().min(3),
    category: zenum(['tech', 'life', 'tutorial']),
    published: boolean(),
    coverImage: cvFile().nullable().optional(),
    subtitle: string().optional()  // new field — optional so existing docs are valid
  })
})
```

Deploy. Existing documents have no `subtitle` field, which satisfies `optional()`. New documents can include it. Forms using `<Text name='subtitle' />` will render an empty field for old documents.

If the field should have a default value for existing documents, backfill after deploying:

```tsx
const backfillSubtitle = m({
  args: {},
  handler: async (c) => {
    const docs = await c.db.query('blog').collect()
    for (const doc of docs)
      if (doc.subtitle === undefined) await c.patch(doc._id, { subtitle: '' })
  }
})
```

Once all documents have the field, you can remove `optional()` to make it required.

## Removing a Field

1. Remove all frontend code that reads or writes the field.
2. Keep the field in the Zod schema as `optional()` during a transition period.
3. Deploy the frontend changes.
4. Remove the field from the Zod schema.
5. Deploy the schema change.

Convex is schemaless at the storage layer — old documents keep the field in the database but it's ignored. No migration needed for removal.

If you want to clean up old data:

```tsx
const cleanupField = m({
  args: {},
  handler: async (c) => {
    const docs = await c.db.query('blog').collect()
    for (const doc of docs)
      if ('oldField' in doc) await c.patch(doc._id, { oldField: undefined })
  }
})
```

## Renaming a Field

Convex doesn't support field renames at the storage layer. Treat it as "add new + migrate + remove old":

1. Add the new field name as `optional()`:

```tsx
blog: object({
  title: string().min(1),
  body: string().min(3),           // old name
  content: string().optional()     // new name — optional during migration
})
```

2. Deploy and run a migration to copy values:

```tsx
const migrateField = m({
  args: {},
  handler: async (c) => {
    const docs = await c.db.query('blog').collect()
    for (const doc of docs)
      if (doc.content === undefined && doc.body !== undefined)
        await c.patch(doc._id, { content: doc.body })
  }
})
```

3. Update frontend to use `content` instead of `body`.
4. Remove `body` from the schema, make `content` required.
5. Deploy.

## Changing a Field's Type

Similar to renaming — you can't change a field's type in-place. Options:

### Option A: New field (safe)

```tsx
blog: object({
  priority: string(),              // old: 'low' | 'medium' | 'high'
  priorityLevel: number().optional() // new: 1 | 2 | 3
})
```

Migrate, then remove the old field.

### Option B: Widen the type temporarily

If the old and new types can coexist:

```tsx
blog: object({
  priority: union([string(), number()])  // accepts both during migration
})
```

Migrate all documents to the new type, then narrow:

```tsx
blog: object({
  priority: number()
})
```

## Adding an Enum Value

Add the value to the Zod enum:

```tsx
category: zenum(['tech', 'life', 'tutorial', 'news'])  // added 'news'
```

Deploy. No migration needed — existing documents keep their old values.

## Removing an Enum Value

1. Stop creating new documents with the old value.
2. Migrate existing documents to a new value:

```tsx
const migrateCategory = m({
  args: {},
  handler: async (c) => {
    const docs = await c.db.query('blog').collect()
    for (const doc of docs)
      if (doc.category === 'tutorial') await c.patch(doc._id, { category: 'tech' })
  }
})
```

3. Remove the value from the enum.
4. Deploy.

## Deployment Strategy

Convex deploys atomically — schema and functions update together. For safe deployments:

| Change type | Safe to deploy directly? |
|-------------|:---:|
| Add optional field | Yes |
| Add enum value | Yes |
| Remove unused field | Yes |
| Make optional field required | Only after backfill |
| Remove enum value | Only after migration |
| Rename field | No — use add/migrate/remove |
| Change field type | No — use add/migrate/remove |

### Zero-downtime pattern

For breaking changes, use a two-phase deployment:

**Phase 1: Deploy backward-compatible schema**

```tsx
blog: object({
  oldField: string().optional(),  // keep for existing docs
  newField: string().optional()   // add for new docs
})
```

**Phase 2: Run migration, then deploy final schema**

```tsx
blog: object({
  newField: string()  // required, all docs migrated
})
```

## Form Compatibility

When you add or remove a field, form components adapt automatically:

- New optional field: form renders with empty/default value
- Removed field: remove the `<Text name='removedField' />` from JSX — if you forget, the `form-field-exists` ESLint rule catches it
- Renamed field: update the `name` prop — `form-field-exists` catches typos
- Type change: update the component — `form-field-kind` warns if you use `<Text>` for a boolean field

## Convex Indexes

If your field change affects a Convex index (defined in `defineSchema`), update the index definition alongside the schema change. Convex rebuilds indexes automatically on deploy.

```tsx
export default defineSchema({
  blog: ownedTable(owned.blog)
    .index('by_category', ['category'])
    .index('by_status', ['status'])  // add index for new field
})
```
