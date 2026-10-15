import Foundation

/// The N-Ways REST APIs (preview). Every call sends the API key and the app's bundle
/// identifier, like the map does. Failures throw ``NWaysError``.
///
/// Use the shared one, ``NWaysMaps/client``, after ``NWaysMaps/configure(apiKey:baseURL:)``.
public final class NWaysClient: @unchecked Sendable {
    public let configuration: NWaysConfiguration
    private let session: URLSession

    /// - Parameter sessionConfiguration: the URLSession set-up (timeouts, caching, test protocols).
    public init(configuration: NWaysConfiguration, sessionConfiguration: URLSessionConfiguration = .default) {
        self.configuration = configuration
        let fixed = configuration
        session = URLSession(configuration: sessionConfiguration, delegate: RedirectGuard { fixed }, delegateQueue: nil)
    }

    deinit { session.finishTasksAndInvalidate() }

    /// Finds places, addresses, businesses and postcodes. `near` ranks nearer results first.
    public func geocode(_ query: String, limit: Int? = nil, near: NWaysLatLng? = nil, lang: String? = nil) async throws -> GeocodeResponse {
        var q = [URLQueryItem(name: "q", value: query)]
        if let limit { q.append(.init(name: "limit", value: String(limit))) }
        if let near { q += Self.latLngItems(near) }
        if let lang { q.append(.init(name: "lang", value: lang)) }
        return try await get(NWaysPaths.geocode, query: q)
    }

    /// What's at `point`, or nil when nothing is known close enough (HTTP 204).
    public func reverse(_ point: NWaysLatLng, lang: String? = nil) async throws -> ReverseResult? {
        var q = Self.latLngItems(point)
        if let lang { q.append(.init(name: "lang", value: lang)) }
        return try await getOptional(NWaysPaths.reverse, query: q)
    }

    /// Looks up a NIPOST building postcode. Unknown codes throw ``NWaysError`` (404 postcode_unknown).
    public func postcode(_ code: String) async throws -> PostcodeResult {
        try await get(NWaysPaths.postcodes, extraPathSegment: code.trimmingCharacters(in: .whitespaces), query: [])
    }

    /// Places near `point`: by `category` (pharmacy, petrol, bank…) and/or a name `query`.
    public func places(near point: NWaysLatLng, category: String? = nil, query: String? = nil,
                       radius: Int? = nil, limit: Int? = nil) async throws -> PlacesResponse {
        var q = Self.latLngItems(point)
        if let category { q.append(.init(name: "category", value: category)) }
        if let query { q.append(.init(name: "q", value: query)) }
        if let radius { q.append(.init(name: "radius", value: String(radius))) }
        if let limit { q.append(.init(name: "limit", value: String(limit))) }
        return try await get(NWaysPaths.places, query: q)
    }

    /// A route from `from` to `to`. `ride` (keke or bus) goes with `.drive`; `alternates` is 0 to 3.
    public func routes(from: NWaysLatLng, to: NWaysLatLng, mode: NWaysTravelMode = .drive, alternates: Int = 0,
                       stops: [NWaysLatLng] = [], ride: String? = nil, lang: String? = nil,
                       avoidTolls: Bool? = nil) async throws -> RoutesResponse {
        let body = RouteRequestBody(from: from, to: to, stops: stops.isEmpty ? nil : stops, mode: mode.rawValue,
                                    alternates: alternates, ride: ride, lang: lang, avoidTolls: avoidTolls)
        var req = request(NWaysPaths.routes, extraPathSegment: nil, query: [])
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        guard let res: RoutesResponse = try await send(req) else {
            throw NWaysError(httpStatus: 204, message: "Empty answer")
        }
        return res
    }

    /// What a ride should cost. `params` go through as query parameters, e.g.
    /// `["from": "6.6018,3.3515", "to": "6.5244,3.3792", "mode": "keke,taxi"]`.
    public func fareEstimate(_ params: [String: String]) async throws -> FareEstimateResponse {
        let q = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await get(NWaysPaths.faresEstimate, query: q)
    }

    // MARK: plumbing

    struct RouteRequestBody: Encodable {
        let from: NWaysLatLng
        let to: NWaysLatLng
        let stops: [NWaysLatLng]?
        let mode: String
        let alternates: Int
        let ride: String?
        let lang: String?
        let avoidTolls: Bool?
    }

    static func latLngItems(_ p: NWaysLatLng) -> [URLQueryItem] {
        [URLQueryItem(name: "lat", value: coord(p.lat)), URLQueryItem(name: "lng", value: coord(p.lng))]
    }

    static func coord(_ v: Double) -> String {
        var s = String(format: "%.7f", locale: Locale(identifier: "en_US_POSIX"), v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    func request(_ path: String, extraPathSegment: String?, query: [URLQueryItem]) -> URLRequest {
        var url = configuration.baseURL
        for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        if let extraPathSegment { url.appendPathComponent(extraPathSegment) }
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            c.queryItems = query
            // URLComponents leaves "+" alone; servers read it as a space.
            c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        var req = URLRequest(url: c.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        NWaysHeaders.decorate(&req, configuration: configuration)
        return req
    }

    private func get<T: Decodable>(_ path: String, extraPathSegment: String? = nil, query: [URLQueryItem]) async throws -> T {
        guard let res: T = try await getOptional(path, extraPathSegment: extraPathSegment, query: query) else {
            throw NWaysError(httpStatus: 204, message: "Empty answer")
        }
        return res
    }

    private func getOptional<T: Decodable>(_ path: String, extraPathSegment: String? = nil, query: [URLQueryItem]) async throws -> T? {
        try await send(request(path, extraPathSegment: extraPathSegment, query: query))
    }

    /// Sends `req`: the decoded body on 2xx, nil on 204, ``NWaysError`` otherwise.
    private func send<T: Decodable>(_ req: URLRequest) async throws -> T? {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let e as NWaysError {
            throw e
        } catch {
            throw NWaysError(httpStatus: 0, status: "NETWORK", message: error.localizedDescription, underlying: error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NWaysError(httpStatus: 0, status: "NETWORK", message: "Not an HTTP response")
        }
        if http.statusCode == 204 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw NWaysError.from(httpStatus: http.statusCode, body: data, retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NWaysError(httpStatus: http.statusCode, message: "Not the JSON expected", underlying: error)
        }
    }
}
