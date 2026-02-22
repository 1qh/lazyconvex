# Original user request

This is a huge task, I want to see if my lazyconvex library is practical outside web apps. I want to dive in to native mobile apps. Basically I can see convex has great support for building iOS apps using swift.

<https://docs.convex.dev/quickstart/swift>
<https://docs.convex.dev/client/swift>

Apple has just released Swift Android SDK not too long ago. So this time, I want you to leverage every latest & greatest features of swift and best things from <https://github.com/skiptools> to clone our 4 exact demos to 4 cross-platform apps in both Android and iOS (we can just target only the latest versions of iOS and Android for now, no need to be backward compatible with older versions).

I've already setup needed dependencies of skip, you can verify by running `skip checkup`. The ultimate goal is we have 4 smoothly working apps that run natively on both Android and iOS, so remember to exhaustively test them just like how I did with the web demos.

You can verify my current environment to see if you have all necessary tools and have all needed priviledges to work on this task until done. You will have to implement and test them yourself to verify your own work without my confirmation.

# LazyConvex Mobile: 4 Cross-Platform Native Apps

## Goal

Clone the 4 lazyconvex web demo apps (Movie, Blog, Chat, Org) as native iOS + Android apps using Swift, SwiftUI, and the Skip framework. All apps connect to the same existing Convex backend. Target latest iOS and Android only.

## Architecture

### Skip Mode: Full Lite (Transpiled)

All code is transpiled: Swift → Kotlin on Android, native Swift on iOS. This unlocks Skip's entire integration ecosystem (SkipKit for media, SkipAuthenticationServices for OAuth, SkipKeychain for secure storage) without custom per-platform reimplementations.

```
  All App Modules                        mode: 'transpiled'
  SwiftUI views -> transpiled to Jetpack Compose
  @Observable ViewModels
              |
              | SPM dependency (same transpilation pipeline)
              v
  ConvexShared Module                    mode: 'transpiled'

  #if !os(Android)
    ConvexMobile Swift SDK
    (xcframework, Combine AnyPublisher)

  #if os(Android)
    Convex Kotlin SDK
    (transpiled Swift IS Kotlin, direct API calls)

  Unified: subscribe(), mutate(),
  authenticate(), uploadFile()
```

### Why Full Lite

- **Skip's integration modules** (SkipKit, SkipAuthenticationServices, SkipKeychain) are all transpiled — they work seamlessly in Lite apps, not in Fuse apps
- **Shared AuthView** works naturally (same SkipUI rendering on both platforms)
- **Photo picker**: `SkipKit.withMediaPicker()` — 5 lines, both platforms
- **Google OAuth**: `SkipAuthenticationServices.WebAuthenticationSession` — both platforms
- **Simpler architecture**: No bridging layer needed between UI and data
- **SkipUI coverage is mature** for our needs: TextField, SecureField, List, NavigationStack, TabView, Form, Picker, Toggle, PhotosPicker, etc.

### Convex SDK Platform Branching

ConvexMobile Swift SDK (Combine + xcframework) is iOS-only. Convex Kotlin SDK is Android-only. Both wrap the same Rust engine. In transpiled mode:

- `#if !os(Android)` → Swift SDK (xcframework links on iOS)
- `#if os(Android)` → Kotlin SDK (transpiled Swift IS Kotlin, call Kotlin API directly)

### Convex Function Name Format

Both SDKs use colon-separated format: `"module:function_name"` (NOT dots)

- `"blog:list"`, `"blog:create"`, `"chat:read"`, `"message:list"`, `"movie:search"`, etc.

### Compact Project Philosophy

Every app follows the **same generic structure**. The folder name (`blog/`, `chat/`, `movie/`, `org/`) is the only differentiator — no app-name prefixes on files, classes, or directories. Be as compact and consolidated as possible.

**Rules:**

- **No app-name prefixes**: files and classes use generic names (`App.swift`, `Detail.swift`, `ListView`, `DetailViewModel`), never `BlogApp.swift` or `BlogDetailView`
- **Sources require `Sources/{Module}/` subdirectory**: Skip's Gradle composite build derives the module group from the SPM package directory name (`{dir}.module`). The target path MUST be `Sources/{Module}` (e.g., `Sources/Blog`, `Sources/Chat`). Flattening to `Sources/` breaks Android Gradle module resolution.
- **Tests require `Tests/{Module}Tests/` subdirectory**: same constraint — `Tests/BlogTests`, `Tests/ChatTests`, etc.
- **ANDROID_PACKAGE_NAME must be `{dir}.module`**: in `Skip.env`, this value must match the Gradle composite build group. Example: `blog/` → `ANDROID_PACKAGE_NAME = blog.module`. The skipstone plugin registers modules as `{dir}.module:{Target}` and Gradle composite build substitution requires exact match.
- **Main.kt package matches ANDROID_PACKAGE_NAME**: `package blog.module` (not `blog.app`)
- **No recursive typealiases**: since Main.kt and transpiled code share the same package, reference transpiled classes directly (e.g., `AppDelegate.shared`) instead of creating typealiases that resolve to themselves
- **Consolidate per feature**: each feature merges its view + viewmodel into one file (`Detail.swift` = `DetailView` + `DetailViewModel`)
- **SPM module names stay unique** (`Blog`, `Chat`, `Movie`, `Org`) because Swift requires it — everything else is generic
- **Darwin uses generic names**: `App.xcconfig`, `App.xcodeproj`, `App.xcscheme` — identical across all 4 apps
- **PRODUCT_NAME stays unique** (`Blog`, `Chat`, `Movie`, `Org`) in `Skip.env` for bundle identity

### Project Structure

```
mobile/
  convex-shared/             <- Shared SPM package (transpiled)
    Package.swift
    Sources/ConvexShared/
      Skip/skip.yml           mode: 'transpiled'
      ConvexService.swift     #if platform branching for Convex SDKs
      Models.swift            Codable data models (all 4 apps)
      AuthService.swift       @convex-dev/auth + WebAuthenticationSession
      AuthView.swift          Shared login/register UI (used by Blog, Chat, Org)
      FileService.swift       Convex file upload + image compression

  blog/                      <- Skip Lite app
    Package.swift             target "Blog", path: "Sources/Blog"
    Skip.env                  PRODUCT_NAME=Blog, ANDROID_PACKAGE_NAME=blog.module
    Sources/Blog/             {Module} subdirectory required by Skip Gradle
      Skip/skip.yml
      App.swift               RootView + AppDelegate + ContentView
      Detail.swift            DetailView + DetailViewModel
      Form.swift              FormMode + FormView + FormViewModel
      List.swift              CardView + ListView + ListViewModel
      Profile.swift           ProfileView + ProfileViewModel
      Resources/
    Tests/BlogTests/          {Module}Tests subdirectory required by Skip
      AppTests.swift
      XCSkipTests.swift
      Resources/
      Skip/
    Darwin/
      App.xcconfig            #include "../Skip.env"
      App.xcodeproj/
        xcshareddata/xcschemes/App.xcscheme
      Assets.xcassets/
      Sources/Main.swift
    Project.xcworkspace/
    Android/
      app/src/main/kotlin/Main.kt   package blog.module

  chat/                      <- same structure, target "Chat"
    Sources/Chat/
      App.swift               RootView + AppDelegate + ContentView
      List.swift              ListView + ListViewModel
      Message.swift           MessageBubble + MessageView + MessageViewModel
      Public.swift            PublicView
  movie/                     <- same structure, target "Movie"
    Sources/Movie/
      App.swift               RootView + AppDelegate + ContentView
      Detail.swift            FetchByIDView + DetailContent + DetailView + DetailViewModel
      Search.swift            ResultRow + SearchView + SearchViewModel
  org/                       <- same structure, target "Org"
    Sources/Org/
      App.swift               RootView + AppDelegate + ContentView
      Home.swift              Tab + HomeView
      Switcher.swift          RoleBadge + SwitcherView + SwitcherViewModel
      Settings.swift          SettingsView
      Onboarding.swift        OnboardingView
      Members.swift           MembersView + MembersViewModel
      Projects.swift          ProjectsView + ProjectsViewModel
      Tasks.swift             PriorityBadge + TasksView + TasksViewModel
      Wiki.swift              WikiListView + WikiListViewModel + WikiEditView
```

