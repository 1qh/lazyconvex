# Native Apps

lazyconvex includes a Swift codegen CLI and 8 native apps (4 mobile + 4 desktop) that consume the same Convex backend as the web demos.

## Swift Codegen

Generate typed Swift models, enums, and API wrappers from your Zod schemas:

```bash
bunx lazyconvex codegen-swift --schema packages/be/t.ts --convex packages/be/convex \
  --output swift-core/Sources/ConvexCore/Generated.swift \
  --mobile-output mobile/convex-shared/Sources/ConvexShared/MobileAPI.swift
```

Output includes:

- **Structs** matching all fields from Zod schemas (`Blog`, `Chat`, `Wiki`, `Movie`, etc.)
- **Enums** for Zod enum fields (`BlogCategory`, `WikiStatus`, `TaskItemPriority`, etc.)
- **API constants** for every exported Convex function (`BlogAPI.list`, `OrgAPI.create`, etc.)
- **Where structs** for typed filtering (`BlogWhere`, `WikiWhere`, etc.)
- **Desktop wrappers** (Generated.swift) — typed CRUD, search, list with `ConvexClientProtocol`:

```swift
try await BlogAPI.create(client, category: .tech, content: "Hello", published: true, title: "Post")
try await WikiAPI.update(client, orgId: orgId, id: wikiId, status: .published)
let profile: BlogProfile? = try await BlogProfileAPI.get(client)
```

- **Mobile wrappers** (MobileAPI.swift) — typed mutations, actions, and subscriptions for Skip cross-platform apps:

```swift
try await MessageAPI.create(chatId: chatID, parts: [MessagePart(type: .text, text: text)], role: "user")
let results = try await MovieAPI.search(query: "inception")
let subID = BlogAPI.subscribePaginated(onUpdate: { result in ... }, onError: { error in ... })
```

Zero raw `ConvexService.shared` calls or `[String: Any]` dictionaries in consumer code. All platform branching (`#if !SKIP`) for Convex calls is hidden inside generated wrappers.

A typo in a field name or wrong enum value is a Swift compile error.

## ConvexClientProtocol

The codegen output depends on a thin protocol in `swift-core`:

```swift
public protocol ConvexClientProtocol: Sendable {
    func query<T: Decodable & Sendable>(_ name: String, args: [String: Any]) async throws -> T
    func mutation<T: Decodable & Sendable>(_ name: String, args: [String: Any]) async throws -> T
    func mutation(_ name: String, args: [String: Any]) async throws
    func action<T: Decodable & Sendable>(_ name: String, args: [String: Any]) async throws -> T
    func action(_ name: String, args: [String: Any]) async throws
}
```

Conform your Convex client to this protocol and the typed wrappers work automatically.

## Mobile Apps (Skip)

4 cross-platform apps (iOS + Android) using [Skip](https://skip.tools):

| App | Features |
|-----|----------|
| Movie | Search + detail, TMDB cache, no auth |
| Blog | Auth + CRUD + file upload + pagination + search + profile |
| Chat | Child CRUD + AI + public/private |
| Org | Multi-tenancy + ACL + soft delete + bulk ops + invites + onboarding |

## Desktop Apps (SwiftCrossUI)

4 native macOS apps using [SwiftCrossUI](https://github.com/stackotter/swift-cross-ui) with 223 E2E tests:

| App | E2E Tests |
|-----|-----------|
| Movie | 26 |
| Blog | 65 |
| Chat | 48 |
| Org | 84 |

## Architecture

```
swift-core/           Shared models, enums, protocol (Foundation-only)
desktop/              4 SwiftCrossUI macOS apps + HTTP/WebSocket Convex client
mobile/               4 Skip cross-platform apps (iOS + Android)
packages/lazyconvex/  Codegen CLI (codegen-swift.ts)
```

All native apps share the same generated `Generated.swift` via SPM dependencies and symlinks.
