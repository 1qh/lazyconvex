
# RULES

---

- only use `bun`, `yarn/npm/npx/pnpm` are forbidden
- `bun fix` must always pass
- `bun test:all` to run all tests in parallel, should pass every time we add new tests, new features, fix bugs or refactor code
- only use arrow functions
- all exports must be at end of file
- if a `.tsx` file only exports a single component, use `export default`
- `bun ts-unused-exports apps/<app-name>/tsconfig.json` to detect and remove unused exports
- `bun why <package>` to check if a package is already installed, no need to install packages that are already dependencies of other packages

---

## Code Style

- consolidate into fewer files, co-locate small components
- short names in map callbacks: `t`, `m`, `i`
- `export default` for components, named exports for utilities/backend
- `catch (error)` is enforced by oxlint; name state variables descriptively to avoid shadow (e.g. `chatError`, `formError`)

### Component & Import Organization

- **co-location**: if a component is only used by 1 page, it lives next to that page (same folder)
- **shared components**: only move to `~/components` when reused across multiple pages
- **explicit imports**: always import from the exact file path, never from barrel `index.ts` files
- **no barrel exports**: do not create `index.ts` re-export files

---

## Linting

| Linter | Ignore comment |
|--------|----------------|
| oxlint | `// oxlint-disable(-next-line) rule-name` |
| eslint | `// eslint-disable(-next-line) rule-name` |
| biomejs| `/** biome-ignore(-all) lint/category/rule: reason */` |

Run `bun fix` to auto-fix and verify all linters pass (zero errors, warnings allowed).

### Safe-to-ignore rules (only when cannot fix)

**oxlint:**

- `promise/prefer-await-to-then` - ky/fetch chaining

**eslint:**

- `no-await-in-loop`, `max-statements`, `complexity` - complex handlers
- `@typescript-eslint/no-unnecessary-condition` - type narrowing false positives
- `@typescript-eslint/promise-function-async` - functions returning thenable (not Promise)
- `@typescript-eslint/max-params` - utility functions with optional trailing params
- `@typescript-eslint/class-methods-use-this` - React lifecycle methods (componentDidCatch)
- `@next/next/no-img-element` - external images without optimization
- `react-hooks/refs` - custom ref patterns

**biomejs:**

- `style/noProcessEnv` - env validation files
- `performance/noAwaitInLoops` - sequential async operations
- `nursery/noContinue`, `nursery/noForIn` - intentional control flow
- `performance/noImgElement` - external images
- `suspicious/noExplicitAny` - unavoidable generic boundaries

---

## Minimal DOM rule (React + Tailwind)

### Philosophy

Same UI, fewest DOM nodes.** Every element must *earn its place
If you can delete it and nothing breaks (semantics, layout, behavior, required styling) → it shouldn't exist. Wrappers require justification in code review.

### When a node is allowed (“real reasons”)

A DOM node is allowed only if it provides at least 1 of:

- Semantics / accessibility

  - Correct elements: `ul/li`, `button`, `label`, `form`, `fieldset/legend`, `nav`, `section`, etc.
  - Required relationships / focus behavior / ARIA patterns.

- Layout constraint you cannot apply to an existing node

  - Needs its own containing block / positioning context / clipping / scroll container / stacking context.
  - Examples: `relative`, `overflow-*`, `sticky`, `isolation`, `z-*`, `transform`, `contain-*`, `min-w-0` (truncation), etc.

- Behavior

  - Measurement refs, observers, portals target, event boundary, virtualization/scroll container.

- Component API necessity

  - You truly can't pass props/classes to the real root (and you considered `as` / `asChild` / prop forwarding).

If none apply → **no wrapper**.

### Default moves (before adding wrappers)

Spacing / rhythm

- Between siblings → parent `gap-*` (flex/grid) or `space-x/y-*`.
- Prefer `gap-*` when you already use `flex`/`grid`

Separators

- Between siblings → parent `divide-y / divide-x` (instead of per-item borders).

Alignment

- Centering/alignment → put `flex/grid` on the existing parent that already owns the layout.

Visual ownership

- Padding/background/border/shadow/radius → put it on the element that visually owns the box.

JSX-only grouping

- Wrapper only to return multiple children → `<>...</>` (Fragment), not a `<div>`.

### Styling repeated children: pass props first, selectors second

#### Prefer passing `className` to the mapped item when

- The row is a component (`<Row />`) that can accept `className`.
- You need per-item variation (selected/disabled/first-last rules).
- You want clarity and low coupling (child internals can change).

```tsx
<div className='divide-y'>
  {items.map(i => (
    <Row key={i.id} item={i} className='px-3 py-2' />
  ))}
</div>
```

#### Use selector pushdown when

- Children are simple elements you control (and styling is uniform).
- You want to avoid repeating the same classes on every item.
- You're styling **direct children**, not deep internals.

