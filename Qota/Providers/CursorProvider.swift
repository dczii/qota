import Foundation

struct CursorProvider: UsageProvider {
    let id: ProviderID = .cursor

    func fetch() async -> ProviderStatus {
        guard let session = await CursorCredentials.load() else {
            if CursorCredentials.hasAnyStore() {
                return .signedOut("Sign in to Cursor, or run `agent login`")
            }
            return .unavailable("Install Cursor or the Cursor CLI")
        }

        do {
            return .ready(try await currentPeriodUsage(session))
        } catch let error as UsageError {
            // The dashboard endpoint is the good one; the legacy request counter is only
            // worth showing when the dashboard is unreachable.
            if let legacy = try? await legacyUsage(session) {
                return .ready(legacy)
            }
            return error.status
        } catch {
            return .failed("Could not reach Cursor")
        }
    }

    private func currentPeriodUsage(_ session: CursorCredentials.Session) async throws -> ProviderSnapshot {
        var request = URLRequest(
            url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "connect-protocol-version")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 20

        let (data, response) = try await HTTPClient.send(request)
        switch response.statusCode {
        case 200 ..< 300:
            break
        case 401, 403:
            throw UsageError.signedOut("Cursor login expired — sign in again")
        case 429:
            throw UsageError.rateLimited(HTTPClient.retryAfter(from: response)?.timeIntervalSinceNow)
        default:
            throw UsageError.failed("Cursor usage HTTP \(response.statusCode)")
        }

        let json = try JSONFlex.object(from: data)
        let plan = JSONFlex.object(json, "planUsage") ?? [:]
        let resetsAt = FlexDate.parse(JSONFlex.value(json, "billingCycleEnd"))

        var windows: [UsageWindow] = []
        if let total = JSONFlex.number(plan, "totalPercentUsed") {
            windows.append(
                UsageWindow(
                    id: "total",
                    label: "Total",
                    usedPercent: PercentFormat.normalized(total),
                    remainingText: nil,
                    resetsAt: resetsAt
                )
            )
        }
        if let api = JSONFlex.number(plan, "apiPercentUsed") {
            windows.append(
                UsageWindow(
                    id: "api",
                    label: "API",
                    usedPercent: PercentFormat.normalized(api),
                    remainingText: nil,
                    resetsAt: resetsAt
                )
            )
        }
        guard !windows.isEmpty else {
            throw UsageError.failed("Cursor usage payload had no spend figures")
        }

        // `totalSpend` is the allowance for the cycle (included plus bonus), not money already spent.
        let allowance = JSONFlex.number(plan, "totalSpend").map { MoneyFormat.usd(cents: $0) }

        return ProviderSnapshot(
            provider: .cursor,
            planLabel: JSONFlex.string(json, "spendLimitUsage", "limitType").map { "\($0) limit" },
            fetchedAt: Date(),
            windows: windows,
            footnote: JSONFlex.string(json, "autoModelSelectedDisplayMessage"),
            headline: allowance
        )
    }

    /// Older accounts only expose a request counter. Useful as a last resort, useless without a cap.
    private func legacyUsage(_ session: CursorCredentials.Session) async throws -> ProviderSnapshot {
        var request = URLRequest(url: URL(string: "https://api2.cursor.sh/auth/usage")!)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await HTTPClient.send(request)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw UsageError.failed("Cursor usage HTTP \(response.statusCode)")
        }

        let json = try JSONFlex.object(from: data)
        guard let bucket = JSONFlex.object(json, "gpt-4"),
              let limit = JSONFlex.number(bucket, "maxRequestUsage"), limit > 0 else {
            throw UsageError.failed("Cursor did not report a request allowance")
        }
        let used = JSONFlex.number(bucket, "numRequests") ?? 0

        return ProviderSnapshot(
            provider: .cursor,
            planLabel: nil,
            fetchedAt: Date(),
            windows: [
                UsageWindow(
                    id: "requests",
                    label: "Requests",
                    usedPercent: PercentFormat.normalized(used / limit * 100),
                    remainingText: "\(Int(limit - used)) left",
                    resetsAt: nil
                )
            ],
            footnote: nil,
            headline: nil
        )
    }
}
