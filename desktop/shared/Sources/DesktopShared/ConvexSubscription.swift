import ConvexCore
import Foundation

public final class ConvexSubscription<T: Decodable & Sendable>: @unchecked Sendable {
    private let deploymentURL: String
    private let name: String
    private let args: [String: Any]
    private var authToken: String?
    private var webSocket: URLSessionWebSocketTask?
    private var isRunning = false
    private let lock = NSLock()
    private let decoder = JSONDecoder()
    private let onChange: @Sendable (T) -> Void
    private let onError: (@Sendable (Error) -> Void)?
    private var reconnectDelay: TimeInterval = 1.0
    private var pingTask: Task<Void, Never>?

    @preconcurrency
    public init(
        deploymentURL: String,
        name: String,
        args: [String: Any] = [:],
        authToken: String? = nil,
        onChange: @escaping @Sendable (T) -> Void,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.deploymentURL = deploymentURL
        self.name = name
        self.args = args
        self.authToken = authToken
        self.onChange = onChange
        self.onError = onError
    }

    public func start() {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }

        isRunning = true
        lock.unlock()
        reconnectDelay = 1.0
        connect()
    }

    public func stop() {
        lock.lock()
        isRunning = false
        lock.unlock()
        pingTask?.cancel()
        pingTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    public func updateAuth(token: String?) {
        lock.lock()
        authToken = token
        lock.unlock()
        if isRunning {
            webSocket?.cancel(with: .goingAway, reason: nil)
            webSocket = nil
            connect()
        }
    }

    private func connect() {
        lock.lock()
        guard isRunning else {
            lock.unlock()
            return
        }

        let token = authToken
        lock.unlock()

        let wsURL: String =
            if deploymentURL.hasPrefix("https://") {
                "wss://" + deploymentURL.dropFirst(8)
            } else if deploymentURL.hasPrefix("http://") {
                "ws://" + deploymentURL.dropFirst(7)
            } else {
                deploymentURL
            }

        guard let url = URL(string: "\(wsURL)/api/sync") else {
            onError?(ConvexError.serverError("Invalid WebSocket URL"))
            return
        }

        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        webSocket = ws
        ws.resume()

        sendSubscribe(ws: ws, token: token)
        startPing(ws: ws)
        receiveMessages(ws: ws)
    }

    private func sendSubscribe(ws: URLSessionWebSocketTask, token: String?) {
        var body: [String: Any] = [
            "type": "Subscribe",
            "queryId": 0,
            "query": name,
            "args": args,
        ]
        if let token {
            body["token"] = token
        }

        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return
        }
        guard let str = String(data: data, encoding: .utf8) else {
            return
        }

        ws.send(.string(str)) { [weak self] sendError in
            if let sendError {
                self?.onError?(sendError)
            }
        }
    }

    private func startPing(ws: URLSessionWebSocketTask) {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else {
                    break
                }

                ws.sendPing { pingError in
                    if let pingError {
                        self?.onError?(pingError)
                    }
                }
            }
        }
    }

    private func receiveMessages(ws: URLSessionWebSocketTask) {
        ws.receive { [weak self] result in
            guard let self else {
                return
            }

            lock.lock()
            let running = isRunning
            lock.unlock()
            guard running else {
                return
            }

            switch result {
            case let .success(message):
                handleMessage(message)
                receiveMessages(ws: ws)

            case let .failure(receiveError):
                onError?(receiveError)
                scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case let .string(text):
            guard let textData = text.data(using: .utf8) else {
                return
            }

            data = textData

        case let .data(rawData):
            data = rawData

        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        guard let type = json["type"] as? String else {
            return
        }

        if type == "QueryResult" || type == "Transition" {
            if let valueData = json["value"] {
                if let encoded = try? JSONSerialization.data(withJSONObject: valueData),
                   let decoded = try? decoder.decode(T.self, from: encoded) {
                    onChange(decoded)
                }
            }
        } else if type == "FunctionError" || type == "AuthError" {
            let msg = json["message"] as? String ?? "Subscription error"
            onError?(ConvexError.serverError(msg))
        }
    }

    private func scheduleReconnect() {
        lock.lock()
        guard isRunning else {
            lock.unlock()
            return
        }

        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30.0)
        lock.unlock()

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.connect()
        }
    }
}