```tsx
// bad
<div className='divide-y'>
  <p className='px-3 py-2'>Item 1</p>
  <p className='px-3 py-2'>Item 2</p>
  <p className='px-3 py-2'>Item 3</p>
  <button>click</button>
</div>
// good
<div className='divide-y [&>p]:px-3 [&>p]:py-2'>
  <p>Item 1</p>
  <p>Item 2</p>
  <p>Item 3</p>
  <button>click</button>
</div>
```

### Tailwind selector tools (for lists you own)

- `*:` applies to direct children: `*:min-w-0 *:shrink-0`
- Direct child targeting: `[&>li]:py-2 [&>li]:px-3`
- Broad descendant targeting (use sparingly): `[&_a]:underline [&_code]:font-mono`
- Stateful styling without wrappers:
  - `group` / `peer` on existing nodes (`group-hover:*`, `peer-focus:*`)
  - `data-[state=open]:*`, `aria-expanded:*`, `disabled:*`
- Structural variants to avoid wrapper logic: `first:* last:* odd:* even:* only:*`

### Examples

Spacing (column)

```tsx
// bad
<div><div className='mb-2'>A</div><div>B</div></div>
// good
<div className='space-y-2'><A /><B /></div>
```

Spacing (row)

```tsx
// bad
<div><div className='mr-3'>A</div><div>B</div></div>
// good
<div className='flex gap-3'><A /><B /></div>
```

Separators

```tsx
// bad
<div>{items.map(i => <div key={i.id} className='border-b'>{i.name}</div>)}</div>
// good
<div className='divide-y'>{items.map(i => <div key={i.id}>{i.name}</div>)}</div>
```

Pointless wrapper

```tsx
// bad
<div className='text-sm'><span>{name}</span></div>
// good
<span className='text-sm'>{name}</span>
```

Wrapper only for JSX

```tsx
// bad
<div><Label /><Input /></div>
// good
<><Label /><Input /></>
```

List semantics (wrapper is OK)

```tsx
<ul className='space-y-2'>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>
```

### Review checklist (strict)

- **Delete test:** can I remove this node without changing semantics/layout/behavior/required styling? → delete.
- **Parent control:** can `gap/space/divide` replace wrapper/margins/borders? → do it.
- **Props first:** can I pass `className` to the mapped item/component? → do it.
- **Selectors second:** can `[&>...]:` / `*:` remove repetition on direct children I control? → do it.
- **No hidden coupling:** avoid styling deep child internals unless it's a deliberate API.

---

## E2E Testing Strategy (Playwright)

### Golden Rule: Verify Before Scaling

NEVER run full test suites blindly. Always follow this progression:

#### 1. Isolate → Fix → Verify (Single Test)

```bash
# Run ONE failing test with short timeout
timeout 10 bun with-env playwright test -g "test name" --timeout=5000
# If it hangs, you have a bug. Don't proceed.
```

#### 2. Verify Fix Works (Same Single Test)

```bash
# Run it 2-3 times to confirm stability
timeout 10 bun with-env playwright test -g "test name" --timeout=5000
```

#### 3. Expand to Test File

```bash
# Only after single test passes reliably
timeout 30 bun with-env playwright test path/to/file.test.ts --timeout=8000
```

#### 4. Run Related Test Files

```bash
# Group related tests
timeout 60 bun with-env playwright test file1.test.ts file2.test.ts --timeout=8000
```

#### 5. Full Suite (ONLY WHEN USER ASKS)

**AI agents: Only run specific failing tests.** Fix them, verify they pass 2-3 times, then stop. Run full suite ONLY when user explicitly requests it.

```bash
# Only run when user explicitly asks
bun test:e2e -- --workers=1 --timeout=10000 --reporter=dot
```

### Timeout Rules

| Scope | Max Timeout | Kill After |
|-------|-------------|------------|
| Single test debug | 5s | 10s |
| Single test file | 8s per test | 30s total |
| Multiple files | 8s per test | 60s total |
| Full suite | 10s per test | 180s total |

### Early Failure Detection

Always use `timeout` command wrapper. If a test hangs beyond expected time, KILL IT and investigate.

```bash
# GOOD: Early exit on hang
timeout 10 bun with-env playwright test -g "my test" --timeout=5000

# BAD: Wait forever
bun test:e2e  # Never do this without timeout wrapper
```

### Debug Hanging Tests

```bash
# Step 1: Check if page loads
timeout 8 bun with-env playwright test -g "test" --timeout=5000 --reporter=list

# Step 2: Add console output in test
test('debug', async ({ page }) => {
  console.log('Step 1')
  await page.goto('/path')
  console.log('Step 2')  // See where it hangs
})

# Step 3: Check element visibility
const el = page.getByTestId('x')
console.log('Visible:', await el.isVisible())
console.log('Enabled:', await el.isEnabled())
```

### Common Playwright Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Test hangs on `fill()` | Input not visible/enabled | Check element state first |
| Test hangs on `click()` | Button disabled | Check `isDisabled()` |
| `waitForLoadState('networkidle')` hangs | Continuous polling/websocket | Use `waitForSelector()` instead |
| Element not found | Wrong locator | Check if testid is on element vs parent |
| Flaky counts | Parallel test interference | Run with `--workers=1` |

