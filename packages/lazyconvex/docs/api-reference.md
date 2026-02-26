# API Reference

## Imports

| Module | Key Exports |
|--------|------------|
| `lazyconvex` | `strictApi`, `guardApi` |
| `lazyconvex/server` | `setup`, `ownedTable`, `orgTable`, `baseTable`, `singletonTable`, `childTable`, `orgChildTable`, `orgTables`, `uploadTables`, `rateLimitTable`, `orgCascade`, `ownedCascade`, `canEdit`, `getOrgMember`, `getOrgRole`, `requireOrgMember`, `requireOrgRole`, `handleConvexError`, `getErrorCode`, `getErrorMessage`, `checkRateLimit`, `checkSchema`, `makeOrg`, `makeFileUpload` |
| `lazyconvex/test` | `makeTestAuth`, `makeOrgTestCrud`, `getOrgMembership`, `discoverModules`, `createTestContext`, `isTestMode` |
| `lazyconvex/react` | `createOrgHooks`, `useForm`, `useFormMutation`, `useList`, `useOptimisticMutation`, `useSoftDelete`, `useUpload`, `useBulkSelection`, `useOnlineStatus`, `OrgProvider`, `useOrg`, `useActiveOrg`, `useMyOrgs`, `useOrgQuery`, `useOrgMutation`, `canEditResource`, `buildMeta`, `getMeta`, `useDevErrors`, `LazyConvexDevtools` |
| `lazyconvex/components` | `Form`, `defineSteps`, `EditorsSection`, `PermissionGuard`, `OfflineIndicator`, `OrgAvatar`, `RoleBadge`, `AutoSaveIndicator`, `ConflictDialog`, `FileApiProvider` |
| `lazyconvex/schema` | `child`, `cvFile`, `cvFiles`, `makeBase`, `makeOrgScoped`, `makeOwned`, `makeSingleton`, `orgSchema` |
| `lazyconvex/zod` | `pickValues`, `defaultValues`, `enumToOptions` |
| `lazyconvex/next` | `getActiveOrg`, `setActiveOrgCookie`, `clearActiveOrgCookie`, `getToken`, `isAuthenticated`, `makeImageRoute` |
| `lazyconvex/retry` | `withRetry`, `fetchWithRetry` |

## Error Codes

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

## Known Limitations

- **Where clauses use runtime filtering** — `$gt`, `$lt`, `$between`, `or` use `.filter()`, not index lookups. Fine for <1,000 docs. For high-volume tables, use `pubIndexed`/`authIndexed` with Convex indexes. Pass `strictFilter: true` to `setup()` to throw instead of warn.
- **Search requires schema index setup** — define `search` in `crud(...)` and add a matching `searchIndex` to the table schema.
- **Bulk operations cap at 100 items** per call.
- **CRUD factories use `as never` casts** at the Zod↔Convex type boundary internally. Consumer code is fully typesafe; boundaries are covered by 396 library unit tests.
- **`anyApi` Proxy accepts arbitrary property names at runtime** — Convex's generated `api` object is typed as `FilterApi<typeof fullApi, ...>` (strict), but the runtime value is `anyApi` — a `Proxy` with `[key: string]` index signatures. TypeScript won't flag `api.blogprofile` (wrong casing) even if only `api.blogProfile` exists. Typos in module paths silently construct invalid function references that crash at runtime. Rely on E2E tests and Convex deploy errors to catch these.
