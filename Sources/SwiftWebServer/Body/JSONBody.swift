import Foundation

extension Request {
    public func decodeJSON<T: Decodable & Sendable>(
        _ type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try decoder.decode(type, from: body)
    }
}

extension Response {
    public init(json: some Encodable & Sendable, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(json)
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: "application/json")
        self.init(status: .ok, headers: headers, body: .data(data))
    }
}