### Test Cleanup

```bash
# Always clean before running tests
pkill -9 -f "next" 2>/dev/null
rm -rf ./test-results ./playwright-report
```

### Pre-Test Checklist

Before running any E2E test:

1. [ ] `bun fix` passes (0 errors)
2. [ ] Dev server killed: `pkill -9 -f "next"`
3. [ ] Test results cleaned: `rm -rf test-results`

For individual tests (`bun with-env playwright test`), deploy Convex first:

```bash
cd packages/cv && CONVEX_TEST_MODE=true bun with-env convex dev --once
```

`bun test:e2e` does this automatically before running tests.

---

## Next.js Prerendering with Convex

Next.js requires signaling dynamic rendering BEFORE calling `Math.random()`. Convex's `preloadQuery`/`fetchQuery` use `Math.random()` internally.

**Fix**: Add `await connection()` at the START of async Server Components:

```tsx
import { connection } from 'next/server'

const Page = async () => {
  await connection()  // MUST be first - signals dynamic rendering
  const data = await preloadQuery(api.foo.bar, {}, { token })
  return <Client data={data} />
}
```

**Affected patterns:**

- `preloadQuery()` / `fetchQuery()` / `fetchAction()` from `convex/nextjs`
- `convexAuthNextjsToken()` from `@convex-dev/auth/nextjs/server`

Without this, you get: `Error: Route "/path" used Math.random() before accessing uncached data`

---

## react-doctor

Run `bunx -y react-doctor@latest . --verbose` to scan all projects for React best-practice violations.

### When to run

- After adding new components or pages
- After significant React refactors
- Before releases

### Known false positives (do NOT fix)

| Warning | Why it's OK |
|---------|-------------|
| Unused file (Next.js pages/layouts/configs) | Framework entry points, not imported by user code |
| Unused export (cross-package library API) | Public API consumed by other packages — react-doctor scans per-project |
| `<img>` for Convex storage URLs | Dynamic URLs from `storage.getUrl()` — `next/image` requires known `images.domains` |
| `preventDefault()` on `<form>` | SPA forms submitting via Convex mutations, no server action |
| `useEffect` with intersection observer `inView` | Standard infinite scroll pattern with `react-intersection-observer` |
| `useSearchParams requires Suspense` when already wrapped at call site | react-doctor scans the component file, not where it's rendered |
| `dangerouslySetInnerHTML` / `<script>` in org-redirect | Controlled redirect pattern for setting active org cookie |
| Missing metadata in demo app layouts/pages | Metadata is optional for demo apps — user preference to keep source clean |

### Rules to always follow

| Rule | Fix |
|------|-----|
| Hook naming: functions calling hooks must start with `use` | Rename `withFoo` → `useFoo` |
| Array keys must use stable IDs, never indices | Use `item.id`, `item.toolCallId`, etc. |
| `useSearchParams()` needs `<Suspense>` boundary | Wrap the component using it at the render site |
| No `Date.now()` / `Math.random()` during render | Move impure calls into `useEffect` / `useState` initializer / event handlers |
| Convex camelCase filenames need oxlint override | Add to `.oxlintrc.json` `overrides` with `unicorn/filename-case: off` |

---

## Convex `anyApi` Proxy — Type Safety Gap

Convex's generated `api` object is typed as `FilterApi<typeof fullApi, ...>` (strict, case-sensitive), but the runtime value is `anyApi` — a `Proxy` with `[key: string]` index signatures that accept ANY property name at runtime.

**Impact**: `api.blogprofile.get` (wrong casing) won't raise a TypeScript error even though only `api.blogProfile.get` exists. The typo silently constructs an invalid function reference that crashes at runtime with "Could not find public function".

**Where it bites**:
- Module paths (e.g. `api.blogprofile` vs `api.blogProfile`)
- `convex-test` masks the issue because it routes modules differently from production Convex
- macOS case-insensitive filesystem masks import typos (e.g. `import('./blogprofile')` resolves to `blogProfile.ts`)

**Defense**:
- Always match `api.<module>` references to the EXACT filename in `convex/` (use `api.d.ts` as reference)
- Rely on E2E tests and `convex dev --once` deployments to catch casing errors
- In `f.test.ts` module maps, use exact casing: `'./blogProfile.ts'` not `'./blogprofile.ts'`

---

## Refactoring

After any significant refactoring, verify `api.blog.update({ typoField: ... })` fails to compile.

---

# PROHIBITIONS

- NEVER write comments at all (lint ignores are allowed)
- NEVER touch files inside `packages/ui` (shared frontend components, read-only)
- NEVER use `Array#reduce()`, use `for` loops instead
- NEVER use `forEach()`, use `for` loops instead
- NEVER use non-null assertion operator (`!`)
- NEVER use `any` type
