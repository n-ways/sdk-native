import XCTest
@testable import NWaysMaps

final class NWaysErrorTests: XCTestCase {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    func testPartnerEnvelope() {
        let e = NWaysError.from(httpStatus: 403, body: data("""
        {"error":{"code":403,"status":"PERMISSION_DENIED","reason":"API_KEY_SERVICE_BLOCKED","message":"This key may not call Routes."}}
        """), retryAfter: nil)
        XCTAssertEqual(e.httpStatus, 403)
        XCTAssertEqual(e.status, "PERMISSION_DENIED")
        XCTAssertEqual(e.reason, "API_KEY_SERVICE_BLOCKED")
        XCTAssertEqual(e.message, "This key may not call Routes.")
        XCTAssertNil(e.code)
        XCTAssertNil(e.retryAfter)
        XCTAssertFalse(e.isRetryable)
    }

    func testQuotaWithRetryAfter() {
        let e = NWaysError.from(httpStatus: 429, body: data("""
        {"error":{"code":429,"status":"RESOURCE_EXHAUSTED","reason":"RATE_LIMIT_EXCEEDED","message":"Slow down."}}
        """), retryAfter: "60")
        XCTAssertEqual(e.status, "RESOURCE_EXHAUSTED")
        XCTAssertEqual(e.retryAfter, 60)
        XCTAssertTrue(e.isRetryable)
    }

    func testOlderShape() {
        let e = NWaysError.from(httpStatus: 422, body: data(#"{"error":"no route between these points","code":"no_route"}"#), retryAfter: nil)
        XCTAssertEqual(e.code, "no_route")
        XCTAssertEqual(e.message, "no route between these points")
        XCTAssertNil(e.status)
        XCTAssertNil(e.reason)
    }

    func testOlderShapeWithoutCode() {
        let e = NWaysError.from(httpStatus: 400, body: data(#"{"error":"lat and lng query parameters are required"}"#), retryAfter: nil)
        XCTAssertNil(e.code)
        XCTAssertEqual(e.message, "lat and lng query parameters are required")
    }

    func testNonJSONAndEmptyBodies() {
        XCTAssertEqual(NWaysError.from(httpStatus: 502, body: data("Bad Gateway"), retryAfter: nil).message, "Bad Gateway")
        XCTAssertEqual(NWaysError.from(httpStatus: 503, body: Data(), retryAfter: nil).message, "HTTP 503")
        XCTAssertEqual(NWaysError.from(httpStatus: 503, body: nil, retryAfter: nil).message, "HTTP 503")
    }

    func testRetryAfterHTTPDate() {
        let now = Date(timeIntervalSince1970: 60)
        XCTAssertEqual(NWaysError.parseRetryAfter("Thu, 01 Jan 1970 00:01:40 GMT", now: now), 40)
        XCTAssertEqual(NWaysError.parseRetryAfter("Thu, 01 Jan 1970 00:01:40 GMT", now: Date(timeIntervalSince1970: 200)), 0)
        XCTAssertNil(NWaysError.parseRetryAfter("soon"))
        XCTAssertNil(NWaysError.parseRetryAfter(nil))
        XCTAssertEqual(NWaysError.parseRetryAfter("-5"), 0)
    }
}
