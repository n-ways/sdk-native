package ng.nways.maps

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Request
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class HeaderInterceptorTest {
    private lateinit var nways: MockWebServer
    private lateinit var other: MockWebServer

    @Before
    fun setUp() {
        nways = MockWebServer().apply { start() }
        other = MockWebServer().apply { start() }
    }

    @After
    fun tearDown() {
        nways.shutdown()
        other.shutdown()
    }

    private fun config() = NWaysConfig(
        apiKey = "test-key-123",
        baseUrl = nways.url("/"),
        packageName = "ng.nways.sample",
        certSha1 = "AB:CD:EF",
    )

    @Test
    fun addsHeadersForTheNWaysHost() {
        nways.enqueue(MockResponse().setBody("ok"))
        val client = NWaysMaps.newHttpClient(config())
        client.newCall(Request.Builder().url(nways.url("/tiles/nigeria.pmtiles")).build()).execute().close()
        val r = nways.takeRequest()
        assertEquals("test-key-123", r.getHeader("X-NWays-Api-Key"))
        assertEquals("ng.nways.sample", r.getHeader("X-Android-Package"))
        assertEquals("AB:CD:EF", r.getHeader("X-Android-Cert"))
        assertEquals("android/1.0.0", r.getHeader("X-NWays-Sdk"))
    }

    @Test
    fun leavesOtherHostsAlone() {
        other.enqueue(MockResponse().setBody("ok"))
        val client = NWaysMaps.newHttpClient(config())
        client.newCall(Request.Builder().url(other.url("/style.json")).build()).execute().close()
        val r = other.takeRequest()
        assertNull(r.getHeader("X-NWays-Api-Key"))
        assertNull(r.getHeader("X-Android-Package"))
        assertNull(r.getHeader("X-Android-Cert"))
        assertNull(r.getHeader("X-NWays-Sdk"))
    }

    @Test
    fun redirectToAnotherHostDropsTheKey() {
        other.enqueue(MockResponse().setBody("landed"))
        nways.enqueue(MockResponse().setResponseCode(302).setHeader("Location", other.url("/elsewhere")))
        val client = NWaysMaps.newHttpClient(config())
        client.newCall(Request.Builder().url(nways.url("/fonts/a.pbf")).build()).execute().use {
            assertEquals("landed", it.body?.string())
        }
        assertEquals("test-key-123", nways.takeRequest().getHeader("X-NWays-Api-Key"))
        val hop = other.takeRequest()
        assertEquals("/elsewhere", hop.path)
        assertNull(hop.getHeader("X-NWays-Api-Key"))
        assertNull(hop.getHeader("X-Android-Cert"))
    }

    @Test
    fun omitsCertWhenUnknown() {
        nways.enqueue(MockResponse().setBody("ok"))
        val client = NWaysMaps.newHttpClient(config().copy(certSha1 = null))
        client.newCall(Request.Builder().url(nways.url("/x")).build()).execute().close()
        val r = nways.takeRequest()
        assertEquals("test-key-123", r.getHeader("X-NWays-Api-Key"))
        assertNull(r.getHeader("X-Android-Cert"))
    }

    @Test
    fun hostMatching() {
        val base = "https://nways.ng".toHttpUrl()
        assertTrue(NWaysHeaderInterceptor.isNWaysHost("https://nways.ng/tiles/nigeria.pmtiles".toHttpUrl(), base))
        assertTrue(NWaysHeaderInterceptor.isNWaysHost("https://NWAYS.ng/fonts/x.pbf".toHttpUrl(), base))
        assertFalse(NWaysHeaderInterceptor.isNWaysHost("http://nways.ng/tiles".toHttpUrl(), base))
        assertFalse(NWaysHeaderInterceptor.isNWaysHost("https://nways.ng:8443/tiles".toHttpUrl(), base))
        assertFalse(NWaysHeaderInterceptor.isNWaysHost("https://api.nways.ng/tiles".toHttpUrl(), base))
        assertFalse(NWaysHeaderInterceptor.isNWaysHost("https://nways.ng.evil.com/tiles".toHttpUrl(), base))
        assertFalse(NWaysHeaderInterceptor.isNWaysHost("https://demotiles.maplibre.org/x".toHttpUrl(), base))
    }
}
