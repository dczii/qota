import Foundation

enum HTTPClient {
    static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.failed("Invalid HTTP response")
        }
        return (data, http)
    }

    static func retryAfter(from response: HTTPURLResponse) -> Date? {
        if let value = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(value) {
            return Date().addingTimeInterval(seconds)
        }
        return nil
    }
}
