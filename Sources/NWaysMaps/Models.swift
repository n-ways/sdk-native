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

    /// A GeoJSON Point (`{"type":"Point","coordinates":[lng,lat]}`) or a `{lat, lng}` object.
    init?(geoJSON v: JSONValue?) {
        if let c = v?["coordinates"]?.arrayValue?.compactMap(\.doubleValue), let p = NWaysLatLng(lngLat: c) {
            self = p
        } else if let lat = v?["lat"]?.doubleValue, let lng = v?["lng"]?.doubleValue {
            self.init(lat: lat, lng: lng)
        } else {
            return nil
        }
    }

    /// A GeoJSON LineString's coordinates, in order.
    static func line(_ v: JSONValue?) -> [NWaysLatLng] {
        (v?["coordinates"]?.arrayValue ?? []).compactMap { NWaysLatLng(lngLat: $0.arrayValue?.compactMap(\.doubleValue) ?? []) }
    }
}

// Models follow the partner API's shapes (/maps/v1) but stay loose: fields the API may leave
// out (or a `fields=` mask removes) are optional, and the whole JSON object is kept in `raw` so
// fields added later aren't lost. GeoJSON locations and lines become NWaysLatLng here.

extension KeyedDecodingContainer {
    func point(_ key: Key) -> NWaysLatLng? { NWaysLatLng(geoJSON: lenient(JSONValue.self, key)) }
    func points(_ key: Key) -> [NWaysLatLng] { (lenient([JSONValue].self, key) ?? []).compactMap { NWaysLatLng(geoJSON: $0) } }
    func line(_ key: Key) -> [NWaysLatLng] { NWaysLatLng.line(lenient(JSONValue.self, key)) }
}

/// A route or matrix point: a location, or a code N-Ways resolves.
public enum NWaysWaypoint: Encodable, Hashable, Sendable {
    /// A location; `heading` in degrees for a vehicle already moving.
    case location(NWaysLatLng, heading: Double? = nil)
    /// A NIPOST postcode: the route ends at the building's best entrance.
    case postcode(String)
    /// A GhanaPost GPS address, e.g. GA-183-8164.
    case ghanaPost(String)
    case plusCode(String)

    public static func at(lat: Double, lng: Double) -> NWaysWaypoint { .location(NWaysLatLng(lat: lat, lng: lng)) }

    enum CodingKeys: String, CodingKey { case lat, lng, heading, postcode, ghanaPost, plusCode }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .location(let p, let heading):
            try c.encode(p.lat, forKey: .lat)
            try c.encode(p.lng, forKey: .lng)
            try c.encodeIfPresent(heading, forKey: .heading)
        case .postcode(let s): try c.encode(s, forKey: .postcode)
        case .ghanaPost(let s): try c.encode(s, forKey: .ghanaPost)
        case .plusCode(let s): try c.encode(s, forKey: .plusCode)
        }
    }
}

/// Travel modes for routes and matrices.
public enum NWaysTravelMode: String, Sendable, CaseIterable {
    case drive
    /// A delivery van (toll class bus).
    case van
    /// A commercial motorcycle taxi: keeps to okada bans.
    case okada
    /// Your own motorbike: okada bans don't apply.
    case motorbike
    case keke
    /// A minibus (danfo): keeps to its bans.
    case danfo
    case walk
    case bicycle
    case boat
    case train
}

public enum NWaysRoutingPreference: String, Sendable {
    /// Today's traffic left out (the default).
    case trafficUnaware = "traffic_unaware"
    /// Live traffic and incidents (advanced SKU).
    case trafficAware = "traffic_aware"
}

public enum NWaysAvoid: String, Sendable {
    case tolls
    case highways
    case badRoads = "bad_roads"
}

