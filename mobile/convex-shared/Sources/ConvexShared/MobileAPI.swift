// swiftlint:disable file_length
import Foundation

extension BlogProfileAPI {
    public static func upsert(
        avatar: String? = nil,
        bio: String? = nil,
        displayName: String? = nil,
        notifications: Bool? = nil,
        theme: BlogProfileTheme? = nil
    ) async throws {
        var args = [String: Any]()
        if let avatar {
            args["avatar"] = avatar
        }
        if let bio {
            args["bio"] = bio
        }
        if let displayName {
            args["displayName"] = displayName
        }
        if let notifications {
            args["notifications"] = notifications
        }
        if let theme {
            args["theme"] = theme.rawValue
        }
        try await ConvexService.shared.mutate("blogProfile:upsert", args: args)
    }
}

extension BlogProfileAPI {
    @preconcurrency
    public static func subscribeGet(
        onUpdate: @escaping @Sendable @MainActor (ProfileData) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () },
        onNull: @escaping @Sendable @MainActor () -> Void = { () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(to: get, args: [:], type: ProfileData.self, onUpdate: onUpdate, onError: onError)
        #else
        return ConvexService.shared.subscribeProfileData(
            to: get,
            args: [:],
            onUpdate: { r in onUpdate(r) },
            onError: { e in onError(e) },
            onNull: { onNull() }
        )
        #endif
    }
}

extension ProjectAPI {
    public static func create(
        orgId: String,
        description: String? = nil,
        editors: [String]? = nil,
        name: String,
        status: ProjectStatus? = nil
    ) async throws {
        var args: [String: Any] = ["orgId": orgId, "name": name]
        if let description {
            args["description"] = description
        }
        if let editors {
            args["editors"] = editors
        }
        if let status {
            args["status"] = status.rawValue
        }
        try await ConvexService.shared.mutate("project:create", args: args)
    }

    public static func update(
        orgId: String,
        id: String,
        description: String? = nil,
        editors: [String]? = nil,
        name: String? = nil,
        status: ProjectStatus? = nil,
        expectedUpdatedAt: Double? = nil
    ) async throws {
        var args: [String: Any] = ["id": id, "orgId": orgId]
        if let description {
            args["description"] = description
        }
        if let editors {
            args["editors"] = editors
        }
        if let name {
            args["name"] = name
        }
        if let status {
            args["status"] = status.rawValue
        }
        if let expectedUpdatedAt {
            args["expectedUpdatedAt"] = expectedUpdatedAt
        }
        try await ConvexService.shared.mutate("project:update", args: args)
    }

    public static func rm(orgId: String, id: String) async throws {
        try await ConvexService.shared.mutate("project:rm", args: ["id": id, "orgId": orgId])
    }

    public static func bulkRm(orgId: String, ids: [String]) async throws {
        try await ConvexService.shared.mutate("project:bulkRm", args: ["ids": ids, "orgId": orgId])
    }
}

extension ProjectAPI {
    @preconcurrency
    public static func subscribeList(
        orgId: String,
        onUpdate: @escaping @Sendable @MainActor (PaginatedResult<Project>) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        let args = listArgs(orgId: orgId)
        #if !SKIP
        return ConvexService.shared.subscribe(
            to: list,
            args: args,
            type: PaginatedResult<Project>.self,
            onUpdate: onUpdate,
            onError: onError
        )
        #else
        return ConvexService.shared.subscribePaginatedProjects(
            to: list,
            args: args,
            onUpdate: { r in onUpdate(r) },
            onError: { e in onError(e) }
        )
        #endif
    }
}

extension WikiAPI {
    public static func create(
        orgId: String,
        content: String? = nil,
        deletedAt: Double? = nil,
        editors: [String]? = nil,
        slug: String,
        status: WikiStatus,
        title: String
    ) async throws {
        var args: [String: Any] = ["orgId": orgId, "slug": slug, "status": status.rawValue, "title": title]
        if let content {
            args["content"] = content
        }
        if let deletedAt {
            args["deletedAt"] = deletedAt
        }
        if let editors {
            args["editors"] = editors
        }
        try await ConvexService.shared.mutate("wiki:create", args: args)
    }

