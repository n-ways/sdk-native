package ng.nways.maps

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class NWaysClientTest {
    private lateinit var server: MockWebServer
    private lateinit var client: NWaysClient

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        client = NWaysClient(NWaysConfig("k", server.url("/"), "ng.nways.sample", "AB:CD"))
    }

    @After
    fun tearDown() = server.shutdown()

    private fun json(body: String, code: Int = 200) =
        MockResponse().setResponseCode(code).setHeader("Content-Type", "application/json").setBody(body)

    @Test
    fun geocode() = runTest {
        server.enqueue(
            json(
                """{"results":[{"id":"osm:n501540907","name":"Ikeja","kind":"city","location":{"lat":6.601627,"lng":3.3515981},
                "context":"Lagos State","country":"NG","newField":{"x":1}},
                {"id":"ghanapost:GA-183-8164","name":"GA-183-8164","kind":"address","location":{"lat":5.5422595,"lng":-0.207658},
                "context":"General Post Office, Greater Accra Region","attribution":"© OpenStreetMap contributors","country":"GH",
                "bbox":[-0.3,5.5,-0.1,5.6],"estimated":true,"radiusM":300}],"didYouMean":"Ikeja"}""",
            ),
        )
        val res = client.geocode("Allen Avenue", limit = 5, near = NWaysLatLng(6.6, 3.35))
        val req = server.takeRequest()
        assertEquals("/v1/geocode", req.requestUrl!!.encodedPath)
        assertEquals("Allen Avenue", req.requestUrl!!.queryParameter("q"))
        assertEquals("5", req.requestUrl!!.queryParameter("limit"))
        assertEquals("6.6", req.requestUrl!!.queryParameter("lat"))
        assertEquals("3.35", req.requestUrl!!.queryParameter("lng"))
        assertEquals("k", req.getHeader("X-NWays-Api-Key"))
        assertEquals("ng.nways.sample", req.getHeader("X-Android-Package"))

        assertEquals(2, res.results.size)
        val a = res.results[0]
        assertEquals("Ikeja", a.name)
        assertEquals("city", a.kind)
        assertEquals(NWaysLatLng(6.601627, 3.3515981), a.location)
        assertEquals("Ikeja, Lagos State", a.label)
        assertEquals(1, a.raw["newField"]!!.jsonObject["x"]!!.jsonPrimitive.int)
        val b = res.results[1]
        assertTrue(b.estimated)
        assertEquals(300.0, b.radiusM!!, 0.0)
        assertEquals(listOf(-0.3, 5.5, -0.1, 5.6), b.bbox)
        assertEquals("Ikeja", res.didYouMean)
    }

    @Test
    fun reverseNothingThereIsNull() = runTest {
        server.enqueue(MockResponse().setResponseCode(204))
        assertNull(client.reverse(NWaysLatLng(6.4281, 3.4219)))
        assertEquals("/v1/reverse?lat=6.4281&lng=3.4219", server.takeRequest().path)
    }

    @Test
    fun reverseBuilding() = runTest {
        server.enqueue(json("""{"code":"100001","display":"100 001","address":"1 Example Street","location":{"lat":6.4,"lng":3.4},"entrances":[]}"""))
        val r = client.reverse(NWaysLatLng(6.4, 3.4))!!
        assertEquals("100001", r.code)
        assertEquals("1 Example Street", r.address)
    }

    @Test
    fun postcode() = runTest {
        server.enqueue(
            json(
                """{"code":"ABC123","display":"ABC 123","location":{"lat":6.5,"lng":3.3},"stateName":"Lagos","lgaName":"Ikeja",
                "entrances":[{"id":7,"location":{"lat":6.5001,"lng":3.3001},"kind":"gate","verified":true}],"source":"osm"}""",
            ),
        )
        val p = client.postcode("ABC123")
        assertEquals("/v1/postcodes/ABC123", server.takeRequest().path)
        assertEquals("Lagos", p.stateName)
        assertEquals(1, p.entrances.size)
        assertEquals(7L, p.entrances[0].id)
        assertTrue(p.entrances[0].verified)
    }

    @Test
    fun places() = runTest {
        server.enqueue(
            json(
                """{"places":[{"id":"ov:1","name":"Example Pharmacy","category":"pharmacy","detail":"Pharmacy",
                "location":{"lat":6.601833,"lng":3.352457},"address":"9 Allen Avenue, Ikeja","phone":"+234 800 000 0000",
                "hoursInfo":{"basis":"usual","hours":"Mo-Sa 08:00-20:00"},"source":"overture","distanceM":106}],"more":false,"offset":0}""",
            ),
        )
        val res = client.places(NWaysLatLng(6.6018, 3.3515), category = "pharmacy", radiusM = 1500, limit = 10)
        val url = server.takeRequest().requestUrl!!
        assertEquals("/v1/places", url.encodedPath)
        assertEquals("pharmacy", url.queryParameter("category"))
        assertEquals("1500", url.queryParameter("radius"))
        assertEquals("10", url.queryParameter("limit"))
        val p = res.places.single()
        assertEquals("Mo-Sa 08:00-20:00", p.hours)
        assertEquals(106.0, p.distanceM!!, 0.0)
    }

    @Test
    fun routes() = runTest {
        server.enqueue(
            json(
                """{"mode":"motorcycle","routes":[{"distanceM":18420,"durationS":2310,"trafficDelayS":420,"via":"Ikorodu Road",
                "geometry":[[3.3515,6.6018],[3.3521,6.6011]],
                "maneuvers":[{"type":1,"instruction":"Head south on Allen Avenue.","distanceM":350,"durationS":60,"beginIndex":0,"endIndex":12}],
                "legs":[],"tolls":{"gates":[],"costNGN":0}}],"tollsUnavoidable":false}""",
            ),
        )
        val res = client.routes(NWaysLatLng(6.6018, 3.3515), NWaysLatLng(6.4541, 3.3947), mode = TravelMode.MOTORCYCLE)
        val req = server.takeRequest()
        assertEquals("POST", req.method)
        assertEquals("/v1/routes", req.path)
        val body = Json.parseToJsonElement(req.body.readUtf8()).jsonObject
        assertEquals("motorcycle", body["mode"]!!.jsonPrimitive.content)
        assertEquals(0, body["alternates"]!!.jsonPrimitive.int)
        assertEquals(6.6018, body["from"]!!.jsonObject["lat"]!!.jsonPrimitive.content.toDouble(), 0.0)
        assertEquals(3.3947, body["to"]!!.jsonObject["lng"]!!.jsonPrimitive.content.toDouble(), 0.0)

        val r = res.routes.single()
        assertEquals(18420.0, r.distanceM, 0.0)
        assertEquals(2310.0, r.durationS, 0.0)
        assertEquals(listOf(NWaysLatLng(6.6018, 3.3515), NWaysLatLng(6.6011, 3.3521)), r.geometry)
        assertEquals("Head south on Allen Avenue.", r.maneuvers.single().instruction)
        assertNotNull(r.raw["tolls"])
    }

    @Test
    fun fareEstimatePassesParamsThrough() = runTest {
        server.enqueue(
            json(
                """{"country":"NG","currency":"NGN","distanceM":9000,"durationS":1500,
                "estimates":[{"mode":"keke","currency":"NGN","low":1500,"typical":2000,"high":2500,"text":"₦1,500–2,500"}],"notAllowed":[]}""",
            ),
        )
        val res = client.fareEstimate(mapOf("from" to "6.6018,3.3515", "to" to "6.5244,3.3792", "mode" to "keke,taxi"))
        val url = server.takeRequest().requestUrl!!
        assertEquals("/v1/fares/estimate", url.encodedPath)
        assertEquals("keke,taxi", url.queryParameter("mode"))
        assertEquals("6.6018,3.3515", url.queryParameter("from"))
        assertEquals("NGN", res.currency)
        assertEquals("₦1,500–2,500", res.estimates.single().text)
    }

    @Test
    fun errorEnvelopeIsThrown() = runTest {
        server.enqueue(
            json(
                """{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","reason":"QUOTA_EXCEEDED","message":"Daily quota used."}}""",
                429,
            ).setHeader("Retry-After", "60"),
        )
        try {
            client.geocode("Ikeja")
            fail("expected NWaysError")
        } catch (e: NWaysError) {
            assertEquals(429, e.httpStatus)
            assertEquals("QUOTA_EXCEEDED", e.reason)
            assertEquals(60L, e.retryAfterSeconds)
        }
    }

    @Test
    fun olderErrorIsThrown() = runTest {
        server.enqueue(json("""{"error":"no route","code":"no_route"}""", 422))
        try {
            client.routes(NWaysLatLng(6.0, 3.0), NWaysLatLng(6.1, 3.1))
            fail("expected NWaysError")
        } catch (e: NWaysError) {
            assertEquals(422, e.httpStatus)
            assertEquals("no_route", e.code)
        }
    }

    @Test
    fun networkFailureIsNWaysError() = runTest {
        server.shutdown()
        try {
            client.geocode("Ikeja")
            fail("expected NWaysError")
        } catch (e: NWaysError) {
            assertEquals(0, e.httpStatus)
            assertTrue(e.isRetryable)
        }
    }
}
