# ``SwiftWebServer``

A Swift 6 embedded HTTP/1.1 WebServer for Apple platforms.

## Overview

SwiftWebServer lets you run an HTTP server inside your app. It is designed around `async/await`, `Network.framework`, and Swift 6 strict concurrency.

## Topics

### Essentials

- ``WebServer``
- ``Request``
- ``Response``
- ``Route``

### Articles

- <doc:GettingStarted>
- <doc:RoutingAndHandlers>

### Authentication

- ``Authenticator``
- ``BasicAuthenticator``
- ``DigestAuthenticator``

### Body Parsing

- ``Request/decodeJSON(_:decoder:)``
- ``Request/multipartParts()``
