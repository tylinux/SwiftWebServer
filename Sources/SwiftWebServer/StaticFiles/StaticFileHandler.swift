import Foundation

public struct StaticFileHandler: Sendable {
    public let rootDirectory: URL
    public let indexFile: String?

    public init(rootDirectory: URL, indexFile: String? = "index.html") {
        self.rootDirectory = rootDirectory
        self.indexFile = indexFile
    }

    public func response(for request: Request) -> Response {
        let relativePath = request.pathParameter("path") ?? ""
        let fileURL = rootDirectory.appendingPathComponent(relativePath)
        let resolvedFile = fileURL.resolvingSymlinksInPath()
        let resolvedRoot = rootDirectory.resolvingSymlinksInPath()

        let rootPath = resolvedRoot.path
        let filePath = resolvedFile.path

        let isInsideRoot = filePath == rootPath || filePath.hasPrefix(rootPath + "/")
        guard isInsideRoot else {
            return Response(text: "Not Found").status(.notFound)
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)

        guard exists else {
            return Response(text: "Not Found").status(.notFound)
        }

        if isDirectory.boolValue {
            if let indexFile {
                let indexURL = resolvedFile.appendingPathComponent(indexFile)
                if fileManager.fileExists(atPath: indexURL.path) {
                    return Response(file: indexURL)
                }
            }
            return Response(text: "Forbidden").status(.forbidden)
        }

        return Response(file: resolvedFile)
    }
}