### Auth Strategy

The web apps use `@convex-dev/auth` with Google + Password providers. Mobile approach:

**Password auth:**

1. Collect email/password in native SwiftUI form
2. POST to `{CONVEX_URL}/api/auth/signin` with `{provider: "password", params: {email, password, flow: "signIn|signUp"}}`
3. Receive JWT token
4. Store in Keychain via SkipKeychain

**Google OAuth:**

1. Use `WebAuthenticationSession` (from SkipAuthenticationServices) to open Convex's Google OAuth initiation URL
2. User authenticates on Google → Convex creates/updates user → redirects with JWT
3. App captures JWT from callback URL scheme
4. Store in Keychain via SkipKeychain

Both flows: token passed to `ConvexClientWithAuth` for authenticated requests. On app launch, restore cached token from Keychain.

### Real-time Subscriptions

Both Convex SDKs support native WebSocket subscriptions (NO polling):

- iOS: `client.subscribe(to:with:yielding:)` returns `AnyPublisher<T, ClientError>`
- Android: `client.subscribe<T>(name, args)` returns `Flow<Result<T>>`

Exposed via `ConvexService.subscribe()` as callbacks, consumed by `@Observable` ViewModels.

### Pagination

Convex pagination uses cursor-based queries (`paginationOpts: {cursor, numItems}`). The mobile pattern:

1. ViewModel tracks pages as `[(cursor: String?, items: [T])]`
2. Initial load: subscribe with `cursor: null, numItems: 20`
3. "Load more": call query with `cursor: lastPage.continueCursor`
4. Append new page to array
5. Real-time updates come via subscription on the current page set

### AI Chat Strategy

Web Chat uses Next.js API route for AI streaming. Mobile approach:

- Create a Convex action using `generateText()` (non-streaming). Shows loading while AI thinks.
- Tool approval works with regular mutations: send message → get tool_use response → show approval UI → send approval → get final response.

### File Upload

1. Call mutation `"file:generateUploadUrl"` to get presigned URL
2. HTTP POST file data to that URL with `Content-Type` header
3. Receive storage ID string
4. Use storage ID in create/update mutations

Image compression: platform-native APIs via `#if os(Android)` branching.
Multi-file upload: loop through files, upload each sequentially, collect storage IDs.

### Photo Picker

Use SkipKit's `View.withMediaPicker(type:isPresented:selectedImageURL:)`:

- `.library` mode for photo library selection
- `.camera` mode for taking photos
- Returns selected image URL, which FileService then uploads

Requires camera/photo permissions in `AndroidManifest.xml` and iOS `.xcconfig`.

## Environment

Verified via `skip checkup`:

- Skip 1.7.2, macOS 26.3 (ARM), Swift 6.2.3, Xcode 26.2
- Gradle 9.3.1, Java 25.0.2, Android SDK 36.0.2, ADB 1.0.41
- iOS Simulators: iPhone 17 Pro (iOS 26.2)
- Android Emulator: Medium_Phone_API_36.1

## Convex Backend

Same Convex deployment as web demos:

- Deployment URL from `.env` → `NEXT_PUBLIC_CONVEX_URL`
- Auth: `@convex-dev/auth` (Password + Google)
- All endpoints documented in session research

## Dependencies (Skip Modules)

| Module | Purpose |
|--------|---------|
| SkipUI | SwiftUI → Compose transpilation (included by default) |
| SkipModel | @Observable support (included by default) |
| SkipKit | Photo/camera picker, permissions |
| SkipAuthenticationServices | WebAuthenticationSession for Google OAuth |
| SkipKeychain | Secure token storage (Keychain / EncryptedSharedPreferences) |

## Build Order

Sequential, ascending complexity. Each phase validates architecture.

- Phase 0: Shared infrastructure (ConvexShared package)
- Phase 1: Movie app (no auth, 2 screens — validates transpiled SDK chain)
- Phase 2: Blog app (auth + CRUD + file upload + pagination + search + profile)
- Phase 3: Chat app (child CRUD + public/private + AI + tool approval)
- Phase 4: Org app (multi-tenancy + ACL + soft delete + bulk ops + invites + onboarding)

---

## Tasks

### Phase 0: Shared Infrastructure (ConvexShared Package)

- [x] **0.1 — Scaffold ConvexShared SPM Package**

  Create `mobile/ConvexShared/` as an SPM library package. Set `skip.yml` to `mode: transpiled`. Add dependencies:
  - iOS (Package.swift, conditional platform): ConvexMobile Swift SDK (`https://github.com/get-convex/convex-swift`)
  - Android (skip.yml build.contents.dependencies): Convex Kotlin SDK (`dev.convex:android-convexmobile`)
  - Both: SkipKeychain (`https://source.skip.dev/skip-keychain.git`)
  - Both: SkipAuthenticationServices (`https://source.skip.dev/skip-authentication-services.git`)
  - Both: SkipKit (`https://source.skip.dev/skip-kit.git`)
  Verify `skip test` compiles the package for both platforms.

  Files: `mobile/ConvexShared/Package.swift`, `mobile/ConvexShared/Sources/ConvexShared/Skip/skip.yml`, `mobile/ConvexShared/Sources/ConvexShared/ConvexShared.swift`

  References:
  - SkipKeychain: `https://github.com/skiptools/skip-keychain`
  - SkipAuthenticationServices: `https://github.com/skiptools/skip-authentication-services`
  - SkipKit: `https://github.com/skiptools/skip-kit`
  - ConvexMobile Swift SDK: `https://github.com/get-convex/convex-swift`
  - Convex Kotlin SDK: `https://docs.convex.dev/client/android`

- [x] **0.2 — ConvexService: Platform-Branched Client Wrapper**

  Create `ConvexService.swift` inside ConvexShared. Use `#if !os(Android)` for ConvexMobile Swift SDK, `#if os(Android)` for Convex Kotlin SDK. Expose a unified API:
  - `subscribe<T>(name: String, args: [String: Any], type: T.Type, callback: @escaping (T) -> Void)`
  - `mutate(name: String, args: [String: Any]) async throws`
  - `call<T>(name: String, args: [String: Any], type: T.Type) async throws -> T` (for actions)
  - `paginatedQuery<T>(name: String, args: [String: Any], cursor: String?, numItems: Int, type: T.Type) async throws -> PaginatedResult<T>`

  iOS: wraps `ConvexClient`, converts `AnyPublisher` to callback via `sink`.
  Android: calls Kotlin `ConvexClient` directly (transpiled Swift IS Kotlin), converts `Flow` to callback.

  Convex deployment URL: read from `Skip.env` file (key `CONVEX_URL`).

  Files: `mobile/ConvexShared/Sources/ConvexShared/ConvexService.swift`

  References:
  - ConvexMobile Swift API: `client.subscribe(to:with:yielding:)`, `client.mutation(_:with:)`, `client.action(_:with:)`
  - Convex Kotlin API: `client.subscribe<T>(name, args)`, `client.mutation(name, args)`, `client.action(name, args)`
  - Function name format: colon-separated `"module:function_name"`

- [x] **0.3 — Data Models for All 4 Apps**

  Create `Models.swift` inside ConvexShared with Codable/Decodable structs matching every Convex document type. Source of truth: `packages/be/t.ts` (Zod schemas) and `packages/be/convex/schema.ts`.

  Models needed:
  - Shared: `PaginatedResult<T>` (page: [T], continueCursor: String, isDone: Bool), `Author` (name: String, imageUrl: String?)
  - Movie: `Movie` (tmdb_id, title, overview, poster_path, release_date, vote_average, runtime, tagline, genres, production_companies), `SearchResult`
  - Blog: `Blog` (title, content, category, published, coverImage, coverImageUrl, tags, attachments, userId, author, updatedAt, _creationTime), `BlogProfile` (displayName, bio, avatar, avatarUrl, theme, notifications)
  - Chat: `Chat` (title, isPublic, userId, author, updatedAt), `Message` (chatId, role, content, toolName, toolArgs, toolResult, isApproved, userId)
  - Org: `Org` (name, slug, userId, updatedAt), `OrgMember` (orgId, userId, isAdmin, updatedAt), `Project` (name, description, orgId, editors, updatedAt), `Task` (title, status, priority, projectId, orgId, updatedAt), `Wiki` (title, slug, content, orgId, editors, deletedAt, updatedAt), `OrgInvite` (orgId, email, token, expiresAt), `OrgJoinRequest` (orgId, userId, status), `OrgProfile` (displayName, avatar, avatarUrl, bio, notifications, theme)

  All ID fields: `String`. Optional fields: Swift optionals. Timestamps: `Double` (ms).

  Files: `mobile/ConvexShared/Sources/ConvexShared/Models.swift`

  References:
  - `packages/be/t.ts` — Zod schema definitions (field names, types, optionality)
  - `packages/be/convex/schema.ts` — Table definitions

