package ng.nways.maps

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.security.MessageDigest

/** Reads the SHA-1 of the app's signing certificate, the way partner key restrictions expect it. */
internal object AppSigning {

    fun certSha1(context: Context): String? = try {
        signatures(context)?.firstOrNull()?.let { sha1Fingerprint(it.toByteArray()) }
    } catch (_: Exception) {
        null
    }

    @SuppressLint("PackageManagerGetSignatures")
    private fun signatures(context: Context): Array<Signature>? {
        val pm = context.packageManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES).signatures
        }
    }

    /** SHA-1 of a DER-encoded certificate, as uppercase hex pairs joined by colons. */
    fun sha1Fingerprint(certificate: ByteArray): String =
        formatFingerprint(MessageDigest.getInstance("SHA-1").digest(certificate))

    fun formatFingerprint(digest: ByteArray): String =
        digest.joinToString(":") { "%02X".format(it.toInt() and 0xFF) }
}
