import Foundation
import CoreLocation
import MapLibre

/// The map's look: N-Ways' light or dark streets style.
public enum NWaysTheme: String, CaseIterable, Sendable {
    case light
    case dark

    /// The style ID on the server: `streets-light` or `streets-dark`.
    public var styleID: String {
        switch self {
        case .light: return NWaysMaps.styleStreetsLight
        case .dark: return NWaysMaps.styleStreetsDark
        }
    }
}

/// What ``NWaysMaps/configure(apiKey:baseURL:)`` was given.
public struct NWaysConfiguration: Sendable, Equatable {
    public let apiKey: String
    public let baseURL: URL
    /// Sent as `X-Ios-Bundle-Identifier`; `Bundle.main.bundleIdentifier` by default.
    public let bundleIdentifier: String?

    public init(apiKey: String, baseURL: URL = NWaysMaps.defaultBaseURL, bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = NWaysMaps.normalizeBaseURL(baseURL)
        self.bundleIdentifier = bundleIdentifier
    }
}

/// N-Ways Maps for iOS. Call ``configure(apiKey:baseURL:)`` once at launch, before the
/// first map view, then use ``NWaysMapView`` (SwiftUI), ``NWaysUIMapView`` (UIKit),
/// ``styleURL(theme:lang:)`` and ``client``.
public enum NWaysMaps {
    public static let sdkVersion = "1.0.0"
    public static let defaultBaseURL = URL(string: "https://nways.ng")!
    public static let styleStreetsLight = "streets-light"
    public static let styleStreetsDark = "streets-dark"

    /// The credit shown on every N-Ways map. Keep it visible.
    public static let attribution = "© N-Ways · © OpenStreetMap contributors · Protomaps"

    /// ``attribution`` as MapLibre attribution HTML (MapLibre lists each link).
    public static let attributionHTML =
        "<a href=\"https://nways.ng/\">© N-Ways</a> · " +
        "<a href=\"https://www.openstreetmap.org/copyright\">© OpenStreetMap contributors</a> · " +
        "<a href=\"https://protomaps.com/\">Protomaps</a>"

    /// Lagos.
    public static let defaultCenter = CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)
    public static let defaultZoom: Double = 11

    /// West Africa: Nigeria, Ghana, Benin and Togo with room around them.
    public static let westAfricaBounds = MLNCoordinateBounds(
        sw: CLLocationCoordinate2D(latitude: 2.5, longitude: -4.5),
        ne: CLLocationCoordinate2D(latitude: 15.5, longitude: 16.5)
    )

    private static let state = ConfigurationStore()

    /// The configuration, or nil before ``configure(apiKey:baseURL:)``.
    public static var configuration: NWaysConfiguration? { state.configuration }

    /// Sets up N-Ways Maps: every request MapLibre sends to `baseURL`'s host carries the
    /// API key and the app's bundle identifier. Requests to other hosts are left alone.
    public static func configure(apiKey: String, baseURL: URL = defaultBaseURL) {
        configure(NWaysConfiguration(apiKey: apiKey, baseURL: baseURL))
    }

    public static func configure(_ configuration: NWaysConfiguration) {
        precondition(!configuration.apiKey.isEmpty, "NWaysMaps: apiKey is empty")
        state.configuration = configuration
        NWaysNetworkDelegate.shared.install()
    }

    /// The REST client (geocoding, places, routes, fares) for the current configuration.
    public static var client: NWaysClient {
        guard let configuration else {
            preconditionFailure("Call NWaysMaps.configure(apiKey:) first.")
        }
        return state.client(for: configuration)
    }

    /// The style URL for `theme` and `lang` ("en" or "fr") on the configured host.
    public static func styleURL(theme: NWaysTheme = .light, lang: String = "en") -> URL {
        guard let configuration else {
            preconditionFailure("Call NWaysMaps.configure(apiKey:) first.")
        }
        guard let url = buildStyleURL(baseURL: configuration.baseURL, styleID: theme.styleID, lang: lang) else {
            preconditionFailure("NWaysMaps: bad lang \(lang)")
        }
        return url
    }

    /// `{baseURL}/maps/v1/styles/{styleID}.json`, with `?lang=xx` when `lang` isn't English
    /// (the server's default). Nil for a malformed style ID or language code.
    public static func buildStyleURL(baseURL: URL, styleID: String, lang: String = "en") -> URL? {
        let l = lang.trimmingCharacters(in: .whitespaces).lowercased()
        guard styleID.range(of: "^[a-z0-9][a-z0-9-]{0,63}$", options: .regularExpression) != nil,
              l.range(of: "^[a-z]{2,3}$", options: .regularExpression) != nil
        else { return nil }
        let base = normalizeBaseURL(baseURL)
        guard var c = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        c.path = (c.path.hasSuffix("/") ? String(c.path.dropLast()) : c.path) + "/maps/v1/styles/\(styleID).json"
        if l != "en" { c.queryItems = [URLQueryItem(name: "lang", value: l)] }
        return c.url
    }

    static func normalizeBaseURL(_ url: URL) -> URL {
        var s = url.absoluteString
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s) ?? url
    }
}

/// Holds the configuration and the shared client; read from MapLibre's network threads.
private final class ConfigurationStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _configuration: NWaysConfiguration?
    private var _client: NWaysClient?

    var configuration: NWaysConfiguration? {
        get { lock.lock(); defer { lock.unlock() }; return _configuration }
        set { lock.lock(); _configuration = newValue; _client = nil; lock.unlock() }
    }

    func client(for configuration: NWaysConfiguration) -> NWaysClient {
        lock.lock(); defer { lock.unlock() }
        if let c = _client, c.configuration == configuration { return c }
        let c = NWaysClient(configuration: configuration)
        _client = c
        return c
    }
}
