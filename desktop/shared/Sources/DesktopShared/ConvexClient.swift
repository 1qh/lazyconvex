import ConvexCore
import Foundation

public final class ConvexClient: @unchecked Sendable {
    private let deploymentURL: String
    private var authToken: String?
    private let lock = NSLock()
    private let decoder = JSONDecoder()

    public init(deploymentURL: String) {
        self.deploymentURL = deploymentURL
    }

    public func setAuth(token: String?) {
        lock.lock()
        authToken = token
        lock.unlock()
    }

    public func query<T: Decodable & Sendable>(
        _ name: String,
        args: [String: Any] = [:]
    ) async throws -> T {
        try await request(path: "/api/query", name: name, args: args)
    }

    public func mutation<T: Decodable & Sendable>(
        _ name: String,
        args: [String: Any] = [:]
    ) async throws -> T {
        try await request(path: "/api/mutation", name: name, args: args)
    }

    public func mutation(_ name: String, args: [String: Any] = [:]) async throws {
        let _: EmptyResponse = try await request(path: "/api/mutation", name: name, args: args)
    }

    public func action<T: Decodable & Sendable>(
        _ name: String,
        args: [String: Any] = [:]
    ) async throws -> T {
        try await request(path: "/api/action", name: name, args: args)
    }

    public func action(_ name: String, args: [String: Any] = [:]) async throws {
        let _: EmptyResponse = try await request(path: "/api/action", name: name, args: args)
    }

    nonisolated private func currentToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return authToken
    }

    private func request<T: Decodable>(
        path: String,
        name: String,
        args: [String: Any]
    ) async throws -> T {
        guard let url = URL(string: "\(deploymentURL)\(path)") else {
            throw ConvexError.serverError("Invalid URL: \(deploymentURL)\(path)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = currentToken()

        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["path": name, "args": args]
        if let token {
            body["token"] = token
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConvexError.serverError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ConvexError.serverError("Request failed (\(httpResponse.statusCode)): \(errorBody)")
        }

        let wrapper = try decoder.decode(ConvexAPIResponse<T>.self, from: data)
        switch wrapper.status {
        case "success":
            guard let value = wrapper.value else {
                throw ConvexError.decodingError("Missing value in success response")
            }

            return value

        default:
            throw ConvexError.serverError(wrapper.errorMessage ?? "Unknown server error")
        }
    }
}

private struct ConvexAPIResponse<T: Decodable>: Decodable {
    let status: String
    let value: T?
    let errorMessage: String?
}

private struct EmptyResponse: Decodable {}