/// `GET /maps/v1/geocode` and `/autocomplete` answer.
public struct GeocodeResponse: Decodable, Sendable {
    public let results: [GeocodeResult]
    /// A spelling the API suggests, when the query looked mistyped.
    public let didYouMean: String?
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case results, didYouMean, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        results = c.lenientArray(GeocodeResult.self, .results)
        didYouMean = c.lenient(String.self, .didYouMean)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// A place, street, address, business, area, NIPOST postcode or GhanaPost GPS address.
public struct GeocodeResult: Decodable, Sendable {
    public let id: String?
    public let name: String?
    /// address, street, business, city, town, neighbourhood, postcode, ghanapost…
    public let type: String?
    /// For a business: pharmacy, petrol, bank…
    public let category: String?
    public let location: NWaysLatLng?
    /// For areas: [west, south, east, north].
    public let bbox: [Double]?
    public let formattedAddress: String?
    /// NIPOST postcode, compact (LA08A09DB09).
    public let postcode: String?
    /// GhanaPost GPS address (GA-183-8164).
    public let ghanaPost: String?
    public let plusCode: String?
    /// ISO 3166-1 alpha-2: NG, GH, BJ or TG.
    public let country: String?
    public let distanceM: Double?
    /// The point is an estimate, within ``accuracyM``.
    public let estimated: Bool
    public let accuracyM: Double?
    /// For a business: its id for ``NWaysClient/place(_:fields:)``.
    public let placeId: String?
    public let attribution: String?
    public let raw: JSONValue

    /// One line for a list: the name and its address.
    public var label: String {
        [name, formattedAddress].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, category, location, bbox, formattedAddress, postcode, ghanaPost, plusCode, country, distanceM
        case estimated, accuracyM, placeId, attribution
    }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id)
        name = c.lenient(String.self, .name)
        type = c.lenient(String.self, .type)
        category = c.lenient(String.self, .category)
        location = c.point(.location)
        bbox = c.lenient([Double].self, .bbox).flatMap { $0.count == 4 ? $0 : nil }
        formattedAddress = c.lenient(String.self, .formattedAddress)
        postcode = c.lenient(String.self, .postcode)
        ghanaPost = c.lenient(String.self, .ghanaPost)
        plusCode = c.lenient(String.self, .plusCode)
        country = c.lenient(String.self, .country)
        distanceM = c.lenient(Double.self, .distanceM)
        estimated = c.lenient(Bool.self, .estimated) ?? false
        accuracyM = c.lenient(Double.self, .accuracyM)
        placeId = c.lenient(String.self, .placeId)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// A country or region (a Nigerian state, a Ghanaian region…).
public struct NWaysArea: Decodable, Sendable {
    public let code: String?
    public let name: String?
    public let nameFr: String?

    enum CodingKeys: String, CodingKey { case code, name, nameFr }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenient(String.self, .code)
        name = c.lenient(String.self, .name)
        nameFr = c.lenient(String.self, .nameFr)
    }
}

/// `GET /maps/v1/reverse` answer: the same shape in all four countries.
public struct ReverseResult: Decodable, Sendable {
    /// The point asked about.
    public let location: NWaysLatLng?
    public let plusCode: String?
    public let country: NWaysArea?
    public let region: NWaysArea?
    public let formattedAddress: String?
    /// Nigeria: the building's NIPOST postcode, when one is near.
    public let postcode: PostcodeResult?
    /// Ghana: the nearest known GhanaPost GPS address.
    public let ghanaPost: String?
    /// The nearest address, street, landmark or area.
    public let nearest: GeocodeResult?
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case location, plusCode, country, region, formattedAddress, postcode, ghanaPost, nearest, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = c.point(.location)
        plusCode = c.lenient(String.self, .plusCode)
        country = c.lenient(NWaysArea.self, .country)
        region = c.lenient(NWaysArea.self, .region)
        formattedAddress = c.lenient(String.self, .formattedAddress)
        postcode = c.lenient(PostcodeResult.self, .postcode)
        ghanaPost = c.lenient(String.self, .ghanaPost)
        nearest = c.lenient(GeocodeResult.self, .nearest)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// A way into a building.
public struct Entrance: Decodable, Sendable {
    public let location: NWaysLatLng?
    /// main, gate, pedestrian or service.
    public let kind: String?
    public let verified: Bool
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case location, kind, verified }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = c.point(.location)
        kind = c.lenient(String.self, .kind)
        verified = c.lenient(Bool.self, .verified) ?? false
    }
}

