# ``SwiftWebServer``

A Swift 6 embedded HTTP/1.1 WebServer for Apple platforms.

## Overview

SwiftWebServer lets you run an HTTP server inside your app. It is designed around `async/await`, `Network.framework`, and Swift 6 strict concurrency.

It supports routing, path parameters, static files, streaming responses, gzip compression, range requests, authentication, form and multipart body parsing, keep-alive, lifecycle management, and optional HTTPS.

## Topics

### Essentials

- ``WebServer``
- ``Request``
- ``Response``
- ``Route``

### Articles

- <doc:GettingStarted>
- <doc:RoutingAndHandlers>
- <doc:StaticFiles>
- <doc:StreamingResponses>
- <doc:TLSAndHTTPS>
- <doc:LoggingAndLifecycle>

### WebUpload

- <doc:WebUpload>

### Authentication

- ``Authenticator``
- ``BasicAuthenticator``
- ``DigestAuthenticator``

### Body Parsing

- ``Request/decodeJSON(_:decoder:)``
- ``Request/formFields()``
- ``Request/multipartParts()``

### Response Types

- ``Response/init(text:)``
- ``Response/init(data:contentType:)``
- ``Response/init(file:)``
- ``Response/init(stream:status:headers:)``
- ``HTTPStatus``

### TLS

- ``TLSConfiguration``
- ``TLSIdentity``

### Logging

- ``LogLevel``
- ``LogHandler``
