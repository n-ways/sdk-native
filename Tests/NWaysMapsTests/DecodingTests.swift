import XCTest
@testable import NWaysMaps

func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(type, from: fixture(name))
}

/// Decoding the partner API's own golden answers (backend/internal/partnerapi/testdata/golden).
final class DecodingTests: XCTestCase {
    func testGeocode() throws {
        let res = try decode(GeocodeResponse.self, "geocode")
        XCTAssertEqual(res.results.count, 4)
        let a = res.results[0]
        XCTAssertEqual(a.id, "osm:w568367632")
        XCTAssertEqual(a.type, "landmark")
        XCTAssertEqual(a.location, NWaysLatLng(lat: 6.61437, lng: 3.357831))
        XCTAssertEqual(a.label, "Ikeja City Mall, Ikeja, Lagos")
        XCTAssertEqual(a.bbox?.count, 4)
        XCTAssertEqual(a.plusCode, "6FR5J975+P4W")
        XCTAssertEqual(a.distanceM, 22445)
        XCTAssertEqual(res.results[1].placeId, "ov:7c065f24-3cc2-4426-9163-a5a54e7e2860")
        XCTAssertEqual(res.attribution, "© OpenStreetMap contributors, N-Ways")
    }

    func testReverseNigeria() throws {
        let r = try decode(ReverseResult.self, "reverse_ng")
        XCTAssertEqual(r.location, NWaysLatLng(lat: 6.4474, lng: 3.472))
        XCTAssertEqual(r.country?.code, "NG")
        XCTAssertEqual(r.region?.nameFr, "État de Lagos")
        XCTAssertEqual(r.postcode?.code, "LA08A09DB09")
        XCTAssertEqual(r.postcode?.components?.lgaName, "Eti-Osa")
        XCTAssertEqual(r.postcode?.distanceM, 16)
        XCTAssertNil(r.ghanaPost)
        XCTAssertEqual(r.nearest?.name, "Brasas'r Place")
    }

    func testReverseGhana() throws {
        let r = try decode(ReverseResult.self, "reverse_gh")
        XCTAssertEqual(r.ghanaPost, "GA-183-8164")
        XCTAssertEqual(r.region?.code, "GH-AA")
        XCTAssertNil(r.postcode)
    }

    func testPostcode() throws {
        let p = try decode(PostcodeResult.self, "postcode")
        XCTAssertEqual(p.display, "LA 08 A09 DB 09")
        XCTAssertEqual(p.components?.state, "LA")
        XCTAssertEqual(p.buildingType, "house")
        XCTAssertEqual(p.entrances.first?.kind, "gate")
        XCTAssertEqual(p.entrances.first?.verified, true)
        XCTAssertEqual(p.entrances.first?.location, NWaysLatLng(lat: 6.44738, lng: 3.47225))
        XCTAssertFalse(p.estimated)
    }

    func testGhanaPost() throws {
        let g = try decode(GeocodeResult.self, "ghanapost")
        XCTAssertEqual(g.type, "ghanapost")
        XCTAssertEqual(g.ghanaPost, "GA-183-8164")
        XCTAssertEqual(g.location, NWaysLatLng(lat: 5.54226, lng: -0.207658))
    }

    func testValidate() throws {
        let v = try decode(AddressValidation.self, "validate_postcode")
        XCTAssertEqual(v.verdict?.status, "VALID")
        XCTAssertEqual(v.verdict?.granularity, "PREMISE")
        XCTAssertEqual(v.verdict?.codesAgree, true)
        XCTAssertEqual(v.components.first?.type, "postcode")
        XCTAssertEqual(v.postcode?.code, "LA08A09DB09")
        XCTAssertEqual(v.location, NWaysLatLng(lat: 6.4475, lng: 3.4721))
    }

    func testPlaces() throws {
        let res = try decode(PlacesResponse.self, "places_nearby")
        XCTAssertEqual(res.places.count, 3)
        XCTAssertEqual(res.places.first?.name, "Access Bank")
        XCTAssertEqual(res.places.first?.businessStatus, "OPERATIONAL")
        XCTAssertEqual(res.places.first?.distanceM, 2403)
        XCTAssertEqual(res.nextPageToken, "bzoz")
        let p = try decode(Place.self, "place_details_all")
        XCTAssertEqual(p.phone, "+234 90 1400 0001")
        XCTAssertEqual(p.openingHours?.text, "Mo-Su 09:00-21:00")
    }

    func testRoutes() throws {
        let res = try decode(RoutesResponse.self, "routes_drive")
        XCTAssertEqual(res.mode, "drive")
        let r = try XCTUnwrap(res.routes.first)
        XCTAssertEqual(r.distanceM, 1395)
        XCTAssertEqual(r.durationS, 228)
        XCTAssertEqual(r.speedSource, "estimated")
        XCTAssertEqual(r.geometry.count, 16)
        XCTAssertEqual(r.geometry.first, NWaysLatLng(lat: 6.4474, lng: 3.472352))
        XCTAssertEqual(r.geometry.last, NWaysLatLng(lat: 6.444003, lng: 3.479797))
        XCTAssertEqual(r.steps.count, 6)
        XCTAssertEqual(r.steps.first?.maneuver, "depart_left")
        XCTAssertEqual(r.steps.first?.streetNames, ["Victoria Arobieke Street"])
        XCTAssertEqual(r.legs.count, 1)
        XCTAssertEqual(res.waypoints.last?.postcode, "LA08A09DB10")
        XCTAssertEqual(r.raw["country"]?.stringValue, "NG")
    }

    func testMatrix() throws {
        let m = try decode(MatrixResponse.self, "matrix")
        XCTAssertEqual(m.elements.count, 6)
        let e = try XCTUnwrap(m.element(origin: 1, destination: 2))
        XCTAssertTrue(e.isOK)
        XCTAssertEqual(e.durationS, 2820)
        XCTAssertEqual(e.distanceM, 28195)
        XCTAssertEqual(m.destinations.last, NWaysLatLng(lat: 6.6, lng: 3.35))
    }

    func testFares() throws {
        let f = try decode(FaresResponse.self, "fares")
        XCTAssertEqual(f.currency, "NGN")
        XCTAssertEqual(f.region, "NG-LA")
        XCTAssertEqual(f.estimates.count, 4)
        XCTAssertEqual(f.estimates.first?.text, "₦8,150–15,200")
        XCTAssertEqual(f.estimates.first?.charter, true)
        XCTAssertEqual(f.estimates.first?.raw["openingOffer"]?.doubleValue, 7750)
        XCTAssertEqual(f.notAllowed.first?.mode, "okada")
        XCTAssertNotNil(f.notAllowed.first?.raw["ban"])
    }

    func testOddFieldsDontSinkTheAnswer() throws {
        let odd = Data(#"{"results":[{"id":42,"name":null,"location":"nowhere"},{"id":"a","location":{"lat":6.5,"lng":3.3}}]}"#.utf8)
        let res = try JSONDecoder().decode(GeocodeResponse.self, from: odd)
        XCTAssertEqual(res.results.count, 2)
        XCTAssertNil(res.results[0].id)
        XCTAssertNil(res.results[0].location)
        XCTAssertEqual(res.results[1].location, NWaysLatLng(lat: 6.5, lng: 3.3))
        let empty = Data("{}".utf8)
        XCTAssertTrue(try JSONDecoder().decode(RoutesResponse.self, from: empty).routes.isEmpty)
        XCTAssertNil(try JSONDecoder().decode(ReverseResult.self, from: empty).postcode)
    }
}
