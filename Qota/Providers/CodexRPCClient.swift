import Foundation

final class CodexRPCClient: @unchecked Sendable {
    static let shared = CodexRPCClient()

    private let lock = NSLock()
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var ready = false

    func rateLimits() async throws -> Data {
        try await ensureReady()
        return try await request(method: "account/rateLimits/read", params: NSNull(), timeout: 12)
    }

    func shutdown() {
        lock.lock()
        process?.terminate()
        process = nil
        stdinHandle = nil
        ready = false
        let waiting = pending
        pending.removeAll()
        lock.unlock()
        for (_, continuation) in waiting {
            continuation.resume(throwing: UsageError.unavailable("Codex app-server stopped"))
        }
    }

    private func ensureReady() async throws {
        if isReady { return }
        guard let binary = await BinaryLocator.find("codex") else {
            throw UsageError.unavailable("Install Codex CLI, then run `codex login`")
        }
        var lastError: Error = UsageError.unavailable("Could not start `codex app-server`")
        for arguments in [["app-server", "--stdio"], ["app-server"]] {
            do {
                try await start(binary: binary, arguments: arguments)
                _ = try await request(
                    method: "initialize",
                    params: [
                        "clientInfo": [
                            "name": "Qota",
                            "title": "Qota",
                            "version": "1.0.0"
                        ]
                    ] as [String: Any],
                    timeout: 12
                )
                try write([
                    "jsonrpc": "2.0",
                    "method": "initialized",
                    "params": [:] as [String: Any]
                ])
                lock.lock()
                ready = true
                lock.unlock()
                return
            } catch {
                lastError = error
                shutdown()
            }
        }
        throw lastError
    }

    private var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready && process?.isRunning == true
    }

    private func start(binary: URL, arguments: [String]) async throws {
        shutdown()
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.environment = augmentedPATH()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            self?.consume(chunk)
        }
        process.terminationHandler = { [weak self] _ in
            self?.handleTermination()
        }

        do {
            try process.run()
        } catch {
            throw UsageError.unavailable("Could not start `codex app-server`")
        }

        lock.lock()
        self.process = process
        self.stdinHandle = stdin.fileHandleForWriting
        lock.unlock()
    }

    private func request(method: String, params: Any, timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { try await self.requestOnce(method: method, params: params) }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                self.shutdown()
                throw UsageError.failed("Codex app-server timed out")
            }
            guard let data = try await group.next() else {
                throw UsageError.failed("Codex app-server timed out")
            }
            group.cancelAll()
            return data
        }
    }

    private func requestOnce(method: String, params: Any) async throws -> Data {
        let id: Int = {
            lock.lock()
            defer { lock.unlock() }
            let value = nextID
            nextID += 1
            return value
        }()
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pending[id] = continuation
            lock.unlock()
            do {
                try write([
                    "jsonrpc": "2.0",
                    "id": id,
                    "method": method,
                    "params": params
                ])
            } catch {
                lock.lock()
                pending.removeValue(forKey: id)
                lock.unlock()
                continuation.resume(throwing: error)
            }
        }
    }

    private func write(_ message: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: message)
        var line = data
        line.append(0x0A)
        lock.lock()
        defer { lock.unlock() }
        guard let handle = stdinHandle else {
            throw UsageError.unavailable("Codex app-server is not running")
        }
        try handle.write(contentsOf: line)
    }

    private func consume(_ chunk: Data) {
        if chunk.isEmpty {
            handleTermination()
            return
        }
        lock.lock()
        buffer.append(chunk)
        let extracted = extractMessagesLocked()
        lock.unlock()
        for message in extracted {
            deliver(message)
        }
    }

    private func extractMessagesLocked() -> [[String: Any]] {
        var messages: [[String: Any]] = []
        while let message = popMessageLocked() {
            messages.append(message)
        }
        return messages
    }

    private func popMessageLocked() -> [String: Any]? {
        if let range = buffer.range(of: Data("Content-Length:".utf8)) {
            // LSP-style framing
            guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8), in: range.lowerBound..<buffer.endIndex)
                    ?? buffer.range(of: Data("\n\n".utf8), in: range.lowerBound..<buffer.endIndex) else {
                return nil
            }
            let header = String(data: buffer[range.lowerBound..<headerEnd.lowerBound], encoding: .utf8) ?? ""
            let lengthLine = header.split(whereSeparator: \.isNewline).first(where: { $0.lowercased().contains("content-length") })
            let lengthValue = lengthLine?.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
            guard let lengthValue, let length = Int(lengthValue) else { return nil }
            let bodyStart = headerEnd.upperBound
            guard buffer.count >= bodyStart + length else { return nil }
            let body = buffer[bodyStart..<(bodyStart + length)]
            buffer.removeSubrange(range.lowerBound..<(bodyStart + length))
            return (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        }

        guard let newline = buffer.firstIndex(of: 0x0A) else { return nil }
        let line = buffer[..<newline]
        buffer.removeSubrange(...newline)
        if line.isEmpty { return nil }
        return (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any]
    }

    private func deliver(_ message: [String: Any]) {
        guard let id = jsonRPCID(message["id"]) else {
            return
        }
        lock.lock()
        let continuation = pending.removeValue(forKey: id)
        lock.unlock()
        guard let continuation else { return }
        if let error = message["error"] as? [String: Any] {
            let text = (error["message"] as? String) ?? "Codex RPC error"
            continuation.resume(throwing: UsageError.failed(text))
            return
        }
        let result = message["result"] ?? [:]
        if JSONSerialization.isValidJSONObject(result),
           let data = try? JSONSerialization.data(withJSONObject: result) {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: UsageError.failed("Codex returned an empty rate-limit payload"))
        }
    }

    private func handleTermination() {
        lock.lock()
        ready = false
        process = nil
        stdinHandle = nil
        let waiting = pending
        pending.removeAll()
        lock.unlock()
        for (_, continuation) in waiting {
            continuation.resume(throwing: UsageError.unavailable("Codex app-server exited"))
        }
    }

    private func jsonRPCID(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private func augmentedPATH() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin").path
        ]
        let current = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = (extras + [current]).joined(separator: ":")
        return environment
    }
}
