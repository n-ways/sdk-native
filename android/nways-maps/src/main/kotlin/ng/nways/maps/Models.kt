package ng.nways.maps

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull

/** A point. The REST API's own type, so it needs no map on screen. */
public data class NWaysLatLng(val lat: Double, val lng: Double)

/*
 * Models are deliberately loose: only the fields most apps need, all optional where the
 * API may leave them out, and the whole JSON object in `raw` so new fields aren't lost.
 */

/** `GET /v1/geocode` answer. */
public data class GeocodeResponse(
    val results: List<GeocodeResult>,
    /** A spelling the API suggests, when the query looked mistyped. */
    val didYouMean: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = GeocodeResponse(
            results = o.objects("results").map(GeocodeResult::parse),
            didYouMean = o.str("didYouMean"),
            raw = o,
        )
    }
}

/** One geocoding result: a place, area, address, business or postcode. */
public data class GeocodeResult(
    val id: String?,
    val name: String?,
    /** city, town, street, address, landmark, business… */
    val kind: String?,
    /** For a business: pharmacy, petrol, bank… */
    val category: String?,
    val location: NWaysLatLng?,
    /** Where it is, to tell places apart: "Lagos Mainland, Lagos". */
    val context: String?,
    val address: String?,
    /** ISO country code: NG, GH, BJ or TG. */
    val country: String?,
    /** For areas: [west, south, east, north]. */
    val bbox: List<Double>?,
    val estimated: Boolean,
    val radiusM: Double?,
    /** A credit to show with this result, when its source asks for one. */
    val attribution: String?,
    val raw: JsonObject,
) {
    /** One line for a list: the name and its context. */
    val label: String get() = listOfNotNull(name, address ?: context).filter { it.isNotBlank() }.joinToString(", ")

    internal companion object {
        fun parse(o: JsonObject) = GeocodeResult(
            id = o.str("id"),
            name = o.str("name"),
            kind = o.str("kind"),
            category = o.str("category"),
            location = o["location"].latLng(),
            context = o.str("context"),
            address = o.str("address"),
            country = o.str("country"),
            bbox = o.arr("bbox")?.mapNotNull { (it as? JsonPrimitive)?.doubleOrNull }?.takeIf { it.size == 4 },
            estimated = o.bool("estimated") ?: false,
            radiusM = o.dbl("radiusM"),
            attribution = o.str("attribution"),
            raw = o,
        )
    }
}

/**
 * `GET /v1/reverse` answer. In Nigeria a building with its NIPOST postcode ([code]);
 * elsewhere the nearest address, street, landmark or area with its [country].
 */
public data class ReverseResult(
    /** NIPOST postcode (Nigeria only). */
    val code: String?,
    /** The postcode written the usual way. */
    val display: String?,
    val name: String?,
    val address: String?,
    val kind: String?,
    val context: String?,
    val country: String?,
    val location: NWaysLatLng?,
    val distanceM: Double?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = ReverseResult(
            code = o.str("code"),
            display = o.str("display"),
            name = o.str("name"),
            address = o.str("address"),
            kind = o.str("kind"),
            context = o.str("context"),
            country = o.str("country"),
            location = o["location"].latLng(),
            distanceM = o.dbl("distanceM"),
            raw = o,
        )
    }
}

/** A door or gate people use to get into a building. */
public data class Entrance(
    val id: Long?,
    val location: NWaysLatLng?,
    /** main, gate, pedestrian or service. */
    val kind: String?,
    val note: String?,
    val verified: Boolean,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Entrance(
            id = (o["id"] as? JsonPrimitive)?.content?.toLongOrNull(),
            location = o["location"].latLng(),
            kind = o.str("kind"),
            note = o.str("note"),
            verified = o.bool("verified") ?: false,
            raw = o,
        )
    }
}

/** `GET /v1/postcodes/{code}` answer: a NIPOST building postcode. */
public data class PostcodeResult(
    val code: String?,
    val display: String?,
    val name: String?,
    val address: String?,
    val location: NWaysLatLng?,
    val stateName: String?,
    val lgaName: String?,
    /** Verified entrances first. Route to one of these, not to the middle of the building. */
    val entrances: List<Entrance>,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = PostcodeResult(
            code = o.str("code"),
            display = o.str("display"),
            name = o.str("name"),
            address = o.str("address"),
            location = o["location"].latLng(),
            stateName = o.str("stateName"),
            lgaName = o.str("lgaName"),
            entrances = o.objects("entrances").map(Entrance::parse),
            raw = o,
        )
    }
}

/** `GET /v1/places` answer. */
public data class PlacesResponse(
    val places: List<Place>,
    /** More places match than were returned. */
    val more: Boolean,
    val offset: Int,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = PlacesResponse(
            places = o.objects("places").map(Place::parse),
            more = o.bool("more") ?: false,
            offset = o.int("offset") ?: 0,
            raw = o,
        )
    }
}

