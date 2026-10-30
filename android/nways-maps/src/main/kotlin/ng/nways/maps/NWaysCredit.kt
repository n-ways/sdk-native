// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
package ng.nways.maps

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.spec.ECGenParameterSpec
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * Startup Program credit for apps (https://nways.ng/developers/startup-credit).
 *
 * The credit pays for an app's calls only when they carry a valid app attestation
 * for the verified app the key is bound to. [start] does it once every 30 days: it
 * asks N-Ways for a challenge, makes a hardware-backed Android Keystore key whose
 * attestation certificate holds the challenge (and, written by Android, this app's
 * package and signing certificate), and keeps the session N-Ways returns. From then
 * on the SDK sends it as `X-NWays-Attestation` on every N-Ways request.
 *
 * Call it from a background thread after [NWaysMaps.init]. Calls made before it
 * finishes, or on devices without hardware key attestation, are billed as normal
 * paid usage.
 */
public object NWaysCredit {
    private const val PREFS = "ng.nways.credit"
    private const val ALIAS = "ng.nways.credit.attest"

    @Volatile
    private var token: String? = null

    @Volatile
    private var expires: Long = 0

    /** The current session (the header's value), or null. */
    @JvmStatic
    public fun session(): String? =
        token?.takeIf { expires > System.currentTimeMillis() + 3_600_000 }

    /** Reads a session kept from an earlier launch. */
    @JvmStatic
    public fun load(context: Context) {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        token = p.getString("token", null)
        expires = p.getLong("expires", 0)
    }

    /** Forgets the session (N-Ways answered `X-NWays-Credit: paid; why=attestation_invalid`). */
    @JvmStatic
    public fun reset(context: Context) {
        token = null
        expires = 0
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** An attestation the server refused, or one the device can't make. */
    public class Failure(public val status: Int, public val reason: String) : Exception("$status $reason")

    /**
     * Attests the app if there's no valid session (blocking: call it off the main
     * thread); returns when the session ends (milliseconds since the epoch).
     */
    @JvmStatic
    public fun start(context: Context): Long {
        if (token == null) load(context)
        session()?.let { return expires }
        // Key attestation with a challenge needs Android 7.0 (API 24).
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) throw Failure(0, "NOT_SUPPORTED")
        val config = NWaysMaps.config
        val http = OkHttpClient.Builder().addNetworkInterceptor(NWaysHeaderInterceptor(config)).build()
        val challenge = post(http, config, "/maps/v1/credit/attest/challenge", JSONObject()).getString("challenge")
        val keyId = UUID.randomUUID().toString()
        val hash = MessageDigest.getInstance("SHA-256").digest("nways-credit|$challenge|$keyId".toByteArray())
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        ks.deleteEntry(ALIAS)
        val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setAttestationChallenge(hash)
            .build()
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").apply {
            initialize(spec)
            generateKeyPair()
        }
        val chain = JSONArray()
        ks.getCertificateChain(ALIAS)?.forEach { chain.put(Base64.encodeToString(it.encoded, Base64.NO_WRAP)) }
            ?: throw Failure(0, "NO_ATTESTATION")
        val res = post(http, config, "/maps/v1/credit/attest", JSONObject()
            .put("platform", "android").put("challenge", challenge).put("keyId", keyId).put("chain", chain))
        val t = res.getString("token")
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val e = iso.parse(res.getString("expiresAt"))?.time ?: throw Failure(200, "BAD_ANSWER")
        token = t
        expires = e
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("token", t).putLong("expires", e).apply()
        return e
    }

    private fun post(http: OkHttpClient, config: NWaysConfig, path: String, body: JSONObject): JSONObject {
        val url = config.baseUrl.newBuilder().encodedPath(path).build()
        val req = Request.Builder().url(url).post(body.toString().toRequestBody("application/json".toMediaType())).build()
        http.newCall(req).execute().use { r ->
            val text = r.body?.string().orEmpty()
            if (r.code != 200) {
                val reason = runCatching { JSONObject(text).getJSONObject("error").getString("reason") }.getOrDefault("HTTP_${r.code}")
                throw Failure(r.code, reason)
            }
            return JSONObject(text)
        }
    }
}
