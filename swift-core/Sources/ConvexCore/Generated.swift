// swiftlint:disable file_types_order
import Foundation

public struct MovieGenre: Codable, Sendable {
    public let id: Double
    public let name: String
}

public struct MessagePart: Codable, Sendable {
    public let type: MessagePartType
    public let text: String?
    public let image: String?
    public let file: String?
    public let name: String?
}

public enum BlogCategory: String, Codable, Sendable {
    case life
    case tech
    case tutorial
}

public enum ProjectStatus: String, Codable, Sendable {
    case active
    case archived
    case completed
}

public enum TaskPriority: String, Codable, Sendable {
    case high
    case low
    case medium
}

public enum WikiStatus: String, Codable, Sendable {
    case draft
    case published
}

public enum BlogProfileTheme: String, Codable, Sendable {
    case dark
    case light
    case system
}

public enum OrgProfileTheme: String, Codable, Sendable {
    case dark
    case light
    case system
}

public enum MessagePartType: String, Codable, Sendable {
    case file
    case image
    case text
}

public enum MessageRole: String, Codable, Sendable {
    case assistant
    case system
    case user
}

public struct Blog: Codable, Identifiable, Sendable {
    public let _creationTime: Double
    public let _id: String
    public let author: Author?
    public let updatedAt: Double
    public let userId: String
    public let attachments: [String]?
    public let category: BlogCategory
    public let content: String
    public let coverImage: String?
    public let published: Bool
    public let tags: [String]?
    public let title: String
    public let attachmentsUrls: [String]?
    public let coverImageUrl: String?

    public var id: String {
        _id
    }
}

public struct Chat: Codable, Identifiable, Sendable {
    public let _creationTime: Double
    public let _id: String
    public let author: Author?
    public let updatedAt: Double
    public let userId: String
    public let isPublic: Bool
    public let title: String

    public var id: String {
        _id
    }
}

public struct Project: Codable, Identifiable, Sendable {
    public let _creationTime: Double
    public let _id: String
    public let orgId: String
    public let updatedAt: Double
    public let userId: String
    public let description: String?
    public let editors: [String]?
    public let name: String
    public let status: ProjectStatus?
    public let editorsUrls: [String]?

    public var id: String {
        _id
    }
}

public struct TaskItem: Codable, Identifiable, Sendable {
    public let _creationTime: Double
    public let _id: String
    public let orgId: String
    public let updatedAt: Double
    public let userId: String
    public let assigneeId: String?
    public let completed: Bool?
    public let priority: TaskPriority?
    public let projectId: String
    public let title: String
    public let assigneeIdUrl: String?
    public let projectIdUrl: String?

    public var id: String {
        _id
    }
}

public struct Wiki: Codable, Identifiable, Sendable {
    public let _creationTime: Double
    public let _id: String
    public let orgId: String
    public let updatedAt: Double
    public let userId: String
    public let content: String?
    public let deletedAt: Double?
    public let editors: [String]?
    public let slug: String
    public let status: WikiStatus
    public let title: String
    public let editorsUrls: [String]?

    public var id: String {
        _id
    }
}

public struct Movie: Codable, Identifiable, Sendable {
    public let _creationTime: Double?
    public let _id: String?
    public let cacheHit: Bool?
    public let backdrop_path: String?
    public let budget: Double?
    public let genres: [MovieGenre]
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
        _id ?? ""
    }
}

public struct BlogProfile: Codable, Identifiable, Sendable {
    public let _id: String?
    public let avatar: String?
    public let bio: String?
    public let displayName: String
    public let notifications: Bool
    public let theme: BlogProfileTheme
    public let avatarUrl: String?

    public var id: String {
        _id ?? ""
    }
}

public struct OrgProfile: Codable, Identifiable, Sendable {
    public let _id: String?
    public let avatar: String?
    public let bio: String?
    public let displayName: String
    public let notifications: Bool
    public let theme: OrgProfileTheme
    public let avatarUrl: String?

    public var id: String {
        _id ?? ""
    }
}

public struct Message: Codable, Identifiable, Sendable {
    public let _creationTime: Double
    public let _id: String
    public let updatedAt: Double?
    public let userId: String?
    public let chatId: String
    public let parts: [MessagePart]
    public let role: MessageRole
    public let chatIdUrl: String?

    public var id: String {
        _id
    }
}

