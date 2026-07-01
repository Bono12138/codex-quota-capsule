import Foundation

public enum CodexAppServerError: Error, CustomStringConvertible, Sendable {
    case missingExecutable(candidates: [String])
    case transport(String)
    case rpc(String)

    public var description: String {
        message(locale: .zhHans)
    }

    public func message(locale: QuotaLocale) -> String {
        switch self {
        case .missingExecutable(let candidates):
            switch locale {
            case .zhHans:
                let checkedPaths = candidates.isEmpty ? "无候选路径" : candidates.joined(separator: ", ")
                return "找不到 codex 命令。App 已检查：\(checkedPaths)。请在终端运行 which codex 和 codex --version；如果终端可用但 app 仍不可用，请把 codex 放到 ~/.local/bin、/opt/homebrew/bin 或 /usr/local/bin。"
            case .zhHant:
                let checkedPaths = candidates.isEmpty ? "沒有候選路徑" : candidates.joined(separator: ", ")
                return "找不到 codex 指令。App 已檢查：\(checkedPaths)。請在終端機執行 which codex 和 codex --version；如果終端機可用但 App 仍不可用，請把 codex 放到 ~/.local/bin、/opt/homebrew/bin 或 /usr/local/bin。"
            case .en:
                let checkedPaths = candidates.isEmpty ? "no candidate paths" : candidates.joined(separator: ", ")
                return "Could not find the codex command. The app checked: \(checkedPaths). Run which codex and codex --version in Terminal. If Terminal works but the app does not, put codex in ~/.local/bin, /opt/homebrew/bin, or /usr/local/bin."
            }
        case .transport(let message):
            return message
        case .rpc(let message):
            return message
        }
    }
}

public protocol CodexRPCTransport: AnyObject {
    func send(_ payload: [String: Any]) throws
    func readMessage(timeoutSeconds: TimeInterval) throws -> [String: Any]
    func close()
}

public enum CodexAppServerClient {
    public static let defaultTimeoutSeconds: TimeInterval = 30

    public static func fetchCurrent(
        codexPath: String? = nil,
        timeoutSeconds: TimeInterval = defaultTimeoutSeconds,
        locale: QuotaLocale = .zhHans
    ) -> AgentQuotaSnapshot {
        let fetchedAt = Date()

        do {
            let path = try codexPath ?? CodexExecutableResolver.resolve()
            let transport = try ProcessCodexRPCTransport(codexPath: path, locale: locale)
            defer { transport.close() }
            return fetchSnapshot(transport: transport, fetchedAt: fetchedAt, timeoutSeconds: timeoutSeconds, locale: locale)
        } catch {
            return errorSnapshot(fetchedAt: fetchedAt, error, locale: locale)
        }
    }

