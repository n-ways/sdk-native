package ng.nways.maps

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * A request N-Ways refused or couldn't answer.
 *
 * - Key and quota errors: `{"error":{"code":403,"status":"PERMISSION_DENIED","reason":"…","message":"…"}}`
 *   fill [status] and [reason].
 * - API errors: `{"error":"…","code":"no_route"}` fill [code].
 * - A network failure has [httpStatus] 0 and the [cause].
 *
 * Act on [httpStatus], [reason] and [code], never on [message]'s words.
 */
public class NWaysError(
    /** The HTTP status, or 0 when no answer came (network failure). */
    public val httpStatus: Int,
    /** Key/quota errors: PERMISSION_DENIED, RESOURCE_EXHAUSTED, INVALID_ARGUMENT, UNAVAILABLE… */
    public val status: String? = null,
    /** Key/quota errors: why, e.g. API_KEY_SERVICE_BLOCKED. */
    public val reason: String? = null,
    /** API errors: a stable code such as no_route or postcode_unknown. */
    public val code: String? = null,
    message: String,
    /** Seconds to wait before retrying, from Retry-After (429, 503). */
    public val retryAfterSeconds: Long? = null,
    /** The error body as JSON, when it was JSON. */
    public val raw: JsonObject? = null,
    cause: Throwable? = null,
) : Exception(message, cause) {

    /** Worth retrying later: rate limits, server trouble and network failures. */
    public val isRetryable: Boolean get() = httpStatus == 0 || httpStatus == 429 || httpStatus >= 500

    override fun toString(): String =
        "NWaysError(httpStatus=$httpStatus, status=$status, reason=$reason, code=$code, " +
            "retryAfterSeconds=$retryAfterSeconds, message=$message)"

    public companion object {
        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        /** Builds the error for an HTTP answer with [httpStatus], [body] and its Retry-After header. */
        @JvmStatic
        @JvmOverloads
        public fun from(httpStatus: Int, body: String?, retryAfter: String?, nowMillis: Long = System.currentTimeMillis()): NWaysError {
            val obj = body?.takeIf { it.isNotBlank() }?.let {
                try {
                    json.parseToJsonElement(it).jsonObject
                } catch (_: Exception) {
                    null
                }
            }
            val wait = parseRetryAfter(retryAfter, nowMillis)
            val err = obj?.get("error")
            if (err is JsonObject) {
                return NWaysError(
                    httpStatus = httpStatus,
                    status = err.str("status"),
                    reason = err.str("reason"),
                    message = err.str("message") ?: "HTTP $httpStatus",
                    retryAfterSeconds = wait,
                    raw = obj,
                )
            }
            val text = (err as? JsonPrimitive)?.takeIf { it.isString }?.content
            return NWaysError(
                httpStatus = httpStatus,
                code = obj?.str("code"),
                message = text ?: obj?.str("message") ?: body?.takeIf { obj == null && it.isNotBlank() }?.take(200)
                    ?: "HTTP $httpStatus",
                retryAfterSeconds = wait,
                raw = obj,
            )
        }

        /** Retry-After as seconds: either a number of seconds or an HTTP date. */
        @JvmStatic
        public fun parseRetryAfter(value: String?, nowMillis: Long = System.currentTimeMillis()): Long? {
            val v = value?.trim().orEmpty()
            if (v.isEmpty()) return null
            v.toLongOrNull()?.let { return it.coerceAtLeast(0) }
            return try {
                val f = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US)
                f.timeZone = TimeZone.getTimeZone("GMT")
                val at = f.parse(v)?.time ?: return null
                ((at - nowMillis + 999) / 1000).coerceAtLeast(0)
            } catch (_: Exception) {
                null
            }
        }
    }
}
