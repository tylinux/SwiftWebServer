public struct HTTPHeaders: Sendable, Equatable {
    private var storage: [String: [String]]

    public init() {
        self.storage = [:]
    }

    public init(_ headers: [(String, String)]) {
        self.storage = [:]
        for (name, value) in headers {
            add(name: name, value: value)
        }
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
    }

    public subscript(name: String) -> String? {
        storage[Self.normalize(name)]?.first
    }

    public func allValues(for name: String) -> [String] {
        storage[Self.normalize(name)] ?? []
    }

    public mutating func add(name: String, value: String) {
        let key = Self.normalize(name)
        storage[key, default: []].append(value)
    }

    public mutating func set(name: String, value: String) {
        let key = Self.normalize(name)
        storage[key] = [value]
    }

    public func allHeaderLines() -> [(name: String, value: String)] {
        storage.flatMap { key, values in
            values.map { (name: key, value: $0) }
        }
    }
}
