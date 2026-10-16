// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
package ng.nways.maps

import okhttp3.HttpUrl
import okhttp3.Interceptor
import okhttp3.Response

/** Header names the N-Ways API reads (they match the partner key restrictions). */
public object NWaysHeaders {
    public const val API_KEY: String = "X-NWays-Api-Key"
    public const val ANDROID_PACKAGE: String = "X-Android-Package"
    public const val ANDROID_CERT: String = "X-Android-Cert"
    public const val SDK: String = "X-NWays-Sdk"
    public const val SDK_VALUE: String = "android/" + NWaysMaps.SDK_VERSION
}

/**
 * Adds the API key and the app's identity to requests for the N-Ways host — same
 * scheme, host and port as the configured base URL — and to nothing else.
 * Install it as a network interceptor so each redirect hop is checked on its own.
 */
public class NWaysHeaderInterceptor(private val config: NWaysConfig) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val req = chain.request()
        if (!isNWaysHost(req.url, config.baseUrl)) return chain.proceed(req)
        val b = req.newBuilder()
            .header(NWaysHeaders.API_KEY, config.apiKey)
            .header(NWaysHeaders.SDK, NWaysHeaders.SDK_VALUE)
        config.packageName?.let { b.header(NWaysHeaders.ANDROID_PACKAGE, it) }
        config.certSha1?.let { b.header(NWaysHeaders.ANDROID_CERT, it) }
        return chain.proceed(b.build())
    }

    public companion object {
        /** True when [url] is on the N-Ways host given by [base]. */
        @JvmStatic
        public fun isNWaysHost(url: HttpUrl, base: HttpUrl): Boolean =
            url.scheme == base.scheme && url.host.equals(base.host, ignoreCase = true) && url.port == base.port
    }
}
