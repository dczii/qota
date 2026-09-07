import Foundation

enum ClaudeCredentials {
    struct Token {
        var accessToken: String
        var expiresAt: Date?
    }

    static func load() async -> Token? {
        if let fromFile = readCredentialsFile() {
            return fromFile
        }
        if let fromLegacy = readLegacyClaudeJSON() {
            return fromLegacy
        }
        for service in ["Claude Code-credentials", "Claude Code"] {
            if let raw = await KeychainPassword.genericPassword(service: service),
               let token = parse(raw) {
                return token
            }
        }
        return nil
    }

    private static func credentialsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude")
            .appending(path: ".credentials.json")
    }

    private static func readCredentialsFile() -> Token? {
        let url = credentialsURL()
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return parseJSON(json)
    }

    private static func readLegacyClaudeJSON() -> Token? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return parseJSON(json)
    }

    private static func parse(_ raw: String) -> Token? {
        if raw.hasPrefix("sk-ant-") || raw.hasPrefix("eyJ") {
            return Token(accessToken: raw, expiresAt: nil)
        }
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return parseJSON(json)
    }

    private static func parseJSON(_ json: Any) -> Token? {
        let oauth = JSONFlex.object(json, "claudeAiOauth") ?? JSONFlex.object(json, "oauth") ?? (json as? [String: Any])
        let access = JSONFlex.string(oauth, "accessToken")
            ?? JSONFlex.string(oauth, "access_token")
            ?? JSONFlex.string(json, "accessToken")
        guard let access, !access.isEmpty else { return nil }
        let expiry = FlexDate.parse(JSONFlex.value(oauth, "expiresAt") ?? JSONFlex.value(oauth, "expires_at"))
        return Token(accessToken: access, expiresAt: expiry)
    }
}
