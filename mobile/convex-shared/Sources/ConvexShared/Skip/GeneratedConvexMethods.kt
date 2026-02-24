@file:Suppress("unused")

package convex.shared

import skip.foundation.*
import skip.lib.*

fun ConvexService.subscribePaginatedBlogs(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (PaginatedResult<Blog>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribePaginatedImpl(to, args, Blog::class, onUpdate, onError)

fun ConvexService.subscribePaginatedChats(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (PaginatedResult<Chat>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribePaginatedImpl(to, args, Chat::class, onUpdate, onError)

fun ConvexService.subscribePaginatedProjects(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (PaginatedResult<Project>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribePaginatedImpl(to, args, Project::class, onUpdate, onError)

fun ConvexService.subscribePaginatedWikis(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (PaginatedResult<Wiki>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribePaginatedImpl(to, args, Wiki::class, onUpdate, onError)

fun ConvexService.subscribeOrgsWithRole(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (skip.lib.Array<OrgWithRole>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeArrayImpl(to, args, OrgWithRole::class, onUpdate, onError)

fun ConvexService.subscribeOrgMembers(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (skip.lib.Array<OrgMemberEntry>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeArrayImpl(to, args, OrgMemberEntry::class, onUpdate, onError)

fun ConvexService.subscribeTasks(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (skip.lib.Array<TaskItem>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeArrayImpl(to, args, TaskItem::class, onUpdate, onError)

fun ConvexService.subscribeInvites(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (skip.lib.Array<OrgInvite>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeArrayImpl(to, args, OrgInvite::class, onUpdate, onError)

fun ConvexService.subscribeMessages(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (skip.lib.Array<Message>) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeArrayImpl(to, args, Message::class, onUpdate, onError)

fun ConvexService.subscribeBlog(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (Blog) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeSingleImpl(to, args, Blog::class, onUpdate, onError)

fun ConvexService.subscribeMovie(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (Movie) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeSingleImpl(to, args, Movie::class, onUpdate, onError)

fun ConvexService.subscribeWiki(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (Wiki) -> Unit,
    onError: (Error) -> Unit = { },
): String = subscribeSingleImpl(to, args, Wiki::class, onUpdate, onError)

fun ConvexService.subscribeProfileData(
    to: String,
    args: Dictionary<String, Any> = dictionaryOf(),
    onUpdate: (ProfileData) -> Unit,
    onError: (Error) -> Unit = { },
    onNull: () -> Unit = { },
): String = subscribeNullableImpl(to, args, ProfileData::class, onUpdate, onError, onNull)

suspend fun ConvexService.actionSearchResults(
    name: String,
    args: Dictionary<String, Any> = dictionaryOf(),
): skip.lib.Array<SearchResult> = actionArrayImpl(name, args, SearchResult::class)

suspend fun ConvexService.actionMovie(
    name: String,
    args: Dictionary<String, Any> = dictionaryOf(),
): Movie = actionOneImpl(name, args, Movie::class)

suspend fun ConvexService.queryProfileData(
    name: String,
    args: Dictionary<String, Any> = dictionaryOf(),
): ProfileData? = queryNullableImpl(name, args, ProfileData::class)