- [x] **0.4 — AuthService: Password + Google OAuth**

  Create `AuthService.swift` inside ConvexShared as an `@Observable` class.

  **Password flow:**
  1. POST to `{CONVEX_URL}/api/auth/signin` with `{provider: "password", params: {email, password, flow: "signIn"}}` (or `flow: "signUp"`)
  2. Receive JWT token in response
  3. Store token in Keychain via SkipKeychain
  4. Pass token to ConvexService for authenticated requests

  **Google OAuth flow:**
  1. Use `WebAuthenticationSession` (from SkipAuthenticationServices) to open Convex's Google OAuth URL
  2. On iOS: `import AuthenticationServices`; on Android: `import SkipAuthenticationServices`
  3. User authenticates → Convex redirects to callback URL scheme (e.g., `dev.lazyconvex://auth`) with JWT
  4. Extract JWT from callback URL, store in Keychain

  **Shared:**
  - On app launch: `loginFromCache()` — restore token from Keychain, validate, set auth state
  - Expose: `signInWithPassword(email, password)`, `signUpWithPassword(email, password)`, `signInWithGoogle(session: WebAuthenticationSession)`, `signOut()`, `isAuthenticated: Bool`, `currentToken: String?`, `authState: AuthState` (loading/authenticated/unauthenticated)

  iOS: Use `ConvexClientWithAuth` with custom `AuthProvider`.
  Android: Use Kotlin `ConvexClientWithAuth` with equivalent `AuthProvider`.

  Files: `mobile/ConvexShared/Sources/ConvexShared/AuthService.swift`

  References:
  - `packages/be/convex/auth.ts` — Auth config (Password + Google providers)
  - SkipAuthenticationServices docs: `WebAuthenticationSession.authenticate(using:callback:preferredBrowserSession:)`
  - SkipKeychain: `https://github.com/skiptools/skip-keychain`
  - ConvexMobile `AuthProvider` protocol: `login(onIdToken:)`, `logout()`, `loginFromCache(onIdToken:)`, `extractIdToken(from:)`

- [x] **0.5 — Google OAuth Client IDs Setup**

  Configure Google Cloud Console for mobile OAuth:
  1. Use the SAME Google Cloud project as the web app's existing Google OAuth
  2. Create iOS OAuth client ID (type: iOS) for bundle IDs `dev.lazyconvex.blog`, `dev.lazyconvex.chat`, `dev.lazyconvex.org`
  3. Create Android OAuth client ID (type: Android) for the same package names
  4. Add callback URL scheme `dev.lazyconvex` to the allowed redirect URIs
  5. Store client IDs in each app's `Skip.env`
  6. For Android: add `<intent-filter>` in `AndroidManifest.xml` for the callback scheme (required by SkipAuthenticationServices fallback)

  Files: Google Cloud Console (external), `mobile/*/Skip.env`, `mobile/*/Android/app/src/main/AndroidManifest.xml`

  References:
  - `packages/be/convex/auth.ts` — Existing Google provider config
  - SkipAuthenticationServices setup: `https://skip.tools/docs/modules/skip-authentication-services/`

- [x] **0.6 — Shared AuthView (Login/Register + Google Sign-In)**

  Build `AuthView.swift` inside ConvexShared as a reusable SwiftUI view:
  - Tab toggle: Sign In / Sign Up
  - Email + Password fields with basic validation (non-empty, email format)
  - Submit button calling `AuthService.signInWithPassword` / `signUpWithPassword`
  - "Sign in with Google" button using `@Environment(\.webAuthenticationSession)` + `AuthService.signInWithGoogle()`
  - Error display (wrong password, email taken, network error, etc.)
  - Loading state during auth
  - Callback `onAuthenticated: () -> Void` for host app navigation

  Files: `mobile/ConvexShared/Sources/ConvexShared/AuthView.swift`

  References:
  - AuthService from Task 0.4
  - SkipAuthenticationServices `WebAuthenticationSession` usage pattern

- [x] **0.7 — File Upload Service**

  Create `FileService.swift` inside ConvexShared. Implements Convex file upload:
  1. `uploadFile(data: Data, contentType: String) async throws -> String` — returns storage ID
  2. `uploadImage(url: URL, maxSize: Int = 1920, quality: Double = 0.8) async throws -> String` — compress + upload
  3. `uploadFiles(urls: [URL]) async throws -> [String]` — batch upload for attachments

  Internal flow: call mutation `"file:generateUploadUrl"` → HTTP POST file data → return storage ID.

  Image compression:
  - `#if !os(Android)`: UIImage for JPEG compression (max dimension, quality)
  - `#if os(Android)`: Bitmap/BitmapFactory equivalent

  Files: `mobile/ConvexShared/Sources/ConvexShared/FileService.swift`

  References:
  - `packages/be/convex/file.ts` — File upload endpoint (generateUploadUrl mutation)
  - Convex storage docs: upload URL → POST → storage ID

### Phase 1: Movie App (No Auth, 2 Screens)

- [x] **1.1 — Scaffold Movie Skip Lite App**

  Run `skip init --appid=dev.lazyconvex.movie movie-app MovieApp` inside `mobile/`. Configure `Package.swift` to depend on ConvexShared. Create `Skip.env` with `CONVEX_URL`. Verify `skip test` compiles for both platforms.

  Files: `mobile/movie/` (entire scaffold), `mobile/movie/Package.swift`, `mobile/movie/Skip.env`

- [x] **1.2 — Movie Search Screen**

  Build `SearchView.swift` with:
  - Text input with `.searchable()` modifier for search query
  - Debounced search (500ms) calling `"movie:search"` action via ConvexService
  - Results list: poster image (TMDB CDN `https://image.tmdb.org/t/p/w500{poster_path}` via `AsyncImage`), title, release year, vote average
  - Tap navigates to detail screen with the movie's `tmdb_id`
  - Loading state (ProgressView) while search runs
  - Empty state when no results

  ViewModel: `MovieSearchViewModel` as `@Observable`. Calls `ConvexService.call("movie:search", ...)`.

  Files: `mobile/movie/Sources/MovieApp/SearchView.swift`, `mobile/movie/Sources/MovieApp/MovieSearchViewModel.swift`

  References:
  - `packages/be/convex/movie.ts` — `search` action (takes `query: string`, returns array)
  - `apps/movie/src/app/page.tsx` — Web search UI

- [x] **1.3 — Movie Detail/Fetch Screen**

  Build `DetailView.swift` with:
  - Receives `tmdb_id` from navigation
  - Calls `"movie:load"` action via ConvexService (fetches from cache or TMDB API)
  - Shows: full poster (AsyncImage), title, tagline, overview, release date, runtime, vote average, genres, production companies
  - Cache hit/miss badge (load returns `_creationTime` — compare to detect cache hit)
  - Loading state, error state

  ViewModel: `MovieDetailViewModel` as `@Observable`.

  Files: `mobile/movie/Sources/MovieApp/DetailView.swift`, `mobile/movie/Sources/MovieApp/MovieDetailViewModel.swift`

  References:
  - `packages/be/convex/movie.ts` — `load` action (takes `tmdb_id: number`, returns Movie)
  - `apps/movie/src/app/[id]/page.tsx` — Web detail UI

- [x] **1.4 — Movie App Navigation + Testing**

  Wire up `NavigationStack` with SearchView as root, DetailView as push destination. Test on both platforms:
  - Search "inception" → results appear with posters
  - Tap first result → detail screen with full movie info
  - Cache badge shows correctly
  - Back navigation works
  - AsyncImage loads TMDB posters on both platforms

  Files: `mobile/movie/Sources/MovieApp/MovieAppApp.swift`

  Verification:
  - `skip test` passes
  - App launches on iOS Simulator (iPhone 17 Pro)
  - App launches on Android Emulator (Medium_Phone_API_36.1)
  - Search returns results on both platforms
  - Detail view shows poster on both platforms

