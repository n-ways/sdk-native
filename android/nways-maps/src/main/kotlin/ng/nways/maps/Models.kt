package ng.nways.maps

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.put

/** A point. The REST API's own type, so it needs no map on screen. */
public data class NWaysLatLng(val lat: Double, val lng: Double)

/*
 * Models follow the partner API's shapes (/maps/v1) but stay loose: fields the API may
 * leave out (or a `fields=` mask removes) are nullable, and the whole JSON object is kept
 * in `raw` so fields added later aren't lost. Locations arrive as GeoJSON ([lng, lat]) and
 * are turned into NWaysLatLng here.
 */

/** A route or matrix point: a location, or a code N-Ways resolves. */
public sealed class Waypoint {
    /** A location; [heading] in degrees for a vehicle already moving. */
    public data class Location(val lat: Double, val lng: Double, val heading: Double? = null) : Waypoint()

    /** A NIPOST postcode: the route ends at the building's best entrance. */
    public data class Postcode(val code: String) : Waypoint()

    /** A GhanaPost GPS address, e.g. GA-183-8164. */
    public data class GhanaPost(val code: String) : Waypoint()

    /** A Plus Code. */
    public data class PlusCode(val code: String) : Waypoint()

    internal fun toJson(): JsonObject = buildJsonObject {
        when (val w = this@Waypoint) {
            is Location -> {
                put("lat", w.lat)
                put("lng", w.lng)
                w.heading?.let { put("heading", it) }
            }
            is Postcode -> put("postcode", w.code)
            is GhanaPost -> put("ghanaPost", w.code)
            is PlusCode -> put("plusCode", w.code)
        }
    }

    public companion object {
        @JvmStatic
        public fun of(point: NWaysLatLng): Waypoint = Location(point.lat, point.lng)
    }
}

/** This point as a route waypoint. */
public fun NWaysLatLng.asWaypoint(): Waypoint = Waypoint.of(this)

/** Travel modes for [NWaysClient.route] and [NWaysClient.matrix]. */
public object TravelMode {
    public const val DRIVE: String = "drive"
    /** A delivery van (toll class bus). */
    public const val VAN: String = "van"
    /** A commercial motorcycle taxi: keeps to okada bans. */
    public const val OKADA: String = "okada"
    /** Your own motorbike: okada bans don't apply. */
    public const val MOTORBIKE: String = "motorbike"
    public const val KEKE: String = "keke"
    /** A minibus (danfo): keeps to its bans. */
    public const val DANFO: String = "danfo"
    public const val WALK: String = "walk"
    public const val BICYCLE: String = "bicycle"
    public const val BOAT: String = "boat"
    public const val TRAIN: String = "train"
}

/** [NWaysClient.route]'s routingPreference. */
public object RoutingPreference {
    /** Today's traffic left out (the default). */
    public const val TRAFFIC_UNAWARE: String = "traffic_unaware"
    /** Live traffic and incidents (advanced SKU). */
    public const val TRAFFIC_AWARE: String = "traffic_aware"
}

/** [NWaysClient.route]'s avoid list. */
public object Avoid {
    public const val TOLLS: String = "tolls"
    public const val HIGHWAYS: String = "highways"
    public const val BAD_ROADS: String = "bad_roads"
}

