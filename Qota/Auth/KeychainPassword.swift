import Foundation

enum KeychainPassword {
    static func genericPassword(service: String, account: String? = nil) async -> String? {
        var arguments = ["find-generic-password", "-s", service, "-w"]
        if let account, !account.isEmpty {
            arguments.insert(contentsOf: ["-a", account], at: 1)
        }
        do {
            let result = try await ProcessRunner.run(
                executable: URL(fileURLWithPath: "/usr/bin/security"),
                arguments: arguments,
                timeout: 8
            )
            guard result.exitCode == 0 else { return nil }
            let value = result.stdoutString
            return value.isEmpty ? nil : value
        } catch {
            return nil
        }
    }
}