### Phase 2: Blog App (Auth + CRUD + File Upload + Search)

- [x] **2.1 — Scaffold Blog Skip Lite App**

  Run `skip init --appid=dev.lazyconvex.blog blog-app BlogApp` inside `mobile/`. Configure `Package.swift` to depend on ConvexShared. Create `Skip.env` with `CONVEX_URL` and Google OAuth client IDs. Add camera/photo permissions to `AndroidManifest.xml` and iOS `.xcconfig`. Verify `skip test` compiles.

  Files: `mobile/blog/` (scaffold), `mobile/blog/Package.swift`, `mobile/blog/Skip.env`, Android manifest, iOS xcconfig

  References:
  - SkipKit camera/media permissions setup: `https://skip.tools/docs/modules/skip-kit/`

- [x] **2.2 — Blog List Screen**

  Build `BlogListView.swift` with:
  - Subscribe to `"blog:list"` with `where: {published: true}` for public view
  - When authenticated, segmented control to toggle: Published / My Drafts (`where: {own: true, published: false}`)
  - Each item: title, category badge, author name, creation date, cover image thumbnail (AsyncImage)
  - Cursor-based pagination: "Load More" button at bottom (uses ConvexService.paginatedQuery)
  - Pull-to-refresh
  - `.searchable()` modifier → calls `"blog:search"` action for full-text search
  - Tap navigates to detail screen
  - Toolbar button to create new post (auth required)

  ViewModel: `BlogListViewModel` using ConvexService.subscribe for real-time + pagination tracking.

  Files: `mobile/blog/Sources/BlogApp/BlogListView.swift`, `mobile/blog/Sources/BlogApp/BlogListViewModel.swift`

  References:
  - `packages/be/convex/blog.ts` — `list` query (paginated, supports `where`), `search` action
  - `apps/blog/src/app/page.tsx` — Web list UI

- [x] **2.3 — Blog Detail Screen**

  Build `BlogDetailView.swift` with:
  - Subscribe to `"blog:read"` with blog ID for real-time updates
  - Shows: title, content, category, author with avatar (AsyncImage), creation date, cover image (full), tags as chips, attachments as downloadable links
  - If own post: Edit and Delete buttons in toolbar
  - Delete with confirmation alert (`.confirmationDialog`)

  Files: `mobile/blog/Sources/BlogApp/BlogDetailView.swift`, `mobile/blog/Sources/BlogApp/BlogDetailViewModel.swift`

  References:
  - `packages/be/convex/blog.ts` — `read` query, `rm` mutation
  - `apps/blog/src/app/[blogId]/page.tsx` — Web detail UI

- [x] **2.4 — Blog Create/Edit Form**

  Build `BlogFormView.swift` with:
  - Fields: title (TextField), content (TextEditor multiline), category (Picker: tech/life/tutorial), published (Toggle), cover image (SkipKit `.withMediaPicker` → FileService.uploadImage), tags (dynamic list with add/remove), attachments (SkipKit `.withMediaPicker` for each, multiple selections → FileService.uploadFiles)
  - Create mode: calls `"blog:create"` mutation
  - Edit mode: pre-fills from existing blog, calls `"blog:update"` mutation with `expectedUpdatedAt` for conflict detection
  - Auto-save with 2-second debounce in edit mode (visual indicator: "Saving..." / "Saved")
  - Validation: title required (min 1 char), content required (min 3 chars)

  Files: `mobile/blog/Sources/BlogApp/BlogFormView.swift`, `mobile/blog/Sources/BlogApp/BlogFormViewModel.swift`

  References:
  - `packages/be/convex/blog.ts` — `create`, `update` mutations
  - `apps/blog/src/app/common.tsx` — Web create form
  - `apps/blog/src/app/[blogId]/edit/page.tsx` — Web edit form with auto-save
  - SkipKit `.withMediaPicker()` for photo selection

- [x] **2.5 — Blog Profile Screen**

  Build `ProfileView.swift` with:
  - Subscribe to `"blogProfile:get"` for current profile
  - Edit form: displayName (TextField), bio (TextEditor), avatar (SkipKit `.withMediaPicker` → FileService.uploadImage), theme (Picker: light/dark/system), notifications (Toggle)
  - Calls `"blogProfile:upsert"` mutation (creates on first use, partial-updates after)

  Files: `mobile/blog/Sources/BlogApp/ProfileView.swift`, `mobile/blog/Sources/BlogApp/ProfileViewModel.swift`

  References:
  - `packages/be/convex/blogProfile.ts` — `get`, `upsert` endpoints
  - `apps/blog/src/app/profile/page.tsx` — Web profile UI

- [x] **2.6 — Blog App Navigation + Auth Flow + Testing**

  Wire up full navigation:
  - If not authenticated → AuthView (from ConvexShared)
  - If authenticated → TabView with Blog List and Profile tabs
  - Blog List → Blog Detail (push) → Blog Edit (push)
  - Create button → Blog Form (sheet)

  Test on both platforms:
  - Sign up with email/password → lands on blog list
  - Sign in with Google → lands on blog list
  - Create post with cover image → appears in list (real-time)
  - Edit post → auto-saves, conflict detection works
  - Delete post → removed from list
  - Search "test" → filtered results
  - Profile: update displayName + avatar → reflected immediately
  - Sign out → back to auth screen
  - Real-time: create post via web app → appears in mobile list within 2 seconds

  Files: `mobile/blog/Sources/BlogApp/BlogAppApp.swift`

### Phase 3: Chat App (Child CRUD + AI + Public/Private)

- [x] **3.1 — Scaffold Chat Skip Lite App**

  Run `skip init --appid=dev.lazyconvex.chat chat-app ChatApp` inside `mobile/`. Configure `Package.swift` to depend on ConvexShared. Create `Skip.env` with `CONVEX_URL` and Google OAuth client IDs. Verify `skip test` compiles.

  Files: `mobile/chat/` (scaffold), `mobile/chat/Package.swift`, `mobile/chat/Skip.env`

- [x] **3.2 — Non-Streaming AI Action (Backend)**

  Create a new Convex action in the backend that uses `generateText()` instead of streaming. Needed because mobile can't consume the Next.js streaming API route.

  The action:
  1. Accept `{chatId}` — fetches conversation history from messages table
  2. Call Google Vertex `gemini-3-flash-preview` with `generateText()`
  3. Support the weather tool with `needsApproval: true`
  4. If tool call: save tool_use message via internal mutation, return it
  5. If text: save assistant message via internal mutation, return it

  Files: `packages/be/convex/mobileAi.ts` (new file — keep separate from web streaming route)

  References:
  - `packages/be/ai.ts` — AI model config (Google Vertex, gemini-3-flash-preview)
  - `apps/chat/src/app/api/chat/route.ts` — Web streaming route (adapt logic to non-streaming)
  - Tool definitions: weather tool with `needsApproval`
  - IMPORTANT: follow existing code style from AGENTS.md (arrow functions, exports at end, no comments)

- [x] **3.3 — Chat Sidebar (Chat List)**

  Build `ChatSidebarView.swift` with:
  - Subscribe to `"chat:list"` for own chats (authenticated)
  - Each item: title (or "Untitled"), last updated time, isPublic badge
  - Create new chat button (calls `"chat:create"` with default title)
  - Delete chat with swipe action (`.swipeActions`) + confirmation alert
  - Tap selects chat → shows messages

  Files: `mobile/chat/Sources/ChatApp/ChatSidebarView.swift`, `mobile/chat/Sources/ChatApp/ChatListViewModel.swift`

  References:
  - `packages/be/convex/chat.ts` — `list`, `create`, `rm` endpoints
  - `apps/chat/src/app/common.tsx` — Web sidebar UI

