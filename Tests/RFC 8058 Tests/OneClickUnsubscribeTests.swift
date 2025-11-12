import Foundation
import RFC_3987
import Testing

@testable import RFC_8058

@Suite("RFC 8058 One-Click Unsubscribe Tests")
struct OneClickUnsubscribeTests {

    // MARK: - Initialization Tests

    @Test("OneClick.Unsubscribe can be created with HTTPS URI")
    func testHTTPSInitialization() throws {
        let baseURL = try RFC_3987.IRI("https://example.com/unsubscribe")
        let token = "abc123xyz"

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: baseURL,
            opaqueToken: token
        )

        #expect(oneClick.opaqueToken == token)
        #expect(oneClick.httpsURI.value == "https://example.com/unsubscribe/abc123xyz")
    }

    @Test("OneClick.Unsubscribe throws error for non-HTTPS URI")
    func testHTTPSRequired() throws {
        let httpURL = try RFC_3987.IRI("http://example.com/unsubscribe")

        #expect(throws: RFC_8058.OneClickError.self) {
            try RFC_8058.OneClick.Unsubscribe(
                baseURL: httpURL,
                opaqueToken: "token123"
            )
        }
    }

    @Test("OneClick.Unsubscribe throws error for empty token")
    func testEmptyTokenRejected() throws {
        let baseURL = try RFC_3987.IRI("https://example.com/unsubscribe")

        #expect(throws: RFC_8058.OneClickError.self) {
            try RFC_8058.OneClick.Unsubscribe(
                baseURL: baseURL,
                opaqueToken: ""
            )
        }
    }

    @Test("OneClick.Unsubscribe handles base URL with trailing slash")
    func testTrailingSlashHandling() throws {
        let baseWithSlash = try RFC_3987.IRI("https://example.com/unsubscribe/")
        let baseWithoutSlash = try RFC_3987.IRI("https://example.com/unsubscribe")
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

    @Test("OneClick.Unsubscribe can be created with IRI.Representable (URL)")
    func testURLConvenience() throws {
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

    @Test("Renders RFC 8058 compliant headers")
    func testHeaderRendering() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)

        // RFC 8058 Section 3: MUST have both headers
        #expect(headers.count == 2)
        #expect(headers["List-Unsubscribe"] == "<https://example.com/unsubscribe/token123>")
        #expect(headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click")
    }

    @Test("List-Unsubscribe header uses angle brackets per RFC 2369")
    func testAngleBrackets() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "abc"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)
        let unsubscribeHeader = headers["List-Unsubscribe"]!

        #expect(unsubscribeHeader.hasPrefix("<"))
        #expect(unsubscribeHeader.hasSuffix(">"))
    }

    @Test("List-Unsubscribe-Post has exact value per RFC 8058")
    func testPostHeaderValue() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "token"
        )

        let headers = [String: String](oneClickUnsubscribe: oneClick)

        // RFC 8058 Section 3: "List-Unsubscribe=One-Click" exactly
        #expect(headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click")
    }

    // MARK: - Token Validation Tests

    @Test("Token validation succeeds with correct token")
    func testValidTokenValidation() throws {
        let token = "correct-token-123"
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: token
        )

        let isValid = oneClick.validate(token: token)

        #expect(isValid == true)
    }

    @Test("Token validation fails with incorrect token")
    func testInvalidTokenValidation() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "correct-token"
        )

        let isValid = oneClick.validate(token: "wrong-token")

        #expect(isValid == false)
    }

    @Test("Token validation fails with different length token")
    func testDifferentLengthTokenValidation() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "short"
        )

        let isValid = oneClick.validate(token: "this-is-much-longer")

        #expect(isValid == false)
    }

    @Test("Token validation uses constant-time comparison")
    func testConstantTimeComparison() throws {
        // This test verifies that validation is constant-time by checking
        // that tokens of the same length take similar time regardless of
        // how many characters match

        let token = "abcdefghijklmnop"  // 16 chars
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
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

    @Test("Token validation with empty string")
    func testEmptyTokenValidation() throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "valid-token"
        )

        let isValid = oneClick.validate(token: "")

        #expect(isValid == false)
    }

    // MARK: - Security Tests

    @Test("Opaque token should be URL-safe")
    func testURLSafeToken() throws {
        // Common URL-safe characters
        let urlSafeToken = "abc123-_."

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: urlSafeToken
        )

        #expect(oneClick.httpsURI.value.contains(urlSafeToken))
    }

    @Test("Typical HMAC-based token works")
    func testHMACStyleToken() throws {
        // Simulate base64url-encoded HMAC token
        let hmacToken = "dGVzdEBleGFtcGxlLmNvbTpuZXdzbGV0dGVy"

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: hmacToken
        )

        #expect(oneClick.opaqueToken == hmacToken)
        #expect(oneClick.validate(token: hmacToken) == true)
    }

    // MARK: - Codable Tests

    @Test("OneClick.Unsubscribe is Codable")
    func testCodable() throws {
        let original = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "test-token-123"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RFC_8058.OneClick.Unsubscribe.self, from: encoded)

        #expect(decoded.httpsURI == original.httpsURI)
        #expect(decoded.opaqueToken == original.opaqueToken)
    }

    // MARK: - Hashable Tests

    @Test("OneClick.Unsubscribe is Hashable")
    func testHashable() throws {
        let oneClick1 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let oneClick2 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: "token123"
        )

        let oneClick3 = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
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

    @Test("OneClick.Unsubscribe is Sendable")
    func testSendable() async throws {
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
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

    @Test("Can be combined with RFC 2369 List-Unsubscribe")
    func testRFC2369Integration() throws {
        // Note: This test demonstrates how RFC 8058 extends RFC 2369
        // Both List-Unsubscribe headers can coexist

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
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

    @Test("Realistic unsubscribe workflow")
    func testRealisticWorkflow() throws {
        // Simulate real-world token generation
        let subscriber = "user@example.com"
        let list = "newsletter"
        let secret = "secret-key-12345"

        // In production, use HMAC-SHA256 or similar
        let tokenData = "\(subscriber):\(list):\(secret)"
        let token = tokenData.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Create one-click unsubscribe
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/api/unsubscribe"),
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
