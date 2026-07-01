import Foundation

public enum CodexAppServerError: Error, CustomStringConvertible, Sendable {
    case missingExecutable
    case transport(String)
    case rpc(String)

    public var description: String {
        switch self {
        case .missingExecutable:
            "找不到 codex 命令。请确认 Codex CLI 已安装，并且 /opt/homebrew/bin 或 /usr/local/bin 中能找到 codex。"
        case .transport(let message):
            message
        case .rpc(let message):
            message
        }
    }
}

public protocol CodexRPCTransport: AnyObject {
    func send(_ payload: [String: Any]) throws
    func readMessage(timeoutSeconds: TimeInterval) throws -> [String: Any]
    func close()
}

public enum CodexAppServerClient {
    public static func fetchCurrent(codexPath: String? = nil, timeoutSeconds: TimeInterval = 8) -> AgentQuotaSnapshot {
        let fetchedAt = Date()

        do {
            let path = try codexPath ?? CodexExecutableResolver.resolve()
            let transport = try ProcessCodexRPCTransport(codexPath: path)
            defer { transport.close() }
            return fetchSnapshot(transport: transport, fetchedAt: fetchedAt, timeoutSeconds: timeoutSeconds)
        } catch {
            return errorSnapshot(fetchedAt: fetchedAt, error)
        }
    }

    public static func fetchSnapshot(
        transport: CodexRPCTransport,
        fetchedAt: Date,
        timeoutSeconds: TimeInterval = 8
    ) -> AgentQuotaSnapshot {
        do {
            try transport.send([
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "quota-capsule",
                        "title": "Quota Capsule",
                        "version": "0.1.0"
                    ],
                    "capabilities": [:]
                ]
            ])

            let initialized = try readUntilID(1, transport: transport, timeoutSeconds: timeoutSeconds)
            if let error = rpcError(from: initialized) {
                return errorSnapshot(fetchedAt: fetchedAt, CodexAppServerError.rpc(error))
            }

            try transport.send(["jsonrpc": "2.0", "method": "initialized", "params": [:]])
            try transport.send(["jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read", "params": [:]])

            let response = try readUntilID(2, transport: transport, timeoutSeconds: timeoutSeconds)
            if let error = rpcError(from: response) {
                return errorSnapshot(fetchedAt: fetchedAt, CodexAppServerError.rpc(error))
            }

            guard let result = response["result"] as? [String: Any] else {
                return errorSnapshot(fetchedAt: fetchedAt, CodexAppServerError.rpc("account/rateLimits/read 回应缺少 result。"))
            }

            return CodexRateLimitParser.parse(result: result, fetchedAt: fetchedAt)
        } catch {
            return errorSnapshot(fetchedAt: fetchedAt, error)
        }
    }

    private static func readUntilID(
        _ id: Int,
        transport: CodexRPCTransport,
        timeoutSeconds: TimeInterval
    ) throws -> [String: Any] {
        for _ in 0..<50 {
            let message = try transport.readMessage(timeoutSeconds: timeoutSeconds)
            if let messageID = message["id"] as? Int, messageID == id {
                return message
            }
        }

        throw CodexAppServerError.rpc("codex app-server 没有返回 id=\(id) 的回应。")
    }

    private static func rpcError(from message: [String: Any]) -> String? {
        guard let error = message["error"] as? [String: Any] else {
            return nil
        }
        return error["message"] as? String ?? "codex app-server returned an unknown RPC error."
    }

    private static func errorSnapshot(fetchedAt: Date, _ error: Error) -> AgentQuotaSnapshot {
        AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: fetchedAt,
            shortWindow: nil,
            weeklyWindow: nil,
            errorMessage: String(describing: error)
        )
    }

}

public enum CodexExecutableResolver {
    public static func resolve() throws -> String {
        try resolveCandidate(
            environmentPath: ProcessInfo.processInfo.environment["PATH"] ?? "",
            homeDirectory: NSHomeDirectory(),
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }

    public static func resolveCandidate(
        environmentPath: String,
        homeDirectory: String,
        isExecutable: (String) -> Bool
    ) throws -> String {
        let pathCandidates = environmentPath
            .split(separator: ":")
            .map { "\($0)/codex" }

        let candidates = [
            "\(homeDirectory)/.local/bin/codex",
            "\(homeDirectory)/.codex/packages/standalone/current/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ] + pathCandidates

        if let candidate = candidates.first(where: isExecutable) {
            return candidate
        }

        throw CodexAppServerError.missingExecutable
    }
}

public final class ProcessCodexRPCTransport: CodexRPCTransport, @unchecked Sendable {
    private let process: Process
    private let input: Pipe
    private let output: Pipe
    private let errorOutput: Pipe
    private var buffer = Data()
    private var messages: [[String: Any]] = []
    private var stderr = ""
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)

    public init(codexPath: String) throws {
        process = Process()
        input = Pipe()
        output = Pipe()
        errorOutput = Pipe()

        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["-s", "read-only", "-a", "untrusted", "app-server"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.appendOutput(handle.availableData)
        }
        errorOutput.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else {
                return
            }
            self?.lock.lock()
            self?.stderr += chunk
            self?.lock.unlock()
        }

        try process.run()
    }

    public func send(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        input.fileHandleForWriting.write(data)
        input.fileHandleForWriting.write(Data([0x0A]))
    }

    public func readMessage(timeoutSeconds: TimeInterval) throws -> [String: Any] {
        if let message = popMessage() {
            return message
        }

        let result = semaphore.wait(timeout: .now() + timeoutSeconds)
        if result == .timedOut {
            lock.lock()
            let stderrText = stderr
            lock.unlock()
            throw CodexAppServerError.transport("codex app-server 读取超时。\(stderrText.isEmpty ? "" : " stderr: \(stderrText)")")
        }

        if let message = popMessage() {
            return message
        }

        throw CodexAppServerError.transport("codex app-server 没有返回可解析的 JSON-RPC 消息。")
    }

    public func close() {
        output.fileHandleForReading.readabilityHandler = nil
        errorOutput.fileHandleForReading.readabilityHandler = nil
        input.fileHandleForWriting.closeFile()
        if process.isRunning {
            process.terminate()
        }
    }

    private func appendOutput(_ data: Data) {
        guard !data.isEmpty else {
            return
        }

        lock.lock()
        buffer.append(data)

        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
                continue
            }
            messages.append(object)
            semaphore.signal()
        }

        lock.unlock()
    }

    private func popMessage() -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        guard !messages.isEmpty else {
            return nil
        }
        return messages.removeFirst()
    }
}
