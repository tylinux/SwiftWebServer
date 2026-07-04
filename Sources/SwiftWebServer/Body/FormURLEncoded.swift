import Foundation

public enum FormURLEncodedError: Error, Sendable {
    case missingContentType
    case invalidBodyEncoding
}

public extension Request {
    /// Parses the request body as `application/x-www-form-urlencoded` data.
    ///
    /// - Returns: A dictionary of form fields. Duplicate keys keep their last value.
    /// - Throws: `FormURLEncodedError` if the content type is wrong or the body is not valid UTF-8.
    func formFields() throws -> [String: String] {
        guard let contentType = headers["Content-Type"],
              contentType.lowercased().hasPrefix("application/x-www-form-urlencoded") else {
            throw FormURLEncodedError.missingContentType
        }

        guard let bodyString = String(data: body, encoding: .utf8) else {
            throw FormURLEncodedError.invalidBodyEncoding
        }

        var fields: [String: String] = [:]
        for pair in bodyString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            let key = percentDecoded(parts[0]) ?? parts[0]
            let value = parts.count > 1 ? (percentDecoded(parts[1]) ?? parts[1]) : ""
            fields[key] = value
        }
        return fields
    }
}

private func percentDecoded(_ string: String) -> String? {
    string.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
}