/// A NIPOST postcode's parts and the names of its state and LGA.
public struct PostcodeComponents: Decodable, Sendable {
    public let state: String?
    public let stateName: String?
    public let lga: String?
    public let lgaName: String?
    public let district: String?
    public let area: String?
    public let building: String?

    enum CodingKeys: String, CodingKey { case state, stateName, lga, lgaName, district, area, building }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = c.lenient(String.self, .state)
        stateName = c.lenient(String.self, .stateName)
        lga = c.lenient(String.self, .lga)
        lgaName = c.lenient(String.self, .lgaName)
        district = c.lenient(String.self, .district)
        area = c.lenient(String.self, .area)
        building = c.lenient(String.self, .building)
    }
}

/// `GET /maps/v1/postcodes/{code}` answer: a NIPOST building postcode.
public struct PostcodeResult: Decodable, Sendable {
    /// Compact: LA08A09DB09.
    public let code: String?
    /// Written the usual way: LA 08 A09 DB 09.
    public let display: String?
    public let components: PostcodeComponents?
    public let location: NWaysLatLng?
    public let name: String?
    public let address: String?
    public let buildingType: String?
    /// Verified first, main first. Route to the first, not to the middle of the building.
    public let entrances: [Entrance]
    public let plusCode: String?
    public let country: String?
    /// nipost, osm, user or estimate.
    public let source: String?
    public let estimated: Bool
    public let accuracyM: Double?
    /// Reverse geocoding: metres from the point asked about.
    public let distanceM: Double?
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey {
        case code, display, components, location, name, address, buildingType, entrances, plusCode, country, source
        case estimated, accuracyM, distanceM, attribution
    }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenient(String.self, .code)
        display = c.lenient(String.self, .display)
        components = c.lenient(PostcodeComponents.self, .components)
        location = c.point(.location)
        name = c.lenient(String.self, .name)
        address = c.lenient(String.self, .address)
        buildingType = c.lenient(String.self, .buildingType)
        entrances = c.lenientArray(Entrance.self, .entrances)
        plusCode = c.lenient(String.self, .plusCode)
        country = c.lenient(String.self, .country)
        source = c.lenient(String.self, .source)
        estimated = c.lenient(Bool.self, .estimated) ?? false
        accuracyM = c.lenient(Double.self, .accuracyM)
        distanceM = c.lenient(Double.self, .distanceM)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// `POST /maps/v1/addresses/validate` answer.
public struct AddressValidation: Decodable, Sendable {
    public struct Verdict: Decodable, Sendable {
        /// VALID, VALID_WITH_CORRECTIONS, PARTIAL, UNRESOLVED or INVALID.
        public let status: String?
        /// PREMISE, POINT, ROUTE, NEIGHBOURHOOD, LOCALITY, REGION or NONE.
        public let granularity: String?
        /// 0 to 1.
        public let confidence: Double?
        /// The codes and the words point to the same place (nil when there's only one of them).
        public let codesAgree: Bool?
        public let inferredPostcode: Bool

        enum CodingKeys: String, CodingKey { case status, granularity, confidence, codesAgree, inferredPostcode }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            status = c.lenient(String.self, .status)
            granularity = c.lenient(String.self, .granularity)
            confidence = c.lenient(Double.self, .confidence)
            codesAgree = c.lenient(Bool.self, .codesAgree)
            inferredPostcode = c.lenient(Bool.self, .inferredPostcode) ?? false
        }
    }

