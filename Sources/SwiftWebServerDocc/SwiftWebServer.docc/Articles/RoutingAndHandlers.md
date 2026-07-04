# Routing and Handlers

Routes match by HTTP method and path pattern.

## Path parameters

Use `:name` for a single path component:

```swift
await server.addRoute(method: .get, path: "/users/:id") { request in
    let id = request.pathParameter("id")!
    return try Response(json: ["id": id])
}
```

Use `:name...` for a variadic path parameter that matches the rest of the path, including slashes. It must be the last component:

```swift
await server.addRoute(method: .get, path: "/files/:path...") { request in
    guard let path = request.pathParameter("path") else {
        return Response(text: "Not found").status(.notFound)
    }
    return Response(text: "Requested: \(path)")
}
```

## Authentication

Attach an authenticator to a route:

```swift
await server.addRoute(
    method: .get,
    path: "/admin",
    authenticator: Authentication.basic { username, password in
        username == "admin" && password == "secret"
    }
) { _ in
    Response(text: "Welcome, admin")
}
```

## Static files

For whole directories, use ``WebServer/addStaticFiles(at:directory:indexFile:)`` instead of writing individual routes. It protects against directory traversal and supports an optional index file.

```swift
await server.addStaticFiles(
    at: "static",
    directory: staticDirectory,
    indexFile: "index.html"
)
```