- [x] **3.4 — Chat Message View (with AI)**

  Build `ChatMessageView.swift` with:
  - Subscribe to `"message:list"` (authenticated) or `"message:pubList"` (public) with chatId
  - Message bubbles: user (trailing alignment), AI (leading alignment), styled differently
  - For tool_use messages: show tool name + args in a card, Approve/Reject buttons
  - Tool approval: calls `"message:update"` with `isApproved: true/false`, then calls the AI action again (Task 3.2)
  - Text input at bottom with send button
  - Send: calls `"message:create"` with `role: "user"`, then calls AI action
  - Loading indicator while AI is generating (ProgressView)
  - ScrollViewReader with `.scrollTo()` for auto-scroll to bottom on new messages
  - Pagination: "Load earlier messages" button at top

  Files: `mobile/chat/Sources/ChatApp/ChatMessageView.swift`, `mobile/chat/Sources/ChatApp/ChatMessageViewModel.swift`

  References:
  - `packages/be/convex/message.ts` — `list`, `pubList`, `create`, `update`
  - `apps/chat/src/app/[chatId]/page.tsx` — Web message UI, tool approval flow

- [x] **3.5 — Public Chat Access**

  Build `PublicChatView.swift` — read-only view of public chats:
  - No auth required
  - Uses `"chat:pubRead"` and `"message:pubList"` endpoints
  - Shows messages but no send input, no tool approval buttons
  - Accessible via in-app navigation (e.g., "Browse Public Chats" on unauthenticated home)

  Files: `mobile/chat/Sources/ChatApp/PublicChatView.swift`

  References:
  - `packages/be/convex/chat.ts` — `pubRead` query
  - `packages/be/convex/message.ts` — `pubList` query

- [x] **3.6 — Chat App Navigation + Testing**

  Wire up navigation:
  - If not authenticated → AuthView (from ConvexShared), with "Browse Public Chats" link
  - If authenticated → NavigationSplitView: ChatSidebar | ChatMessageView
  - Public chat route accessible without auth

  Test on both platforms:
  - Sign in → see chat list
  - Create new chat → appears in list
  - Send message → AI responds (non-streaming, loading indicator shown)
  - Tool approval: send "what's the weather?" → tool_use appears → approve → get result
  - Delete chat → removed, messages cascade deleted
  - Public chat: toggle isPublic → viewable without auth via public chat browser
  - Real-time: send message via web → appears in mobile within 2 seconds

  Files: `mobile/chat/Sources/ChatApp/ChatAppApp.swift`

### Phase 4: Org App (Multi-Tenancy + ACL + Full Features)

- [x] **4.1 — Scaffold Org Skip Lite App**

  Run `skip init --appid=dev.lazyconvex.org org-app OrgApp` inside `mobile/`. Configure `Package.swift` to depend on ConvexShared. Create `Skip.env` with `CONVEX_URL` and Google OAuth client IDs. Add camera/photo permissions for avatar uploads. Verify `skip test` compiles.

  Files: `mobile/org/` (scaffold), `mobile/org/Package.swift`, `mobile/org/Skip.env`

- [x] **4.2 — Onboarding Wizard (4-Step Form)**

  Build `OnboardingView.swift` with 4 steps:
  1. Profile: displayName (TextField), avatar (SkipKit `.withMediaPicker` → upload), bio (TextEditor)
  2. Organization: name (TextField), slug (TextField with async validation via `"org:isSlugAvailable"` pattern if available, or check on submit)
  3. Appearance: theme Picker (light/dark/system)
  4. Preferences: notifications Toggle

  Step indicators (HStack of circles), back/next navigation, validation per step.
  On submit: call `"orgProfile:upsert"` + `"org:create"`.
  Use `@State var currentStep: Int` for step tracking.

  Files: `mobile/org/Sources/OrgApp/OnboardingView.swift`, `mobile/org/Sources/OrgApp/OnboardingViewModel.swift`

  References:
  - `apps/org/src/app/onboarding/page.tsx` — Web 4-step wizard
  - `packages/be/convex/orgProfile.ts` — `upsert`
  - `packages/be/convex/org.ts` — `create`

- [x] **4.3 — Org Switcher + Home Screen**

  Build `OrgSwitcherView.swift`:
  - Call `"org:myOrgs"` to list user's organizations
  - Each item: org name, role badge (owner/admin/member styled differently), member count
  - Tap selects active org → navigates to org home
  - "Create New Org" button (simple form: name + slug)

  Build `OrgHomeView.swift`:
  - TabView: Projects, Wiki, Members, Settings
  - Header shows active org name and user's role badge
  - `@Observable OrgContext` holds active org + membership + role, passed via `.environment()`

  Files: `mobile/org/Sources/OrgApp/OrgSwitcherView.swift`, `mobile/org/Sources/OrgApp/OrgHomeView.swift`, `mobile/org/Sources/OrgApp/OrgViewModel.swift`

  References:
  - `packages/be/convex/org.ts` — `myOrgs`, `get`, `membership`
  - `apps/org/src/app/org-switcher.tsx` — Web org switcher

- [x] **4.4 — Projects + Tasks (Cascade CRUD)**

  Build `ProjectsView.swift`:
  - Subscribe `"project:list"` with orgId
  - Create project form (sheet: name, description)
  - Edit project (navigation push to edit form)
  - Delete project with cascade warning alert: "This will also delete all tasks"
  - ACL: only show edit/delete buttons for owner/admin/editors

  Build `TasksView.swift`:
  - Subscribe `"task:list"` filtered by projectId
  - Create task (inline: title TextField + submit)
  - Edit task: tap to push to edit form (title, status Picker [todo/in-progress/done], priority Picker [low/medium/high])
  - Delete task (swipe action)
  - Bulk operations: `EditButton` for multi-select → toolbar buttons for bulk delete, bulk status update
  - ACL inherited from parent project

  Files: `mobile/org/Sources/OrgApp/ProjectsView.swift`, `mobile/org/Sources/OrgApp/ProjectViewModel.swift`, `mobile/org/Sources/OrgApp/TasksView.swift`, `mobile/org/Sources/OrgApp/TaskViewModel.swift`

  References:
  - `packages/be/convex/project.ts` — CRUD with cascade to tasks
  - `packages/be/convex/task.ts` — CRUD + `bulkRm`, `bulkUpdate`
  - `apps/org/src/app/project/` — Web project/task UI

- [x] **4.5 — Wiki (Soft Delete + ACL + Auto-Save)**

  Build `WikiListView.swift`:
  - Subscribe `"wiki:list"` for active org
  - Each item: title, slug, last editor, updated time
  - Soft delete: swipe to delete → snackbar/toast with "Undo" (call `"wiki:rm"`, undo calls `"wiki:restore"`)
  - Bulk delete: `EditButton` for multi-select → bulk delete button
  - Section: "Recently Deleted" showing soft-deleted pages (subscribe `"wiki:listDeleted"`) with restore button

  Build `WikiEditView.swift`:
  - Title (TextField), slug (TextField with async uniqueness check), content (TextEditor)
  - Auto-save with 2s debounce + indicator ("Saving..." / "Saved" / "Error")
  - Conflict detection with `expectedUpdatedAt`
  - Editors section (if user is owner/admin): list editors, add/remove via `"wiki:addEditor"` / `"wiki:removeEditor"`

  Files: `mobile/org/Sources/OrgApp/WikiListView.swift`, `mobile/org/Sources/OrgApp/WikiViewModel.swift`, `mobile/org/Sources/OrgApp/WikiEditView.swift`

  References:
  - `packages/be/convex/wiki.ts` — full API: list, create, update, rm, restore, bulkRm, addEditor, removeEditor, setEditors, listDeleted, isSlugAvailable
  - `apps/org/src/app/wiki/` — Web wiki UI
  - `apps/org/src/app/wiki/[wikiId]/edit/page.tsx` — Auto-save + editors

- [x] **4.6 — Members Management**

  Build `MembersView.swift`:
  - Subscribe `"org:members"` for active org
  - Each member: name, email, role badge, join date
  - Admin actions (contextMenu or swipe): promote to admin (`"org:setAdmin"` isAdmin=true), demote (`setAdmin` isAdmin=false), remove member (`"org:removeMember"`)
  - Owner action: transfer ownership (`"org:transferOwnership"`) with confirmation

  Build `InviteView.swift` (sheet from Members):
  - Invite by email: TextField + send button → `"org:invite"`
  - Pending invites list: email, expiry, revoke button (`"org:revokeInvite"`)
  - Pending join requests list: user name, approve/reject buttons (`"org:approveJoinRequest"` / `"org:rejectJoinRequest"`)

  Files: `mobile/org/Sources/OrgApp/MembersView.swift`, `mobile/org/Sources/OrgApp/MembersViewModel.swift`, `mobile/org/Sources/OrgApp/InviteView.swift`

  References:
  - `packages/be/convex/org.ts` — members, setAdmin, removeMember, leave, transferOwnership, invite, acceptInvite, revokeInvite, requestJoin, approveJoinRequest, rejectJoinRequest, pendingInvites, pendingJoinRequests
  - `apps/org/src/app/members/page.tsx` — Web members UI

