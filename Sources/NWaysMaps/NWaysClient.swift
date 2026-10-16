// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import Foundation

/// The N-Ways Maps Platform REST API (`/maps/v1`). Every call sends the API key and the app's bundle
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

    // MARK: Geocoding and addresses

    /// Finds places, addresses, businesses, NIPOST postcodes and GhanaPost GPS addresses.
    /// `near` ranks nearer results first; `country` limits to NG, GH, BJ and/or TG; `fields`
    /// picks the fields of each result.
    public func geocode(_ query: String, near: NWaysLatLng? = nil, country: [String]? = nil, limit: Int? = nil,
                        lang: String? = nil, fields: [String]? = nil) async throws -> GeocodeResponse {
        var q = [URLQueryItem(name: "q", value: query)]
        if let near { q.append(.init(name: "near", value: Self.latLng(near))) }
        if let v = Self.list(country) { q.append(.init(name: "country", value: v)) }
        if let limit { q.append(.init(name: "limit", value: String(limit))) }
        if let lang { q.append(.init(name: "lang", value: lang)) }
        if let v = Self.list(fields) { q.append(.init(name: "fields", value: v)) }
        return try await get(NWaysPaths.geocode, query: q)
    }

    /// What's at `point`: its country, region, Plus Code, nearest address and (Nigeria) postcode.
    public func reverse(_ point: NWaysLatLng, radius: Int? = nil, lang: String? = nil) async throws -> ReverseResult {
        var q = Self.latLngItems(point)
        if let radius { q.append(.init(name: "radius", value: String(radius))) }
        if let lang { q.append(.init(name: "lang", value: lang)) }
        return try await get(NWaysPaths.reverse, query: q)
    }

    /// A NIPOST building postcode. Unknown codes throw ``NWaysError`` (404).
    public func postcode(_ code: String) async throws -> PostcodeResult {
        try await get(NWaysPaths.postcodes, extraPathSegment: code.trimmingCharacters(in: .whitespaces), query: [])
    }

    /// A GhanaPost GPS address, e.g. GA-183-8164. Unknown codes throw ``NWaysError`` (404).
    public func ghanaPost(_ code: String) async throws -> GeocodeResult {
        try await get(NWaysPaths.ghanaPost, extraPathSegment: code.trimmingCharacters(in: .whitespaces), query: [])
    }

    /// Suggestions as someone types. Send the same `session` token (8–64 letters, digits, `-` or
    /// `_`; a UUID is fine) for every keystroke until they pick a result: the session is billed
    /// once. `types`: address, street, business, place, area, postcode, ghanapost.
    public func autocomplete(_ query: String, session: String? = nil, near: NWaysLatLng? = nil, types: [String]? = nil,
                             country: [String]? = nil, limit: Int? = nil, lang: String? = nil) async throws -> GeocodeResponse {
        var q = [URLQueryItem(name: "q", value: query)]
        if let session { q.append(.init(name: "session", value: session)) }
        if let near { q.append(.init(name: "near", value: Self.latLng(near))) }
        if let v = Self.list(types) { q.append(.init(name: "types", value: v)) }
        if let v = Self.list(country) { q.append(.init(name: "country", value: v)) }
        if let limit { q.append(.init(name: "limit", value: String(limit))) }
        if let lang { q.append(.init(name: "lang", value: lang)) }
        return try await get(NWaysPaths.autocomplete, query: q)
    }

    /// Checks an address before dispatch: what was found, corrected or added, and how sure.
    public func validateAddress(_ address: String, country: String? = nil, near: NWaysLatLng? = nil,
                                lang: String? = nil) async throws -> AddressValidation {
        try await post(NWaysPaths.addressesValidate, body: ValidateBody(address: address, country: country, near: near, lang: lang))
    }

    // MARK: Places

    /// Places near `point`, by `category` (pharmacy, petrol, bank…) and/or a name `query`. For the
    /// next page pass the answer's `nextPageToken` as `pageToken`. `fields` picks the fields (and
    /// the billing tier).
    public func placesNearby(_ point: NWaysLatLng, category: String? = nil, query: String? = nil, radius: Int? = nil,
                             limit: Int? = nil, pageToken: String? = nil, fields: [String]? = nil) async throws -> PlacesResponse {
        var q = Self.latLngItems(point)
        if let category { q.append(.init(name: "category", value: category)) }
        if let query { q.append(.init(name: "q", value: query)) }
        if let radius { q.append(.init(name: "radius", value: String(radius))) }
        if let limit { q.append(.init(name: "limit", value: String(limit))) }
        if let pageToken { q.append(.init(name: "pageToken", value: pageToken)) }
        if let v = Self.list(fields) { q.append(.init(name: "fields", value: v)) }
        return try await get(NWaysPaths.placesNearby, query: q)
    }

    /// A place's details by id (from ``placesNearby(_:category:query:radius:limit:pageToken:fields:)``,
    /// or a geocoding result's `placeId`).
    public func place(_ id: String, fields: [String]? = nil) async throws -> Place {
        var q: [URLQueryItem] = []
        if let v = Self.list(fields) { q.append(.init(name: "fields", value: v)) }
        return try await get(NWaysPaths.places, extraPathSegment: id, query: q)
    }

    // MARK: Routes

    /// A route from `origin` to `destination` through up to 25 `intermediates`. `alternatives`
    /// asks for up to 2 more routes (no intermediates); `departAt` is when the trip starts;
    /// `fares` adds fare estimates to each route.
    public func route(origin: NWaysWaypoint, destination: NWaysWaypoint, mode: NWaysTravelMode = .drive,
                      intermediates: [NWaysWaypoint] = [], alternatives: Bool = false,
                      routingPreference: NWaysRoutingPreference? = nil, departAt: Date? = nil, avoid: [NWaysAvoid] = [],
                      fares: Bool = false, lang: String? = nil) async throws -> RoutesResponse {
        let body = RouteBody(
            origin: origin, destination: destination, intermediates: intermediates.isEmpty ? nil : intermediates,
            mode: mode.rawValue, alternatives: alternatives ? true : nil, routingPreference: routingPreference?.rawValue,
            departAt: departAt.map(Self.rfc3339), avoid: avoid.isEmpty ? nil : avoid.map(\.rawValue),
            fares: fares ? true : nil, lang: lang)
        return try await post(NWaysPaths.routesCompute, body: body)
    }

    /// Times and distances from each origin to each destination (up to 50 × 50, 625 elements).
    public func matrix(origins: [NWaysWaypoint], destinations: [NWaysWaypoint],
                       mode: NWaysTravelMode = .drive) async throws -> MatrixResponse {
        try await post(NWaysPaths.routesMatrix, body: MatrixBody(origins: origins, destinations: destinations, mode: mode.rawValue))
    }

    /// What a ride should cost from `from` to `to`. `modes`: taxi, shared_taxi, okada, keke, danfo,
    /// ridehail, boat. `extra` goes through as query parameters (distanceM, durationS, charter,
    /// rain, lang).
    public func fares(from: NWaysLatLng, to: NWaysLatLng, modes: [String]? = nil, at: Date? = nil,
                      extra: [String: String] = [:]) async throws -> FaresResponse {
        var q = [URLQueryItem(name: "from", value: Self.latLng(from)), URLQueryItem(name: "to", value: Self.latLng(to))]
        if let v = Self.list(modes) { q.append(.init(name: "mode", value: v)) }
        if let at { q.append(.init(name: "at", value: Self.rfc3339(at))) }
        q += extra.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await get(NWaysPaths.faresEstimate, query: q)
    }

    // MARK: plumbing

    struct ValidateBody: Encodable {
        let address: String
        let country: String?
        let near: NWaysLatLng?
        let lang: String?
    }

    struct RouteBody: Encodable {
        let origin: NWaysWaypoint
        let destination: NWaysWaypoint
        let intermediates: [NWaysWaypoint]?
        let mode: String
        let alternatives: Bool?
        let routingPreference: String?
        let departAt: String?
        let avoid: [String]?
        let fares: Bool?
        let lang: String?
    }

    struct MatrixBody: Encodable {
        let origins: [NWaysWaypoint]
        let destinations: [NWaysWaypoint]
        let mode: String
    }

    static func latLng(_ p: NWaysLatLng) -> String { coord(p.lat) + "," + coord(p.lng) }

    static func list(_ items: [String]?) -> String? {
        guard let items = items?.filter({ !$0.isEmpty }), !items.isEmpty else { return nil }
        return items.joined(separator: ",")
    }

    static func rfc3339(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
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
        try await send(request(path, extraPathSegment: extraPathSegment, query: query))
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = request(path, extraPathSegment: nil, query: [])
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    /// Sends `req`: the decoded body on 2xx (an empty object on 204), ``NWaysError`` otherwise.
    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
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
        guard (200..<300).contains(http.statusCode) else {
            throw NWaysError.from(httpStatus: http.statusCode, body: data, retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        }
        do {
            return try JSONDecoder().decode(T.self, from: http.statusCode == 204 || data.isEmpty ? Data("{}".utf8) : data)
        } catch {
            throw NWaysError(httpStatus: http.statusCode, message: "Not the JSON expected", underlying: error)
        }
    }
}
