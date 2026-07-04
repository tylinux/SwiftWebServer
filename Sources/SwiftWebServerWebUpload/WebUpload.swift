import Foundation
import SwiftWebServer

public actor WebUpload {
    public let server: WebServer
    public let rootDirectory: URL
    public let pathPrefix: String
    public let customIndexHTML: URL?
    public let authenticator: (any Authenticator)?

    public init(
        server: WebServer,
        rootDirectory: URL,
        at pathPrefix: String = "upload",
        customIndexHTML: URL? = nil,
        authenticator: (any Authenticator)? = nil
    ) {
        self.server = server
        self.rootDirectory = rootDirectory
        self.pathPrefix = pathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.customIndexHTML = customIndexHTML
        self.authenticator = authenticator
    }

    public func configure() async {
        let rootDirectory = self.rootDirectory
        let prefix = self.pathPrefix
        let customIndexHTML = self.customIndexHTML
        let authenticator = self.authenticator

        let indexPath = "/\(prefix)"
        let indexHandler: @Sendable (Request) async throws -> Response = { _ in
            let files = try listFileNames(in: rootDirectory)
            let html = uploadPageHTML(prefix: prefix, files: files, customIndexHTML: customIndexHTML)
            return Response(data: Data(html.utf8), contentType: "text/html; charset=utf-8")
        }

        let uploadPath = "/\(prefix)"
        let uploadHandler: @Sendable (Request) async throws -> Response = { request in
            let parts = try request.multipartParts()
            var saved = 0
            for part in parts {
                guard let filename = part.filename.map(sanitizeFilename) else { continue }
                guard !filename.isEmpty else { continue }
                let fileURL = rootDirectory.appendingPathComponent(filename)
                guard isInsideRoot(fileURL: fileURL, rootDirectory: rootDirectory) else { continue }
                try part.body.write(to: fileURL, options: .atomic)
                saved += 1
            }
            guard saved > 0 else {
                return Response(text: "No files uploaded").status(.badRequest)
            }
            return Response(text: "Uploaded \(saved) file(s)")
        }

        let filePath = "/\(prefix)/files/:name"
        let downloadHandler: @Sendable (Request) async throws -> Response = { request in
            guard let name = request.pathParameter("name").flatMap(percentDecoded),
                  !name.isEmpty else {
                return Response(text: "Not Found").status(.notFound)
            }
            let fileURL = rootDirectory.appendingPathComponent(name)
            guard isInsideRoot(fileURL: fileURL, rootDirectory: rootDirectory),
                  FileManager.default.fileExists(atPath: fileURL.path) else {
                return Response(text: "Not Found").status(.notFound)
            }
            return Response(file: fileURL)
        }
        let deleteHandler: @Sendable (Request) async throws -> Response = { request in
            guard let name = request.pathParameter("name").flatMap(percentDecoded),
                  !name.isEmpty else {
                return Response(text: "Not Found").status(.notFound)
            }
            let fileURL = rootDirectory.appendingPathComponent(name)
            guard isInsideRoot(fileURL: fileURL, rootDirectory: rootDirectory) else {
                return Response(text: "Not Found").status(.notFound)
            }
            try? FileManager.default.removeItem(at: fileURL)
            return Response(text: "Deleted")
        }
        let deleteOverrideHandler: @Sendable (Request) async throws -> Response = { request in
            let fields = try? request.formFields()
            guard fields?["_method"] == "DELETE" else {
                return Response(text: "Method Not Allowed").status(.methodNotAllowed)
            }
            return try await deleteHandler(request)
        }

        if let authenticator {
            await server.addRoute(method: .get, path: indexPath, authenticator: authenticator, handler: indexHandler)
            await server.addRoute(method: .post, path: uploadPath, authenticator: authenticator, handler: uploadHandler)
            await server.addRoute(method: .get, path: filePath, authenticator: authenticator, handler: downloadHandler)
            await server.addRoute(method: .post, path: filePath, authenticator: authenticator, handler: deleteOverrideHandler)
            await server.addRoute(method: .delete, path: filePath, authenticator: authenticator, handler: deleteHandler)
        } else {
            await server.addRoute(method: .get, path: indexPath, handler: indexHandler)
            await server.addRoute(method: .post, path: uploadPath, handler: uploadHandler)
            await server.addRoute(method: .get, path: filePath, handler: downloadHandler)
            await server.addRoute(method: .post, path: filePath, handler: deleteOverrideHandler)
            await server.addRoute(method: .delete, path: filePath, handler: deleteHandler)
        }
    }
}

private func listFileNames(in directory: URL) throws -> [String] {
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: .skipsHiddenFiles
    )
    return urls
        .filter { url in
            guard let value = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  value.isRegularFile == true else { return false }
            return true
        }
        .map { $0.lastPathComponent }
        .sorted()
}

private func isInsideRoot(fileURL: URL, rootDirectory: URL) -> Bool {
    let resolvedFile = fileURL.resolvingSymlinksInPath().standardizedFileURL
    let resolvedRoot = rootDirectory.resolvingSymlinksInPath().standardizedFileURL
    let rootPath = resolvedRoot.path
    let filePath = resolvedFile.path
    return filePath == rootPath || filePath.hasPrefix(rootPath + "/")
}

private func sanitizeFilename(_ filename: String) -> String {
    filename
        .removingPercentEncoding?
        .components(separatedBy: CharacterSet(charactersIn: "/\\"))
        .last ?? filename
}

private func percentDecoded(_ string: String) -> String? {
    string.removingPercentEncoding
}

private func uploadPageHTML(prefix: String, files: [String], customIndexHTML: URL?) -> String {
    let fileRows = files.map { name in
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return """
        <li>
          <a href="/\(prefix)/files/\(encodedName)">\(escapeHTML(name))</a>
          <form style="display:inline" method="post" action="/\(prefix)/files/\(encodedName)">
            <input type="hidden" name="_method" value="DELETE">
            <button type="submit">Delete</button>
          </form>
        </li>
        """
    }.joined(separator: "\n")

    let template = loadIndexHTMLTemplate(customIndexHTML: customIndexHTML)
    return template
        .replacingOccurrences(of: "{{prefix}}", with: prefix)
        .replacingOccurrences(of: "{{fileRows}}", with: fileRows)
}

private func loadIndexHTMLTemplate(customIndexHTML: URL?) -> String {
    if let customIndexHTML {
        if let template = try? String(contentsOf: customIndexHTML, encoding: .utf8) {
            return template
        }
    }

    if let resourceURL = Bundle.module.url(forResource: "upload", withExtension: "html"),
       let template = try? String(contentsOf: resourceURL, encoding: .utf8) {
        return template
    }

    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Web Upload</title>
    </head>
    <body>
      <h1>Upload Files</h1>
      <form method="post" action="/{{prefix}}" enctype="multipart/form-data">
        <input type="file" name="file" multiple>
        <button type="submit">Upload</button>
      </form>
      <h2>Files</h2>
      <ul>
        {{fileRows}}
      </ul>
    </body>
    </html>
    """
}

private func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
