import XCTest
@testable import NWaysMaps

final class StyleURLTests: XCTestCase {
    private let base = URL(string: "https://nways.ng")!

    func testDefaultLightEnglish() {
        XCTAssertEqual(NWaysMaps.buildStyleURL(baseURL: base, styleID: NWaysTheme.light.styleID)?.absoluteString,
                       "https://nways.ng/maps/v1/styles/streets-light.json")
    }

    func testDarkFrench() {
        XCTAssertEqual(NWaysMaps.buildStyleURL(baseURL: base, styleID: NWaysTheme.dark.styleID, lang: "fr")?.absoluteString,
                       "https://nways.ng/maps/v1/styles/streets-dark.json?lang=fr")
    }

    func testLangIsNormalised() {
        XCTAssertEqual(NWaysMaps.buildStyleURL(baseURL: base, styleID: "streets-light", lang: " FR ")?.absoluteString,
                       "https://nways.ng/maps/v1/styles/streets-light.json?lang=fr")
    }

    func testCustomBaseWithPathAndTrailingSlash() {
        let custom = URL(string: "https://maps.example.com/nways/")!
        XCTAssertEqual(NWaysMaps.buildStyleURL(baseURL: custom, styleID: "streets-light")?.absoluteString,
                       "https://maps.example.com/nways/maps/v1/styles/streets-light.json")
    }

    func testRejectsBadInput() {
        XCTAssertNil(NWaysMaps.buildStyleURL(baseURL: base, styleID: "streets-light", lang: "fr&x=1"))
        XCTAssertNil(NWaysMaps.buildStyleURL(baseURL: base, styleID: "../secret"))
    }

    func testConfiguredStyleURL() {
        NWaysMaps.configure(NWaysConfiguration(apiKey: "k", baseURL: URL(string: "https://staging.example.org/")!, bundleIdentifier: "ng.nways.tests"))
        XCTAssertEqual(NWaysMaps.styleURL(theme: .dark, lang: "fr").absoluteString,
                       "https://staging.example.org/maps/v1/styles/streets-dark.json?lang=fr")
        XCTAssertEqual(NWaysMaps.styleURL().absoluteString, "https://staging.example.org/maps/v1/styles/streets-light.json")
    }

    func testDefaults() {
        XCTAssertEqual(NWaysMaps.defaultCenter.latitude, 6.5244)
        XCTAssertEqual(NWaysMaps.defaultCenter.longitude, 3.3792)
        XCTAssertEqual(NWaysMaps.defaultZoom, 11)
        XCTAssertEqual(NWaysMaps.westAfricaBounds.sw.longitude, -4.5)
        XCTAssertEqual(NWaysMaps.westAfricaBounds.ne.longitude, 16.5)
        XCTAssertEqual(NWaysMaps.westAfricaBounds.sw.latitude, 2.5)
        XCTAssertEqual(NWaysMaps.westAfricaBounds.ne.latitude, 15.5)
        XCTAssertEqual(NWaysMaps.attribution, "© N-Ways · © OpenStreetMap contributors · Protomaps")
    }
}
