// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
package ng.nways.maps

import android.content.Context
import okhttp3.Dispatcher
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import org.maplibre.android.MapLibre
import org.maplibre.android.module.http.HttpRequestUtil

/** The map's look: N-Ways' light or dark streets style. */
public enum class Theme(public val styleId: String) {
    LIGHT(NWaysMaps.STYLE_STREETS_LIGHT),
    DARK(NWaysMaps.STYLE_STREETS_DARK),
}

/**
 * N-Ways Maps for Android: call [init] once (in `Application.onCreate` or before the
 * first `MapView`), then use [styleUrl], `MapLibreMap.setNWaysStyle(...)` and [client].
 */
public object NWaysMaps {
    public const val SDK_VERSION: String = BuildConfig.SDK_VERSION
    public const val DEFAULT_BASE_URL: String = "https://nways.ng"
    public const val STYLE_STREETS_LIGHT: String = "streets-light"
    public const val STYLE_STREETS_DARK: String = "streets-dark"

    /** The credit shown on every N-Ways map. Keep it visible. */
    public const val ATTRIBUTION: String = "© N-Ways · © OpenStreetMap contributors · Protomaps"

    /** [ATTRIBUTION] as MapLibre attribution HTML (MapLibre lists each link). */
    public const val ATTRIBUTION_HTML: String =
        "<a href=\"https://nways.ng/\">© N-Ways</a> · " +
            "<a href=\"https://www.openstreetmap.org/copyright\">© OpenStreetMap contributors</a> · " +
            "<a href=\"https://protomaps.com/\">Protomaps</a>"

    @Volatile
    private var current: NWaysConfig? = null

    @Volatile
    private var restClient: NWaysClient? = null

    /** The configuration given to [init]; throws if [init] wasn't called. */
    public val config: NWaysConfig
        get() = current ?: throw IllegalStateException("Call NWaysMaps.init(context, apiKey) first.")

    /** Whether [init] has been called. */
    public val isInitialized: Boolean get() = current != null

    /**
     * Sets up N-Ways Maps: starts MapLibre and makes every request MapLibre sends to
     * [baseUrl]'s host carry the API key and this app's identity (package and signing
     * certificate SHA-1). Requests to other hosts are left alone.
     */
    @JvmStatic
    @JvmOverloads
    public fun init(context: Context, apiKey: String, baseUrl: String = DEFAULT_BASE_URL) {
        require(apiKey.isNotBlank()) { "apiKey is empty" }
        val app = context.applicationContext ?: context
        val cfg = NWaysConfig(
            apiKey = apiKey.trim(),
            baseUrl = normalizeBaseUrl(baseUrl),
            packageName = app.packageName,
            certSha1 = AppSigning.certSha1(app),
        )
        val http = newHttpClient(cfg)
        current = cfg
        restClient = NWaysClient(cfg, http)
        MapLibre.getInstance(app)
        HttpRequestUtil.setOkHttpClient(http)
    }

    /** The REST client (geocoding, places, routes, fares), set up by [init]. */
    @JvmStatic
    public val client: NWaysClient
        get() = restClient ?: throw IllegalStateException("Call NWaysMaps.init(context, apiKey) first.")

    /** The style URL for [theme] and [lang] ("en" or "fr") on the configured host. */
    @JvmStatic
    @JvmOverloads
    public fun styleUrl(theme: Theme = Theme.LIGHT, lang: String = "en"): String =
        buildStyleUrl(config.baseUrl.toString(), theme.styleId, lang)

    /**
     * `{baseUrl}/maps/v1/styles/{styleId}.json`, with `?lang=xx` when [lang] isn't English
     * (the server's default).
     */
    @JvmStatic
    public fun buildStyleUrl(baseUrl: String, styleId: String, lang: String = "en"): String {
        require(STYLE_ID.matches(styleId)) { "bad styleId: $styleId" }
        val l = lang.trim().lowercase()
        require(LANG.matches(l)) { "lang must be a language code like en or fr: $lang" }
        val b = normalizeBaseUrl(baseUrl).newBuilder()
            .addPathSegments(NWaysPaths.STYLES)
            .addPathSegment("$styleId.json")
        if (l != "en") b.addQueryParameter("lang", l)
        return b.build().toString()
    }

    /** An OkHttp client carrying the N-Ways headers for [config]'s host only. */
    @JvmStatic
    public fun newHttpClient(config: NWaysConfig): OkHttpClient {
        // Like MapLibre's own client: tiles come in bursts from one host.
        val dispatcher = Dispatcher().apply { maxRequestsPerHost = 20 }
        return OkHttpClient.Builder()
            .dispatcher(dispatcher)
            // A network interceptor runs on every hop, so a redirect to another host
            // never carries the key.
            .addNetworkInterceptor(NWaysHeaderInterceptor(config))
            .build()
    }

    internal fun normalizeBaseUrl(baseUrl: String): HttpUrl {
        val u = baseUrl.trim().trimEnd('/').toHttpUrl()
        require(u.query == null && u.fragment == null) { "baseUrl can't have a query or fragment: $baseUrl" }
        return u
    }

    private val STYLE_ID = Regex("[a-z0-9][a-z0-9-]{0,63}")
    private val LANG = Regex("[a-z]{2,3}")
}

/** What [NWaysMaps.init] was given, and what it found out about the app. */
public data class NWaysConfig(
    val apiKey: String,
    val baseUrl: HttpUrl,
    val packageName: String?,
    /** SHA-1 of the app's signing certificate, `AB:CD:…`, or null if unreadable. */
    val certSha1: String?,
) {
    override fun toString(): String =
        "NWaysConfig(apiKey=${apiKey.take(6)}…, baseUrl=$baseUrl, packageName=$packageName, certSha1=$certSha1)"
}
