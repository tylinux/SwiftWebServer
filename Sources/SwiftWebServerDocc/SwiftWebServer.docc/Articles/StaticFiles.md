# Static Files

Serve a directory of files with a single call.

## Basic usage

```swift
let directory = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("public")

await server.addStaticFiles(at: "static", directory: directory)
```

Requests to `/static/image.png` will serve `<directory>/image.png`.

## Index file

When a request matches a directory, you can automatically serve an index file:

```swift
await server.addStaticFiles(
    at: "static",
    directory: directory,
    indexFile: "index.html"
)
```

## Safety

`addStaticFiles` resolves the requested path and rejects any request that escapes the root directory, protecting against directory-traversal attacks.