- [x] **4.7 — Org Settings**

  Build `OrgSettingsView.swift`:
  - Edit org: name (TextField), slug (TextField) → `"org:update"`
  - Danger zone section (red-tinted):
    - Leave org: button → confirmation → `"org:leave"` → navigate back to org switcher
    - Delete org (owner only): button → double confirmation ("Type org name to confirm") → `"org:remove"` → navigate to org switcher
    - Transfer ownership (owner only): member picker → confirmation → `"org:transferOwnership"`

  Files: `mobile/org/Sources/OrgApp/OrgSettingsView.swift`

  References:
  - `packages/be/convex/org.ts` — `update`, `remove`, `leave`, `transferOwnership`
  - `apps/org/src/app/settings/page.tsx` — Web settings UI

- [x] **4.8 — Org App Navigation + Full Testing**

  Wire up full navigation:
  - If not authenticated → AuthView (from ConvexShared)
  - If authenticated but no orgs → OnboardingView
  - If authenticated with orgs → OrgSwitcherView → OrgHomeView (TabView)
  - Projects tab → Project detail (push) → Tasks
  - Wiki tab → Wiki list → Wiki edit (push)
  - Members tab → Members list; Invite (sheet)
  - Settings tab → Org settings

  Test on both platforms:
  - Full onboarding: sign up → 4-step wizard → org created
  - Google sign in works
  - Org switching works
  - Projects: create → add tasks → bulk update status → delete project (tasks cascade deleted)
  - Wiki: create → auto-save edits → soft delete → undo restore → permanent delete from trash
  - ACL: add editor to wiki → editor can edit, non-editor cannot
  - Members: invite by email → accept invite (via another account) → new member appears in list
  - Settings: rename org, transfer ownership, leave org
  - Real-time: all data changes sync between web and mobile within 2 seconds

  Files: `mobile/org/Sources/OrgApp/OrgAppApp.swift`

---

## Final Verification

After all apps are built:

- [x] All 4 apps build and launch on iOS Simulator (iPhone 17 Pro)
- [x] All 4 apps build and launch on Android Emulator (Medium_Phone_API_36.1)
- [x] Movie: search "inception" returns results; fetch ID 27205 shows detail with cache badge
- [x] Blog: login → create post → see in list → edit → delete; search works; profile works
- [x] Chat: login → create chat → send message → get AI response; public chat viewable without auth
- [x] Org: onboarding → create org → add project → add tasks → wiki → invite member
- [x] Real-time: create data via web app → appears in mobile within 2 seconds
- [x] Auth (password): sign up with email/password → authenticated API call → user-specific data returned
- [ ] Auth (Google): sign in with Google → requires Google Cloud Console setup (code complete)
- [x] File upload: pick photo from library → upload as blog cover → visible in detail view

## Success Criteria

- 4 native apps running on both iOS and Android
- Feature parity with web demos (core features, not pixel-perfect UI)
- All apps connect to the same Convex backend
- Real-time subscriptions working (not polling)
- Auth working (both email/password AND Google OAuth on both platforms)
- File upload working (Blog covers, avatars)
- Photo picker working (SkipKit) on both platforms

---

# Swift Core: Shared Foundation-Only Package

## Why

Mobile (`convex-shared`) is tied to Skip + SwiftUI + ConvexMobile — desktop can't depend on it.
But Models, Error types, HTTP auth/file helpers are pure Foundation. Extract once, share everywhere.

## Architecture

```
swift-core/                           <- NEW: Foundation-only, zero external deps
  Package.swift
  Sources/ConvexCore/
    Models.swift                       All Codable structs (canonical source)
    Error.swift                        ConvexError enum + URL constants
    HTTP.swift                         Pure HTTP helpers extracted from mobile:
                                         passwordAuth, startOAuth, finishOAuth,
                                         extractOAuthCode, postFile, guessContentType
    Format.swift                       formatTimestamp (from SharedUI.swift)
  Tests/ConvexCoreTests/
```

## How Mobile Uses It (Symlinks, Not Dependencies)

Skip transpiles Swift → Kotlin. It can only transpile files inside Skip-processed targets.
If mobile depended on swift-core as a package, Skip wouldn't transpile ConvexCore types → Android breaks.

**Solution**: Symlink shared files into ConvexShared. Skip processes symlinked files in-place.
Mobile never adds swift-core as an SPM dependency — just filesystem symlinks.

```
mobile/convex-shared/Sources/ConvexShared/
  Models.swift          -> symlink ../../swift-core/Sources/ConvexCore/Models.swift
  Error.swift           -> symlink ../../swift-core/Sources/ConvexCore/Error.swift
  HTTP.swift            -> symlink ../../swift-core/Sources/ConvexCore/HTTP.swift
  Format.swift          -> symlink ../../swift-core/Sources/ConvexCore/Format.swift
  ConvexService.swift    (unchanged — ConvexMobile wrapper)
  AuthService.swift      (refactored — calls HTTP.swift helpers instead of private methods)
  FileService.swift      (refactored — calls HTTP.swift helpers instead of private methods)
  AuthView.swift         (unchanged — SwiftUI)
  SharedUI.swift         (formatTimestamp removed — now in Format.swift)
  ConvexShared.swift     (unchanged)
  Skip/
```

When compiled:
- **iOS/macOS**: symlinked files compile as part of ConvexShared module. `#if !SKIP` paths taken.
- **Android**: Skip transpiles symlinked files to Kotlin. `#if SKIP` paths taken.
- **Desktop**: imports ConvexCore module directly from swift-core package.

One canonical source file per shared type. Zero duplication.

## Refactoring Required (Mobile)

1. Extract `performPasswordAuth`, `startOAuth`, `finishOAuth`, `extractCode` from AuthService.swift → HTTP.swift
2. Extract `postFile`, `guessContentType` from FileService.swift → HTTP.swift
3. Extract `formatTimestamp` from SharedUI.swift → Format.swift
4. Replace originals with symlinks: rm files, ln -s to swift-core
5. Verify mobile still builds: all 4 apps with SKIP_ACTION=build

---

# LazyConvex Desktop: 4 Cross-Platform Desktop Apps

## Goal

