import Foundation
import RFC_3987

extension RFC_8058.OneClick {
    /// One-click unsubscribe mechanism as defined in RFC 8058
    ///
    /// This type implements the one-click unsubscribe functionality that allows
    /// email clients to offer users a simple unsubscribe button that works with
    /// a single HTTP POST request.
    ///
    /// ## Security Requirements (RFC 8058 Section 3)
    ///
    /// 1. **HTTPS Required**: The URI MUST use HTTPS scheme for security
    /// 2. **Opaque Token**: The URI SHOULD include an opaque, hard-to-forge token
    /// 3. **No Context**: The POST request MUST NOT include cookies or HTTP authorization
    /// 4. **User Consent**: Receivers MUST NOT POST without user consent
    ///
    /// ## Protocol Flow
    ///
    /// 1. Email includes List-Unsubscribe and List-Unsubscribe-Post headers
    /// 2. Client presents unsubscribe button to user
    /// 3. User clicks button
    /// 4. Client performs POST to URI with body: `List-Unsubscribe=One-Click`
    /// 5. Server processes unsubscription
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Generate cryptographically secure token
    /// let token = generateSecureToken(for: subscriber, list: list)
    ///
    /// // Create one-click unsubscribe
    /// let oneClick = try RFC_8058.OneClick.Unsubscribe(
    ///     baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
    ///     opaqueToken: token
    /// )
    ///
    /// // Include in email headers
    /// let headers = [String: String](oneClickUnsubscribe: oneClick)
    /// // ["List-Unsubscribe": "<https://example.com/unsubscribe/TOKEN>",
    /// //  "List-Unsubscribe-Post": "List-Unsubscribe=One-Click"]
    ///
    /// // Later, validate incoming request
    /// if oneClick.validate(token: requestToken) {
    ///     // Process unsubscription
    /// }
    /// ```
    ///
    /// ## RFC 8058 Section 3.1: POST Content
    ///
    /// > The POST content SHOULD be sent as "multipart/form-data" or MAY be sent
    /// > as "application/x-www-form-urlencoded". The POST SHOULD contain only the
    /// > single field "List-Unsubscribe=One-Click".
    ///
    /// > The POST request MUST NOT include cookies, HTTP authorization, or any
    /// > other context information. The unsubscribe operation is logically
    /// > unrelated to any previous web activity or email content, and the act
    /// > itself provides the context.
    public struct Unsubscribe: Hashable, Sendable, Codable {
        /// The HTTPS URI for one-click unsubscription
        ///
        /// Per RFC 8058 Section 3.1:
        /// > The message MUST have a List-Unsubscribe header field containing one
        /// > or more HTTPS URIs.
        public let httpsURI: RFC_3987.IRI

        /// The opaque token included in the URI
        ///
        /// Per RFC 8058 Section 3.2:
        /// > The URI SHOULD include an opaque identifier or another hard-to-forge
        /// > component in addition to, or instead of, the plaintext names of the
        /// > list and subscriber.
        ///
        /// This token should be:
        /// - Cryptographically secure (e.g., HMAC of subscriber+list+secret)
        /// - URL-safe
        /// - Unique per subscriber-list combination
        /// - Time-limited (optional but recommended)
        public let opaqueToken: String

        /// Creates a one-click unsubscribe with opaque token
        ///
        /// - Parameters:
        ///   - baseURL: Base HTTPS URI (e.g., `https://example.com/unsubscribe`)
        ///   - opaqueToken: Cryptographically secure, URL-safe token
        ///
        /// - Throws: `RFC_8058.OneClickError.requiresHTTPS` if URI is not HTTPS
        /// - Throws: `RFC_8058.OneClickError.invalidToken` if token is empty
        /// - Throws: `RFC_8058.OneClickError.invalidURI` if combined URI is invalid
        ///
        /// ## Example
        ///
        /// ```swift
        /// // Generate secure token (example using HMAC)
        /// import CryptoKit
        ///
        /// func generateToken(subscriber: String, list: String, secret: String) -> String {
        ///     let data = "\(subscriber):\(list)".data(using: .utf8)!
        ///     let key = SymmetricKey(data: secret.data(using: .utf8)!)
        ///     let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        ///     return Data(hmac).base64EncodedString()
        ///         .replacingOccurrences(of: "+", with: "-")
        ///         .replacingOccurrences(of: "/", with: "_")
        ///         .replacingOccurrences(of: "=", with: "")
        /// }
        ///
        /// let token = generateToken(
        ///     subscriber: "user@example.com",
        ///     list: "newsletter",
        ///     secret: "your-secret-key"
        /// )
        ///
        /// let oneClick = try RFC_8058.OneClick.Unsubscribe(
        ///     baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
        ///     opaqueToken: token
        /// )
        /// ```
        public init(
            baseURL: RFC_3987.IRI,
            opaqueToken: String
        ) throws {
            // RFC 8058 Section 3.1: MUST use HTTPS
            guard baseURL.value.hasPrefix("https://") else {
                throw RFC_8058.OneClickError.requiresHTTPS
            }

            // Validate token is non-empty
            guard !opaqueToken.isEmpty else {
                throw RFC_8058.OneClickError.invalidToken(opaqueToken)
            }

            self.opaqueToken = opaqueToken

            // Construct full URI with token
            // Format: https://example.com/unsubscribe/TOKEN
            let fullURIString: String
            if baseURL.value.hasSuffix("/") {
                fullURIString = "\(baseURL.value)\(opaqueToken)"
            } else {
                fullURIString = "\(baseURL.value)/\(opaqueToken)"
            }

            guard let uri = try? RFC_3987.IRI(fullURIString) else {
                throw RFC_8058.OneClickError.invalidURI(fullURIString)
            }

            self.httpsURI = uri
        }

