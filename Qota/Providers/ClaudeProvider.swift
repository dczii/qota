import Foundation

struct ClaudeProvider: UsageProvider {
    let id: ProviderID = .claude

    func fetch() async -> ProviderStatus {
        guard let credentials = await ClaudeCredentials.load() else {
            return .signedOut("Sign in with Claude Code (`claude auth login`)")
        }
        if let expiry = credentials.expiresAt, expiry < Date().addingTimeInterval(-60) {
            return .signedOut("Claude login expired — run `claude auth login`")
        }

        do {
            let data = try await requestUsage(accessToken: credentials.accessToken)
            let snapshot = try parse(data)
            return .ready(snapshot)
        } catch let error as UsageError {
            return map(error)
        } catch {
            return .failed("Could not reach Anthropic")
        }
    }

    private func requestUsage(accessToken: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Qota/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await HTTPClient.send(request)
        if response.statusCode == 429 {
            let versioned = await claudeCodeUserAgent()
            if versioned != "Qota/1.0" {
                var retry = request
                retry.setValue(versioned, forHTTPHeaderField: "User-Agent")
                let (retryData, retryResponse) = try await HTTPClient.send(retry)
                return try validate(retryData, retryResponse)
            }
            throw UsageError.rateLimited(HTTPClient.retryAfter(from: response)?.timeIntervalSinceNow)
        }
        return try validate(data, response)
    }

    private func validate(_ data: Data, _ response: HTTPURLResponse) throws -> Data {
        switch response.statusCode {
        case 200 ..< 300:
            return data
        case 401, 403:
            throw UsageError.signedOut("Sign in again with Claude Code")
        case 429:
            throw UsageError.rateLimited(HTTPClient.retryAfter(from: response)?.timeIntervalSinceNow)
        default:
            throw UsageError.failed("Claude usage HTTP \(response.statusCode)")
        }
    }

    private func parse(_ data: Data) throws -> ProviderSnapshot {
        let json = try JSONFlex.object(from: data)
        var windows: [UsageWindow] = []
        let buckets: [(id: String, label: String)] = [
            ("five_hour", "5h"),
            ("seven_day", "7d"),
            ("seven_day_sonnet", "Sonnet"),
            ("seven_day_opus", "Opus")
        ]
        for bucket in buckets {
            guard let used = JSONFlex.number(json, bucket.id, "utilization")
                    ?? JSONFlex.number(json, bucket.id, "used_percentage") else {
                continue
            }
            windows.append(
                UsageWindow(
                    id: bucket.id,
                    label: bucket.label,
                    usedPercent: PercentFormat.normalized(used),
                    remainingText: nil,
                    resetsAt: FlexDate.parse(JSONFlex.value(json, bucket.id, "resets_at"))
                )
            )
        }
        guard !windows.isEmpty else {
            throw UsageError.failed("Claude usage payload had no windows")
        }
        return ProviderSnapshot(
            provider: .claude,
            planLabel: nil,
            fetchedAt: Date(),
            windows: windows,
            footnote: extraUsageFootnote(json)
        )
    }

    private func extraUsageFootnote(_ json: [String: Any]) -> String? {
        guard JSONFlex.number(json, "extra_usage", "is_enabled") == 1
                || (JSONFlex.value(json, "extra_usage", "is_enabled") as? Bool) == true else {
            return nil
        }
        if let used = JSONFlex.number(json, "extra_usage", "used_credits"),
           let limit = JSONFlex.number(json, "extra_usage", "monthly_limit") {
            return "Extra \(Int(used))/\(Int(limit))"
        }
        return "Extra usage on"
    }

    private func claudeCodeUserAgent() async -> String {
        guard let binary = await BinaryLocator.find("claude") else {
            return "claude-code/2.1.80"
        }
        if let result = try? await ProcessRunner.run(
            executable: binary,
            arguments: ["--version"],
            timeout: 4
        ), result.exitCode == 0 {
            let digits = result.stdoutString.split(whereSeparator: { !$0.isNumber && $0 != "." }).first
            if let digits, !digits.isEmpty {
                return "claude-code/\(digits)"
            }
        }
        return "claude-code/2.1.80"
    }

    private func map(_ error: UsageError) -> ProviderStatus {
        switch error {
        case .signedOut(let message):
            return .signedOut(message)
        case .unavailable(let message):
            return .unavailable(message)
        case .rateLimited(let seconds):
            let retry = seconds.map { Date().addingTimeInterval($0) }
            return .rateLimited(retryAfter: retry)
        case .failed(let message):
            return .failed(message)
        }
    }
}
