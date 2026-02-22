import Foundation
#if !SKIP
import Combine
import ConvexMobile

private func encodeValue(_ value: Any) -> ConvexEncodable? {
    switch value {
    case let s as String:
        return s

    case let n as Int:
        return n

    case let n as Double:
        return n

    case let b as Bool:
        return b

    case let dict as [String: Any]:
        return encodeArgs(dict) as ConvexEncodable

    case let arr as [Any]:
        var encoded = [ConvexEncodable?]()
        for item in arr {
            encoded.append(encodeValue(item))
        }
        return encoded as ConvexEncodable

    default:
        return nil
    }
}

private func encodeArgs(_ args: [String: Any]) -> [String: ConvexEncodable?] {
    var result = [String: ConvexEncodable?]()
    for (key, value) in args {
        result[key] = encodeValue(value)
    }
    return result
}

public final class ConvexService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = ConvexService()

    private var client: ConvexClient?

    private let lock = NSLock()

    private var subscriptions = [String: AnyCancellable]()

    private init() {
        _ = ()
    }

    public func initialize(url: String) {
        lock.lock()
        // swiftformat:disable:next acronyms
        client = ConvexClient(deploymentUrl: url)
        lock.unlock()
    }

    @preconcurrency
    public func subscribe<T: Decodable & Sendable>(
        to name: String,
        args: [String: Any] = [:],
        type _: T.Type,
        onUpdate: @escaping @Sendable @MainActor (T) -> Void,
        onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }
    ) -> String {
        let c: ConvexClient
        do {
            c = try getClient()
        } catch {
            Task { @MainActor in onError(error) }
            return ""
        }

        let subID = UUID().uuidString
        let encoded = args.isEmpty ? nil : encodeArgs(args)
        let publisher: AnyPublisher<T, ClientError> = c.subscribe(
            to: name,
            with: encoded
        )
        let cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(err) = completion {
                        Task { @MainActor in onError(err) }
                    }
                },
                receiveValue: { value in
                    Task { @MainActor in onUpdate(value) }
                }
            )
        lock.lock()
        subscriptions[subID] = cancellable
        lock.unlock()
        return subID
    }

    public func cancelSubscription(_ subID: String) {
        lock.lock()
        let cancellable = subscriptions.removeValue(forKey: subID)
        lock.unlock()
        cancellable?.cancel()
    }

    public func setAuth(token _: String?) {
        _ = ()
    }

    public func mutate(_ name: String, args: [String: Any] = [:]) async throws {
        let c = try getClient()
        let encoded = args.isEmpty ? nil : encodeArgs(args)
        let _: String? = try await c.mutation(name, with: encoded)
    }

    public func mutate<T: Decodable & Sendable>(
        _ name: String,
        args: [String: Any] = [:],
        returning _: T.Type
    ) async throws -> T {
        let c = try getClient()
        let encoded = args.isEmpty ? nil : encodeArgs(args)
        return try await c.mutation(name, with: encoded)
    }

    public func action<T: Decodable & Sendable>(
        _ name: String,
        args: [String: Any] = [:],
        returning _: T.Type
    ) async throws -> T {
        let c = try getClient()
        let encoded = args.isEmpty ? nil : encodeArgs(args)
        return try await c.action(name, with: encoded)
    }

    public func action(_ name: String, args: [String: Any] = [:]) async throws {
        let c = try getClient()
        let encoded = args.isEmpty ? nil : encodeArgs(args)
        let _: String? = try await c.action(name, with: encoded)
    }

    private func getClient() throws -> ConvexClient {
        lock.lock()
        defer { lock.unlock() }
        guard let client else {
            throw ConvexError.notInitialized
        }

        return client
    }
}
#endif
