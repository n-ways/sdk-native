package ng.nways.maps

import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
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
 * The N-Ways REST APIs (preview). Every call sends the API key and the app's identity,
 * like the map does. Failures throw [NWaysError].
 *
 * Get the shared one from [NWaysMaps.client] after [NWaysMaps.init].
 */
public class NWaysClient(
    private val config: NWaysConfig,
    private val http: OkHttpClient = NWaysMaps.newHttpClient(config),
) {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    /** Finds places, addresses, businesses and postcodes. [near] ranks nearer results first. */
    public suspend fun geocode(
        query: String,
        limit: Int? = null,
        near: NWaysLatLng? = null,
        lang: String? = null,
    ): GeocodeResponse {
        val url = url(NWaysPaths.GEOCODE) {
            addQueryParameter("q", query)
            limit?.let { addQueryParameter("limit", it.toString()) }
            near?.let { addLatLng(it) }
            lang?.let { addQueryParameter("lang", it) }
        }
        return GeocodeResponse.parse(get(url)!!)
    }

    /** What's at [point], or null when nothing is known close enough (HTTP 204). */
    public suspend fun reverse(point: NWaysLatLng, lang: String? = null): ReverseResult? {
        val url = url(NWaysPaths.REVERSE) {
            addLatLng(point)
            lang?.let { addQueryParameter("lang", it) }
        }
        return get(url)?.let(ReverseResult::parse)
    }

    /** Looks up a NIPOST building postcode. Unknown codes throw [NWaysError] (404 postcode_unknown). */
    public suspend fun postcode(code: String): PostcodeResult {
        val url = url(NWaysPaths.POSTCODES) { addPathSegment(code.trim()) }
        return PostcodeResult.parse(get(url)!!)
    }

    /** Places near [point]: by [category] (pharmacy, petrol, bank…) and/or a name [query]. */
    public suspend fun places(
        point: NWaysLatLng,
        category: String? = null,
        query: String? = null,
        radiusM: Int? = null,
        limit: Int? = null,
    ): PlacesResponse {
        val url = url(NWaysPaths.PLACES) {
            addLatLng(point)
            category?.let { addQueryParameter("category", it) }
            query?.let { addQueryParameter("q", it) }
            radiusM?.let { addQueryParameter("radius", it.toString()) }
            limit?.let { addQueryParameter("limit", it.toString()) }
        }
        return PlacesResponse.parse(get(url)!!)
    }

    /**
     * A route from [from] to [to]. [mode] is one of [TravelMode]; [ride] (keke or bus)
     * goes with [TravelMode.DRIVE]. [alternates] is 0 to 3 other routes.
     */
    public suspend fun routes(
        from: NWaysLatLng,
        to: NWaysLatLng,
        mode: String = TravelMode.DRIVE,
        alternates: Int = 0,
        stops: List<NWaysLatLng> = emptyList(),
        ride: String? = null,
        lang: String? = null,
        avoidTolls: Boolean? = null,
    ): RoutesResponse {
        val body = buildJsonObject {
            put("from", from.toJson())
            put("to", to.toJson())
            if (stops.isNotEmpty()) put("stops", buildJsonArray { stops.forEach { add(it.toJson()) } })
            put("mode", mode)
            put("alternates", alternates)
            ride?.let { put("ride", it) }
            lang?.let { put("lang", it) }
            avoidTolls?.let { put("avoidTolls", it) }
        }
        return RoutesResponse.parse(post(url(NWaysPaths.ROUTES) {}, body))
    }

    /**
     * What a ride should cost. [params] go through as query parameters, e.g.
     * `mapOf("from" to "6.6018,3.3515", "to" to "6.5244,3.3792", "mode" to "keke,taxi")`.
     */
    public suspend fun fareEstimate(params: Map<String, String>): FareEstimateResponse {
        val url = url(NWaysPaths.FARES_ESTIMATE) { params.forEach { (k, v) -> addQueryParameter(k, v) } }
        return FareEstimateResponse.parse(get(url)!!)
    }

    // ── plumbing ─────────────────────────────────────────────────────────

    private fun url(path: String, build: HttpUrl.Builder.() -> Unit): HttpUrl =
        config.baseUrl.newBuilder().addPathSegments(path).apply(build).build()

    private fun HttpUrl.Builder.addLatLng(p: NWaysLatLng) {
        addQueryParameter("lat", coord(p.lat))
        addQueryParameter("lng", coord(p.lng))
    }

    private fun coord(v: Double) = String.format(Locale.US, "%.7f", v).trimEnd('0').trimEnd('.')

    private fun NWaysLatLng.toJson() = buildJsonObject {
        put("lat", lat)
        put("lng", lng)
    }

    private suspend fun get(url: HttpUrl): JsonObject? =
        execute(Request.Builder().url(url).header("Accept", "application/json").get().build())

    private suspend fun post(url: HttpUrl, body: JsonObject): JsonObject =
        execute(
            Request.Builder().url(url).header("Accept", "application/json")
                .post(body.toString().toRequestBody(JSON_TYPE)).build(),
        ) ?: throw NWaysError(204, message = "Empty answer")

    /** Runs [request]; the JSON object on 2xx, null on 204, [NWaysError] otherwise. */
    private suspend fun execute(request: Request): JsonObject? {
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
                res.code == 204 -> null
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
