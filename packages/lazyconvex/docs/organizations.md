# Organizations

Full multi-tenant system with roles, invites, join requests, and per-item ACL.

## One Line for Org-Scoped CRUD

> [Real example: packages/be/convex/wiki.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/wiki.ts)

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

## ACL (Per-Item Editor Permissions)

Pass `acl: true` → get `addEditor`, `removeEditor`, `setEditors`, `editors` endpoints.
Add `editors: array(zid('users')).optional()` to schema.

| Role            | Can edit?         |
| --------------- | ----------------- |
| Org owner/admin | Always            |
| Item creator    | Always (own docs) |
| In `editors[]`  | Yes               |
| Regular member  | View only         |

Child tables inherit ACL from parents:

```tsx
orgCrud('task', orgScoped.task, {
  aclFrom: { field: 'projectId', table: 'project' }
})
```

## Cascade Delete

> [Real example: packages/be/convex/project.ts](https://github.com/1qh/lazyconvex/blob/main/packages/be/convex/project.ts)

```tsx
orgCrud('project', orgScoped.project, {
  acl: true,
  cascade: orgCascade(orgScoped.task, {
    foreignKey: 'projectId',
    table: 'task'
  })
})
```

Both `foreignKey` and `table` are type-checked — typos are compile errors.

## Frontend Org Hooks

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

## Org API

Management: `create`, `update`, `get`, `getBySlug`, `myOrgs`, `remove` Membership:
`membership`, `members`, `setAdmin`, `removeMember`, `leave`, `transferOwnership`
Invites: `invite`, `acceptInvite`, `revokeInvite`, `pendingInvites` Join requests:
`requestJoin`, `approveJoinRequest`, `rejectJoinRequest`, `pendingJoinRequests`

## Pre-Built Components

```tsx
import {
  EditorsSection,
  PermissionGuard,
  OrgAvatar,
  RoleBadge,
  OfflineIndicator
} from 'lazyconvex/components'
```

> [Real example: apps/org/src/app/wiki/\[wikiId\]/page.tsx — EditorsSection](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/wiki/%5BwikiId%5D/page.tsx)
> |
> [apps/org/src/app/wiki/\[wikiId\]/edit/page.tsx — PermissionGuard + AutoSave](https://github.com/1qh/lazyconvex/blob/main/apps/org/src/app/wiki/%5BwikiId%5D/edit/page.tsx)

## Invite and Join Lifecycle

Two paths for adding members to an org.

**Path 1: Admin invites a user**

```
Admin calls invite(email, orgId)
  → Invite record created with expiration token
  → Invited user calls acceptInvite(token)
    → orgMember record created
    → Invite marked as used
```

```tsx
await invite({ email: 'alice@company.com', orgId: org._id })

const pending = await pendingInvites({ orgId: org._id })

await revokeInvite({ inviteId: pending[0]._id, orgId: org._id })
```

**Path 2: User requests to join**

```
User calls requestJoin(orgId, message?)
  → Join request created (status: 'pending')
  → Admin sees request in pendingJoinRequests(orgId)
  → Admin calls approveJoinRequest(requestId, orgId)
    → orgMember record created
    → Request status → 'approved'
  OR rejectJoinRequest(requestId, orgId)
    → Request status → 'rejected'
```

```tsx
await requestJoin({ orgId: org._id, message: 'I work on the frontend team' })

const requests = await pendingJoinRequests({ orgId: org._id })

await approveJoinRequest({ orgId: org._id, requestId: requests[0]._id })
```

## Org Switching

The active org is stored as a cookie so server components can read it.

```tsx
import {
  setActiveOrgCookie,
  getActiveOrg,
  clearActiveOrgCookie
} from 'lazyconvex/next'

await setActiveOrgCookie(orgId)

const activeOrg = await getActiveOrg()

await clearActiveOrgCookie()
```

Client-side:

```tsx
import { setActiveOrgCookieClient } from 'lazyconvex/react'

setActiveOrgCookieClient(orgId)
```

`useOrgQuery` and `useOrgMutation` automatically inject `orgId` from the `OrgProvider`
context — no manual passing required.

## Handling Permission Errors

```tsx
import { handleConvexError } from 'lazyconvex/server'

handleConvexError(error, {
  NOT_ORG_MEMBER: () => router.push('/orgs'),
  INSUFFICIENT_ORG_ROLE: () => toast.error('Admin access required'),
  EDITOR_REQUIRED: () => toast.error('You need editor permission'),
  ALREADY_ORG_MEMBER: () => toast.info('Already a member'),
  INVITE_EXPIRED: () => toast.error('This invite has expired'),
  MUST_TRANSFER_OWNERSHIP: () =>
    toast.error('Transfer ownership before leaving'),
  default: () => toast.error('Something went wrong')
})
```

Role escalation:

| Action                    | Minimum role        |
| ------------------------- | ------------------- |
| View org content          | `member`            |
| Create/edit own items     | `member`            |
| Edit items in `editors[]` | `member` (with ACL) |
| Edit any item             | `admin`             |
| Manage members            | `admin`             |
| Invite users              | `admin`             |
| Approve join requests     | `admin`             |
| Transfer ownership        | `owner`             |
| Delete org                | `owner`             |
