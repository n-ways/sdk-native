import Foundation
import CoreLocation

/// A point. The REST API's own type, so it needs no map on screen.
public struct NWaysLatLng: Codable, Hashable, Sendable {
    public var lat: Double
    public var lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }

    public init(_ coordinate: CLLocationCoordinate2D) {
        self.init(lat: coordinate.latitude, lng: coordinate.longitude)
    }

    public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }

    /// A `[lng, lat]` pair (GeoJSON order).
    init?(lngLat a: [Double]) {
        guard a.count >= 2 else { return nil }
        self.init(lat: a[1], lng: a[0])
    }
}

// Models are deliberately loose: only the fields most apps need, all optional where the API
// may leave them out, and the whole JSON object in `raw` so new fields aren't lost.

/// `GET /v1/geocode` answer.
public struct GeocodeResponse: Decodable, Sendable {
    public let results: [GeocodeResult]
    /// A spelling the API suggests, when the query looked mistyped.
    public let didYouMean: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case results, didYouMean }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        results = c.lenientArray(GeocodeResult.self, .results)
        didYouMean = c.lenient(String.self, .didYouMean)
    }
}

/// One geocoding result: a place, area, address, business or postcode.
public struct GeocodeResult: Decodable, Sendable {
    public let id: String?
    public let name: String?
    /// city, town, street, address, landmark, business…
    public let kind: String?
    /// For a business: pharmacy, petrol, bank…
    public let category: String?
    public let location: NWaysLatLng?
    /// Where it is, to tell places apart: "Lagos Mainland, Lagos".
    public let context: String?
    public let address: String?
    /// ISO country code: NG, GH, BJ or TG.
    public let country: String?
    /// For areas: [west, south, east, north].
    public let bbox: [Double]?
    public let estimated: Bool
    public let radiusM: Double?
    /// A credit to show with this result, when its source asks for one.
    public let attribution: String?
    public let raw: JSONValue

    /// One line for a list: the name and its context.
    public var label: String {
        [name, address ?? context].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, category, location, context, address, country, bbox, estimated, radiusM, attribution
    }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id)
        name = c.lenient(String.self, .name)
        kind = c.lenient(String.self, .kind)
        category = c.lenient(String.self, .category)
        location = c.lenient(NWaysLatLng.self, .location)
        context = c.lenient(String.self, .context)
        address = c.lenient(String.self, .address)
        country = c.lenient(String.self, .country)
        bbox = c.lenient([Double].self, .bbox).flatMap { $0.count == 4 ? $0 : nil }
        estimated = c.lenient(Bool.self, .estimated) ?? false
        radiusM = c.lenient(Double.self, .radiusM)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// `GET /v1/reverse` answer. In Nigeria a building with its NIPOST postcode (`code`);
/// elsewhere the nearest address, street, landmark or area with its `country`.
public struct ReverseResult: Decodable, Sendable {
    /// NIPOST postcode (Nigeria only).
    public let code: String?
    /// The postcode written the usual way.
    public let display: String?
    public let name: String?
    public let address: String?
    public let kind: String?
    public let context: String?
    public let country: String?
    public let location: NWaysLatLng?
    public let distanceM: Double?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case code, display, name, address, kind, context, country, location, distanceM }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenient(String.self, .code)
        display = c.lenient(String.self, .display)
        name = c.lenient(String.self, .name)
        address = c.lenient(String.self, .address)
        kind = c.lenient(String.self, .kind)
        context = c.lenient(String.self, .context)
        country = c.lenient(String.self, .country)
        location = c.lenient(NWaysLatLng.self, .location)
        distanceM = c.lenient(Double.self, .distanceM)
    }
}

/// A door or gate people use to get into a building.
public struct Entrance: Decodable, Sendable {
    public let id: Int64?
    public let location: NWaysLatLng?
    /// main, gate, pedestrian or service.
    public let kind: String?
    public let note: String?
    public let verified: Bool
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case id, location, kind, note, verified }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(Int64.self, .id)
        location = c.lenient(NWaysLatLng.self, .location)
        kind = c.lenient(String.self, .kind)
        note = c.lenient(String.self, .note)
        verified = c.lenient(Bool.self, .verified) ?? false
    }
}

/// `GET /v1/postcodes/{code}` answer: a NIPOST building postcode.
public struct PostcodeResult: Decodable, Sendable {
    public let code: String?
    public let display: String?
    public let name: String?
    public let address: String?
    public let location: NWaysLatLng?
    public let stateName: String?
    public let lgaName: String?
    /// Verified entrances first. Route to one of these, not to the middle of the building.
    public let entrances: [Entrance]
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case code, display, name, address, location, stateName, lgaName, entrances }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenient(String.self, .code)
        display = c.lenient(String.self, .display)
        name = c.lenient(String.self, .name)
        address = c.lenient(String.self, .address)
        location = c.lenient(NWaysLatLng.self, .location)
        stateName = c.lenient(String.self, .stateName)
        lgaName = c.lenient(String.self, .lgaName)
        entrances = c.lenientArray(Entrance.self, .entrances)
    }
}