    public struct Component: Decodable, Sendable {
        /// postcode, ghanapost, pluscode, premise, street, neighbourhood, locality, lga, region, country.
        public let type: String?
        public let text: String?
        public let code: String?
        /// input, corrected, inferred or unconfirmed.
        public let source: String?

        enum CodingKeys: String, CodingKey { case type, text, code, source }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = c.lenient(String.self, .type)
            text = c.lenient(String.self, .text)
            code = c.lenient(String.self, .code)
            source = c.lenient(String.self, .source)
        }
    }

    public struct Issue: Decodable, Sendable {
        public let code: String?
        public let message: String?
    }

    public let verdict: Verdict?
    public let formattedAddress: String?
    public let components: [Component]
    public let location: NWaysLatLng?
    public let accuracyM: Double?
    public let postcode: PostcodeResult?
    public let plusCode: String?
    public let issues: [Issue]
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case verdict, formattedAddress, components, location, accuracyM, postcode, plusCode, issues, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        verdict = c.lenient(Verdict.self, .verdict)
        formattedAddress = c.lenient(String.self, .formattedAddress)
        components = c.lenientArray(Component.self, .components)
        location = c.point(.location)
        accuracyM = c.lenient(Double.self, .accuracyM)
        postcode = c.lenient(PostcodeResult.self, .postcode)
        plusCode = c.lenient(String.self, .plusCode)
        issues = c.lenientArray(Issue.self, .issues)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// `GET /maps/v1/places/nearby` answer.
public struct PlacesResponse: Decodable, Sendable {
    public let places: [Place]
    /// Pass as `pageToken` for the next page; nil on the last.
    public let nextPageToken: String?
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case places, nextPageToken, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        places = c.lenientArray(Place.self, .places)
        nextPageToken = c.lenient(String.self, .nextPageToken).flatMap { $0.isEmpty ? nil : $0 }
        attribution = c.lenient(String.self, .attribution)
    }
}

/// A business or place of interest (`/places/nearby` items and `GET /maps/v1/places/{id}`).
public struct Place: Decodable, Sendable {
    public struct OpeningHours: Decodable, Sendable {
        /// Mo-Fr 08:00-16:00
        public let text: String?
        /// listed, owner, brand or usual.
        public let source: String?
        public let confirmed: Int?
    }

    public struct Rating: Decodable, Sendable {
        public let score: Double?
        public let count: Int?
        public let percentUp: Int?
        public let reviewCount: Int?
    }

    public let id: String?
    public let name: String?
    public let category: String?
    public let location: NWaysLatLng?
    public let formattedAddress: String?
    public let plusCode: String?
    public let country: String?
    /// Straight-line distance from the search point, in metres.
    public let distanceM: Double?
    /// OPERATIONAL, UNVERIFIED or REPORTED_CLOSED.
    public let businessStatus: String?
    public let phone: String?
    public let email: String?
    public let website: String?
    public let openingHours: OpeningHours?
    public let rating: Rating?
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey {
        case id, name, category, location, formattedAddress, plusCode, country, distanceM, businessStatus
        case phone, email, website, openingHours, rating, attribution
    }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id)
        name = c.lenient(String.self, .name)
        category = c.lenient(String.self, .category)
        location = c.point(.location)
        formattedAddress = c.lenient(String.self, .formattedAddress)
        plusCode = c.lenient(String.self, .plusCode)
        country = c.lenient(String.self, .country)
        distanceM = c.lenient(Double.self, .distanceM)
        businessStatus = c.lenient(String.self, .businessStatus)
        phone = c.lenient(String.self, .phone)
        email = c.lenient(String.self, .email)
        website = c.lenient(String.self, .website)
        openingHours = c.lenient(OpeningHours.self, .openingHours)
        rating = c.lenient(Rating.self, .rating)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// `POST /maps/v1/routes/compute` answer.
public struct RoutesResponse: Decodable, Sendable {
    /// A waypoint as routed (a postcode's entrance…).
    public struct ResolvedWaypoint: Decodable, Sendable {
        public let location: NWaysLatLng?
        public let postcode: String?
        /// The entrance's kind, when routed to one.
        public let entrance: String?

