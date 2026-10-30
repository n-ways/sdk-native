// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import Foundation

/// Header names the N-Ways API reads (they match the partner key restrictions).
public enum NWaysHeaders {
    public static let apiKey = "X-NWays-Api-Key"
    public static let iosBundleIdentifier = "X-Ios-Bundle-Identifier"
    public static let sdk = "X-NWays-Sdk"
    public static let sdkValue = "ios/" + NWaysMaps.sdkVersion
    /// Startup Program credit: the app attestation session (``NWaysCredit``).
    public static let attestation = "X-NWays-Attestation"
    /// Startup Program credit, server keys only: an opaque end-user ID (never personal data).
    public static let endUser = "X-NWays-End-User"
    public static let endUserCountry = "X-NWays-End-User-Country"

    /// All headers the SDK adds, for configuration.
    public static func all(for configuration: NWaysConfiguration) -> [String: String] {
        var h = [apiKey: configuration.apiKey, sdk: sdkValue]
        if let b = configuration.bundleIdentifier, !b.isEmpty { h[iosBundleIdentifier] = b }
        if let s = NWaysCredit.session { h[attestation] = s }
        return h
    }

    /// True when `url` is on the N-Ways host: same scheme, host and port as `base`.
    public static func isNWaysHost(_ url: URL?, base: URL) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(),
              let baseScheme = base.scheme?.lowercased(), let baseHost = base.host?.lowercased()
        else { return false }
        return scheme == baseScheme && host == baseHost && port(of: url) == port(of: base)
    }

    /// Adds the headers when `request` goes to the N-Ways host; otherwise leaves it alone.
    /// Returns whether it added them.
    @discardableResult
    public static func decorate(_ request: inout URLRequest, configuration: NWaysConfiguration) -> Bool {
        guard isNWaysHost(request.url, base: configuration.baseURL) else { return false }
        for (k, v) in all(for: configuration) { request.setValue(v, forHTTPHeaderField: k) }
        return true
    }

    /// Removes the SDK's headers (a redirect away from the N-Ways host).
    public static func strip(_ request: inout URLRequest) {
        for k in [apiKey, iosBundleIdentifier, sdk, attestation] { request.setValue(nil, forHTTPHeaderField: k) }
    }

    private static func port(of url: URL) -> Int? {
        if let p = url.port { return p }
        switch url.scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return nil
        }
    }
}