/** `GET /maps/v1/geocode` and `/autocomplete` answer. */
public data class GeocodeResponse(
    val results: List<GeocodeResult>,
    /** A spelling the API suggests, when the query looked mistyped. */
    val didYouMean: String?,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = GeocodeResponse(
            results = o.objects("results").map(GeocodeResult::parse),
            didYouMean = o.str("didYouMean"),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** A place, street, address, business, area, NIPOST postcode or GhanaPost GPS address. */
public data class GeocodeResult(
    val id: String?,
    val name: String?,
    /** address, street, business, city, town, neighbourhood, postcode, ghanapost… */
    val type: String?,
    /** For a business: pharmacy, petrol, bank… */
    val category: String?,
    val location: NWaysLatLng?,
    /** For areas: [west, south, east, north]. */
    val bbox: List<Double>?,
    val formattedAddress: String?,
    /** NIPOST postcode, compact (LA08A09DB09). */
    val postcode: String?,
    /** GhanaPost GPS address (GA-183-8164). */
    val ghanaPost: String?,
    val plusCode: String?,
    /** ISO 3166-1 alpha-2: NG, GH, BJ or TG. */
    val country: String?,
    val distanceM: Double?,
    /** The point is an estimate, within [accuracyM]. */
    val estimated: Boolean,
    val accuracyM: Double?,
    /** For a business: its id for [NWaysClient.place]. */
    val placeId: String?,
    /** A credit to show with this result. */
    val attribution: String?,
    val raw: JsonObject,
) {
    /** One line for a list: the name and its address. */
    val label: String get() = listOfNotNull(name, formattedAddress).filter { it.isNotBlank() }.joinToString(", ")

    internal companion object {
        fun parse(o: JsonObject) = GeocodeResult(
            id = o.str("id"),
            name = o.str("name"),
            type = o.str("type"),
            category = o.str("category"),
            location = o["location"].point(),
            bbox = o.arr("bbox")?.mapNotNull { (it as? JsonPrimitive)?.doubleOrNull }?.takeIf { it.size == 4 },
            formattedAddress = o.str("formattedAddress"),
            postcode = o.str("postcode"),
            ghanaPost = o.str("ghanaPost"),
            plusCode = o.str("plusCode"),
            country = o.str("country"),
            distanceM = o.dbl("distanceM"),
            estimated = o.bool("estimated") ?: false,
            accuracyM = o.dbl("accuracyM"),
            placeId = o.str("placeId"),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** A country or region (a Nigerian state, a Ghanaian region…). */
public data class Area(val code: String?, val name: String?, val nameFr: String?, val raw: JsonObject) {
    internal companion object {
        fun parse(o: JsonObject) = Area(o.str("code"), o.str("name"), o.str("nameFr"), o)
    }
}

/** `GET /maps/v1/reverse` answer: the same shape in all four countries. */
public data class ReverseResult(
    /** The point asked about. */
    val location: NWaysLatLng?,
    val plusCode: String?,
    val country: Area?,
    val region: Area?,
    val formattedAddress: String?,
    /** Nigeria: the building's NIPOST postcode, when one is near. */
    val postcode: PostcodeResult?,
    /** Ghana: the nearest known GhanaPost GPS address. */
    val ghanaPost: String?,
    /** The nearest address, street, landmark or area. */
    val nearest: GeocodeResult?,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = ReverseResult(
            location = o["location"].point(),
            plusCode = o.str("plusCode"),
            country = o.obj("country")?.let(Area::parse),
            region = o.obj("region")?.let(Area::parse),
            formattedAddress = o.str("formattedAddress"),
            postcode = o.obj("postcode")?.let(PostcodeResult::parse),
            ghanaPost = o.str("ghanaPost"),
            nearest = o.obj("nearest")?.let(GeocodeResult::parse),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** A way into a building. */
public data class Entrance(
    val location: NWaysLatLng?,
    /** main, gate, pedestrian or service. */
    val kind: String?,
    val verified: Boolean,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Entrance(o["location"].point(), o.str("kind"), o.bool("verified") ?: false, o)
    }
}

/** A NIPOST postcode's parts and the names of its state and LGA. */
public data class PostcodeComponents(
    val state: String?,
    val stateName: String?,
    val lga: String?,
    val lgaName: String?,
    val district: String?,
    val area: String?,
    val building: String?,
) {
    internal companion object {
        fun parse(o: JsonObject) = PostcodeComponents(
            o.str("state"), o.str("stateName"), o.str("lga"), o.str("lgaName"), o.str("district"), o.str("area"), o.str("building"),
        )
    }
}

/** `GET /maps/v1/postcodes/{code}` answer: a NIPOST building postcode. */
public data class PostcodeResult(
    /** Compact: LA08A09DB09. */
    val code: String?,
    /** Written the usual way: LA 08 A09 DB 09. */
    val display: String?,
    val components: PostcodeComponents?,
    val location: NWaysLatLng?,
    val name: String?,
    val address: String?,
    val buildingType: String?,
    /** Verified first, main first. Route to the first, not to the middle of the building. */
    val entrances: List<Entrance>,
    val plusCode: String?,
    val country: String?,
    /** nipost, osm, user or estimate. */
    val source: String?,
    val estimated: Boolean,
    val accuracyM: Double?,
    /** Reverse geocoding: metres from the point asked about. */
    val distanceM: Double?,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = PostcodeResult(
            code = o.str("code"),
            display = o.str("display"),
            components = o.obj("components")?.let(PostcodeComponents::parse),
            location = o["location"].point(),
            name = o.str("name"),
            address = o.str("address"),
            buildingType = o.str("buildingType"),
            entrances = o.objects("entrances").map(Entrance::parse),
            plusCode = o.str("plusCode"),
            country = o.str("country"),
            source = o.str("source"),
            estimated = o.bool("estimated") ?: false,
            accuracyM = o.dbl("accuracyM"),
            distanceM = o.dbl("distanceM"),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** `POST /maps/v1/addresses/validate` verdict. */
public data class AddressVerdict(
    /** VALID, VALID_WITH_CORRECTIONS, PARTIAL, UNRESOLVED or INVALID. */
    val status: String?,
    /** PREMISE, POINT, ROUTE, NEIGHBOURHOOD, LOCALITY, REGION or NONE. */
    val granularity: String?,
    /** 0 to 1. */
    val confidence: Double?,
    /** The codes and the words point to the same place (null when there's only one of them). */
    val codesAgree: Boolean?,
    val inferredPostcode: Boolean,
) {
    internal companion object {
        fun parse(o: JsonObject) = AddressVerdict(
            o.str("status"), o.str("granularity"), o.dbl("confidence"),
            (o["codesAgree"] as? JsonPrimitive)?.booleanOrNull, o.bool("inferredPostcode") ?: false,
        )
    }
}

/** One part of a validated address. */
public data class AddressComponent(
    /** postcode, ghanapost, pluscode, premise, street, neighbourhood, locality, lga, region, country. */
    val type: String?,
    val text: String?,
    val code: String?,
    /** input, corrected, inferred or unconfirmed. */
    val source: String?,
) {
    internal companion object {
        fun parse(o: JsonObject) = AddressComponent(o.str("type"), o.str("text"), o.str("code"), o.str("source"))
    }
}

/** Something wrong with an address, or worth checking. */
public data class AddressIssue(val code: String?, val message: String?) {
    internal companion object {
        fun parse(o: JsonObject) = AddressIssue(o.str("code"), o.str("message"))
    }
}

/** `POST /maps/v1/addresses/validate` answer. */
public data class AddressValidation(
    val verdict: AddressVerdict?,
    val formattedAddress: String?,
    val components: List<AddressComponent>,
    val location: NWaysLatLng?,
    val accuracyM: Double?,
    val postcode: PostcodeResult?,
    val plusCode: String?,
    val issues: List<AddressIssue>,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = AddressValidation(
            verdict = o.obj("verdict")?.let(AddressVerdict::parse),
            formattedAddress = o.str("formattedAddress"),
            components = o.objects("components").map(AddressComponent::parse),
            location = o["location"].point(),
            accuracyM = o.dbl("accuracyM"),
            postcode = o.obj("postcode")?.let(PostcodeResult::parse),
            plusCode = o.str("plusCode"),
            issues = o.objects("issues").map(AddressIssue::parse),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** `GET /maps/v1/places/nearby` answer. */
public data class PlacesResponse(
    val places: List<Place>,
    /** Pass to [NWaysClient.placesNearby] as pageToken for the next page; null on the last. */
    val nextPageToken: String?,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = PlacesResponse(
            places = o.objects("places").map(Place::parse),
            nextPageToken = o.str("nextPageToken")?.takeIf { it.isNotEmpty() },
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** Opening hours, in OpenStreetMap's syntax, and where they come from. */
public data class OpeningHours(
    /** Mo-Fr 08:00-16:00 */
    val text: String?,
    /** listed, owner, brand or usual. */
    val source: String?,
    val confirmed: Int?,
)

/** People's rating, once enough rated it. */
public data class Rating(val score: Double?, val count: Int?, val percentUp: Int?, val reviewCount: Int?)

/** A business or place of interest (`/places/nearby` items and `GET /maps/v1/places/{id}`). */
public data class Place(
    val id: String?,
    val name: String?,
    val category: String?,
    val location: NWaysLatLng?,
    val formattedAddress: String?,
    val plusCode: String?,
    val country: String?,
    /** Straight-line distance from the search point, in metres. */
    val distanceM: Double?,
    /** OPERATIONAL, UNVERIFIED or REPORTED_CLOSED. */
    val businessStatus: String?,
    val phone: String?,
    val email: String?,
    val website: String?,
    val openingHours: OpeningHours?,
    val rating: Rating?,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Place(
            id = o.str("id"),
            name = o.str("name"),
            category = o.str("category"),
            location = o["location"].point(),
            formattedAddress = o.str("formattedAddress"),
            plusCode = o.str("plusCode"),
            country = o.str("country"),
            distanceM = o.dbl("distanceM"),
            businessStatus = o.str("businessStatus"),
            phone = o.str("phone"),
            email = o.str("email"),
            website = o.str("website"),
            openingHours = o.obj("openingHours")?.let { OpeningHours(it.str("text"), it.str("source"), it.int("confirmed")) },
            rating = o.obj("rating")?.let { Rating(it.dbl("score"), it.int("count"), it.int("percentUp"), it.int("reviewCount")) },
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** `POST /maps/v1/routes/compute` answer. */
public data class RoutesResponse(
    /** The best route first, then the alternatives. */
    val routes: List<Route>,
    /** Where each waypoint was resolved to (a postcode's entrance…), in request order. */
    val waypoints: List<ResolvedWaypoint>,
    val mode: String?,
    val warnings: List<String>,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = RoutesResponse(
            routes = o.objects("routes").map(Route::parse),
            waypoints = o.objects("waypoints").map(ResolvedWaypoint::parse),
            mode = o.str("mode"),
            warnings = o.strings("warnings"),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** A waypoint as routed. */
public data class ResolvedWaypoint(
    val location: NWaysLatLng?,
    val postcode: String?,
    /** The entrance's kind, when routed to one. */
    val entrance: String?,
) {
    internal companion object {
        fun parse(o: JsonObject) = ResolvedWaypoint(o["location"].point(), o.str("postcode"), o.str("entrance"))
    }
}

/** One way to make the trip. */
public data class Route(
    val distanceM: Double,
    val durationS: Double,
    /** Without live traffic. */
    val staticDurationS: Double?,
    /** What traffic and incidents add now (traffic-aware routes). */
    val trafficDelayS: Double?,
    /** live, typical or estimated. */
    val speedSource: String?,
    /** The main road ("via Third Mainland Bridge"). */
    val summary: String?,
    /** The line, in order (from the GeoJSON LineString). */
    val geometry: List<NWaysLatLng>,
    val legs: List<Leg>,
    val steps: List<Step>,
    /** With `fares = true`. */
    val fares: List<FareEstimate>,
    val warnings: List<String>,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Route(
            distanceM = o.dbl("distanceM") ?: 0.0,
            durationS = o.dbl("durationS") ?: 0.0,
            staticDurationS = o.dbl("staticDurationS"),
            trafficDelayS = o.dbl("trafficDelayS"),
            speedSource = o.str("speedSource"),
            summary = o.str("summary"),
            geometry = o["geometry"].line(),
            legs = o.objects("legs").map { Leg(it.dbl("distanceM") ?: 0.0, it.dbl("durationS") ?: 0.0) },
            steps = o.objects("steps").map(Step::parse),
            fares = o.objects("fares").map(FareEstimate::parse),
            warnings = o.strings("warnings"),
            raw = o,
        )
    }
}

/** The part of a route between two stops. */
public data class Leg(val distanceM: Double, val durationS: Double)

/** One instruction. */
public data class Step(
    /** depart, right, keep_left, roundabout_enter, arrive… */
    val maneuver: String?,
    val instruction: String?,
    val distanceM: Double?,
    val durationS: Double?,
    val streetNames: List<String>,
    /** The step's stretch of [Route.geometry]. */
    val startIndex: Int?,
    val endIndex: Int?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Step(
            maneuver = o.str("maneuver"),
            instruction = o.str("instruction"),
            distanceM = o.dbl("distanceM"),
            durationS = o.dbl("durationS"),
            streetNames = o.strings("streetNames"),
            startIndex = o.int("startIndex"),
            endIndex = o.int("endIndex"),
            raw = o,
        )
    }
}

/** `POST /maps/v1/routes/matrix` answer. */
public data class MatrixResponse(
    val elements: List<MatrixElement>,
    val origins: List<NWaysLatLng>,
    val destinations: List<NWaysLatLng>,
    val mode: String?,
    val attribution: String?,
    val raw: JsonObject,
) {
    /** The element from origin [o] to destination [d], if the answer has it. */
    public fun element(o: Int, d: Int): MatrixElement? =
        elements.firstOrNull { it.originIndex == o && it.destinationIndex == d }

    internal companion object {
        fun parse(o: JsonObject) = MatrixResponse(
            elements = o.objects("elements").map(MatrixElement::parse),
            origins = o.points("origins"),
            destinations = o.points("destinations"),
            mode = o.str("mode"),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** One origin–destination pair. */
public data class MatrixElement(
    val originIndex: Int,
    val destinationIndex: Int,
    /** OK, or ROUTE_NOT_FOUND. */
    val status: String?,
    val durationS: Double?,
    val distanceM: Double?,
) {
    val isOk: Boolean get() = status == "OK"

    internal companion object {
        fun parse(o: JsonObject) = MatrixElement(
            o.int("originIndex") ?: -1, o.int("destinationIndex") ?: -1, o.str("status"), o.dbl("durationS"), o.dbl("distanceM"),
        )
    }
}

/** `GET /maps/v1/fares/estimate` answer. */
public data class FaresResponse(
    val country: String?,
    val region: String?,
    /** ISO 4217, e.g. NGN or XOF. */
    val currency: String?,
    val distanceM: Double?,
    val durationS: Double?,
    val night: Boolean,
    val estimates: List<FareEstimate>,
    /** Modes that can't make the trip (an okada ban…), with why. */
    val notAllowed: List<FareNotAllowed>,
    val attribution: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = FaresResponse(
            country = o.str("country"),
            region = o.str("region"),
            currency = o.str("currency"),
            distanceM = o.dbl("distanceM"),
            durationS = o.dbl("durationS"),
            night = o.bool("night") ?: false,
            estimates = o.objects("estimates").map(FareEstimate::parse),
            notAllowed = o.objects("notAllowed").map { FareNotAllowed(it.str("mode"), it.str("text"), it) },
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/** A mode that can't make the trip; the ban is in [raw]. */
public data class FareNotAllowed(val mode: String?, val text: String?, val raw: JsonObject)

/** What a ride may cost by one mode. */
public data class FareEstimate(
    /** taxi, shared_taxi, okada, keke, danfo, boat, ridehail… */
    val mode: String?,
    /** The ride-hail app, e.g. Bolt. */
    val service: String?,
    val currency: String?,
    val low: Double?,
    val typical: Double?,
    val high: Double?,
    /** The range written out: "₦3,000–4,500". */
    val text: String?,
    val perPerson: Boolean,
    val charter: Boolean,
    /** crowd (what riders paid) or guide (published sources). */
    val basis: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = FareEstimate(
            mode = o.str("mode"),
            service = o.str("service"),
            currency = o.str("currency"),
            low = o.dbl("low"),
            typical = o.dbl("typical"),
            high = o.dbl("high"),
            text = o.str("text"),
            perPerson = o.bool("perPerson") ?: false,
            charter = o.bool("charter") ?: false,
            basis = o.str("basis"),
            raw = o,
        )
    }
}