        /// Creates one-click unsubscribe with IRI.Representable base URL (convenience)
        ///
        /// - Parameters:
        ///   - baseURL: Base HTTPS URI (e.g., Foundation URL)
        ///   - opaqueToken: Cryptographically secure, URL-safe token
        ///
        /// - Throws: `RFC_8058.OneClickError.requiresHTTPS` if URI is not HTTPS
        /// - Throws: `RFC_8058.OneClickError.invalidToken` if token is empty
        /// - Throws: `RFC_8058.OneClickError.invalidURI` if combined URI is invalid
        public init(
            baseURL: any RFC_3987.IRI.Representable,
            opaqueToken: String
        ) throws {
            try self.init(baseURL: baseURL.iri, opaqueToken: opaqueToken)
        }

        /// Validates a token using constant-time comparison
        ///
        /// Uses constant-time string comparison to prevent timing attacks that could
        /// be used to guess valid tokens.
        ///
        /// Per RFC 8058 Section 3.2 (Security Considerations):
        ///
        /// > The URI SHOULD include an opaque identifier or another hard-to-forge
        /// > component [...] This is important because an attacker could send
        /// > fraudulent one-click unsubscribe requests for victim email addresses.
        ///
        /// - Parameter token: The token to validate (typically from incoming HTTP request)
        /// - Returns: `true` if token matches, `false` otherwise
        ///
        /// ## Example
        ///
        /// ```swift
        /// // In your HTTP handler
        /// func handleUnsubscribe(request: Request) async throws -> Response {
        ///     let tokenFromURL = request.parameters.get("token")!
        ///
        ///     // Retrieve stored OneClick.Unsubscribe for this request
        ///     let oneClick = try await getOneClickUnsubscribe(from: tokenFromURL)
        ///
        ///     guard oneClick.validate(token: tokenFromURL) else {
        ///         throw Abort(.unauthorized, reason: "Invalid unsubscribe token")
        ///     }
        ///
        ///     // Process unsubscription
        ///     try await unsubscribe(token: tokenFromURL)
        ///
        ///     return Response(status: .ok)
        /// }
        /// ```
        public func validate(token: String) -> Bool {
            // Constant-time comparison to prevent timing attacks
            guard token.count == opaqueToken.count else { return false }

            var result = 0
            for (a, b) in zip(token.utf8, opaqueToken.utf8) {
                result |= Int(a ^ b)
            }
            return result == 0
        }
    }
}

// MARK: - Email Header Rendering

extension [String: String] {
    /// Creates RFC 8058 compliant email headers from one-click unsubscribe
    ///
    /// Renders the one-click unsubscribe as email headers per RFC 8058 Section 3:
    ///
    /// > The message MUST have a List-Unsubscribe header field containing one
    /// > or more HTTPS URIs.
    /// >
    /// > The message MUST have a List-Unsubscribe-Post header field. The
    /// > List-Unsubscribe-Post header field MUST contain the single key/value
    /// > pair "List-Unsubscribe=One-Click".
    ///
    /// - Parameter oneClickUnsubscribe: The RFC 8058 one-click unsubscribe to render
    ///
    /// ## Example
    ///
    /// ```swift
    /// let headers = [String: String](oneClickUnsubscribe: myUnsubscribe)
    /// // Returns:
    /// // [
    /// //     "List-Unsubscribe": "<https://example.com/unsubscribe/abc123>",
    /// //     "List-Unsubscribe-Post": "List-Unsubscribe=One-Click"
    /// // ]
    /// ```
    public init(oneClickUnsubscribe: RFC_8058.OneClick.Unsubscribe) {
        self = [
            "List-Unsubscribe": "<\(oneClickUnsubscribe.httpsURI.value)>",
            "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
        ]
    }
}