public struct Author: Codable, Sendable {
    public let name: String?
    public let email: String?
    public let imageUrl: String?
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

public enum BlogProfileAPI {
    public static let get = "blogProfile:get"
    public static let upsert = "blogProfile:upsert"
}

public enum ProjectAPI {
    public static let addEditor = "project:addEditor"
    public static let bulkRm = "project:bulkRm"
    public static let create = "project:create"
    public static let editors = "project:editors"
    public static let list = "project:list"
    public static let read = "project:read"
    public static let removeEditor = "project:removeEditor"
    public static let rm = "project:rm"
    public static let setEditors = "project:setEditors"
    public static let update = "project:update"
}

public enum WikiAPI {
    public static let addEditor = "wiki:addEditor"
    public static let bulkRm = "wiki:bulkRm"
    public static let bulkUpdate = "wiki:bulkUpdate"
    public static let create = "wiki:create"
    public static let editors = "wiki:editors"
    public static let list = "wiki:list"
    public static let read = "wiki:read"
    public static let removeEditor = "wiki:removeEditor"
    public static let restore = "wiki:restore"
    public static let rm = "wiki:rm"
    public static let setEditors = "wiki:setEditors"
    public static let update = "wiki:update"
}

public enum MobileAiAPI {
    public static let chat = "mobileAi:chat"
}

public enum BlogAPI {
    public static let bulkRm = "blog:bulkRm"
    public static let bulkUpdate = "blog:bulkUpdate"
    public static let create = "blog:create"
    public static let list = "blog:list"
    public static let read = "blog:read"
    public static let search = "blog:search"
    public static let rm = "blog:rm"
    public static let update = "blog:update"
}

public enum MovieAPI {
    public static let search = "movie:search"
    public static let all = "movie:all"
    public static let checkRL = "movie:checkRL"
    public static let create = "movie:create"
    public static let get = "movie:get"
    public static let getInternal = "movie:getInternal"
    public static let invalidate = "movie:invalidate"
    public static let list = "movie:list"
    public static let load = "movie:load"
    public static let purge = "movie:purge"
    public static let read = "movie:read"
    public static let refresh = "movie:refresh"
    public static let rm = "movie:rm"
    public static let set = "movie:set"
    public static let update = "movie:update"
}

public enum FileAPI {
    public static let assembleChunks = "file:assembleChunks"
    public static let cancelChunkedUpload = "file:cancelChunkedUpload"
    public static let CHUNK_SIZE = "file:CHUNK_SIZE"
    public static let confirmChunk = "file:confirmChunk"
    public static let finalizeAssembly = "file:finalizeAssembly"
    public static let getSessionForAssembly = "file:getSessionForAssembly"
    public static let getUploadProgress = "file:getUploadProgress"
    public static let info = "file:info"
    public static let startChunkedUpload = "file:startChunkedUpload"
    public static let upload = "file:upload"
    public static let uploadChunk = "file:uploadChunk"
    public static let validate = "file:validate"
}

public enum ChatAPI {
    public static let list = "chat:list"
    public static let read = "chat:read"
    public static let create = "chat:create"
    public static let pubRead = "chat:pubRead"
    public static let rm = "chat:rm"
    public static let update = "chat:update"
}

public enum MessageAPI {
    public static let create = "message:create"
    public static let list = "message:list"
    public static let update = "message:update"
    public static let pubGet = "message:pubGet"
    public static let pubList = "message:pubList"
}

public enum OrgProfileAPI {
    public static let get = "orgProfile:get"
    public static let upsert = "orgProfile:upsert"
}

public enum OrgAPI {
    public static let acceptInvite = "org:acceptInvite"
    public static let approveJoinRequest = "org:approveJoinRequest"
    public static let cancelJoinRequest = "org:cancelJoinRequest"
    public static let create = "org:create"
    public static let get = "org:get"
    public static let getBySlug = "org:getBySlug"
    public static let getPublic = "org:getPublic"
    public static let invite = "org:invite"
    public static let isSlugAvailable = "org:isSlugAvailable"
    public static let leave = "org:leave"
    public static let members = "org:members"
    public static let membership = "org:membership"
    public static let myJoinRequest = "org:myJoinRequest"
    public static let myOrgs = "org:myOrgs"
    public static let pendingInvites = "org:pendingInvites"
    public static let pendingJoinRequests = "org:pendingJoinRequests"
    public static let rejectJoinRequest = "org:rejectJoinRequest"
    public static let remove = "org:remove"
    public static let removeMember = "org:removeMember"
    public static let requestJoin = "org:requestJoin"
    public static let revokeInvite = "org:revokeInvite"
    public static let setAdmin = "org:setAdmin"
    public static let transferOwnership = "org:transferOwnership"
    public static let update = "org:update"
    public static let getOrCreate = "org:getOrCreate"
}

public enum UserAPI {
    public static let me = "user:me"
}

public enum TaskAPI {
    public static let assign = "task:assign"
    public static let bulkRm = "task:bulkRm"
    public static let bulkUpdate = "task:bulkUpdate"
    public static let byProject = "task:byProject"
    public static let create = "task:create"
    public static let list = "task:list"
    public static let read = "task:read"
    public static let rm = "task:rm"
    public static let toggle = "task:toggle"
    public static let update = "task:update"
}

// swiftlint:enable file_types_order
