import Foundation

/// Talks to `codex app-server` over stdio JSON-RPC.
///
/// A session is short-lived: spawn, `initialize`, read the rate limits, exit. Keeping a
/// long-running server alive is cheaper but leaves a child process to babysit, and the
/// handshake costs only a few seconds against a one-minute poll.
actor CodexRPCClient {
    static let shared = CodexRPCClient()

    private static let initializeID = 1
    private static let rateLimitsID = 2

    func rateLimits() async throws -> Data {
        guard let binary = await BinaryLocator.find("codex") else {
            throw UsageError.unavailable("Install Codex CLI, then run `codex login`")
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    continuation.resume(returning: try Self.readRateLimits(binary: binary, timeout: 30))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func readRateLimits(binary: URL, timeout: TimeInterval) throws -> Data {
        let process = Process()
        process.executableURL = binary
        process.arguments = ["app-server"]
        process.environment = environment()

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw UsageError.unavailable("Could not start `codex app-server`")
        }
        defer {
            if process.isRunning { process.terminate() }
        }

        let stream = LineStream(output.fileHandleForReading)
        stream.start()

        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(0x0A)
            try input.fileHandleForWriting.write(contentsOf: data)
        }

        do {
            try send([
                "jsonrpc": "2.0",
                "id": initializeID,
                "method": "initialize",
                "params": ["clientInfo": ["name": "Qota", "title": "Qota", "version": "1.0"]]
            ])
        } catch {
            throw UsageError.failed("Could not talk to `codex app-server`")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while let line = stream.next(before: deadline) {
            guard let message = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let id = message["id"] as? Int else {
                continue
            }

            if let failure = message["error"] as? [String: Any] {
                throw UsageError.failed(JSONFlex.string(failure, "message") ?? "Codex app-server error")
            }

            switch id {
            case initializeID:
                do {
                    try send(["jsonrpc": "2.0", "method": "initialized", "params": [:]])
                    try send(["jsonrpc": "2.0", "id": rateLimitsID, "method": "account/rateLimits/read", "params": [:]])
                } catch {
                    throw UsageError.failed("Could not talk to `codex app-server`")
                }
            case rateLimitsID:
                guard let result = message["result"] else {
                    throw UsageError.failed("Codex returned no rate limits")
                }
                return try JSONSerialization.data(withJSONObject: result)
            default:
                continue
            }
        }

        throw UsageError.failed("`codex app-server` did not respond")
    }

    /// A GUI app starts with a bare PATH, so hand Codex the directories its own installer uses.
    private static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extras = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "\(home)/.local/bin"]
        let existing = environment["PATH"].map { $0.split(separator: ":").map(String.init) } ?? []
        environment["PATH"] = (existing + extras.filter { !existing.contains($0) }).joined(separator: ":")
        return environment
    }
}

/// Turns a pipe into newline-delimited strings that a caller can pull with a deadline,
/// so a silent app-server cannot wedge the poll forever.
private final class LineStream {
    private let handle: FileHandle
    private let condition = NSCondition()
    private var pending: [String] = []
    private var buffer = Data()
    private var closed = false

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    func start() {
        DispatchQueue.global(qos: .utility).async { [self] in
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                condition.lock()
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = Data(buffer[buffer.startIndex ..< newline])
                    buffer.removeSubrange(buffer.startIndex ... newline)
                    if let text = String(data: line, encoding: .utf8), !text.isEmpty {
                        pending.append(text)
                    }
                }
                condition.signal()
                condition.unlock()
            }
            condition.lock()
            closed = true
            condition.broadcast()
            condition.unlock()
        }
    }

    func next(before deadline: Date) -> String? {
        condition.lock()
        defer { condition.unlock() }
        while pending.isEmpty && !closed {
            if !condition.wait(until: deadline) { return nil }
        }
        return pending.isEmpty ? nil : pending.removeFirst()
    }
}
