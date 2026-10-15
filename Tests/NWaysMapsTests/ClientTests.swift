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

    private func body() throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: MockURLProtocol.seenBodies.last!) }

    func testGeocode() async throws {
        answer(200, try fixture("geocode"))
        let res = try await client.geocode("Ikeja + Co", near: NWaysLatLng(lat: 6.6, lng: 3.35), country: ["NG", "GH"], limit: 5,
                                           lang: "fr", fields: ["id", "name"])
        XCTAssertEqual(res.results.count, 4)
        XCTAssertEqual(lastURL.path, "/maps/v1/geocode")
        XCTAssertEqual(query("q"), "Ikeja + Co")
        XCTAssertTrue(lastURL.percentEncodedQuery!.contains("%2B"))
        XCTAssertEqual(query("near"), "6.6,3.35")
        XCTAssertEqual(query("country"), "NG,GH")
        XCTAssertEqual(query("limit"), "5")
        XCTAssertEqual(query("lang"), "fr")
        XCTAssertEqual(query("fields"), "id,name")
        let req = MockURLProtocol.seen.last!
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-NWays-Api-Key"), "k")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "ng.nways.sample")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-NWays-Sdk"), "ios/1.0.0")
    }

    func testReverse() async throws {
        answer(200, try fixture("reverse_ng"))
        let r = try await client.reverse(NWaysLatLng(lat: 6.4474, lng: 3.472), radius: 150, lang: "en")
        XCTAssertEqual(r.postcode?.code, "LA08A09DB09")
        XCTAssertEqual(lastURL.path, "/maps/v1/reverse")
        XCTAssertEqual(query("lat"), "6.4474")
        XCTAssertEqual(query("lng"), "3.472")
        XCTAssertEqual(query("radius"), "150")
    }

    func testPostcodeAndGhanaPostPaths() async throws {
        answer(200, try fixture("postcode"))
        let p = try await client.postcode("LA08A09DB09")
        XCTAssertEqual(p.components?.lgaName, "Eti-Osa")
        XCTAssertEqual(lastURL.path, "/maps/v1/postcodes/LA08A09DB09")
        answer(200, try fixture("ghanapost"))
        let g = try await client.ghanaPost("GA-183-8164")
        XCTAssertEqual(g.ghanaPost, "GA-183-8164")
        XCTAssertEqual(lastURL.path, "/maps/v1/ghanapost/GA-183-8164")
    }

    func testAutocomplete() async throws {
        answer(200, try fixture("autocomplete"))
        let res = try await client.autocomplete("ikeja ci", session: "3f2a9c1e-session", near: NWaysLatLng(lat: 6.6, lng: 3.35),
                                                types: ["business", "place"], limit: 5)
        XCTAssertEqual(res.results.count, 2)
        XCTAssertEqual(lastURL.path, "/maps/v1/autocomplete")
        XCTAssertEqual(query("session"), "3f2a9c1e-session")
        XCTAssertEqual(query("types"), "business,place")
    }

    func testValidateAddress() async throws {
        answer(200, try fixture("validate_postcode"))
        let v = try await client.validateAddress("LA 08 A09 DB 09", country: "NG", near: NWaysLatLng(lat: 6.45, lng: 3.47), lang: "en")
        XCTAssertEqual(v.verdict?.status, "VALID")
        XCTAssertEqual(MockURLProtocol.seen.last?.httpMethod, "POST")
        XCTAssertEqual(lastURL.path, "/maps/v1/addresses/validate")
        let b = try body()
        XCTAssertEqual(b["address"]?.stringValue, "LA 08 A09 DB 09")
        XCTAssertEqual(b["country"]?.stringValue, "NG")
        XCTAssertEqual(b["near"]?["lat"]?.doubleValue, 6.45)
    }

    func testPlaces() async throws {
        answer(200, try fixture("places_nearby"))
        let res = try await client.placesNearby(NWaysLatLng(lat: 6.4474, lng: 3.472), category: "bank", radius: 5000, limit: 3,
                                                pageToken: "abc", fields: ["name", "phone"])
        XCTAssertEqual(res.nextPageToken, "bzoz")
        XCTAssertEqual(lastURL.path, "/maps/v1/places/nearby")
        XCTAssertEqual(query("category"), "bank")
        XCTAssertEqual(query("radius"), "5000")
        XCTAssertEqual(query("pageToken"), "abc")
        XCTAssertEqual(query("fields"), "name,phone")
        answer(200, try fixture("place_details_all"))
        let p = try await client.place("osm:n2987189855")
        XCTAssertEqual(p.name, "Shoprite")
        XCTAssertEqual(lastURL.path, "/maps/v1/places/osm:n2987189855")
    }

    func testRouteBody() async throws {
        answer(200, try fixture("routes_drive"))
        let res = try await client.route(
            origin: .at(lat: 6.4474, lng: 3.472), destination: .postcode("LA08A09DB10"), mode: .drive,
            intermediates: [.ghanaPost("GA-183-8164"), .plusCode("6FR5CFWC+XR6")], routingPreference: .trafficAware,
            departAt: Date(timeIntervalSince1970: 0), avoid: [.tolls, .badRoads], fares: true)
        XCTAssertEqual(res.routes.first?.geometry.count, 16)
        XCTAssertEqual(MockURLProtocol.seen.last?.httpMethod, "POST")
        XCTAssertEqual(lastURL.path, "/maps/v1/routes/compute")
        let b = try body()
        XCTAssertEqual(b["origin"]?["lat"]?.doubleValue, 6.4474)
        XCTAssertEqual(b["destination"]?["postcode"]?.stringValue, "LA08A09DB10")
        XCTAssertEqual(b["intermediates"]?[0]?["ghanaPost"]?.stringValue, "GA-183-8164")
        XCTAssertEqual(b["intermediates"]?[1]?["plusCode"]?.stringValue, "6FR5CFWC+XR6")
        XCTAssertEqual(b["mode"]?.stringValue, "drive")
        XCTAssertEqual(b["routingPreference"]?.stringValue, "traffic_aware")
        XCTAssertEqual(b["departAt"]?.stringValue, "1970-01-01T00:00:00Z")
        XCTAssertEqual(b["avoid"], .array([.string("tolls"), .string("bad_roads")]))
        XCTAssertEqual(b["fares"]?.boolValue, true)
        XCTAssertNil(b["alternatives"])
        XCTAssertNil(b["lang"])
    }

    func testMatrix() async throws {
        answer(200, try fixture("matrix"))
        let m = try await client.matrix(origins: [.at(lat: 6.4474, lng: 3.472), .postcode("LA08A09DB09")],
                                        destinations: [.at(lat: 6.43, lng: 3.42), .at(lat: 6.45, lng: 3.4), .at(lat: 6.6, lng: 3.35)],
                                        mode: .bicycle)
        XCTAssertEqual(m.element(origin: 0, destination: 1)?.durationS, 1035)
        XCTAssertEqual(lastURL.path, "/maps/v1/routes/matrix")
        let b = try body()
        XCTAssertEqual(b["origins"]?.arrayValue?.count, 2)
        XCTAssertEqual(b["destinations"]?.arrayValue?.count, 3)
        XCTAssertEqual(b["mode"]?.stringValue, "bicycle")
    }

    func testFares() async throws {
        answer(200, try fixture("fares"))
        let f = try await client.fares(from: NWaysLatLng(lat: 6.4474, lng: 3.472), to: NWaysLatLng(lat: 6.6018, lng: 3.3515),
                                       modes: ["taxi", "okada"], at: Date(timeIntervalSince1970: 0), extra: ["rain": "true"])
        XCTAssertEqual(f.currency, "NGN")
        XCTAssertEqual(lastURL.path, "/maps/v1/fares/estimate")
        XCTAssertEqual(query("from"), "6.4474,3.472")
        XCTAssertEqual(query("to"), "6.6018,3.3515")
        XCTAssertEqual(query("mode"), "taxi,okada")
        XCTAssertEqual(query("at"), "1970-01-01T00:00:00Z")
        XCTAssertEqual(query("rain"), "true")
    }

    func testErrorEnvelopeThrown() async throws {
        answer(400, try fixture("postcode_invalid"))
        do {
            _ = try await client.postcode("nope")
            XCTFail("expected NWaysError")
        } catch let e as NWaysError {
            XCTAssertEqual(e.httpStatus, 400)
            XCTAssertEqual(e.status, "INVALID_ARGUMENT")
            XCTAssertEqual(e.reason, "POSTCODE_INVALID")
            XCTAssertTrue(e.message.hasPrefix("That isn't a NIPOST postcode"))
        }
    }

    func testQuotaErrorHonoursRetryAfter() async throws {
        answer(429, Data(#"{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","reason":"QUOTA_EXCEEDED","message":"Daily quota used."}}"#.utf8),
               headers: ["Content-Type": "application/json", "Retry-After": "60"])
        do {
            _ = try await client.geocode("Ikeja")
            XCTFail("expected NWaysError")
        } catch let e as NWaysError {
            XCTAssertEqual(e.httpStatus, 429)
            XCTAssertEqual(e.reason, "QUOTA_EXCEEDED")
            XCTAssertEqual(e.retryAfter, 60)
            XCTAssertTrue(e.isRetryable)
        }
    }

    func testRelayedRouteErrorThrown() async throws {
        answer(422, Data(#"{"error":{"code":422,"status":"FAILED_PRECONDITION","reason":"NO_ROUTE","message":"No route."}}"#.utf8))
        do {
            _ = try await client.route(origin: .at(lat: 6, lng: 3), destination: .at(lat: 6.1, lng: 3.1))
            XCTFail("expected NWaysError")
        } catch let e as NWaysError {
            XCTAssertEqual(e.httpStatus, 422)
            XCTAssertEqual(e.reason, "NO_ROUTE")
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
