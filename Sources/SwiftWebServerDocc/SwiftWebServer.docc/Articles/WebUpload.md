# WebUpload

`SwiftWebServerWebUpload` is an optional module that adds a complete upload / list / download / delete endpoint.

## Setup

```swift
import SwiftWebServer
import SwiftWebServerWebUpload

let server = WebServer()

let uploadRoot = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("Uploads")

let webUpload = WebUpload(
    server: server,
    rootDirectory: uploadRoot,
    at: "upload"
)

await webUpload.configure()
try await server.start(port: 8080)
```

The default upload page is served at `http://localhost:8080/upload`.

## Custom HTML template

Provide your own HTML file. The template can use `{{prefix}}` and `{{fileRows}}` placeholders:

```swift
let webUpload = WebUpload(
    server: server,
    rootDirectory: uploadRoot,
    customIndexHTML: URL(fileURLWithPath: "/path/to/upload.html")
)
```

Example template:

```html
<!DOCTYPE html>
<html>
<body>
  <h1>Upload Files</h1>
  <form method="post" action="/{{prefix}}" enctype="multipart/form-data">
    <input type="file" name="file" multiple>
    <button type="submit">Upload</button>
  </form>
  <ul>
    {{fileRows}}
  </ul>
</body>
</html>
```

## Endpoints

- `GET /upload` — upload page
- `POST /upload` — upload one or more files (`multipart/form-data`, field name `file`)
- `GET /upload/files/:name` — download a file
- `DELETE /upload/files/:name` — delete a file

The bundled HTML delete button uses a `_method=DELETE` form override, which the server also supports.
