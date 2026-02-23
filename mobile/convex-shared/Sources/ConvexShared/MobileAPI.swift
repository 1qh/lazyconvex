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
}