/** A business or point of interest. */
public data class Place(
    val id: String?,
    val name: String?,
    val category: String?,
    /** A more precise kind: Pharmacy, Filling station. */
    val detail: String?,
    val location: NWaysLatLng?,
    val address: String?,
    val phone: String?,
    val website: String?,
    /** Opening hours in OpenStreetMap's format. */
    val hours: String?,
    val rating: Double?,
    /** Straight-line distance from the search point, in metres. */
    val distanceM: Double?,
    /** osm, overture, user… */
    val source: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Place(
            id = o.str("id"),
            name = o.str("name"),
            category = o.str("category"),
            detail = o.str("detail"),
            location = o["location"].latLng(),
            address = o.str("address"),
            phone = o.str("phone"),
            website = o.str("website"),
            hours = o.str("hours") ?: o.obj("hoursInfo")?.str("hours"),
            rating = o.dbl("rating"),
            distanceM = o.dbl("distanceM"),
            source = o.str("source"),
            raw = o,
        )
    }
}

/** Travel modes for [NWaysClient.routes]. */
public object TravelMode {
    public const val DRIVE: String = "drive"
    /** A commercial okada (keeps to okada bans). */
    public const val MOTORCYCLE: String = "motorcycle"
    /** Your own motorbike (okada bans don't apply). */
    public const val MOTORBIKE: String = "motorbike"
    public const val WALK: String = "walk"
    public const val BICYCLE: String = "bicycle"
    public const val TRAIN: String = "train"
    public const val BOAT: String = "boat"
    /** With [DRIVE] and `ride` = keke or bus. */
    public const val RIDE: String = "ride"
}

/** `POST /v1/routes` answer. */
public data class RoutesResponse(
    val mode: String?,
    /** The best route first, then the alternates. */
    val routes: List<Route>,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = RoutesResponse(
            mode = o.str("mode"),
            routes = o.objects("routes").map(Route::parse),
            raw = o,
        )
    }
}

public data class Route(
    /** Length in metres. */
    val distanceM: Double,
    /** Time in seconds, with live traffic. */
    val durationS: Double,
    val trafficDelayS: Double?,
    /** The main road it takes. */
    val via: String?,
    /** The line, in order. (The API sends [lng, lat] pairs; this is already turned around.) */
    val geometry: List<NWaysLatLng>,
    val maneuvers: List<Maneuver>,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Route(
            distanceM = o.dbl("distanceM") ?: 0.0,
            durationS = o.dbl("durationS") ?: 0.0,
            trafficDelayS = o.dbl("trafficDelayS"),
            via = o.str("via"),
            geometry = o.arr("geometry")?.mapNotNull { it.lngLatPair() }.orEmpty(),
            maneuvers = o.objects("maneuvers").map(Maneuver::parse),
            raw = o,
        )
    }
}

/** A turn-by-turn step. */
public data class Maneuver(
    val type: Int?,
    val instruction: String?,
    val distanceM: Double?,
    val durationS: Double?,
    /** Where it starts and ends in [Route.geometry]. */
    val beginIndex: Int?,
    val endIndex: Int?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = Maneuver(
            type = o.int("type"),
            instruction = o.str("instruction"),
            distanceM = o.dbl("distanceM"),
            durationS = o.dbl("durationS"),
            beginIndex = o.int("beginIndex"),
            endIndex = o.int("endIndex"),
            raw = o,
        )
    }
}

/** `GET /v1/fares/estimate` answer. */
public data class FareEstimateResponse(
    val country: String?,
    /** ISO 4217, e.g. NGN or XOF. */
    val currency: String?,
    val distanceM: Double?,
    val durationS: Double?,
    val estimates: List<FareEstimate>,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = FareEstimateResponse(
            country = o.str("country"),
            currency = o.str("currency"),
            distanceM = o.dbl("distanceM"),
            durationS = o.dbl("durationS"),
            estimates = o.objects("estimates").map(FareEstimate::parse),
            raw = o,
        )
    }
}

/** One mode's price range. */
public data class FareEstimate(
    val mode: String?,
    val currency: String?,
    val low: Double?,
    val typical: Double?,
    val high: Double?,
    /** The range written out: "₦3,000–4,500". */
    val text: String?,
    val raw: JsonObject,
) {
    internal companion object {
        fun parse(o: JsonObject) = FareEstimate(
            mode = o.str("mode"),
            currency = o.str("currency"),
            low = o.dbl("low"),
            typical = o.dbl("typical"),
            high = o.dbl("high"),
            text = o.str("text"),
            raw = o,
        )
    }
}