    public static func update(
        orgId: String,
        id: String,
        content: String? = nil,
        deletedAt: Double? = nil,
        editors: [String]? = nil,
        slug: String? = nil,
        status: WikiStatus? = nil,
        title: String? = nil,
        expectedUpdatedAt: Double? = nil
    ) async throws {
        var args: [String: Any] = ["id": id, "orgId": orgId]
        if let content {
            args["content"] = content
        }
        if let deletedAt {
            args["deletedAt"] = deletedAt
        }
        if let editors {
            args["editors"] = editors
        }
        if let slug {
            args["slug"] = slug
        }
        if let status {
            args["status"] = status.rawValue
        }
        if let title {
            args["title"] = title
        }
        if let expectedUpdatedAt {
            args["expectedUpdatedAt"] = expectedUpdatedAt
        }
        try await ConvexService.shared.mutate("wiki:update", args: args)
    }

    public static func rm(orgId: String, id: String) async throws {
        try await ConvexService.shared.mutate("wiki:rm", args: ["id": id, "orgId": orgId])
    }

    public static func restore(orgId: String, id: String) async throws {
        try await ConvexService.shared.mutate("wiki:restore", args: ["id": id, "orgId": orgId])
    }

    public static func bulkRm(orgId: String, ids: [String]) async throws {
        try await ConvexService.shared.mutate("wiki:bulkRm", args: ["ids": ids, "orgId": orgId])
    }
}

extension WikiAPI {
    @preconcurrency
    public static func subscribeList(
        orgId: String,
        onUpdate: @escaping @Sendable @MainActor (PaginatedResult<Wiki>) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        let args = listArgs(orgId: orgId)
        #if !SKIP
        return ConvexService.shared.subscribe(to: list, args: args, type: PaginatedResult<Wiki>.self, onUpdate: onUpdate, onError: onError)
        #else
        return ConvexService.shared.subscribePaginatedWikis(
            to: list,
            args: args,
            onUpdate: { r in onUpdate(r) },
            onError: { e in onError(e) }
        )
        #endif
    }
}

extension MobileAiAPI {
    public static func chat(chatId: String) async throws {
        #if !SKIP
        let _: [String: String] = try await ConvexService.shared.action(
            "mobileAi:chat",
            args: ["chatId": chatId],
            returning: [String: String].self
        )
        #else
        try await ConvexService.shared.action(name: "mobileAi:chat", args: ["chatId": chatId])
        #endif
    }
}

extension BlogAPI {
    public static func create(
        attachments: [String]? = nil,
        category: BlogCategory,
        content: String,
        coverImage: String? = nil,
        published: Bool,
        tags: [String]? = nil,
        title: String
    ) async throws {
        var args: [String: Any] = ["category": category.rawValue, "content": content, "published": published, "title": title]
        if let attachments {
            args["attachments"] = attachments
        }
        if let coverImage {
            args["coverImage"] = coverImage
        }
        if let tags {
            args["tags"] = tags
        }
        try await ConvexService.shared.mutate("blog:create", args: args)
    }

    public static func update(
        id: String,
        attachments: [String]? = nil,
        category: BlogCategory? = nil,
        content: String? = nil,
        coverImage: String? = nil,
        published: Bool? = nil,
        tags: [String]? = nil,
        title: String? = nil,
        expectedUpdatedAt: Double? = nil
    ) async throws {
        var args: [String: Any] = ["id": id]
        if let attachments {
            args["attachments"] = attachments
        }
        if let category {
            args["category"] = category.rawValue
        }
        if let content {
            args["content"] = content
        }
        if let coverImage {
            args["coverImage"] = coverImage
        }
        if let published {
            args["published"] = published
        }
        if let tags {
            args["tags"] = tags
        }
        if let title {
            args["title"] = title
        }
        if let expectedUpdatedAt {
            args["expectedUpdatedAt"] = expectedUpdatedAt
        }
        try await ConvexService.shared.mutate("blog:update", args: args)
    }

    public static func rm(id: String) async throws {
        try await ConvexService.shared.mutate("blog:rm", args: ["id": id])
    }

    public static func bulkRm(ids: [String]) async throws {
        try await ConvexService.shared.mutate("blog:bulkRm", args: ["ids": ids])
    }
}

