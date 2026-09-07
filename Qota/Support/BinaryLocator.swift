import Foundation

enum BinaryLocator {
    static func find(_ name: String) async -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var directories: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/bin"),
            URL(fileURLWithPath: "/usr/local/bin"),
            URL(fileURLWithPath: "/usr/bin"),
            URL(fileURLWithPath: "/bin"),
            home.appending(path: ".local/bin"),
            home.appending(path: ".volta/bin"),
            home.appending(path: ".cargo/bin"),
            home.appending(path: ".bun/bin"),
            home.appending(path: "Library/Application Support/fnm/aliases/default/bin")
        ]

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map { URL(fileURLWithPath: String($0)) })
        }

        if let nvmVersions = try? fileManager.contentsOfDirectory(
            at: home.appending(path: ".nvm/versions/node"),
            includingPropertiesForKeys: nil
        ) {
            directories.append(contentsOf: nvmVersions.map { $0.appending(path: "bin") })
        }

        for directory in directories {
            let candidate = directory.appending(path: name)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        if let fromShell = await commandFromLoginShell(name) {
            return fromShell
        }
        return nil
    }

    private static func commandFromLoginShell(_ name: String) async -> URL? {
        let zsh = URL(fileURLWithPath: "/bin/zsh")
        guard FileManager.default.isExecutableFile(atPath: zsh.path) else { return nil }
        do {
            let result = try await ProcessRunner.run(
                executable: zsh,
                arguments: ["-lc", "command -v \(shellEscape(name))"],
                timeout: 4
            )
            guard result.exitCode == 0 else { return nil }
            let path = result.stdoutString
            guard !path.isEmpty else { return nil }
            let url = URL(fileURLWithPath: path)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        } catch {
            return nil
        }
    }

    private static func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
