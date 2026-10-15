import Foundation

/// A request N-Ways refused or couldn't answer.
///
/// - Key and quota errors, `{"error":{"code":403,"status":"PERMISSION_DENIED","reason":"…","message":"…"}}`,
///   fill ``status`` and ``reason``.
/// - API errors, `{"error":"…","code":"no_route"}`, fill ``code``.
/// - A network failure has ``httpStatus`` 0 and the ``underlying`` error.
///
/// Act on ``httpStatus``, ``reason`` and ``code``, never on ``message``'s words.
public struct NWaysError: Error, LocalizedError, CustomStringConvertible, @unchecked Sendable {
    /// The HTTP status, or 0 when no answer came (network failure).
    public let httpStatus: Int
    /// Key/quota errors: PERMISSION_DENIED, RESOURCE_EXHAUSTED, INVALID_ARGUMENT, UNAVAILABLE…
    public let status: String?
    /// Key/quota errors: why, e.g. API_KEY_SERVICE_BLOCKED.
    public let reason: String?
    /// API errors: a stable code such as no_route or postcode_unknown.
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