extension BlogAPI {
    @preconcurrency
    public static func subscribeList(
        where filterWhere: BlogWhere?,
        onUpdate: @escaping @Sendable @MainActor (PaginatedResult<Blog>) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        let args = listArgs(where: filterWhere)
        #if !SKIP
        return ConvexService.shared.subscribe(to: list, args: args, type: PaginatedResult<Blog>.self, onUpdate: onUpdate, onError: onError)
        #else
        return ConvexService.shared.subscribePaginatedBlogs(
            to: list,
            args: args,
            onUpdate: { r in onUpdate(r) },
            onError: { e in onError(e) }
        )
        #endif
    }

    @preconcurrency
    public static func subscribeRead(
        id: String,
        onUpdate: @escaping @Sendable @MainActor (Blog) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(to: read, args: ["id": id], type: Blog.self, onUpdate: onUpdate, onError: onError)
        #else
        return ConvexService.shared.subscribeBlog(to: read, args: ["id": id], onUpdate: { r in onUpdate(r) }, onError: { e in onError(e) })
        #endif
    }
}

extension MovieAPI {
    public static func load(tmdbId: Int) async throws -> Movie {
        #if !SKIP
        return try await ConvexService.shared.action("movie:load", args: ["tmdb_id": Double(tmdbId)], returning: Movie.self)
        #else
        return try await ConvexService.shared.actionMovie(name: "movie:load", args: ["tmdb_id": Double(tmdbId)])
        #endif
    }

    public static func search(query: String) async throws -> [SearchResult] {
        #if !SKIP
        return try await ConvexService.shared.action("movie:search", args: ["query": query], returning: [SearchResult].self)
        #else
        return try await Array(ConvexService.shared.actionSearchResults(name: "movie:search", args: ["query": query]))
        #endif
    }
}

extension ChatAPI {
    public static func create(
        isPublic: Bool,
        title: String
    ) async throws {
        let args: [String: Any] = ["isPublic": isPublic, "title": title]
        try await ConvexService.shared.mutate("chat:create", args: args)
    }

    public static func update(
        id: String,
        isPublic: Bool? = nil,
        title: String? = nil,
        expectedUpdatedAt: Double? = nil
    ) async throws {
        var args: [String: Any] = ["id": id]
        if let isPublic {
            args["isPublic"] = isPublic
        }
        if let title {
            args["title"] = title
        }
        if let expectedUpdatedAt {
            args["expectedUpdatedAt"] = expectedUpdatedAt
        }
        try await ConvexService.shared.mutate("chat:update", args: args)
    }

    public static func rm(id: String) async throws {
        try await ConvexService.shared.mutate("chat:rm", args: ["id": id])
    }
}

extension ChatAPI {
    @preconcurrency
    public static func subscribeList(
        where filterWhere: ChatWhere?,
        onUpdate: @escaping @Sendable @MainActor (PaginatedResult<Chat>) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        let args = listArgs(where: filterWhere)
        #if !SKIP
        return ConvexService.shared.subscribe(to: list, args: args, type: PaginatedResult<Chat>.self, onUpdate: onUpdate, onError: onError)
        #else
        return ConvexService.shared.subscribePaginatedChats(
            to: list,
            args: args,
            onUpdate: { r in onUpdate(r) },
            onError: { e in onError(e) }
        )
        #endif
    }
}

extension MessageAPI {
    public static func create(chatId: String, parts: [MessagePart], role: MessageRole) async throws {
        var partDicts = [[String: Any]]()
        for p in parts {
            var d: [String: Any] = ["type": p.type.rawValue]
            if let text = p.text {
                d["text"] = text
            }
            if let image = p.image {
                d["image"] = image
            }
            if let file = p.file {
                d["file"] = file
            }
            if let name = p.name {
                d["name"] = name
            }
            partDicts.append(d)
        }
        try await ConvexService.shared.mutate("message:create", args: ["chatId": chatId, "role": role.rawValue, "parts": partDicts])
    }
}

