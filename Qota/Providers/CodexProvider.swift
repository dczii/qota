import Foundation

struct CodexProvider: UsageProvider {
    let id: ProviderID = .codex

    func fetch() async -> ProviderStatus {
        if await BinaryLocator.find("codex") == nil {
            return .unavailable("Install Codex CLI, then run `codex login`")
        }

        do {
            let data = try await CodexRPCClient.shared.rateLimits()
            let snapshot = try parse(data)
            return .ready(snapshot)
        } catch let error as UsageError {
            if case .unavailable = error, !FileManager.default.fileExists(atPath: authURL().path) {
                return .signedOut("Sign in with Codex CLI (`codex login`)")
            }
            return error.status
        } catch {
            return .failed("Could not read Codex rate limits")
        }
    }

    private func authURL() -> URL {
        if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: custom).appending(path: "auth.json")
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/auth.json")
    }

    private func parse(_ data: Data) throws -> ProviderSnapshot {
        let json = try JSONFlex.object(from: data)
        let root = JSONFlex.object(json, "rateLimits") ?? json
        var windows: [UsageWindow] = []

        if let window = parseWindow(root, key: "primary", fallbackLabel: "5h") {
            windows.append(window)
        }
        if let window = parseWindow(root, key: "secondary", fallbackLabel: "7d") {
            windows.append(window)
        }

        if windows.isEmpty {
            throw UsageError.failed("Codex rate-limit payload had no windows")
        }

        let plan = JSONFlex.string(root, "planType") ?? JSONFlex.string(json, "planType")
        var footnote: String?
        if let credits = JSONFlex.object(root, "credits"),
           (credits["hasCredits"] as? Bool) == true,
           (credits["unlimited"] as? Bool) != true,
           let balance = JSONFlex.string(credits, "balance") ?? JSONFlex.number(credits, "balance").map({ String($0) }) {
            footnote = "Credits \(balance)"
        }

        return ProviderSnapshot(
            provider: .codex,
            planLabel: plan,
            fetchedAt: Date(),
            windows: windows,
            footnote: footnote
        )
    }

    private func parseWindow(_ root: [String: Any], key: String, fallbackLabel: String) -> UsageWindow? {
        guard let object = JSONFlex.object(root, key) else { return nil }
        let used = JSONFlex.number(object, "usedPercent")
            ?? JSONFlex.number(object, "used_percent")
            ?? JSONFlex.number(object, "usedPercentage")
        guard let used else { return nil }
        let minutes = JSONFlex.number(object, "windowDurationMins") ?? JSONFlex.number(object, "window_duration_mins")
        let label = labelForWindow(minutes: minutes, fallback: fallbackLabel)
        return UsageWindow(
            id: key,
            label: label,
            usedPercent: PercentFormat.normalized(used),
            remainingText: nil,
            resetsAt: FlexDate.parse(JSONFlex.value(object, "resetsAt") ?? JSONFlex.value(object, "resets_at"))
        )
    }

    private func labelForWindow(minutes: Double?, fallback: String) -> String {
        guard let minutes else { return fallback }
        switch minutes {
        case 250 ... 350: return "5h"
        case 1_400 ... 1_500: return "1d"
        case 9_000 ... 12_000: return "7d"
        default:
            if minutes >= 60 {
                return "\(Int((minutes / 60).rounded()))h"
            }
            return fallback
        }
    }
}
