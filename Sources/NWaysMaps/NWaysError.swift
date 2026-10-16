// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import Foundation

/// A request N-Ways refused or couldn't answer.
///
/// - Every `/maps/v1` error, `{"error":{"code":403,"status":"PERMISSION_DENIED","reason":"API_KEY_SERVICE_BLOCKED","message":"…"}}`,
///   fills ``status`` and ``reason`` (NO_ROUTE, POSTCODE_UNKNOWN, LAT_LNG_REQUIRED, QUOTA_EXCEEDED…).
/// - The older `{"error":"…","code":"no_route"}` shape (another host, an older server) fills ``code``.
/// - A network failure has ``httpStatus`` 0 and the ``underlying`` error.
///
/// Act on ``httpStatus`` and ``reason`` (or ``code``), never on ``message``'s words.
public struct NWaysError: Error, LocalizedError, CustomStringConvertible, @unchecked Sendable {
    /// The HTTP status, or 0 when no answer came (network failure).
    public let httpStatus: Int
    /// INVALID_ARGUMENT, UNAUTHENTICATED, PERMISSION_DENIED, NOT_FOUND, FAILED_PRECONDITION, RESOURCE_EXHAUSTED, UNAVAILABLE…
    public let status: String?
    /// Why, in capitals: API_KEY_SERVICE_BLOCKED, NO_ROUTE, POSTCODE_UNKNOWN…
    public let reason: String?
    /// The older error shape's code (no_route…); nil for `/maps/v1` envelopes.
    public let code: String?
    public let message: String
    /// Seconds to wait before retrying, from Retry-After (429, 503).
    public let retryAfter: TimeInterval?
    /// The error body, when it was JSON.
    public let raw: JSONValue?
    public let underlying: Error?

    public init(httpStatus: Int, status: String? = nil, reason: String? = nil, code: String? = nil, message: String,
                retryAfter: TimeInterval? = nil, raw: JSONValue? = nil, underlying: Error? = nil) {
        self.httpStatus = httpStatus
        self.status = status
        self.reason = reason
        self.code = code
        self.message = message
        self.retryAfter = retryAfter
        self.raw = raw
        self.underlying = underlying
    }

    /// Worth retrying later: rate limits, server trouble and network failures.
    public var isRetryable: Bool { httpStatus == 0 || httpStatus == 429 || httpStatus >= 500 }

    public var errorDescription: String? { message }

    public var description: String {
        "NWaysError(httpStatus: \(httpStatus), status: \(status ?? "nil"), reason: \(reason ?? "nil"), " +
            "code: \(code ?? "nil"), retryAfter: \(retryAfter.map { "\($0)" } ?? "nil"), message: \(message))"
    }

    /// The error for an HTTP answer with `httpStatus`, `body` and its Retry-After header.
    public static func from(httpStatus: Int, body: Data?, retryAfter: String?, now: Date = Date()) -> NWaysError {
        let json = body.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
        let wait = parseRetryAfter(retryAfter, now: now)
        if case .object(let e)? = json?["error"] {
            return NWaysError(
                httpStatus: httpStatus,
                status: e["status"]?.stringValue,
                reason: e["reason"]?.stringValue,
                message: e["message"]?.stringValue ?? "HTTP \(httpStatus)",
                retryAfter: wait,
                raw: json
            )
        }
        let text = json?["error"]?.stringValue ?? json?["message"]?.stringValue
        let plain = json == nil ? body.flatMap { String(data: $0.prefix(200), encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 } : nil
        return NWaysError(
            httpStatus: httpStatus,
            code: json?["code"]?.stringValue,
            message: text ?? plain ?? "HTTP \(httpStatus)",
            retryAfter: wait,
            raw: json
        )
    }

    /// Retry-After as seconds: a number of seconds or an HTTP date.
    public static func parseRetryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        if let s = Int(v) { return TimeInterval(max(0, s)) }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let at = f.date(from: v) else { return nil }
        return max(0, at.timeIntervalSince(now).rounded(.up))
    }
}
