// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import XCTest
import MapLibre
@testable import NWaysMaps

final class HeaderTests: XCTestCase {
    private let config = NWaysConfiguration(apiKey: "test-key-123", baseURL: URL(string: "https://nways.ng")!, bundleIdentifier: "ng.nways.sample")

    func testHostMatching() {
        let base = URL(string: "https://nways.ng")!
        XCTAssertTrue(NWaysHeaders.isNWaysHost(URL(string: "https://nways.ng/tiles/nigeria.pmtiles"), base: base))
        XCTAssertTrue(NWaysHeaders.isNWaysHost(URL(string: "https://NWAYS.ng/fonts/a.pbf"), base: base))
        XCTAssertTrue(NWaysHeaders.isNWaysHost(URL(string: "https://nways.ng:443/x"), base: base))
        XCTAssertFalse(NWaysHeaders.isNWaysHost(URL(string: "http://nways.ng/tiles"), base: base))
        XCTAssertFalse(NWaysHeaders.isNWaysHost(URL(string: "https://nways.ng:8443/tiles"), base: base))
        XCTAssertFalse(NWaysHeaders.isNWaysHost(URL(string: "https://api.nways.ng/tiles"), base: base))
        XCTAssertFalse(NWaysHeaders.isNWaysHost(URL(string: "https://nways.ng.evil.com/tiles"), base: base))
        XCTAssertFalse(NWaysHeaders.isNWaysHost(URL(string: "https://demotiles.maplibre.org/x"), base: base))
        XCTAssertFalse(NWaysHeaders.isNWaysHost(nil, base: base))
    }

    func testDecorateOnlyTheNWaysHost() {
        var mine = URLRequest(url: URL(string: "https://nways.ng/maps/v1/styles/streets-light.json")!)
        XCTAssertTrue(NWaysHeaders.decorate(&mine, configuration: config))
        XCTAssertEqual(mine.value(forHTTPHeaderField: "X-NWays-Api-Key"), "test-key-123")
        XCTAssertEqual(mine.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "ng.nways.sample")
        XCTAssertEqual(mine.value(forHTTPHeaderField: "X-NWays-Sdk"), "ios/1.0.0")

        var other = URLRequest(url: URL(string: "https://tile.example.com/1/2/3.png")!)
        XCTAssertFalse(NWaysHeaders.decorate(&other, configuration: config))
        XCTAssertNil(other.value(forHTTPHeaderField: "X-NWays-Api-Key"))
        XCTAssertNil(other.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"))
    }

    func testRedirectAwayStripsHeaders() {
        var hop = URLRequest(url: URL(string: "https://cdn.example.com/nigeria.pmtiles")!)
        hop.setValue("test-key-123", forHTTPHeaderField: "X-NWays-Api-Key")
        hop.setValue("ng.nways.sample", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        hop.setValue("bytes=0-16383", forHTTPHeaderField: "Range")
        let out = RedirectGuard.redirect(hop, configuration: config)
        XCTAssertNil(out.value(forHTTPHeaderField: "X-NWays-Api-Key"))
        XCTAssertNil(out.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"))
        XCTAssertEqual(out.value(forHTTPHeaderField: "Range"), "bytes=0-16383")

        let back = RedirectGuard.redirect(URLRequest(url: URL(string: "https://nways.ng/tiles/x")!), configuration: config)
        XCTAssertEqual(back.value(forHTTPHeaderField: "X-NWays-Api-Key"), "test-key-123")
    }

    /// Goes through MapLibre's own delegate protocol, as MapLibre's HTTP file source does.
    func testMapLibreDelegateDecoratesRequests() throws {
        NWaysMaps.configure(config)
        let delegate = try XCTUnwrap(MLNNetworkConfiguration.sharedManager.delegate)
        XCTAssertTrue(delegate.responds(to: NSSelectorFromString("willSendRequest:")))
        XCTAssertTrue(delegate.responds(to: NSSelectorFromString("sessionForNetworkConfiguration:")))

        let tiles = NSMutableURLRequest(url: URL(string: "https://nways.ng/tiles/nigeria.pmtiles")!)
        let out = try XCTUnwrap(delegate.willSend?(tiles))
        XCTAssertEqual(out.value(forHTTPHeaderField: "X-NWays-Api-Key"), "test-key-123")
        XCTAssertEqual(out.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "ng.nways.sample")
        XCTAssertEqual(out.value(forHTTPHeaderField: "X-NWays-Sdk"), "ios/1.0.0")

        let elsewhere = NSMutableURLRequest(url: URL(string: "https://demotiles.maplibre.org/style.json")!)
        let out2 = try XCTUnwrap(delegate.willSend?(elsewhere))
        XCTAssertNil(out2.value(forHTTPHeaderField: "X-NWays-Api-Key"))
        XCTAssertNil(out2.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"))

        let session = try XCTUnwrap(delegate.session?(for: MLNNetworkConfiguration.sharedManager))
        XCTAssertTrue(session.delegate is URLSessionTaskDelegate)
        XCTAssertFalse(session.delegate is URLSessionDataDelegate, "MapLibre doesn't support data delegates")
    }

    func testNoBundleIdentifierNoHeader() {
        let c = NWaysConfiguration(apiKey: "k", bundleIdentifier: nil)
        XCTAssertNil(NWaysHeaders.all(for: c)["X-Ios-Bundle-Identifier"])
        XCTAssertEqual(NWaysHeaders.all(for: c)["X-NWays-Api-Key"], "k")
    }
}
