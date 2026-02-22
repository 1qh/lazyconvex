// swiftlint:disable file_types_order
import Foundation

public struct Genre: Codable, Sendable {
    public let id: Double
    public let name: String
}

public struct Movie: Codable, Identifiable, Sendable {
    public let _id: String?
    public let _creationTime: Double?
    public let backdrop_path: String?
    public let budget: Double?
    public let cacheHit: Bool?
    public let genres: [Genre]
    public let original_title: String
    public let overview: String
    public let poster_path: String?
    public let release_date: String
    public let revenue: Double?
    public let runtime: Double?
    public let tagline: String?
    public let title: String
    public let tmdb_id: Double
    public let vote_average: Double
    public let vote_count: Double

    public var id: String {
        _id ?? String(Int(tmdb_id))
    }
}

public struct SearchResult: Codable, Identifiable, Sendable {
    public let tmdb_id: Double
    public let title: String
    public let overview: String
    public let poster_path: String?
    public let release_date: String?
    public let vote_average: Double

    public var id: Int {
        Int(tmdb_id)
    }
}

public struct Author: Codable, Sendable {
    public let name: String?
    public let email: String?
    public let imageUrl: String?
}

public struct Blog: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let title: String
    public let content: String
    public let category: String
    public let published: Bool
    public let coverImage: String?
    public let coverImageUrl: String?
    public let tags: [String]?
    public let attachments: [String]?
    public let attachmentsUrls: [String]?
    public let attachmentsUrl: String?
    public let userId: String
    public let updatedAt: Double
    public let author: Author?

    public var id: String {
        _id
    }
}

public struct ProfileData: Codable, Sendable {
    public let _id: String?
    public let displayName: String
    public let bio: String?
    public let avatar: String?
    public let avatarUrl: String?
    public let notifications: Bool
    public let theme: String
}

public struct Chat: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let title: String
    public let isPublic: Bool
    public let userId: String
    public let updatedAt: Double
    public let author: Author?

    public var id: String {
        _id
    }
}

public enum MessagePartType: String, Codable, Sendable {
    case file
    case image
    case text
}

public struct MessagePart: Codable, Sendable {
    public let type: MessagePartType
    public let text: String?
    public let image: String?
    public let file: String?
    public let name: String?
}

public struct Message: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let chatId: String
    public let parts: [MessagePart]
    public let role: String
    public let userId: String?
    public let updatedAt: Double?

    public var id: String {
        _id
    }
}

public struct Org: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let name: String
    public let slug: String
    public let userId: String
    public let updatedAt: Double

    public var id: String {
        _id
    }
}

public struct OrgMember: Codable, Identifiable, Sendable {
    public let _id: String
    public let orgId: String
    public let userId: String
    public let isAdmin: Bool
    public let updatedAt: Double

    public var id: String {
        _id
    }
}

public struct Project: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let name: String
    public let description: String?
    public let orgId: String
    public let editors: [String]?
    public let status: String?
    public let userId: String
    public let updatedAt: Double

    public var id: String {
        _id
    }
}

public struct TaskItem: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let title: String
    public let projectId: String
    public let orgId: String
    public let priority: String?
    public let completed: Bool?
    public let assigneeId: String?
    public let userId: String
    public let updatedAt: Double

    public var id: String {
        _id
    }
}

public struct Wiki: Codable, Identifiable, Sendable {
    public let _id: String
    public let _creationTime: Double
    public let title: String
    public let slug: String
    public let content: String?
    public let orgId: String
    public let status: String
    public let editors: [String]?
    public let deletedAt: Double?
    public let userId: String
    public let updatedAt: Double

    public var id: String {
        _id
    }
}

public struct OrgInvite: Codable, Identifiable, Sendable {
    public let _id: String
    public let orgId: String
    public let email: String
    public let expiresAt: Double

    public var id: String {
        _id
    }
}

public struct OrgJoinRequest: Codable, Identifiable, Sendable {
    public let _id: String
    public let orgId: String
    public let userId: String
    public let status: String

    public var id: String {
        _id
    }
}

#if !SKIP
public struct PaginatedResult<T: Codable & Sendable>: Codable, Sendable {
    public let page: [T]

    public let continueCursor: String

    public let isDone: Bool

    public init(page: [T], continueCursor: String, isDone: Bool) {
        self.page = page
        self.continueCursor = continueCursor
        self.isDone = isDone
    }
}
#else
public struct PaginatedResult<T: Codable & Sendable>: Sendable {
    public let page: [T]

    public let continueCursor: String

    public let isDone: Bool

    public init(page: [T], continueCursor: String, isDone: Bool) {
        self.page = page
        self.continueCursor = continueCursor
        self.isDone = isDone
    }
}
#endif

public struct OrgMemberEntry: Codable, Identifiable, Sendable {
    public let userId: String
    public let role: String
    public let name: String?
    public let email: String?
    public let imageUrl: String?

    public var id: String {
        userId
    }
}

public struct OrgWithRole: Codable, Identifiable, Sendable {
    public let org: Org
    public let role: String

    public var id: String {
        org._id
    }
}

public struct OrgMembership: Codable, Sendable {
    public let _id: String?
    public let orgId: String?
    public let userId: String?
    public let isAdmin: Bool?
    public let role: String?
}

public struct OrgProfile: Codable, Sendable {
    public let _id: String?
    public let displayName: String?
    public let bio: String?
    public let avatar: String?
    public let avatarUrl: String?
    public let notifications: Bool?
    public let theme: String?
}

// swiftlint:enable file_types_order