    public static func fetchSnapshot(
        transport: CodexRPCTransport,
        fetchedAt: Date,
        timeoutSeconds: TimeInterval = defaultTimeoutSeconds,
        locale: QuotaLocale = .zhHans
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

            let initialized = try readUntilID(1, transport: transport, timeoutSeconds: timeoutSeconds, locale: locale)
            if let error = rpcError(from: initialized) {
                return errorSnapshot(fetchedAt: fetchedAt, CodexAppServerError.rpc(error), locale: locale)
            }

            try transport.send(["jsonrpc": "2.0", "method": "initialized", "params": [:]])
            try transport.send(["jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read", "params": [:]])

            let response = try readUntilID(2, transport: transport, timeoutSeconds: timeoutSeconds, locale: locale)
            if let error = rpcError(from: response) {
                return errorSnapshot(fetchedAt: fetchedAt, CodexAppServerError.rpc(error), locale: locale)
            }

            guard let result = response["result"] as? [String: Any] else {
                return errorSnapshot(fetchedAt: fetchedAt, CodexAppServerError.rpc(missingResultMessage(locale)), locale: locale)
            }

            return CodexRateLimitParser.parse(result: result, fetchedAt: fetchedAt)
        } catch {
            return errorSnapshot(fetchedAt: fetchedAt, error, locale: locale)
        }
    }

    private static func readUntilID(
        _ id: Int,
        transport: CodexRPCTransport,
        timeoutSeconds: TimeInterval,
        locale: QuotaLocale
    ) throws -> [String: Any] {
        for _ in 0..<50 {
            let message = try transport.readMessage(timeoutSeconds: timeoutSeconds)
            if let messageID = message["id"] as? Int, messageID == id {
                return message
            }
        }

        throw CodexAppServerError.rpc(noResponseMessage(id: id, locale: locale))
    }

    private static func rpcError(from message: [String: Any]) -> String? {
        guard let error = message["error"] as? [String: Any] else {
            return nil
        }
        return error["message"] as? String ?? "codex app-server returned an unknown RPC error."
    }

    private static func missingResultMessage(_ locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "account/rateLimits/read 回应缺少 result。"
        case .zhHant: "account/rateLimits/read 回應缺少 result。"
        case .en: "account/rateLimits/read response is missing result."
        }
    }

    private static func noResponseMessage(id: Int, locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "codex app-server 没有返回 id=\(id) 的回应。"
        case .zhHant: "codex app-server 沒有返回 id=\(id) 的回應。"
        case .en: "codex app-server did not return a response for id=\(id)."
        }
    }

    private static func errorSnapshot(fetchedAt: Date, _ error: Error, locale: QuotaLocale) -> AgentQuotaSnapshot {
        let message = if let error = error as? CodexAppServerError {
            error.message(locale: locale)
        } else {
            String(describing: error)
        }

        return AgentQuotaSnapshot(
            provider: "codex",
            sourceStatus: .error,
            fetchedAt: fetchedAt,
            shortWindow: nil,
            weeklyWindow: nil,
            errorMessage: message
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
        let candidates = candidatePaths(environmentPath: environmentPath, homeDirectory: homeDirectory)

        if let candidate = candidates.first(where: isExecutable) {
            return candidate
        }

        throw CodexAppServerError.missingExecutable(candidates: candidates)
    }

    public static func candidatePaths(environmentPath: String, homeDirectory: String) -> [String] {
        let explicitCandidates = [
            "\(homeDirectory)/.local/bin/codex",
            "\(homeDirectory)/.codex/packages/standalone/current/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]
        let pathCandidates = environmentPath
            .split(separator: ":")
            .map { "\($0)/codex" }

        var seen = Set<String>()
        return (explicitCandidates + pathCandidates).filter { candidate in
            seen.insert(candidate).inserted
        }
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
    private let locale: QuotaLocale

    public init(codexPath: String, locale: QuotaLocale = .zhHans) throws {
        self.locale = locale
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
            throw CodexAppServerError.transport(ProcessCodexRPCTransport.timeoutMessage(stderr: stderrText, locale: locale))
        }

        if let message = popMessage() {
            return message
        }

        throw CodexAppServerError.transport(ProcessCodexRPCTransport.unparseableMessage(locale: locale))
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

    private static func timeoutMessage(stderr: String, locale: QuotaLocale) -> String {
        let suffix = stderr.isEmpty ? "" : " stderr: \(stderr)"
        switch locale {
        case .zhHans:
            return "codex app-server 读取超时。\(suffix)"
        case .zhHant:
            return "codex app-server 讀取逾時。\(suffix)"
        case .en:
            return "codex app-server timed out while reading.\(suffix)"
        }
    }

    private static func unparseableMessage(locale: QuotaLocale) -> String {
        switch locale {
        case .zhHans: "codex app-server 没有返回可解析的 JSON-RPC 消息。"
        case .zhHant: "codex app-server 沒有返回可解析的 JSON-RPC 訊息。"
        case .en: "codex app-server did not return a parseable JSON-RPC message."
        }
    }
}
