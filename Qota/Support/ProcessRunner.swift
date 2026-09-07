import Foundation

enum ProcessRunner {
    struct Result {
        var exitCode: Int32
        var stdout: Data
        var stderr: Data

        var stdoutString: String {
            String(data: stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    enum RunnerError: Error {
        case timeout
        case launchFailed(String)
    }

    static func run(
        executable: URL,
        arguments: [String] = [],
        extraEnvironment: [String: String] = [:],
        currentDirectory: URL? = nil,
        timeout: TimeInterval = 12
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectory
            if !extraEnvironment.isEmpty {
                var environment = ProcessInfo.processInfo.environment
                extraEnvironment.forEach { environment[$0.key] = $0.value }
                process.environment = environment
            }

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.standardInput = FileHandle.nullDevice

            let lock = NSLock()
            var settled = false
            let finish: (Result<Result, Error>) -> Void = { outcome in
                lock.lock()
                defer { lock.unlock() }
                guard !settled else { return }
                settled = true
                continuation.resume(with: outcome)
            }

            process.terminationHandler = { finished in
                let result = Result(
                    exitCode: finished.terminationStatus,
                    stdout: stdout.fileHandleForReading.readDataToEndOfFile(),
                    stderr: stderr.fileHandleForReading.readDataToEndOfFile()
                )
                finish(.success(result))
            }

            do {
                try process.run()
            } catch {
                finish(.failure(RunnerError.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                    finish(.failure(RunnerError.timeout))
                }
            }
        }
    }
}
