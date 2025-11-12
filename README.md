# Swift RFC 8058

[![CI](https://github.com/swift-standards/swift-rfc-8058/workflows/CI/badge.svg)](https://github.com/swift-standards/swift-rfc-8058/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Swift implementation of RFC 8058: Signaling One-Click Functionality for List Email Headers

## Overview

This package provides a Swift implementation of the one-click unsubscribe mechanism defined in [RFC 8058](https://www.ietf.org/rfc/rfc8058.txt). RFC 8058 extends RFC 2369 list headers with enhanced security and user experience, allowing email clients to offer a single-click unsubscribe button.

## Features

- ✅ One-click unsubscribe implementation
- ✅ HTTPS-only security enforcement
- ✅ Opaque token support for security
- ✅ Constant-time token validation (prevents timing attacks)
- ✅ RFC-compliant header rendering
- ✅ IRI support via RFC 3987
- ✅ Foundation `URL` compatibility
- ✅ Swift 6 strict concurrency support
- ✅ Full `Sendable` conformance

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/swift-standards/swift-rfc-8058", branch: "main")
]
```

## Usage

### Creating One-Click Unsubscribe

```swift
import RFC_8058
import RFC_3987
import CryptoKit

// Generate cryptographically secure token
func generateSecureToken(subscriber: String, list: String, secret: String) -> String {
    let data = "\(subscriber):\(list)".data(using: .utf8)!
    let key = SymmetricKey(data: secret.data(using: .utf8)!)
    let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
    return Data(hmac).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let token = generateSecureToken(
    subscriber: "user@example.com",
    list: "newsletter",
    secret: "your-secret-key"
)

// Create one-click unsubscribe
let oneClick = try RFC_8058.OneClick.Unsubscribe(
    baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
    opaqueToken: token
)
```

### Rendering Email Headers

```swift
let headers = [String: String](oneClickUnsubscribe: oneClick)
// [
//     "List-Unsubscribe": "<https://example.com/unsubscribe/TOKEN>",
//     "List-Unsubscribe-Post": "List-Unsubscribe=One-Click"
// ]

// Include these headers in your email
```

### Validating Unsubscribe Requests

```swift
// In your HTTP POST handler
func handleUnsubscribe(request: Request) async throws -> Response {
    let token = request.parameters.get("token")!

    // Retrieve stored oneClick for this token
    let oneClick = try await getOneClickUnsubscribe(token: token)

    // Validate token (constant-time comparison)
    guard oneClick.validate(token: token) else {
        throw Abort(.unauthorized, reason: "Invalid token")
    }

    // Process unsubscription
    try await unsubscribe(token: token)

    return Response(status: .ok)
}
```

### Using Foundation URLs

```swift
// Foundation URLs work seamlessly via IRI.Representable
let oneClick = try RFC_8058.OneClick.Unsubscribe(
    baseURL: URL(string: "https://example.com/unsubscribe")!,
    opaqueToken: secureToken
)
```

## RFC 8058 Compliance

This implementation follows RFC 8058 precisely:

### Security Requirements

✅ **HTTPS Required** (RFC 8058 Section 3.1)
> The message MUST have a List-Unsubscribe header field containing one or more HTTPS URIs.

✅ **Opaque Tokens** (RFC 8058 Section 3.2)
> The URI SHOULD include an opaque identifier or another hard-to-forge component.

✅ **No Context Required** (RFC 8058 Section 3.1)
> The POST request MUST NOT include cookies, HTTP authorization, or any other context information.

✅ **Constant-Time Validation**
- Prevents timing attacks that could be used to guess valid tokens

### Protocol Flow

1. Email includes `List-Unsubscribe` and `List-Unsubscribe-Post` headers
2. Email client presents unsubscribe button to user
3. User clicks button
4. Client performs HTTP POST with body: `List-Unsubscribe=One-Click`
5. Server validates token and processes unsubscription

### POST Request Format

Per RFC 8058 Section 3.1:

```http
POST /unsubscribe/TOKEN HTTP/1.1
Host: example.com
Content-Type: application/x-www-form-urlencoded

List-Unsubscribe=One-Click
```

## Security Best Practices

### Token Generation

Use cryptographically secure methods:

```swift
import CryptoKit

// HMAC-based token (recommended)
let key = SymmetricKey(size: .bits256)
let data = "\(subscriber):\(list):\(timestamp)".data(using: .utf8)!
let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
let token = Data(hmac).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")  // URL-safe
    .replacingOccurrences(of: "/", with: "_")  // URL-safe
    .replacingOccurrences(of: "=", with: "")   // Remove padding
```

### Token Validation

Always use the provided `validate(token:)` method:

```swift
// ✅ Good: Constant-time comparison
if oneClick.validate(token: requestToken) {
    // Process unsubscription
}

// ❌ Bad: String comparison vulnerable to timing attacks
if oneClick.opaqueToken == requestToken {  // Don't do this!
    // Process unsubscription
}
```

### Additional Recommendations

1. **Time-limit tokens**: Include timestamp in token generation and reject expired tokens
2. **One-time use**: Mark tokens as used after successful unsubscription
3. **Rate limiting**: Limit unsubscribe requests per IP/token
4. **Logging**: Log all unsubscribe attempts for security monitoring

## Type Overview

### `RFC_8058.OneClick.Unsubscribe`

One-click unsubscribe with security features:

```swift
public struct Unsubscribe {
    public let httpsURI: RFC_3987.IRI      // HTTPS URI with token
    public let opaqueToken: String          // Secure token

    public func toEmailHeaders() -> [String: String]
    public func validate(token: String) -> Bool  // Constant-time
}
```

## Integration with RFC 2369

RFC 8058 extends RFC 2369. You can use both together:

```swift
import RFC_2369
import RFC_8058

// RFC 2369: Traditional list headers
let listHeaders = try RFC_2369.List.Header(
    help: try RFC_3987.IRI("https://example.com/help"),
    subscribe: [try RFC_3987.IRI("https://example.com/subscribe")]
)

// RFC 8058: Enhanced one-click unsubscribe
let oneClick = try RFC_8058.OneClick.Unsubscribe(
    baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
    opaqueToken: secureToken
)

// Combine headers
var emailHeaders = [String: String](listHeader: listHeaders)
emailHeaders.merge([String: String](oneClickUnsubscribe: oneClick)) { _, new in new }

// Result: Complete RFC 2369 + RFC 8058 compliance
```

## Requirements

- Swift 6.0+
- macOS 14+, iOS 17+, tvOS 17+, watchOS 10+

## Related RFCs

- [RFC 2369](https://www.ietf.org/rfc/rfc2369.txt) - The Use of URLs as Meta-Syntax for Core Mail List Commands
- [RFC 3987](https://www.ietf.org/rfc/rfc3987.txt) - Internationalized Resource Identifiers (IRIs)
- [RFC 8058](https://www.ietf.org/rfc/rfc8058.txt) - Signaling One-Click Functionality for List Email Headers

## Related Packages

- [swift-rfc-2369](https://github.com/swift-standards/swift-rfc-2369) - List email headers (foundation for RFC 8058)
- [swift-rfc-3987](https://github.com/swift-standards/swift-rfc-3987) - IRI implementation

## Why RFC 8058 Matters

### For Email Clients

- Gmail, Apple Mail, and others prioritize emails with RFC 8058 headers
- Improves inbox placement and deliverability
- Provides better user experience

### For List Operators

- Reduces false spam reports
- Improves sender reputation
- Demonstrates compliance with best practices

### For Users

- One-click unsubscribe (no website visit required)
- Works directly from email client UI
- Faster, more convenient

## License & Contributing

Licensed under Apache 2.0.

Contributions welcome! Please ensure:
- All tests pass
- Code follows existing style
- RFC 8058 compliance maintained
- Security best practices followed
