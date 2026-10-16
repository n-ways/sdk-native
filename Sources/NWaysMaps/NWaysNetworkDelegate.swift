// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import Foundation
import MapLibre

/// Hooks into MapLibre's networking: `willSendRequest` adds the N-Ways headers to every
/// request for the N-Ways host (style, PMTiles ranges, fonts, sprites) and to nothing else;
/// the session's redirect handler takes them off again if a redirect leaves that host.
final class NWaysNetworkDelegate: NSObject, MLNNetworkConfigurationDelegate, @unchecked Sendable {
    static let shared = NWaysNetworkDelegate()

    private let lock = NSLock()
    private var session: URLSession?

    func install() {
        // MLNNetworkConfiguration holds its delegate weakly; `shared` keeps this one alive.
        MLNNetworkConfiguration.sharedManager.delegate = self
    }

    @objc(willSendRequest:)
    func willSend(_ request: NSMutableURLRequest) -> NSMutableURLRequest {
        guard let configuration = NWaysMaps.configuration else { return request }
        var r = request as URLRequest
        guard NWaysHeaders.decorate(&r, configuration: configuration) else { return request }
        for (k, v) in NWaysHeaders.all(for: configuration) { request.setValue(v, forHTTPHeaderField: k) }
        return request
    }

    @objc(sessionForNetworkConfiguration:)
    func session(for configuration: MLNNetworkConfiguration) -> URLSession {
        lock.lock(); defer { lock.unlock() }
        if let session { return session }
        let s = URLSession(configuration: configuration.sessionConfiguration, delegate: RedirectGuard { NWaysMaps.configuration }, delegateQueue: nil)
        session = s
        return s
    }
}

/// Drops the N-Ways headers when a redirect leaves the N-Ways host, so the key never
/// reaches another host. A task delegate only (MapLibre doesn't support data delegates).
final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let configuration: @Sendable () -> NWaysConfiguration?

    init(_ configuration: @escaping @Sendable () -> NWaysConfiguration?) {
        self.configuration = configuration
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(Self.redirect(request, configuration: configuration()))
    }

    static func redirect(_ request: URLRequest, configuration: NWaysConfiguration?) -> URLRequest {
        var r = request
        if let configuration, NWaysHeaders.isNWaysHost(r.url, base: configuration.baseURL) {
            NWaysHeaders.decorate(&r, configuration: configuration)
        } else {
            NWaysHeaders.strip(&r)
        }
        return r
    }
}
