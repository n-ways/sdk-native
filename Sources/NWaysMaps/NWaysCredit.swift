// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import CryptoKit
import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// Startup Program credit for apps (https://nways.ng/developers/startup-credit).
///
/// The credit pays for an app's calls only when they carry a valid app attestation
/// for the verified app the key is bound to. ``NWaysCredit/start()`` does it once
/// every 30 days: it asks N-Ways for a challenge, has Apple's App Attest
/// (`DCAppAttestService`) attest a key over it, and keeps the session N-Ways returns.
/// From then on the SDK sends it as `X-NWays-Attestation` on every N-Ways request.
///
/// Call it after ``NWaysMaps/configure(apiKey:baseURL:)`` (a background task at launch
/// is fine). Calls made before it finishes, or on a device that can't attest
/// (the simulator, jailbroken devices), are billed as normal paid usage.
public enum NWaysCredit {
    /// Where the session is kept between launches.
    static let tokenKey = "ng.nways.credit.session"
    static let expiryKey = "ng.nways.credit.session.expires"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: (token: String, expires: Date)?

    /// The current session, if any and not expired (the header's value).
    public static var session: String? {
        lock.lock()
        defer { lock.unlock() }
        if cached == nil, let t = UserDefaults.standard.string(forKey: tokenKey),
           let e = UserDefaults.standard.object(forKey: expiryKey) as? Date {
            cached = (t, e)
        }
        guard let c = cached, c.expires > Date().addingTimeInterval(3600) else { return nil }
        return c.token
    }

    static func store(_ token: String, expires: Date) {
        lock.lock()
        cached = (token, expires)
        lock.unlock()
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(expires, forKey: expiryKey)
    }

    /// Forgets the session (N-Ways answered `X-NWays-Credit: paid; why=attestation_invalid`).
    public static func reset() {
        lock.lock()
        cached = nil
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)
    }

    /// Errors attesting.
    public enum Failure: Error, Equatable {
        case notConfigured
        case notSupported // App Attest isn't available on this device
        case server(status: Int, reason: String)
    }

    /// Attests the app if there's no valid session; returns when the session ends.
    @discardableResult
    public static func start() async throws -> Date {
        if let s = session, let e = cached?.expires, !s.isEmpty { return e }
        guard let config = NWaysMaps.configuration else { throw Failure.notConfigured }
        #if canImport(DeviceCheck)
        let service = DCAppAttestService.shared
        guard service.isSupported else { throw Failure.notSupported }
        let challenge = try await post(config, path: "/maps/v1/credit/attest/challenge", body: [:])["challenge"] as? String ?? ""
        let keyId = try await service.generateKey()
        let clientData = Data("nways-credit|\(challenge)|\(keyId)".utf8)
        let hash = Data(SHA256.hash(data: clientData))
        let attestation = try await service.attestKey(keyId, clientDataHash: hash)
        let res = try await post(config, path: "/maps/v1/credit/attest", body: [
            "platform": "ios", "challenge": challenge, "keyId": keyId, "attestation": attestation.base64EncodedString(),
        ])
        guard let token = res["token"] as? String, let exp = res["expiresAt"] as? String,
              let expires = ISO8601DateFormatter().date(from: exp)
        else { throw Failure.server(status: 200, reason: "BAD_ANSWER") }
        store(token, expires: expires)
        return expires
        #else
        throw Failure.notSupported
        #endif
    }

    private static func post(_ config: NWaysConfiguration, path: String, body: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: config.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        NWaysHeaders.decorate(&req, configuration: config)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard status == 200 else {
            let reason = (json["error"] as? [String: Any])?["reason"] as? String ?? "HTTP_\(status)"
            throw Failure.server(status: status, reason: reason)
        }
        return json
    }
}