        enum CodingKeys: String, CodingKey { case location, postcode, entrance }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            location = c.point(.location)
            postcode = c.lenient(String.self, .postcode)
            entrance = c.lenient(String.self, .entrance)
        }
    }

    /// The best route first, then the alternatives.
    public let routes: [Route]
    /// Where each waypoint was resolved to, in request order.
    public let waypoints: [ResolvedWaypoint]
    public let mode: String?
    public let warnings: [String]
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case routes, waypoints, mode, warnings, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        routes = c.lenientArray(Route.self, .routes)
        waypoints = c.lenientArray(ResolvedWaypoint.self, .waypoints)
        mode = c.lenient(String.self, .mode)
        warnings = c.lenient([String].self, .warnings) ?? []
        attribution = c.lenient(String.self, .attribution)
    }
}

/// One way to make the trip.
public struct Route: Decodable, Sendable {
    /// The part between two stops.
    public struct Leg: Decodable, Sendable {
        public let distanceM: Double?
        public let durationS: Double?
    }

    /// One instruction.
    public struct Step: Decodable, Sendable {
        /// depart, right, keep_left, roundabout_enter, arrive…
        public let maneuver: String?
        public let instruction: String?
        public let distanceM: Double?
        public let durationS: Double?
        public let streetNames: [String]
        /// The step's stretch of ``Route/geometry``.
        public let startIndex: Int?
        public let endIndex: Int?
        public let raw: JSONValue

        enum CodingKeys: String, CodingKey { case maneuver, instruction, distanceM, durationS, streetNames, startIndex, endIndex }

        public init(from decoder: Decoder) throws {
            raw = try JSONValue(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            maneuver = c.lenient(String.self, .maneuver)
            instruction = c.lenient(String.self, .instruction)
            distanceM = c.lenient(Double.self, .distanceM)
            durationS = c.lenient(Double.self, .durationS)
            streetNames = c.lenient([String].self, .streetNames) ?? []
            startIndex = c.lenient(Int.self, .startIndex)
            endIndex = c.lenient(Int.self, .endIndex)
        }
    }

    public let distanceM: Double
    public let durationS: Double
    /// Without live traffic.
    public let staticDurationS: Double?
    /// What traffic and incidents add now (traffic-aware routes).
    public let trafficDelayS: Double?
    /// live, typical or estimated.
    public let speedSource: String?
    /// The main road ("via Third Mainland Bridge").
    public let summary: String?
    /// The line, in order (from the GeoJSON LineString).
    public let geometry: [NWaysLatLng]
    public let legs: [Leg]
    public let steps: [Step]
    /// With `fares: true`.
    public let fares: [FareEstimate]
    public let warnings: [String]
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey {
        case distanceM, durationS, staticDurationS, trafficDelayS, speedSource, summary, geometry, legs, steps, fares, warnings
    }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        distanceM = c.lenient(Double.self, .distanceM) ?? 0
        durationS = c.lenient(Double.self, .durationS) ?? 0
        staticDurationS = c.lenient(Double.self, .staticDurationS)
        trafficDelayS = c.lenient(Double.self, .trafficDelayS)
        speedSource = c.lenient(String.self, .speedSource)
        summary = c.lenient(String.self, .summary)
        geometry = c.line(.geometry)
        legs = c.lenientArray(Leg.self, .legs)
        steps = c.lenientArray(Step.self, .steps)
        fares = c.lenientArray(FareEstimate.self, .fares)
        warnings = c.lenient([String].self, .warnings) ?? []
    }
}

/// `POST /maps/v1/routes/matrix` answer.
public struct MatrixResponse: Decodable, Sendable {
    /// One origin–destination pair.
    public struct Element: Decodable, Sendable {
        public let originIndex: Int
        public let destinationIndex: Int
        /// OK, or ROUTE_NOT_FOUND.
        public let status: String?
        public let durationS: Double?
        public let distanceM: Double?

