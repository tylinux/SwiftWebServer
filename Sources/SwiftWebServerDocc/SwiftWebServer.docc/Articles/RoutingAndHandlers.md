# Routing and Handlers

Routes match by HTTP method and path pattern.

Use `:name` for path parameters.

```swift
server.addRoute(method: .get, path: "/users/:id") { request in
    let id = request.pathParameter("id")!
    return try Response(json: ["id": id])
}
```
