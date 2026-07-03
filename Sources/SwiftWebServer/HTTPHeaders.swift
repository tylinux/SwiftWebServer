public struct HTTPHeaders: Sendable, Equatable {
    private var storage: [(name: String, value: String)]
    private var index: [String: [Int]]

    public init() {
        self.storage = []
        self.index = [:]
    }

    public init(_ headers: [(String, String)]) {
        self.init()
        for (name, value) in headers {
            add(name: name, value: value)
        }
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
    }

    public subscript(name: String) -> String? {
        guard let firstIndex = index[Self.normalize(name)]?.first else { return nil }
        return storage[firstIndex].value
    }

    public func allValues(for name: String) -> [String] {
        index[Self.normalize(name), default: []].map { storage[$0].value }
    }

    public mutating func add(name: String, value: String) {
        let key = Self.normalize(name)
        let newIndex = storage.count
        storage.append((name: name, value: value))
        index[key, default: []].append(newIndex)
    }

    public mutating func set(name: String, value: String) {
        let key = Self.normalize(name)
        storage.removeAll { Self.normalize($0.name) == key }
        index.removeAll()
        for (i, entry) in storage.enumerated() {
            index[Self.normalize(entry.name), default: []].append(i)
        }
        add(name: name, value: value)
    }

    public func allHeaderLines() -> [(name: String, value: String)] {
        storage
    }
}

extension HTTPHeaders {
    public static func == (lhs: HTTPHeaders, rhs: HTTPHeaders) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        for (left, right) in zip(lhs.storage, rhs.storage) {
            guard left.name == right.name, left.value == right.value else { return false }
        }
        return true
    }
}