/// `GET /v1/places` answer.
public struct PlacesResponse: Decodable, Sendable {
    public let places: [Place]
    /// More places match than were returned.
    public let more: Bool
    public let offset: Int
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case places, more, offset }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        places = c.lenientArray(Place.self, .places)
        more = c.lenient(Bool.self, .more) ?? false
        offset = c.lenient(Int.self, .offset) ?? 0
    }
}

/// A business or point of interest.
public struct Place: Decodable, Sendable {
    public let id: String?
    public let name: String?
    public let category: String?
    /// A more precise kind: Pharmacy, Filling station.
    public let detail: String?
    public let location: NWaysLatLng?
    public let address: String?
    public let phone: String?
    public let website: String?
    /// Opening hours in OpenStreetMap's format.
    public let hours: String?
    public let rating: Double?
    /// Straight-line distance from the search point, in metres.
    public let distanceM: Double?
    /// osm, overture, user…
    public let source: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey {
        case id, name, category, detail, location, address, phone, website, hours, hoursInfo, rating, distanceM, source
    }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id)
        name = c.lenient(String.self, .name)
        category = c.lenient(String.self, .category)
        detail = c.lenient(String.self, .detail)
        location = c.lenient(NWaysLatLng.self, .location)
        address = c.lenient(String.self, .address)
        phone = c.lenient(String.self, .phone)
        website = c.lenient(String.self, .website)
        hours = c.lenient(String.self, .hours) ?? c.lenient(JSONValue.self, .hoursInfo)?["hours"]?.stringValue
        rating = c.lenient(Double.self, .rating)
        distanceM = c.lenient(Double.self, .distanceM)
        source = c.lenient(String.self, .source)
    }
}

/// Travel modes for ``NWaysClient/routes(from:to:mode:alternates:stops:ride:lang:avoidTolls:)``.
public enum NWaysTravelMode: String, Sendable, CaseIterable {
    case drive
    /// A commercial okada (keeps to okada bans).
    case motorcycle
    /// Your own motorbike (okada bans don't apply).
    case motorbike
    case walk
    case bicycle
    case train
    case boat
    /// With `ride` = keke or bus.
    case ride
}

/// `POST /v1/routes` answer.
public struct RoutesResponse: Decodable, Sendable {
    public let mode: String?
    /// The best route first, then the alternates.
    public let routes: [Route]
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case mode, routes }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = c.lenient(String.self, .mode)
        routes = c.lenientArray(Route.self, .routes)
    }
}

public struct Route: Decodable, Sendable {
    /// Length in metres.
    public let distanceM: Double
    /// Time in seconds, with live traffic.
    public let durationS: Double
    public let trafficDelayS: Double?
    /// The main road it takes.
    public let via: String?
    /// The line, in order. (The API sends [lng, lat] pairs; this is already turned around.)
    public let geometry: [NWaysLatLng]
    public let maneuvers: [Maneuver]
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case distanceM, durationS, trafficDelayS, via, geometry, maneuvers }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        distanceM = c.lenient(Double.self, .distanceM) ?? 0
        durationS = c.lenient(Double.self, .durationS) ?? 0
        trafficDelayS = c.lenient(Double.self, .trafficDelayS)
        via = c.lenient(String.self, .via)
        geometry = c.lenientArray([Double].self, .geometry).compactMap(NWaysLatLng.init(lngLat:))
        maneuvers = c.lenientArray(Maneuver.self, .maneuvers)
    }
}

/// A turn-by-turn step.
public struct Maneuver: Decodable, Sendable {
    public let type: Int?
    public let instruction: String?
    public let distanceM: Double?
    public let durationS: Double?
    /// Where it starts and ends in ``Route/geometry``.
    public let beginIndex: Int?
    public let endIndex: Int?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case type, instruction, distanceM, durationS, beginIndex, endIndex }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.lenient(Int.self, .type)
        instruction = c.lenient(String.self, .instruction)
        distanceM = c.lenient(Double.self, .distanceM)
        durationS = c.lenient(Double.self, .durationS)
        beginIndex = c.lenient(Int.self, .beginIndex)
        endIndex = c.lenient(Int.self, .endIndex)
    }
}

/// `GET /v1/fares/estimate` answer.
public struct FareEstimateResponse: Decodable, Sendable {
    public let country: String?
    /// ISO 4217, e.g. NGN or XOF.
    public let currency: String?
    public let distanceM: Double?
    public let durationS: Double?
    public let estimates: [FareEstimate]
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case country, currency, distanceM, durationS, estimates }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        country = c.lenient(String.self, .country)
        currency = c.lenient(String.self, .currency)
        distanceM = c.lenient(Double.self, .distanceM)
        durationS = c.lenient(Double.self, .durationS)
        estimates = c.lenientArray(FareEstimate.self, .estimates)
    }
}

/// One mode's price range.
public struct FareEstimate: Decodable, Sendable {
    public let mode: String?
    public let currency: String?
    public let low: Double?
    public let typical: Double?
    public let high: Double?
    /// The range written out: "₦3,000–4,500".
    public let text: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case mode, currency, low, typical, high, text }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = c.lenient(String.self, .mode)
        currency = c.lenient(String.self, .currency)
        low = c.lenient(Double.self, .low)
        typical = c.lenient(Double.self, .typical)
        high = c.lenient(Double.self, .high)
        text = c.lenient(String.self, .text)
    }
}