        public var isOK: Bool { status == "OK" }

        enum CodingKeys: String, CodingKey { case originIndex, destinationIndex, status, durationS, distanceM }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            originIndex = c.lenient(Int.self, .originIndex) ?? -1
            destinationIndex = c.lenient(Int.self, .destinationIndex) ?? -1
            status = c.lenient(String.self, .status)
            durationS = c.lenient(Double.self, .durationS)
            distanceM = c.lenient(Double.self, .distanceM)
        }
    }

    public let elements: [Element]
    public let origins: [NWaysLatLng]
    public let destinations: [NWaysLatLng]
    public let mode: String?
    public let attribution: String?
    public let raw: JSONValue

    /// The element from origin `o` to destination `d`, if the answer has it.
    public func element(origin o: Int, destination d: Int) -> Element? {
        elements.first { $0.originIndex == o && $0.destinationIndex == d }
    }

    enum CodingKeys: String, CodingKey { case elements, origins, destinations, mode, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        elements = c.lenientArray(Element.self, .elements)
        origins = c.points(.origins)
        destinations = c.points(.destinations)
        mode = c.lenient(String.self, .mode)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// `GET /maps/v1/fares/estimate` answer.
public struct FaresResponse: Decodable, Sendable {
    /// A mode that can't make the trip; the ban is in `raw`.
    public struct NotAllowed: Decodable, Sendable {
        public let mode: String?
        public let text: String?
        public let raw: JSONValue

        enum CodingKeys: String, CodingKey { case mode, text }

        public init(from decoder: Decoder) throws {
            raw = try JSONValue(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mode = c.lenient(String.self, .mode)
            text = c.lenient(String.self, .text)
        }
    }

    public let country: String?
    public let region: String?
    /// ISO 4217, e.g. NGN or XOF.
    public let currency: String?
    public let distanceM: Double?
    public let durationS: Double?
    public let night: Bool
    public let estimates: [FareEstimate]
    public let notAllowed: [NotAllowed]
    public let attribution: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case country, region, currency, distanceM, durationS, night, estimates, notAllowed, attribution }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        country = c.lenient(String.self, .country)
        region = c.lenient(String.self, .region)
        currency = c.lenient(String.self, .currency)
        distanceM = c.lenient(Double.self, .distanceM)
        durationS = c.lenient(Double.self, .durationS)
        night = c.lenient(Bool.self, .night) ?? false
        estimates = c.lenientArray(FareEstimate.self, .estimates)
        notAllowed = c.lenientArray(NotAllowed.self, .notAllowed)
        attribution = c.lenient(String.self, .attribution)
    }
}

/// What a ride may cost by one mode.
public struct FareEstimate: Decodable, Sendable {
    /// taxi, shared_taxi, okada, keke, danfo, boat, ridehail…
    public let mode: String?
    /// The ride-hail app, e.g. Bolt.
    public let service: String?
    public let currency: String?
    public let low: Double?
    public let typical: Double?
    public let high: Double?
    /// The range written out: "₦3,000–4,500".
    public let text: String?
    public let perPerson: Bool
    public let charter: Bool
    /// crowd (what riders paid) or guide (published sources).
    public let basis: String?
    public let raw: JSONValue

    enum CodingKeys: String, CodingKey { case mode, service, currency, low, typical, high, text, perPerson, charter, basis }

    public init(from decoder: Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = c.lenient(String.self, .mode)
        service = c.lenient(String.self, .service)
        currency = c.lenient(String.self, .currency)
        low = c.lenient(Double.self, .low)
        typical = c.lenient(Double.self, .typical)
        high = c.lenient(Double.self, .high)
        text = c.lenient(String.self, .text)
        perPerson = c.lenient(Bool.self, .perPerson) ?? false
        charter = c.lenient(Bool.self, .charter) ?? false
        basis = c.lenient(String.self, .basis)
    }
}
