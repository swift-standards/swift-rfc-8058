import Foundation
import RFC_3987
import Testing

@testable import RFC_8058

@Suite
struct `README Verification` {

    @Test
    func `Example from README: Creating One-Click Unsubscribe`() throws {
        // Simplified from README line 36-63 (without CryptoKit for test simplicity)
        let token = "secure-token-123"

        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: token
        )

        #expect(oneClick.opaqueToken == token)
        #expect(oneClick.httpsURI.value.contains("https://example.com/unsubscribe"))
    }

    @Test
    func `Example from README: Rendering Email Headers`() throws {
        let token = "token123"
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try RFC_3987.IRI("https://example.com/unsubscribe"),
            opaqueToken: token
        )

        // From README line 69
        let headers = [String: String](oneClickUnsubscribe: oneClick)

        #expect(headers["List-Unsubscribe"]?.contains("https://example.com/unsubscribe") == true)
        #expect(headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click")
    }
    //
    //    @Test
    //    func `Example from README: Using Foundation URLs`() throws {
    //        // From README line 101-107
    //        let oneClick = try RFC_8058.OneClick.Unsubscribe(
    //            baseURL: URL(string: "https://example.com/unsubscribe")!,
    //            opaqueToken: "secureToken"
    //        )
    //
    //        #expect(oneClick.httpsURI.value.contains("https://example.com/unsubscribe"))
    //    }

    @Test
    func `Example from README: Token Validation`() throws {
        let token = "valid-token-123"
        let oneClick = try RFC_8058.OneClick.Unsubscribe(
            baseURL: try .init("https://example.com/unsubscribe"),
            opaqueToken: token
        )

        // From README line 89 - validate method
        #expect(oneClick.validate(token: token) == true)
        #expect(oneClick.validate(token: "wrong-token") == false)
    }
}