extension MessageAPI {
    @preconcurrency
    public static func subscribeList(
        chatId: String,
        onUpdate: @escaping @Sendable @MainActor ([Message]) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(
            to: list,
            args: ["chatId": chatId],
            type: [Message].self,
            onUpdate: onUpdate,
            onError: onError
        )
        #else
        return ConvexService.shared.subscribeMessages(
            to: list,
            args: ["chatId": chatId],
            onUpdate: { r in onUpdate(Array(r)) },
            onError: { e in onError(e) }
        )
        #endif
    }
}

extension OrgProfileAPI {
    public static func upsert(
        avatar: String? = nil,
        bio: String? = nil,
        displayName: String? = nil,
        notifications: Bool? = nil,
        theme: OrgProfileTheme? = nil
    ) async throws {
        var args = [String: Any]()
        if let avatar {
            args["avatar"] = avatar
        }
        if let bio {
            args["bio"] = bio
        }
        if let displayName {
            args["displayName"] = displayName
        }
        if let notifications {
            args["notifications"] = notifications
        }
        if let theme {
            args["theme"] = theme.rawValue
        }
        try await ConvexService.shared.mutate("orgProfile:upsert", args: args)
    }
}

extension OrgAPI {
    public static func acceptInvite(token: String) async throws {
        try await ConvexService.shared.mutate("org:acceptInvite", args: ["token": token])
    }

    public static func approveJoinRequest(requestId: String, isAdmin: Bool? = nil) async throws {
        var args: [String: Any] = ["requestId": requestId]
        if let isAdmin {
            args["isAdmin"] = isAdmin
        }
        try await ConvexService.shared.mutate("org:approveJoinRequest", args: args)
    }

    public static func cancelJoinRequest(requestId: String) async throws {
        try await ConvexService.shared.mutate("org:cancelJoinRequest", args: ["requestId": requestId])
    }

    public static func create(name: String, slug: String, avatarId: String? = nil) async throws {
        var data: [String: Any] = ["name": name, "slug": slug]
        if let avatarId {
            data["avatarId"] = avatarId
        }
        try await ConvexService.shared.mutate("org:create", args: ["data": data])
    }

    public static func getOrCreate() async throws {
        try await ConvexService.shared.mutate("org:getOrCreate", args: [:])
    }

    public static func invite(email: String, isAdmin: Bool, orgId: String) async throws {
        try await ConvexService.shared.mutate("org:invite", args: ["email": email, "isAdmin": isAdmin, "orgId": orgId])
    }

    public static func leave(orgId: String) async throws {
        try await ConvexService.shared.mutate("org:leave", args: ["orgId": orgId])
    }

    public static func rejectJoinRequest(requestId: String) async throws {
        try await ConvexService.shared.mutate("org:rejectJoinRequest", args: ["requestId": requestId])
    }

    public static func remove(orgId: String) async throws {
        try await ConvexService.shared.mutate("org:remove", args: ["orgId": orgId])
    }

    public static func removeMember(memberId: String) async throws {
        try await ConvexService.shared.mutate("org:removeMember", args: ["memberId": memberId])
    }

    public static func requestJoin(orgId: String, message: String? = nil) async throws {
        var args: [String: Any] = ["orgId": orgId]
        if let message {
            args["message"] = message
        }
        try await ConvexService.shared.mutate("org:requestJoin", args: args)
    }

    public static func revokeInvite(inviteId: String) async throws {
        try await ConvexService.shared.mutate("org:revokeInvite", args: ["inviteId": inviteId])
    }

    public static func setAdmin(isAdmin: Bool, memberId: String) async throws {
        try await ConvexService.shared.mutate("org:setAdmin", args: ["isAdmin": isAdmin, "memberId": memberId])
    }

    public static func transferOwnership(newOwnerId: String, orgId: String) async throws {
        try await ConvexService.shared.mutate("org:transferOwnership", args: ["newOwnerId": newOwnerId, "orgId": orgId])
    }

    public static func update(orgId: String, name: String? = nil, slug: String? = nil, avatarId: String? = nil) async throws {
        var data = [String: Any]()
        if let name {
            data["name"] = name
        }
        if let slug {
            data["slug"] = slug
        }
        if let avatarId {
            data["avatarId"] = avatarId
        }
        try await ConvexService.shared.mutate("org:update", args: ["orgId": orgId, "data": data])
    }
}

