package ng.nways.maps

import org.junit.Assert.assertEquals
import org.junit.Test

class AppSigningTest {
    @Test
    fun formatsUppercaseColonSeparatedPairs() {
        val digest = byteArrayOf(0x00, 0x0f, 0xab.toByte(), 0xff.toByte(), 0x7f)
        assertEquals("00:0F:AB:FF:7F", AppSigning.formatFingerprint(digest))
    }

    @Test
    fun sha1OfKnownInput() {
        // SHA-1("abc") = a9993e364706816aba3e25717850c26c9cd0d89d
        assertEquals(
            "A9:99:3E:36:47:06:81:6A:BA:3E:25:71:78:50:C2:6C:9C:D0:D8:9D",
            AppSigning.sha1Fingerprint("abc".toByteArray()),
        )
    }

    @Test
    fun sha1Has20Pairs() {
        val f = AppSigning.sha1Fingerprint(ByteArray(100) { it.toByte() })
        assertEquals(20, f.split(":").size)
        assertEquals(59, f.length)
    }
}
