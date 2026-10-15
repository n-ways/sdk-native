import XCTest
@testable import NWaysMaps

/// Answers requests in-process: no test reaches a real host.
final class MockURLProtocol: URLProtocol {
    struct Reply {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]
    }

    nonisolated(unsafe) static var reply: Reply?
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var seenBodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.seen.append(request)
        Self.seenBodies.append(Self.body(of: request))
        guard let reply = Self.reply else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let res = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: res, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func body(of request: URLRequest) -> Data {
        if let b = request.httpBody { return b }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var out = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            out.append(buf, count: n)
        }
        return out
    }
}

final class ClientTests: XCTestCase {
    private var client: NWaysClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reply = nil
        MockURLProtocol.seen = []
        MockURLProtocol.seenBodies = []
        let session = URLSessionConfiguration.ephemeral
        session.protocolClasses = [MockURLProtocol.self]
        client = NWaysClient(
            configuration: NWaysConfiguration(apiKey: "k", baseURL: URL(string: "https://nways.test")!, bundleIdentifier: "ng.nways.sample"),
            sessionConfiguration: session
        )
    }

    private func answer(_ status: Int, _ body: Data, headers: [String: String] = ["Content-Type": "application/json"]) {
        MockURLProtocol.reply = .init(status: status, body: body, headers: headers)
    }

    private var lastURL: URLComponents { URLComponents(url: MockURLProtocol.seen.last!.url!, resolvingAgainstBaseURL: false)! }
    private func query(_ name: String) -> String? { lastURL.queryItems?.first { $0.name == name }?.value }

    func testGeocode() async throws {
        answer(200, try fixture("geocode"))
        let res = try await client.geocode("Allen Avenue + Co", limit: 5, near: NWaysLatLng(lat: 6.6, lng: 3.35))
        XCTAssertEqual(res.results.first?.name, "Ikeja")
        XCTAssertEqual(lastURL.path, "/v1/geocode")
        XCTAssertEqual(query("q"), "Allen Avenue + Co")
        XCTAssertTrue(lastURL.percentEncodedQuery!.contains("%2B"))
        XCTAssertEqual(query("limit"), "5")
        XCTAssertEqual(query("lat"), "6.6")
        XCTAssertEqual(query("lng"), "3.35")
        let req = MockURLProtocol.seen.last!
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-NWays-Api-Key"), "k")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "ng.nways.sample")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-NWays-Sdk"), "ios/1.0.0")
    }

    func testReverseNothingThere() async throws {
        answer(204, Data(), headers: [:])
        let r = try await client.reverse(NWaysLatLng(lat: 6.4281, lng: 3.4219))
        XCTAssertNil(r)
        XCTAssertEqual(lastURL.path, "/v1/reverse")
        XCTAssertEqual(query("lat"), "6.4281")
    }

    func testPostcodePath() async throws {
        answer(200, try fixture("postcode"))
        let p = try await client.postcode("ABC123")
        XCTAssertEqual(p.lgaName, "Ikeja")
        XCTAssertEqual(lastURL.path, "/v1/postcodes/ABC123")
    }

    func testPlaces() async throws {
        answer(200, try fixture("places"))
        let res = try await client.places(near: NWaysLatLng(lat: 6.6018, lng: 3.3515), category: "pharmacy", radius: 1500, limit: 10)
        XCTAssertEqual(res.places.count, 1)
        XCTAssertEqual(lastURL.path, "/v1/places")
        XCTAssertEqual(query("category"), "pharmacy")
        XCTAssertEqual(query("radius"), "1500")
        XCTAssertEqual(query("limit"), "10")
    }

    func testRoutesBody() async throws {
        answer(200, try fixture("routes"))
        let res = try await client.routes(from: NWaysLatLng(lat: 6.6018, lng: 3.3515), to: NWaysLatLng(lat: 6.4541, lng: 3.3947), mode: .motorcycle)
        XCTAssertEqual(res.routes.first?.geometry.first, NWaysLatLng(lat: 6.6018, lng: 3.3515))
        let req = MockURLProtocol.seen.last!
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(lastURL.path, "/v1/routes")
        let body = try JSONDecoder().decode(JSONValue.self, from: MockURLProtocol.seenBodies.last!)
        XCTAssertEqual(body["mode"]?.stringValue, "motorcycle")
        XCTAssertEqual(body["alternates"]?.intValue, 0)
        XCTAssertEqual(body["from"]?["lat"]?.doubleValue, 6.6018)
        XCTAssertEqual(body["to"]?["lng"]?.doubleValue, 3.3947)
        XCTAssertNil(body["stops"])
    }

    func testFaresPassParamsThrough() async throws {
        answer(200, try fixture("fares"))
        let f = try await client.fareEstimate(["from": "6.6018,3.3515", "to": "6.5244,3.3792", "mode": "keke,taxi"])
        XCTAssertEqual(f.currency, "NGN")
        XCTAssertEqual(lastURL.path, "/v1/fares/estimate")
        XCTAssertEqual(query("mode"), "keke,taxi")
        XCTAssertEqual(query("from"), "6.6018,3.3515")
    }

    func testErrorEnvelopeThrown() async throws {
        answer(429, Data(#"{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","reason":"QUOTA_EXCEEDED","message":"Daily quota used."}}"#.utf8),
               headers: ["Content-Type": "application/json", "Retry-After": "60"])
        do {
            _ = try await client.geocode("Ikeja")
            XCTFail("expected NWaysError")
        } catch let e as NWaysError {
            XCTAssertEqual(e.httpStatus, 429)
            XCTAssertEqual(e.reason, "QUOTA_EXCEEDED")
            XCTAssertEqual(e.retryAfter, 60)
        }
    }

    func testOlderErrorThrown() async throws {
        answer(422, Data(#"{"error":"no route","code":"no_route"}"#.utf8))
        do {
            _ = try await client.routes(from: NWaysLatLng(lat: 6, lng: 3), to: NWaysLatLng(lat: 6.1, lng: 3.1))
            XCTFail("expected NWaysError")
        } catch let e as NWaysError {
            XCTAssertEqual(e.httpStatus, 422)
            XCTAssertEqual(e.code, "no_route")
        }
    }

    func testNetworkFailure() async throws {
        do {
            _ = try await client.geocode("Ikeja")
            XCTFail("expected NWaysError")
        } catch let e as NWaysError {
            XCTAssertEqual(e.httpStatus, 0)
            XCTAssertTrue(e.isRetryable)
        }
    }

    func testCoordFormatting() {
        XCTAssertEqual(NWaysClient.coord(6.5), "6.5")
        XCTAssertEqual(NWaysClient.coord(3), "3")
        XCTAssertEqual(NWaysClient.coord(-0.207658), "-0.207658")
        XCTAssertEqual(NWaysClient.coord(6.123456789), "6.1234568")
    }
}