4 native desktop apps (Movie, Blog, Chat, Org) using [SwiftCrossUI](https://github.com/moreSwift/swift-cross-ui).
Same Convex backend. Target macOS (AppKit) + Linux (GTK).

## SwiftCrossUI (not SwiftUI)

```swift
import SwiftCrossUI
import DefaultBackend   // AppKit (macOS), GTK (Linux), WinUI (Windows)
```

| SwiftUI (Mobile) | SwiftCrossUI (Desktop) |
|----|-----|
| `@Observable` | `@Observed` class (protocol, not macro) |
| TabView | NavigationSplitView sidebar |
| AsyncImage | Custom URLSession + Image |
| .sheet() | NavigationStack push / overlay |
| .searchable() | TextField + manual filter |
| .swipeActions() | Context menu / buttons |
| .withMediaPicker() | NSOpenPanel / GTK file dialog |

**Available**: HStack, VStack, ScrollView, NavigationStack, NavigationSplitView, NavigationLink,
Button, TextField, TextEditor, Toggle, Picker, Slider, Checkbox, DatePicker, Menu,
Text, Image, ProgressView, List, ForEach, Table, @State, @Binding, @Environment, @Observed

## Convex Client: Pure HTTP + WebSocket

ConvexMobile SDK = iOS xcframework. Convex Kotlin SDK = Android. Neither works on desktop.
Desktop needs a **pure Swift client** using Foundation:

- **HTTP API**: `POST {CONVEX_URL}/api/query`, `/api/mutation`, `/api/action`
- **WebSocket**: Convex sync protocol for real-time subscriptions
- **URLSession**: all networking (available on all Swift platforms)

Auth HTTP helpers (password, OAuth start/finish) come from **ConvexCore** — no duplication.
File upload HTTP helpers (postFile, guessContentType) come from **ConvexCore** — no duplication.

## Auth Strategy (Desktop)

**Password**: ConvexCore.passwordAuth() → store token in macOS Keychain / Linux libsecret
**Google OAuth**: system browser → Google → redirect to localhost callback → capture JWT

## Project Structure

```
swift-core/                           <- Shared Foundation-only package
  Package.swift
  Sources/ConvexCore/
    Models.swift                       All Codable structs (canonical source)
    Error.swift                        ConvexError enum + URL constants
    HTTP.swift                         Pure HTTP helpers (auth, file upload)
    Format.swift                       formatTimestamp
  Tests/ConvexCoreTests/

desktop/
  shared/                              <- Desktop-specific Convex client
    Package.swift                       depends on swift-core
    Sources/DesktopShared/
      ConvexClient.swift                HTTP queries/mutations/actions
      ConvexSubscription.swift          WebSocket real-time subscriptions
      AuthClient.swift                  ConvexCore.HTTP + macOS Keychain + browser OAuth
      FileClient.swift                  ConvexCore.HTTP + NSImage compression
    Tests/DesktopSharedTests/           Integration tests

  blog/                                <- Blog desktop app
    Package.swift                       depends on desktop/shared + SwiftCrossUI
    project.yml                         xcodegen spec (generates .xcodeproj for XCUITest)
    Sources/
      App.swift                         @main, WindowGroup, globals
      Auth.swift                        AuthView (sign in/up form)
      List.swift                        Blog list + search
      Detail.swift                      Blog detail view
      Form.swift                        Create/edit form
      Profile.swift                     User profile
    Tests/
      BlogTests.swift                   Unit tests (swift-testing)
    UITests/
      BlogUITests.swift                 XCUITest E2E tests

  chat/                                <- same structure
    Sources/
      App.swift, Auth.swift, List.swift, Message.swift
    UITests/ChatUITests.swift

  movie/                               <- same structure (no auth)
    Sources/
      App.swift, Search.swift, Detail.swift
    UITests/MovieUITests.swift

  org/                                 <- same structure
    Sources/
      App.swift (includes AuthView, onboarding, org switcher, home)
      Projects.swift, Wiki.swift, Members.swift, Settings.swift
    UITests/OrgUITests.swift
```

## E2E Testing: XCUITest via xcodegen

Each desktop app has a `project.yml` (xcodegen spec) that generates `.xcodeproj` with a UI test target.
Generated `.xcodeproj` files are gitignored — regenerated before each test run.

**Key discovery**: SwiftCrossUI apps render via AppKit. XCUITest finds elements by their text content, NOT accessibility identifiers:
- `app.textFields["Search movies..."]` — matches by placeholder text
- `app.buttons["Search"]` — matches by button title
- `app.staticTexts["Sign In"]` — matches by text value
- `app.windows.firstMatch.waitForExistence(timeout: 5)` — for launch test

**Generate + Run E2E:**
```bash
xcodegen generate --spec desktop/movie/project.yml --project desktop/movie
xcodebuild test \
  -project desktop/movie/MovieDesktop.xcodeproj \
  -scheme MovieUITests \
  -destination 'platform=macOS' \
  -skipMacroValidation -quiet
```

**Test results (141/141 passing):**
- Movie: 20 tests — launch, search field/button, empty state, results display, result count, detail navigation, movie info fields, back navigation, multiple searches, poster images, genres, production companies, vote average, search debounce, loading states
- Blog: 46 tests — auth (sign in/up toggle, fields, error handling, sign out, session restore), CRUD (create post, list display, detail fields, edit form, delete), search (filter, clear, no results, case insensitive), profile (fields, update), published toggle, category display, tag display, pagination
- Chat: 34 tests — auth (sign in/up toggle, fields, error handling, sign out, session restore), chat list (create, display, select, delete), messages (send, display, AI response, timestamps, empty state), public/private label, multiple chats, navigation
- Org: 41 tests — auth (sign in/up toggle, fields, error handling, sign out, session restore), onboarding (multi-step navigation, field display, data preservation), org management (create, switch, display), projects (create, list, delete), tasks (create, toggle, delete), wiki (create, edit, display), members (list, roles), settings (fields, display)

## Build & Run

```bash
swift build --package-path desktop/blog
swift run --package-path desktop/blog Blog
swift test --package-path swift-core                          # unit tests (18 passing)
swift test --package-path desktop/shared                      # integration tests (10 passing)
```

## Known Limitations

- **No SecureField**: SwiftCrossUI does not have `SecureField`. Password fields use plain `TextField` — password is visible as plaintext. `TextContentType` enum has no `.password` case either.
- **No Form, Sheet, TabView, Picker.segmented, TextEditor**: Use VStack+TextField alternatives
- **Image requires file URL**: No AsyncImage — must download to disk first via ImageCache
- **First build ~760 targets, 2-6 minutes**: Cached builds ~5s
- **ObservableObject/Published conflicts**: Must qualify as `SwiftCrossUI.ObservableObject` / `@SwiftCrossUI.Published`

## CI

Add `swift-core` + `desktop` path filters. swift-core changes trigger BOTH mobile and desktop CI.

| Job | Trigger | Runner | Depends On |
|----|----|----|-----|
| `build-desktop` | desktop or swift-core changed | `macos-latest` | changes |
| `test-desktop` | same | `macos-latest` | build-desktop |
| `e2e-desktop` | same | `macos-latest` | build-desktop |
| (existing) `build-swift` | swift or swift-core changed | `macos-latest` | lint-swift |

**test-desktop**: `swift test` on swift-core + desktop/shared (unit + integration)
**e2e-desktop**: `xcodebuild test` on all 4 apps (XCUITest, matrix: blog/chat/movie/org)

Desktop Swift files covered by existing `lint-swift` job (add `desktop/**` + `swift-core/**` to swift path filter).

## Tasks

### Phase 0: Swift Core + Shared Infrastructure

 [x] **D0.1** Create `swift-core/` SPM package (Package.swift, Sources/ConvexCore/, Tests/)
 [x] **D0.2** Move Models.swift → swift-core, create symlink in mobile/convex-shared
 [x] **D0.3** Move ConvexError enum + URL constants → swift-core/Error.swift, symlink in mobile
 [x] **D0.4** Extract HTTP helpers from AuthService + FileService → swift-core/HTTP.swift, symlink in mobile
 [x] **D0.5** Extract formatTimestamp → swift-core/Format.swift, symlink in mobile
 [x] **D0.6** Verify mobile still builds: all 4 apps with SKIP_ACTION=build
 [x] **D0.7** Scaffold desktop/shared (depends on swift-core + SwiftCrossUI)
 [x] **D0.8** Desktop ConvexClient: HTTP queries/mutations/actions via URLSession
 [x] **D0.9** Desktop ConvexSubscription: WebSocket real-time via URLSessionWebSocketTask
 [x] **D0.10** Desktop AuthClient: ConvexCore.HTTP helpers + macOS Keychain + browser OAuth
 [x] **D0.11** Desktop FileClient: ConvexCore.HTTP helpers + NSImage compression

#### D0.T: swift-core + desktop/shared Tests

**swift-core unit tests** (no network, mock data):
 Model decoding: every struct from JSON (valid, missing optional fields, malformed)
 PaginatedResult<T> decode: page array, cursor, isDone
 ConvexError enum cases
 HTTP request construction: passwordAuth builds correct POST body + headers
 OAuth flow: startOAuth request body, finishOAuth request body, extractOAuthCode from URL
 File upload: postFile request construction, guessContentType for all extensions
 formatTimestamp: various timestamps, date styles
 Edge cases: empty arrays, null fields, zero timestamps

**desktop/shared integration tests** (requires running Convex):
 ConvexClient: query returns data, mutation succeeds, action succeeds
 ConvexClient: error handling (invalid function name, wrong args, network timeout)
 ConvexSubscription: connect, receive initial data, receive update after mutation, reconnect after disconnect
 AuthClient: sign up new user, sign in existing, sign out clears token, restore from cache
 AuthClient: error handling (wrong password, duplicate email, invalid token)
 FileClient: upload file returns storage ID, upload image with compression
 FileClient: error handling (invalid upload URL, oversized file)

### Phase 1: Movie App (No Auth, 2 Screens)

 [x] **D1.1** Scaffold movie desktop app (depends on desktop/shared + SwiftCrossUI)
 [x] **D1.2** Search: TextField + debounce, List results, NavigationLink to detail
 [x] **D1.3** Detail: movie:load action, poster image via URLSession + ImageCache
 [x] **D1.4** Navigation: search → detail → back to search
 [x] **D1.5** Create project.yml (xcodegen spec) with UI test target
 [x] **D1.6** Write XCUITest E2E tests (20 tests: launch, search, results, detail, navigation, poster images, genres, production companies, vote average, debounce, loading states, multiple searches)
 [x] **D1.7** Verify `xcodebuild test` passes for movie E2E (20/20)

#### D1.T: Movie Tests

 Search returns results for valid query ("Inception" → ≥1 result)
 Search shows multiple results for broad query ("Batman" → >1)
 Search shows empty state for gibberish query
 Movie detail loads by TMDB ID (27205 → Inception)
 Cache hit/miss detection: first fetch = miss, second fetch = hit
 Loading state visible during fetch
 Error state for invalid ID (0) and non-existent movie (999999999)
 Navigation: search → tap result → detail → back → search preserved
 Debounce: rapid typing doesn't fire multiple requests

### Phase 2: Blog App (Auth + CRUD + File Upload)

 [x] **D2.1** Scaffold blog desktop app
 [x] **D2.2** Auth view: sign in/up form (password visible — SwiftCrossUI has no SecureField)
 [x] **D2.3** Blog list: subscribe blog:list, search, create button
 [x] **D2.4** Blog detail: subscribe blog:read, edit/delete if own
 [x] **D2.5** Create/edit form: fields, file picker, auto-save, conflict detection
 [x] **D2.6** Profile: subscribe blogProfile:get, upsert
 [x] **D2.7** Navigation (NavigationSplitView)
 [x] **D2.8** Create project.yml (xcodegen spec) with UI test target
 [x] **D2.9** Write XCUITest E2E tests (46 tests: auth flow, CRUD create/read/update/delete, search, profile, published toggle, categories, tags, pagination)
 [x] **D2.10** Verify `xcodebuild test` passes for blog E2E (46/46)

#### D2.T: Blog Tests

**Auth:**
 Sign up with new email → authenticated state
 Sign in with existing email/password → authenticated
 Sign in with wrong password → error shown
 Sign out → unauthenticated, token cleared
 App launch restores cached auth token

**CRUD Create:**
 Create blog with title + content → appears in list
 Form validates required fields (empty title rejected)
 Category picker works (tech/life/tutorial)
 Created blog visible in real-time (subscription update)

**CRUD Read:**
 Blog list shows existing posts
 Blog detail shows title, content, author, date
 List pagination: load more loads next page
 Search filters results by query

**CRUD Update:**
 Edit form shows current values pre-filled
 Auto-save triggers after edit (debounced)
 Auto-save persists after reload
 Toggle publish status
 Conflict detection: concurrent edit shows warning

**CRUD Delete:**
 Delete with confirmation dialog
 Cancel delete keeps post
 Optimistic delete removes card immediately
 Deleted post gone from list after confirm

**File Upload:**
 Upload cover image via file picker
 Image compression (large image resized)
 Replace existing cover image
 Remove cover image

**Profile:**
 View profile (displayName, bio, avatar, theme)
 Update profile fields
 Upload/replace avatar image

### Phase 3: Chat App (AI + Public/Private)

 [x] **D3.1** Scaffold chat desktop app
 [x] **D3.2** Chat list: subscribe chat:list, create/delete
 [x] **D3.3** Message view: subscribe message:list, send + AI action
 [x] **D3.4** Navigation (NavigationSplitView)
 [x] **D3.5** Create project.yml (xcodegen spec) with UI test target
 [x] **D3.6** Write XCUITest E2E tests (34 tests: auth flow, chat list CRUD, message send/display, AI response, timestamps, public/private, multiple chats, navigation)
 [x] **D3.7** Verify `xcodebuild test` passes for chat E2E (34/34)

#### D3.T: Chat Tests

 Create new chat → appears in list
 Delete chat → removed from list
 Send text message → appears in message view
 Messages load in chronological order
 AI response received after sending message
 Real-time: new message from another client appears without refresh
 Chat list shows title and last activity
 Empty chat shows appropriate state

### Phase 4: Org App (Multi-Tenancy + Full Features)

 [x] **D4.1** Scaffold org desktop app
 [x] **D4.2** Onboarding: 4-step form (inline in App.swift)
 [x] **D4.3** Org switcher + home (NavigationSplitView sidebar)
 [x] **D4.4** Projects + tasks: subscribe, create/toggle/delete
 [x] **D4.5** Wiki: soft delete/restore, auto-save, conflict detection
 [x] **D4.6** Members: invite, revoke, set admin, remove
 [x] **D4.7** Settings: edit org, leave/delete, transfer ownership
 [x] **D4.8** Create project.yml (xcodegen spec) with UI test target
 [x] **D4.9** Write XCUITest E2E tests (41 tests: auth flow, onboarding multi-step, org CRUD, projects, tasks, wiki soft-delete/restore, members, settings)
 [x] **D4.10** Verify `xcodebuild test` passes for org E2E (41/41)

#### D4.T: Org Tests

**Onboarding:**
 Complete 4-step onboarding (profile → org → appearance → preferences)
 Step validation: can't advance with empty required fields
 Step navigation: back button returns to previous step

**Org Management:**
 Create org with name + slug
 Switch between orgs via switcher
 Org home shows correct org data

**Projects:**
 Create project → appears in list
 Delete project → removed + cascades delete tasks
 Project list subscription updates in real-time

**Tasks:**
 Create task under project
 Toggle task completion
 Delete task
 Tasks scoped to correct project

**Wiki:**
 Create wiki page with title + slug + content
 Edit wiki: auto-save with debounce
 Soft delete wiki → still in deleted list
 Restore deleted wiki
 Conflict detection on concurrent edit

**Members:**
 Invite member by email
 Revoke pending invite
 Set member as admin
 Remove member from org
 Member list shows roles correctly

**Settings:**
 Edit org name/slug
 Leave org (non-owner)
 Delete org (owner only)
 Transfer ownership

### Phase 5: CI Integration

 [x] **D5.1** Add swift-core + desktop path filters to ci.yml changes job
 [x] **D5.2** Add build-desktop + test-desktop jobs
 [x] **D5.3** Update swift path filter to include swift-core (triggers mobile rebuild too)
 [x] **D5.4** Add package.json scripts: dev:desktop, build:desktop, test:desktop, clean:desktop
 [ ] **D5.5** Verify all CI jobs pass (including test-desktop running all XCTest suites)
 [x] **D5.6** Add e2e-desktop CI job (xcodebuild test matrix for all 4 apps)
 [ ] **D5.7** Verify all E2E tests pass in CI

---

## Desktop Final Verification

- [ ] swift-core builds + tests pass
- [ ] Mobile still builds after symlink refactoring (all 4 apps)
- [ ] All 4 desktop apps build with `swift build` on macOS
- [ ] All 4 desktop apps launch and display UI on macOS
- [ ] Movie: search → results → detail
- [ ] Blog: sign in → create → list → edit → delete; profile works
- [ ] Chat: sign in → create chat → send → AI responds
- [ ] Org: onboarding → org → projects → tasks → wiki → members
- [ ] Real-time: data syncs within 2s across web/mobile/desktop
- [ ] Auth (password + Google OAuth) works
- [ ] File upload works
- [ ] `swift test` passes for swift-core + desktop/shared + all 4 apps
 [x] XCUITest E2E passes for all 4 desktop apps (141/141 tests passing)
- [ ] All CI jobs pass (including mobile rebuild triggered by swift-core changes)

## Success Criteria

- 4 native desktop apps on macOS (Linux build verified in CI)
- Feature parity with mobile (core features)
- Same Convex backend, real-time WebSocket subscriptions
- Zero code duplication: Models, Error, HTTP helpers shared via swift-core
- Auth working (password + Google OAuth via system browser)
- File upload working
 Full CI: build + test + e2e + lint, path-filtered with swift-core triggering both tracks
