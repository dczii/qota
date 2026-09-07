import Foundation

struct CursorProvider: UsageProvider {
    let id: ProviderID = .cursor

    func fetch() async -> ProviderStatus {
        guard let session = await CursorCredentials.load() else {
            if CursorCredentials.hasAnyStore() {
                return .signedOut("Cursor is installed — sign in to Cursor or run `agent login`")
            }
            return .signedOut("Sign in to Cursor or Cursor CLI (`agent login`)")
        }

        do {
            if let snapshot = try await fetchPeriodUsage(session) {
                return .ready(snapshot)
            }
            if let snapshot = try await fetchLegacyUsage(session) {
                return .ready(snapshot)
            }
            return .failed("Cursor usage payload was empty")
        } catch let error as UsageError {
            return map(error)
        } catch {
            return .failed("Could not reach Cursor")
        }
    }

    private func fetchPeriodUsage(_ session: CursorCredentials.Session) async throws -> ProviderSnapshot? {
        var request = URLRequest(url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Qota/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 20

        var (data, response) = try await HTTPClient.send(request)
        if response.statusCode == 401 || response.statusCode == 403 {
            (data, response) = try await sendCookieFallback(session)
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw UsageError.signedOut("Sign in again to Cursor")
        }
        if response.statusCode == 429 {
            throw UsageError.rateLimited(HTTPClient.retryAfter(from: response)?.timeIntervalSinceNow)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            return nil
        }
        return parsePeriod(data)
    }

    private func sendCookieFallback(_ session: CursorCredentials.Session) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "https://cursor.com/api/dashboard/get-current-period-usage")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Qota/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        if let cookie = cookieValue(session) {
            request.setValue("WorkosCursorSessionToken=\(cookie)", forHTTPHeaderField: "Cookie")
        } else {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 20
        return try await HTTPClient.send(request)
    }

    private func fetchLegacyUsage(_ session: CursorCredentials.Session) async throws -> ProviderSnapshot? {
        var request = URLRequest(url: URL(string: "https://api2.cursor.sh/auth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Qota/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await HTTPClient.send(request)
        guard (200 ..< 300).contains(response.statusCode) else { return nil }
        return parseLegacy(data)
    }

    private func parsePeriod(_ data: Data) -> ProviderSnapshot? {
        guard let json = try? JSONFlex.object(from: data) else { return nil }
        let planUsage = JSONFlex.object(json, "planUsage")
            ?? JSONFlex.object(json, "individualUsage", "plan")
        let billingEnd = FlexDate.parse(
            JSONFlex.value(json, "billingCycleEnd") ?? JSONFlex.value(json, "billing_cycle_end")
        )
        var windows: [UsageWindow] = []

        if let planUsage {
            let limit = JSONFlex.number(planUsage, "limit")
            let used = JSONFlex.number(planUsage, "used")
                ?? JSONFlex.number(planUsage, "includedSpend")
                ?? JSONFlex.number(planUsage, "totalSpend")
            let remaining = JSONFlex.number(planUsage, "remaining")
            let percent = JSONFlex.number(planUsage, "totalPercentUsed")

            var usedPercent: Double?
            if let percent {
                usedPercent = PercentFormat.normalized(percent)
            } else if let used, let limit, limit > 0 {
                usedPercent = min(100, max(0, (used / limit) * 100))
            } else if let remaining, let limit, limit > 0 {
                usedPercent = min(100, max(0, ((limit - remaining) / limit) * 100))
            }

            var remainingText: String?
            if let remaining {
                remainingText = "\(MoneyFormat.usd(cents: remaining)) left"
            } else if let used, let limit {
                remainingText = "\(MoneyFormat.usd(cents: max(0, limit - used))) left"
            }

            if let usedPercent {
                windows.append(
                    UsageWindow(
                        id: "included",
                        label: "Plan",
                        usedPercent: usedPercent,
                        remainingText: remainingText,
                        resetsAt: billingEnd
                    )
                )
            }

            if let api = JSONFlex.number(planUsage, "apiPercentUsed") {
                windows.append(
                    UsageWindow(
                        id: "api",
                        label: "API",
                        usedPercent: PercentFormat.normalized(api),
                        remainingText: nil,
                        resetsAt: billingEnd
                    )
                )
            }
            if let auto = JSONFlex.number(planUsage, "autoPercentUsed") {
                windows.append(
                    UsageWindow(
                        id: "auto",
                        label: "Auto",
                        usedPercent: PercentFormat.normalized(auto),
                        remainingText: nil,
                        resetsAt: billingEnd
                    )
                )
            }
        }

        guard !windows.isEmpty else { return nil }
        return ProviderSnapshot(
            provider: .cursor,
            planLabel: JSONFlex.string(json, "membershipType"),
            fetchedAt: Date(),
            windows: windows,
            footnote: nil
        )
    }

    private func parseLegacy(_ data: Data) -> ProviderSnapshot? {
        guard let json = try? JSONFlex.object(from: data) else { return nil }
        let start = FlexDate.parse(JSONFlex.value(json, "startOfMonth"))
        let preferred = ["gpt-4", "gpt-4o", "default"]
        var buckets: [(String, [String: Any])] = []
        for (key, value) in json {
            if let object = value as? [String: Any],
               object["numRequests"] != nil || object["maxRequestUsage"] != nil {
                buckets.append((key, object))
            }
        }
        let chosen = preferred.compactMap { name in buckets.first(where: { $0.0 == name }) }.first
            ?? buckets.max(by: {
                (JSONFlex.number($0.1, "maxRequestUsage") ?? 0) < (JSONFlex.number($1.1, "maxRequestUsage") ?? 0)
            })
        guard let chosen else { return nil }
        let used = JSONFlex.number(chosen.1, "numRequests") ?? 0
        let max = JSONFlex.number(chosen.1, "maxRequestUsage") ?? 0
        let remaining = max(0, max - used)
        let percent = max > 0 ? (used / max) * 100 : 0
        let window = UsageWindow(
            id: chosen.0,
            label: "Included",
            usedPercent: percent,
            remainingText: "\(Int(remaining)) left",
            resetsAt: start.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil
        )
        return ProviderSnapshot(
            provider: .cursor,
            planLabel: nil,
            fetchedAt: Date(),
            windows: [window],
            footnote: nil
        )
    }

    private func cookieValue(_ session: CursorCredentials.Session) -> String? {
        guard let userID = session.userID else { return session.accessToken }
        return "\(userID)::\(session.accessToken)"
    }

    private func map(_ error: UsageError) -> ProviderStatus {
        switch error {
        case .signedOut(let message):
            return .signedOut(message)
        case .unavailable(let message):
            return .unavailable(message)
        case .rateLimited(let seconds):
            return .rateLimited(retryAfter: seconds.map { Date().addingTimeInterval($0) })
        case .failed(let message):
            return .failed(message)
        }
    }
}
