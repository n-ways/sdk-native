package ng.nways.maps

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NWaysErrorTest {
    @Test
    fun partnerEnvelope() {
        val e = NWaysError.from(
            403,
            """{"error":{"code":403,"status":"PERMISSION_DENIED","reason":"API_KEY_SERVICE_BLOCKED","message":"This key may not call Routes."}}""",
            null,
        )
        assertEquals(403, e.httpStatus)
        assertEquals("PERMISSION_DENIED", e.status)
        assertEquals("API_KEY_SERVICE_BLOCKED", e.reason)
        assertEquals("This key may not call Routes.", e.message)
        assertNull(e.code)
        assertNull(e.retryAfterSeconds)
        assertFalse(e.isRetryable)
    }

    @Test
    fun quotaWithRetryAfterSeconds() {
        val e = NWaysError.from(
            429,
            """{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","reason":"RATE_LIMIT_EXCEEDED","message":"Slow down."}}""",
            "60",
        )
        assertEquals("RESOURCE_EXHAUSTED", e.status)
        assertEquals(60L, e.retryAfterSeconds)
        assertTrue(e.isRetryable)
    }

    @Test
    fun olderShapeWithCode() {
        val e = NWaysError.from(422, """{"error":"no route between these points","code":"no_route"}""", null)
        assertEquals(422, e.httpStatus)
        assertEquals("no_route", e.code)
        assertEquals("no route between these points", e.message)
        assertNull(e.status)
        assertNull(e.reason)
    }

    @Test
    fun olderShapeWithoutCode() {
        val e = NWaysError.from(400, """{"error":"lat and lng query parameters are required"}""", null)
        assertNull(e.code)
        assertEquals("lat and lng query parameters are required", e.message)
    }

    @Test
    fun nonJsonBody() {
        val e = NWaysError.from(502, "Bad Gateway", null)
        assertEquals(502, e.httpStatus)
        assertEquals("Bad Gateway", e.message)
        assertTrue(e.isRetryable)
    }

    @Test
    fun emptyBody() {
        assertEquals("HTTP 503", NWaysError.from(503, "", null).message)
    }

    @Test
    fun retryAfterHttpDate() {
        // Thu, 01 Jan 1970 00:01:40 GMT is 100 s after epoch.
        assertEquals(40L, NWaysError.parseRetryAfter("Thu, 01 Jan 1970 00:01:40 GMT", nowMillis = 60_000))
        assertEquals(0L, NWaysError.parseRetryAfter("Thu, 01 Jan 1970 00:01:40 GMT", nowMillis = 200_000))
    }

    @Test
    fun retryAfterGarbage() {
        assertNull(NWaysError.parseRetryAfter("soon"))
        assertNull(NWaysError.parseRetryAfter(null))
        assertEquals(0L, NWaysError.parseRetryAfter("-5"))
    }
}