extension OrgAPI {
    @preconcurrency
    public static func subscribeMyOrgs(
        onUpdate: @escaping @Sendable @MainActor ([OrgWithRole]) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(to: myOrgs, args: [:], type: [OrgWithRole].self, onUpdate: onUpdate, onError: onError)
        #else
        return ConvexService.shared.subscribeOrgsWithRole(
            to: myOrgs,
            args: [:],
            onUpdate: { r in onUpdate(Array(r)) },
            onError: { e in onError(e) }
        )
        #endif
    }

    @preconcurrency
    public static func subscribeMembers(
        orgId: String,
        onUpdate: @escaping @Sendable @MainActor ([OrgMemberEntry]) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(
            to: members,
            args: ["orgId": orgId],
            type: [OrgMemberEntry].self,
            onUpdate: onUpdate,
            onError: onError
        )
        #else
        return ConvexService.shared.subscribeOrgMembers(
            to: members,
            args: ["orgId": orgId],
            onUpdate: { r in onUpdate(Array(r)) },
            onError: { e in onError(e) }
        )
        #endif
    }

    @preconcurrency
    public static func subscribePendingInvites(
        orgId: String,
        onUpdate: @escaping @Sendable @MainActor ([OrgInvite]) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(
            to: pendingInvites,
            args: ["orgId": orgId],
            type: [OrgInvite].self,
            onUpdate: onUpdate,
            onError: onError
        )
        #else
        return ConvexService.shared.subscribeInvites(
            to: pendingInvites,
            args: ["orgId": orgId],
            onUpdate: { r in onUpdate(Array(r)) },
            onError: { e in onError(e) }
        )
        #endif
    }
}

extension TaskAPI {
    public static func create(
        orgId: String,
        assigneeId: String? = nil,
        completed: Bool? = nil,
        priority: TaskPriority? = nil,
        projectId: String,
        title: String
    ) async throws {
        var args: [String: Any] = ["orgId": orgId, "projectId": projectId, "title": title]
        if let assigneeId {
            args["assigneeId"] = assigneeId
        }
        if let completed {
            args["completed"] = completed
        }
        if let priority {
            args["priority"] = priority.rawValue
        }
        try await ConvexService.shared.mutate("task:create", args: args)
    }

    public static func update(
        orgId: String,
        id: String,
        assigneeId: String? = nil,
        completed: Bool? = nil,
        priority: TaskPriority? = nil,
        projectId: String? = nil,
        title: String? = nil,
        expectedUpdatedAt: Double? = nil
    ) async throws {
        var args: [String: Any] = ["id": id, "orgId": orgId]
        if let assigneeId {
            args["assigneeId"] = assigneeId
        }
        if let completed {
            args["completed"] = completed
        }
        if let priority {
            args["priority"] = priority.rawValue
        }
        if let projectId {
            args["projectId"] = projectId
        }
        if let title {
            args["title"] = title
        }
        if let expectedUpdatedAt {
            args["expectedUpdatedAt"] = expectedUpdatedAt
        }
        try await ConvexService.shared.mutate("task:update", args: args)
    }

    public static func rm(orgId: String, id: String) async throws {
        try await ConvexService.shared.mutate("task:rm", args: ["id": id, "orgId": orgId])
    }

    public static func bulkRm(orgId: String, ids: [String]) async throws {
        try await ConvexService.shared.mutate("task:bulkRm", args: ["ids": ids, "orgId": orgId])
    }

    public static func toggle(orgId: String, id: String) async throws {
        try await ConvexService.shared.mutate("task:toggle", args: ["orgId": orgId, "id": id])
    }
}

extension TaskAPI {
    @preconcurrency
    public static func subscribeByProject(
        orgId: String,
        projectId: String,
        onUpdate: @escaping @Sendable @MainActor ([TaskItem]) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        #if !SKIP
        return ConvexService.shared.subscribe(
            to: byProject,
            args: ["orgId": orgId, "projectId": projectId],
            type: [TaskItem].self,
            onUpdate: onUpdate,
            onError: onError
        )
        #else
        return ConvexService.shared.subscribeTasks(
            to: byProject,
            args: ["orgId": orgId, "projectId": projectId],
            onUpdate: { r in onUpdate(Array(r)) },
            onError: { e in onError(e) }
        )
        #endif
    }
}
