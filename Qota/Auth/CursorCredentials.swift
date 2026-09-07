import Foundation

enum CursorCredentials {
    struct Session {
        var accessToken: String
        var userID: String?
        var source: String
    }

    static func load() async -> Session? {
        if let fromIDE = readIDEDatabase() {
            return fromIDE
        }
        if let fromKeychain = await readCLIKeychain() {
            return fromKeychain
        }
        if let fromFile = readAuthFile() {
            return fromFile
        }
        return nil
    }

    static func hasAnyStore() -> Bool {
        FileManager.default.fileExists(atPath: ideDatabaseURL().path)
            || FileManager.default.fileExists(atPath: authFileURL().path)
            || FileManager.default.fileExists(atPath: linuxAuthFileURL().path)
    }

    private static func readIDEDatabase() -> Session? {
        let database = ideDatabaseURL()
        guard FileManager.default.fileExists(atPath: database.path) else { return nil }
        let sqlite = URL(fileURLWithPath: "/usr/bin/sqlite3")
        let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1;"
        let arguments = ["-readonly", "-noheader", "-batch", database.path, query]
        guard let result = try? runSync(executable: sqlite, arguments: arguments),
              result.exitCode == 0 else {
            return nil
        }
        let token = result.stdoutString
        guard !token.isEmpty else { return nil }
        return Session(accessToken: token, userID: jwtSubject(token), source: "Cursor IDE")
    }

    private static func readCLIKeychain() async -> Session? {
        guard let token = await KeychainPassword.genericPassword(
            service: "cursor-access-token",
            account: "cursor-user"
        ), !token.isEmpty else {
            return nil
        }
        return Session(accessToken: token, userID: jwtSubject(token), source: "Cursor CLI")
    }

    private static func readAuthFile() -> Session? {
        for url in [authFileURL(), linuxAuthFileURL()] {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            let token = JSONFlex.string(json, "accessToken")
                ?? JSONFlex.string(json, "access_token")
                ?? JSONFlex.string(json, "authInfo", "accessToken")
            if let token, !token.isEmpty {
                return Session(accessToken: token, userID: jwtSubject(token), source: "Cursor CLI")
            }
        }
        return nil
    }

    private static func ideDatabaseURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    private static func authFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".cursor/auth.json")
    }

    private static func linuxAuthFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/cursor/auth.json")
    }

    private static func jwtSubject(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - payload.count % 4
        if pad < 4 { payload += String(repeating: "=", count: pad) }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var sub = json["sub"] as? String else {
            return nil
        }
        if let range = sub.range(of: "|") {
            sub = String(sub[range.upperBound...])
        }
        return sub.isEmpty ? nil : sub
    }

    private static func runSync(executable: URL, arguments: [String]) throws -> ProcessRunner.Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return ProcessRunner.Result(
            exitCode: process.terminationStatus,
            stdout: stdout.fileHandleForReading.readDataToEndOfFile(),
            stderr: stderr.fileHandleForReading.readDataToEndOfFile()
        )
    }
}
