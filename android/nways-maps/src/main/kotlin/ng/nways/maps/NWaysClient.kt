package ng.nways.maps

import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.Locale
import kotlin.coroutines.resumeWithException

/**
 * The N-Ways Maps Platform REST API (`/maps/v1`). Every call sends the API key and the
 * app's identity, like the map does. Failures throw [NWaysError].
 *
 * Get the shared one from [NWaysMaps.client] after [NWaysMaps.init].
 */
public class NWaysClient(
    private val config: NWaysConfig,
    private val http: OkHttpClient = NWaysMaps.newHttpClient(config),
) {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    // ── Geocoding and addresses ──────────────────────────────────────────

    /**
     * Finds places, addresses, businesses, NIPOST postcodes and GhanaPost GPS addresses.
     * [near] ranks nearer results first; [country] limits to NG, GH, BJ and/or TG;
     * [fields] picks the fields of each result.
     */
    public suspend fun geocode(
        query: String,
        near: NWaysLatLng? = null,
        country: List<String>? = null,
        limit: Int? = null,
        lang: String? = null,
        fields: List<String>? = null,
    ): GeocodeResponse = GeocodeResponse.parse(
        get(NWaysPaths.GEOCODE) {
            addQueryParameter("q", query)
            near?.let { addQueryParameter("near", latLng(it)) }
            country.list()?.let { addQueryParameter("country", it) }
            limit?.let { addQueryParameter("limit", it.toString()) }
            lang?.let { addQueryParameter("lang", it) }
            fields.list()?.let { addQueryParameter("fields", it) }
        },
    )

    /** What's at [point]: its country, region, Plus Code, nearest address and (Nigeria) postcode. */
    public suspend fun reverse(point: NWaysLatLng, radiusM: Int? = null, lang: String? = null): ReverseResult =
        ReverseResult.parse(
            get(NWaysPaths.REVERSE) {
                addQueryParameter("lat", coord(point.lat))
                addQueryParameter("lng", coord(point.lng))
                radiusM?.let { addQueryParameter("radius", it.toString()) }
                lang?.let { addQueryParameter("lang", it) }
            },
        )

    /** A NIPOST building postcode. Unknown codes throw [NWaysError] (404). */
    public suspend fun postcode(code: String): PostcodeResult =
        PostcodeResult.parse(get(NWaysPaths.POSTCODES) { addPathSegment(code.trim()) })

    /** A GhanaPost GPS address, e.g. GA-183-8164. Unknown codes throw [NWaysError] (404). */
    public suspend fun ghanaPost(code: String): GeocodeResult =
        GeocodeResult.parse(get(NWaysPaths.GHANAPOST) { addPathSegment(code.trim()) })

    /**
     * Suggestions as someone types. Send the same [session] token (8–64 letters, digits,
     * `-` or `_`; a UUID is fine) for every keystroke until they pick a result: the session is
     * billed once. [types]: address, street, business, place, area, postcode, ghanapost.
     */
    public suspend fun autocomplete(
        query: String,
        session: String? = null,
        near: NWaysLatLng? = null,
        types: List<String>? = null,
        country: List<String>? = null,
        limit: Int? = null,
        lang: String? = null,
    ): GeocodeResponse = GeocodeResponse.parse(
        get(NWaysPaths.AUTOCOMPLETE) {
            addQueryParameter("q", query)
            session?.let { addQueryParameter("session", it) }
            near?.let { addQueryParameter("near", latLng(it)) }
            types.list()?.let { addQueryParameter("types", it) }
            country.list()?.let { addQueryParameter("country", it) }
            limit?.let { addQueryParameter("limit", it.toString()) }
            lang?.let { addQueryParameter("lang", it) }
        },
    )

    /** Checks an address before dispatch: what was found, corrected or added, and how sure. */
    public suspend fun validateAddress(
        address: String,
        country: String? = null,
        near: NWaysLatLng? = null,
        lang: String? = null,
    ): AddressValidation = AddressValidation.parse(
        post(NWaysPaths.ADDRESSES_VALIDATE) {
            put("address", address)
            country?.let { put("country", it) }
            near?.let { put("near", Waypoint.of(it).toJson()) }
            lang?.let { put("lang", it) }
        },
    )

    // ── Places ───────────────────────────────────────────────────────────

    /**
     * Places near [point], by [category] (pharmacy, petrol, bank…) and/or a name [query].
     * For the next page pass the answer's `nextPageToken` as [pageToken]. [fields] picks the
     * fields (and the billing tier).
     */
    public suspend fun placesNearby(
        point: NWaysLatLng,
        category: String? = null,
        query: String? = null,
        radiusM: Int? = null,
        limit: Int? = null,
        pageToken: String? = null,
        fields: List<String>? = null,
    ): PlacesResponse = PlacesResponse.parse(
        get(NWaysPaths.PLACES_NEARBY) {
            addQueryParameter("lat", coord(point.lat))
            addQueryParameter("lng", coord(point.lng))
            category?.let { addQueryParameter("category", it) }
            query?.let { addQueryParameter("q", it) }
            radiusM?.let { addQueryParameter("radius", it.toString()) }
            limit?.let { addQueryParameter("limit", it.toString()) }
            pageToken?.let { addQueryParameter("pageToken", it) }
            fields.list()?.let { addQueryParameter("fields", it) }
        },
    )

    /** A place's details by id (from [placesNearby], or a geocoding result's `placeId`). */
    public suspend fun place(id: String, fields: List<String>? = null): Place = Place.parse(
        get(NWaysPaths.PLACES) {
            addPathSegment(id)
            fields.list()?.let { addQueryParameter("fields", it) }
        },
    )

    // ── Routes ───────────────────────────────────────────────────────────

    /**
     * A route from [origin] to [destination] through up to 25 [intermediates]. [mode] is one of
     * [TravelMode]; [alternatives] asks for up to 2 more routes (no intermediates);
     * [routingPreference] is one of [RoutingPreference]; [departAt] an RFC 3339 time;
     * [avoid] lists [Avoid] values; [fares] adds fare estimates to each route.
     */
    public suspend fun route(
        origin: Waypoint,
        destination: Waypoint,
        mode: String = TravelMode.DRIVE,
        intermediates: List<Waypoint> = emptyList(),
        alternatives: Boolean = false,
        routingPreference: String? = null,
        departAt: String? = null,
        avoid: List<String> = emptyList(),
        fares: Boolean = false,
        lang: String? = null,
    ): RoutesResponse = RoutesResponse.parse(
        post(NWaysPaths.ROUTES_COMPUTE) {
            put("origin", origin.toJson())
            put("destination", destination.toJson())
            if (intermediates.isNotEmpty()) put("intermediates", buildJsonArray { intermediates.forEach { add(it.toJson()) } })
            put("mode", mode)
            if (alternatives) put("alternatives", true)
            routingPreference?.let { put("routingPreference", it) }
            departAt?.let { put("departAt", it) }
            if (avoid.isNotEmpty()) put("avoid", buildJsonArray { avoid.forEach { add(it) } })
            if (fares) put("fares", true)
            lang?.let { put("lang", it) }
        },
    )

    /** Times and distances from each origin to each destination (up to 50 × 50, 625 elements). */
    public suspend fun matrix(
        origins: List<Waypoint>,
        destinations: List<Waypoint>,
        mode: String = TravelMode.DRIVE,
    ): MatrixResponse = MatrixResponse.parse(
        post(NWaysPaths.ROUTES_MATRIX) {
            put("origins", buildJsonArray { origins.forEach { add(it.toJson()) } })
            put("destinations", buildJsonArray { destinations.forEach { add(it.toJson()) } })
            put("mode", mode)
        },
    )

    /**
     * What a ride should cost from [from] to [to]. [modes]: taxi, shared_taxi, okada, keke,
     * danfo, ridehail, boat. [at]: an RFC 3339 time. [extra] goes through as query parameters
     * (distanceM, durationS, charter, rain, lang).
     */
    public suspend fun fares(
        from: NWaysLatLng,
        to: NWaysLatLng,
        modes: List<String>? = null,
        at: String? = null,
        extra: Map<String, String> = emptyMap(),
    ): FaresResponse = FaresResponse.parse(
        get(NWaysPaths.FARES_ESTIMATE) {
            addQueryParameter("from", latLng(from))
            addQueryParameter("to", latLng(to))
            modes.list()?.let { addQueryParameter("mode", it) }
            at?.let { addQueryParameter("at", it) }
            extra.forEach { (k, v) -> addQueryParameter(k, v) }
        },
    )

    // ── plumbing ─────────────────────────────────────────────────────────

    private fun url(path: String, build: HttpUrl.Builder.() -> Unit): HttpUrl =
        config.baseUrl.newBuilder().addPathSegments(path).apply(build).build()

    private fun List<String>?.list(): String? = this?.filter { it.isNotBlank() }?.takeIf { it.isNotEmpty() }?.joinToString(",")

    private fun latLng(p: NWaysLatLng) = coord(p.lat) + "," + coord(p.lng)

    private fun coord(v: Double) = String.format(Locale.US, "%.7f", v).trimEnd('0').trimEnd('.')

    private suspend fun get(path: String, build: HttpUrl.Builder.() -> Unit): JsonObject =
        execute(Request.Builder().url(url(path, build)).header("Accept", "application/json").get().build())

    private suspend fun post(path: String, body: JsonObjectBuilder.() -> Unit): JsonObject =
        execute(
            Request.Builder().url(url(path) {}).header("Accept", "application/json")
                .post(buildJsonObject(body).toString().toRequestBody(JSON_TYPE)).build(),
        )

    /** Runs [request]: the JSON object on 2xx (empty on 204), [NWaysError] otherwise. */
    private suspend fun execute(request: Request): JsonObject {
        val response = try {
            http.newCall(request).await()
        } catch (e: IOException) {
            throw NWaysError(0, status = "NETWORK", message = e.message ?: "Network error", cause = e)
        }
        return response.use { res ->
            val text = try {
                res.body?.string()
            } catch (e: IOException) {
                throw NWaysError(0, status = "NETWORK", message = e.message ?: "Network error", cause = e)
            }
            when {
                res.code == 204 -> JsonObject(emptyMap())
                res.isSuccessful -> try {
                    json.parseToJsonElement(text.orEmpty()).jsonObject
                } catch (e: Exception) {
                    throw NWaysError(res.code, message = "Not a JSON object", cause = e)
                }
                else -> throw NWaysError.from(res.code, text, res.header("Retry-After"))
            }
        }
    }

    private suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
        cont.invokeOnCancellation { cancel() }
        enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                cont.resume(response) { _, r, _ -> r.close() }
            }
            override fun onFailure(call: Call, e: IOException) {
                if (!cont.isCancelled) cont.resumeWithException(e)
            }
        })
    }

    private companion object {
        val JSON_TYPE = "application/json; charset=utf-8".toMediaType()
    }
}
