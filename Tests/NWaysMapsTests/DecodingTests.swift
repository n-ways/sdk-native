import XCTest
@testable import NWaysMaps

func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

final class DecodingTests: XCTestCase {
    func testGeocode() throws {
        let res = try JSONDecoder().decode(GeocodeResponse.self, from: fixture("geocode"))
        XCTAssertEqual(res.results.count, 3, "an odd result is kept, with its fields nil")
        let a = res.results[0]
        XCTAssertEqual(a.id, "osm:n501540907")
        XCTAssertEqual(a.name, "Ikeja")
        XCTAssertEqual(a.kind, "city")
        XCTAssertEqual(a.location, NWaysLatLng(lat: 6.601627, lng: 3.3515981))
        XCTAssertEqual(a.label, "Ikeja, Lagos State")
        XCTAssertEqual(a.raw["someFutureField"]?["x"]?.intValue, 1)
        let b = res.results[1]
        XCTAssertTrue(b.estimated)
        XCTAssertEqual(b.radiusM, 300)
        XCTAssertEqual(b.bbox, [-0.3, 5.5, -0.1, 5.6])
        XCTAssertEqual(b.attribution, "© OpenStreetMap contributors")
        let odd = res.results[2]
        XCTAssertNil(odd.id)
        XCTAssertNil(odd.name)
        XCTAssertNil(odd.location)
        XCTAssertEqual(res.didYouMean, "Ikeja")
    }

    func testPlaces() throws {
        let res = try JSONDecoder().decode(PlacesResponse.self, from: fixture("places"))
        let p = try XCTUnwrap(res.places.first)
        XCTAssertEqual(p.name, "Example Pharmacy")
        XCTAssertEqual(p.hours, "Mo-Sa 08:00-20:00")
        XCTAssertEqual(p.distanceM, 106)
        XCTAssertEqual(p.source, "overture")
        XCTAssertFalse(res.more)
    }

    func testRoutes() throws {
        let res = try JSONDecoder().decode(RoutesResponse.self, from: fixture("routes"))
        XCTAssertEqual(res.mode, "motorcycle")
        let r = try XCTUnwrap(res.routes.first)
        XCTAssertEqual(r.distanceM, 18420)
        XCTAssertEqual(r.durationS, 2310)
        XCTAssertEqual(r.trafficDelayS, 420)
        XCTAssertEqual(r.via, "Ikorodu Road")
        XCTAssertEqual(r.geometry, [NWaysLatLng(lat: 6.6018, lng: 3.3515), NWaysLatLng(lat: 6.6011, lng: 3.3521)])
        XCTAssertEqual(r.maneuvers.first?.instruction, "Head south on Allen Avenue.")
        XCTAssertEqual(r.maneuvers.first?.endIndex, 12)
        XCTAssertEqual(r.raw["tolls"]?["costNGN"]?.doubleValue, 0)
        XCTAssertEqual(res.raw["tollsUnavoidable"]?.boolValue, false)
    }

    func testPostcode() throws {
        let p = try JSONDecoder().decode(PostcodeResult.self, from: fixture("postcode"))
        XCTAssertEqual(p.code, "ABC123")
        XCTAssertEqual(p.display, "ABC 123")
        XCTAssertEqual(p.stateName, "Lagos")
        XCTAssertEqual(p.entrances.first?.id, 7)
        XCTAssertEqual(p.entrances.first?.verified, true)
    }

    func testFares() throws {
        let f = try JSONDecoder().decode(FareEstimateResponse.self, from: fixture("fares"))
        XCTAssertEqual(f.currency, "NGN")
        XCTAssertEqual(f.estimates.first?.mode, "keke")
        XCTAssertEqual(f.estimates.first?.text, "₦1,500–2,500")
        XCTAssertEqual(f.estimates.first?.raw["typicalText"]?.stringValue, "₦2,000")
        XCTAssertEqual(f.raw["area"]?.stringValue, "lagos")
    }

    func testEmptyObjectsDecode() throws {
        let empty = Data("{}".utf8)
        XCTAssertTrue(try JSONDecoder().decode(GeocodeResponse.self, from: empty).results.isEmpty)
        XCTAssertTrue(try JSONDecoder().decode(RoutesResponse.self, from: empty).routes.isEmpty)
        XCTAssertNil(try JSONDecoder().decode(ReverseResult.self, from: empty).code)
    }
}
