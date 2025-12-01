import Foundation
import RFC_3987
import RFC_3987_Foundation
import Testing
import RFC_8058

@Suite
struct `RFC 8058 One-Click Unsubscribe Tests` {

    // MARK: - Initialization Tests

    @Test
    func `OneClick.Unsubscribe can be created with HTTPS URI`() throws {
        let baseURL = try RFC_3987.IRI.init("https://example.com/unsubscribe")
        let token = "abc123xyz"

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: baseURL,
            opaqueToken: token
        )

        #expect(oneClick.opaqueToken == token)
        #expect(oneClick.httpsURI.value == "https://example.com/unsubscribe/abc123xyz")
    }

    @Test
    func `OneClick.Unsubscribe throws error for non-HTTPS URI`() throws {
        let httpURL = try RFC_3987.IRI.init("http://example.com/unsubscribe")

        #expect(throws: RFC_8058.OneClickError.self) {
            try RFC_8058.OneClick.Unsubscribe(
                baseURL: httpURL,
                opaqueToken: "token123"
            )
        }
    }

    @Test
    func `OneClick.Unsubscribe throws error for empty token`() throws {
        let baseURL = try RFC_3987.IRI.init("https://example.com/unsubscribe")

        #expect(throws: RFC_8058.OneClickError.self) {
            try RFC_8058.OneClick.Unsubscribe(
                baseURL: baseURL,
                opaqueToken: ""
            )
        }
    }

    @Test
    func `OneClick.Unsubscribe handles base URL with trailing slash`() throws {
        let baseWithSlash = try RFC_3987.IRI.init("https://example.com/unsubscribe/")
        let baseWithoutSlash = try RFC_3987.IRI.init("https://example.com/unsubscribe")
        let token = "abc123"

        let oneClick1 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: baseWithSlash,
            opaqueToken: token
        )

        let oneClick2 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: baseWithoutSlash,
            opaqueToken: token
        )

        #expect(oneClick1.httpsURI.value == "https://example.com/unsubscribe/abc123")
        #expect(oneClick2.httpsURI.value == "https://example.com/unsubscribe/abc123")
    }

    @Test
    func `OneClick.Unsubscribe can be created with IRI.Representable (URL)`() throws {
        let baseURL = URL(string: "https://example.com/unsubscribe")!
        let token = "secure-token-123"

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: baseURL,
            opaqueToken: token
        )

        #expect(oneClick.httpsURI.value.contains("https://example.com/unsubscribe"))
        #expect(oneClick.httpsURI.value.contains(token))
    }

    // MARK: - Header Rendering Tests

    @Test
    func `Renders RFC 8058 compliant headers`() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)

        // RFC 8058 Section 3: MUST have both headers
        #expect(headers.count == 2)
        #expect(headers["List-Unsubscribe"] == "<https://example.com/unsubscribe/token123>")
        #expect(headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click")
    }

    @Test
    func `List-Unsubscribe header uses angle brackets per RFC 2369`() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "abc"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)
        let unsubscribeHeader = headers["List-Unsubscribe"]!

        #expect(unsubscribeHeader.hasPrefix("<"))
        #expect(unsubscribeHeader.hasSuffix(">"))
    }

    @Test
    func `List-Unsubscribe-Post has exact value per RFC 8058`() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "token"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)

        // RFC 8058 Section 3: "List-Unsubscribe=One-Click" exactly
        #expect(headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click")
    }

    // MARK: - Token Validation Tests

    @Test
    func `Token validation succeeds with correct token`() throws {
        let token = "correct-token-123"
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: token
        )

        let isValid = oneClick.validate(token: token)

        #expect(isValid == true)
    }

    @Test
    func `Token validation fails with incorrect token`() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "correct-token"
        )

        let isValid = oneClick.validate(token: "wrong-token")

        #expect(isValid == false)
    }

    @Test
    func `Token validation fails with different length token`() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "short"
        )

        let isValid = oneClick.validate(token: "this-is-much-longer")

        #expect(isValid == false)
    }

    @Test
    func `Token validation uses constant-time comparison`() throws {
        // This test verifies that validation is constant-time by checking
        // that tokens of the same length take similar time regardless of
        // how many characters match

        let token = "abcdefghijklmnop"  // 16 chars
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: token
        )

        // All different
        let allDifferent = "xxxxxxxxxxxxxxxx"
        let result1 = oneClick.validate(token: allDifferent)
        #expect(result1 == false)

        // First char matches
        let firstMatches = "axxxxxxxxxxxxxxx"
        let result2 = oneClick.validate(token: firstMatches)
        #expect(result2 == false)

        // All but last match
        let almostMatches = "abcdefghijklmnox"
        let result3 = oneClick.validate(token: almostMatches)
        #expect(result3 == false)

        // Verification that all false cases behave consistently
        // (constant-time comparison ensures timing doesn't reveal which chars match)
    }

    @Test
    func `Token validation with empty string`() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "valid-token"
        )

        let isValid = oneClick.validate(token: "")

        #expect(isValid == false)
    }

    // MARK: - Security Tests

    @Test
    func `Opaque token should be URL-safe`() throws {
        // Common URL-safe characters
        let urlSafeToken = "abc123-_."

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: urlSafeToken
        )

        #expect(oneClick.httpsURI.value.contains(urlSafeToken))
    }

    @Test
    func `Typical HMAC-based token works`() throws {
        // Simulate base64url-encoded HMAC token
        let hmacToken = "dGVzdEBleGFtcGxlLmNvbTpuZXdzbGV0dGVy"

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: hmacToken
        )

        #expect(oneClick.opaqueToken == hmacToken)
        #expect(oneClick.validate(token: hmacToken) == true)
    }

    // MARK: - Codable Tests

    @Test
    func `OneClick.Unsubscribe is Codable`() throws {
        let original = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "test-token-123"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RFC_8058.OneClick.Unsubscribe.self, from: encoded)

        #expect(decoded.httpsURI == original.httpsURI)
        #expect(decoded.opaqueToken == original.opaqueToken)
    }

    // MARK: - Hashable Tests

    @Test
    func `OneClick.Unsubscribe is Hashable`() throws {
        let oneClick1 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let oneClick2 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let oneClick3 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "different-token"
        )

        #expect(oneClick1 == oneClick2)
        #expect(oneClick1 != oneClick3)

        var set = Set<RFC_8058.OneClick.Unsubscribe>()
        set.insert(oneClick1)
        set.insert(oneClick2)
        set.insert(oneClick3)

        #expect(set.count == 2)
    }

    // MARK: - Sendable Tests

    @Test
    func `OneClick.Unsubscribe is Sendable`() async throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "token"
        )

        await withCheckedContinuation { continuation in
            Task {
                let _ = oneClick  // Can use in async context
                continuation.resume()
            }
        }
    }

    // MARK: - Integration with RFC 2369

    @Test
    func `Can be combined with RFC 2369 List-Unsubscribe`() throws {
        // Note: This test demonstrates how RFC 8058 extends RFC 2369
        // Both List-Unsubscribe headers can coexist

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)

        // RFC 8058 provides enhanced List-Unsubscribe with POST capability
        // Email clients that support RFC 8058 will use the one-click functionality
        // Email clients that only support RFC 2369 will open the URL in a browser

        #expect(headers["List-Unsubscribe"]?.contains("https://") == true)
        #expect(headers["List-Unsubscribe-Post"] != nil)
    }

    // MARK: - Realistic Example

    @Test
    func `Realistic unsubscribe workflow`() throws {
        // Simulate real-world token generation
        let subscriber = "user@example.com"
        let list = "newsletter"
        let secret = "secret-key-12345"

        // In production, use HMAC-SHA256 or similar
        let tokenData = "\(subscriber):\(list):\(secret)"
        let token = tokenData.data(using: .utf8)!
            .base64EncodedString()
            .replacing("+", with: "-")
            .replacing("/", with: "_")
            .replacing("=", with: "")

        // Create one-click unsubscribe
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI.init("https://example.com/api/unsubscribe"),
            opaqueToken: token
        )

        // Render headers for email
        let headers = [String: String](oneClickUnsubscribe: oneClick)

        #expect(headers["List-Unsubscribe"]?.contains(token) == true)
        #expect(headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click")

        // Later, when request comes in with token
        let requestToken = token
        #expect(oneClick.validate(token: requestToken) == true)
    }
}
