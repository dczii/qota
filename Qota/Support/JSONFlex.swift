import Foundation

enum JSONFlex {
    static func object(from data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else {
            throw UsageError.failed("Unexpected JSON shape")
        }
        return object
    }

    static func value(_ root: Any?, _ path: String...) -> Any? {
        value(root, path)
    }

    static func value(_ root: Any?, _ path: [String]) -> Any? {
        var current: Any? = root
        for key in path {
            if let object = current as? [String: Any] {
                current = object[key]
            } else if let object = current as? NSDictionary {
                current = object[key]
            } else {
                return nil
            }
        }
        return current
    }

    static func string(_ root: Any?, _ path: String...) -> String? {
        let raw = value(root, path)
        if let string = raw as? String, !string.isEmpty { return string }
        if let number = raw as? NSNumber { return number.stringValue }
        return nil
    }

    static func number(_ root: Any?, _ path: String...) -> Double? {
        let raw = value(root, path)
        if let number = raw as? NSNumber { return number.doubleValue }
        if let double = raw as? Double { return double }
        if let int = raw as? Int { return Double(int) }
        if let string = raw as? String, let double = Double(string) { return double }
        return nil
    }

    static func object(_ root: Any?, _ path: String...) -> [String: Any]? {
        value(root, path) as? [String: Any]
    }
}
