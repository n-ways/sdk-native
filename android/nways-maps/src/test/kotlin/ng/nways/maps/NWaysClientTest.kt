package ng.nways.maps

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/** The client against the partner API's own golden answers (backend/internal/partnerapi/testdata/golden). */
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

    private fun fixture(name: String): String =
        requireNotNull(javaClass.getResource("/fixtures/$name.json")) { "no fixture $name" }.readText()

    private fun answer(body: String, code: Int = 200) = server.enqueue(
        MockResponse().setResponseCode(code).setHeader("Content-Type", "application/json").setBody(body),
    )

    private fun RecordedRequest.q(name: String) = requestUrl!!.queryParameter(name)
    private fun RecordedRequest.bodyJson(): JsonObject = Json.parseToJsonElement(body.readUtf8()).jsonObject

    @Test
    fun geocode() = runTest {
        answer(fixture("geocode"))
        val res = client.geocode("Ikeja City Mall", near = NWaysLatLng(6.6, 3.35), country = listOf("NG", "GH"), limit = 5, lang = "fr", fields = listOf("id", "name"))
        val req = server.takeRequest()
        assertEquals("GET", req.method)
        assertEquals("/maps/v1/geocode", req.requestUrl!!.encodedPath)
        assertEquals("Ikeja City Mall", req.q("q"))
        assertEquals("6.6,3.35", req.q("near"))
        assertEquals("NG,GH", req.q("country"))
        assertEquals("5", req.q("limit"))
        assertEquals("fr", req.q("lang"))
        assertEquals("id,name", req.q("fields"))
        assertEquals("k", req.getHeader("X-NWays-Api-Key"))
        assertEquals("ng.nways.sample", req.getHeader("X-Android-Package"))
        assertEquals("AB:CD", req.getHeader("X-Android-Cert"))

        assertEquals(4, res.results.size)
        val a = res.results[0]
        assertEquals("osm:w568367632", a.id)
        assertEquals("landmark", a.type)
        assertEquals(NWaysLatLng(6.61437, 3.357831), a.location)
        assertEquals("Ikeja City Mall, Ikeja, Lagos", a.label)
        assertEquals(4, a.bbox!!.size)
        assertEquals("6FR5J975+P4W", a.plusCode)
        assertEquals(22445.0, a.distanceM!!, 0.0)
        assertEquals("ov:7c065f24-3cc2-4426-9163-a5a54e7e2860", res.results[1].placeId)
        assertEquals("© OpenStreetMap contributors, N-Ways", res.attribution)
    }

    @Test
    fun reverseNigeria() = runTest {
        answer(fixture("reverse_ng"))
        val r = client.reverse(NWaysLatLng(6.4474, 3.472), radiusM = 150, lang = "en")
        val req = server.takeRequest()
        assertEquals("/maps/v1/reverse?lat=6.4474&lng=3.472&radius=150&lang=en", req.path)
        assertEquals(NWaysLatLng(6.4474, 3.472), r.location)
        assertEquals("NG", r.country!!.code)
        assertEquals("État de Lagos", r.region!!.nameFr)
        assertEquals("LA08A09DB09", r.postcode!!.code)
        assertEquals("Eti-Osa", r.postcode!!.components!!.lgaName)
        assertEquals(16.0, r.postcode!!.distanceM!!, 0.0)
        assertNull(r.ghanaPost)
        assertEquals("Brasas'r Place", r.nearest!!.name)
    }

    @Test
    fun reverseGhana() = runTest {
        answer(fixture("reverse_gh"))
        val r = client.reverse(NWaysLatLng(5.6037, -0.187))
        assertEquals("GA-183-8164", r.ghanaPost)
        assertEquals("GH-AA", r.region!!.code)
        assertNull(r.postcode)
        assertEquals(NWaysLatLng(5.6037, -0.187), r.location)
    }

    @Test
    fun postcode() = runTest {
        answer(fixture("postcode"))
        val p = client.postcode("LA08A09DB09")
        assertEquals("/maps/v1/postcodes/LA08A09DB09", server.takeRequest().path)
        assertEquals("LA 08 A09 DB 09", p.display)
        assertEquals("LA", p.components!!.state)
        assertEquals("house", p.buildingType)
        val e = p.entrances.single()
        assertEquals("gate", e.kind)
        assertTrue(e.verified)
        assertEquals(NWaysLatLng(6.44738, 3.47225), e.location)
        assertFalse(p.estimated)
    }

    @Test
    fun ghanaPost() = runTest {
        answer(fixture("ghanapost"))
        val g = client.ghanaPost("GA-183-8164")
        assertEquals("/maps/v1/ghanapost/GA-183-8164", server.takeRequest().path)
        assertEquals("ghanapost", g.type)
        assertEquals("GA-183-8164", g.ghanaPost)
        assertEquals(NWaysLatLng(5.54226, -0.207658), g.location)
    }

    @Test
    fun autocomplete() = runTest {
        answer(fixture("autocomplete"))
        val res = client.autocomplete("ikeja ci", session = "3f2a9c1e-session", near = NWaysLatLng(6.6, 3.35), types = listOf("business", "place"), limit = 5)
        val req = server.takeRequest()
        assertEquals("/maps/v1/autocomplete", req.requestUrl!!.encodedPath)
        assertEquals("3f2a9c1e-session", req.q("session"))
        assertEquals("business,place", req.q("types"))
        assertEquals("6.6,3.35", req.q("near"))
        assertEquals(2, res.results.size)
    }

    @Test
    fun validateAddress() = runTest {
        answer(fixture("validate_postcode"))
        val v = client.validateAddress("LA 08 A09 DB 09", country = "NG", near = NWaysLatLng(6.45, 3.47), lang = "en")
        val req = server.takeRequest()
        assertEquals("POST", req.method)
        assertEquals("/maps/v1/addresses/validate", req.path)
        val body = req.bodyJson()
        assertEquals("LA 08 A09 DB 09", body["address"]!!.jsonPrimitive.content)
        assertEquals("NG", body["country"]!!.jsonPrimitive.content)
        assertEquals(6.45, body["near"]!!.jsonObject["lat"]!!.jsonPrimitive.double, 0.0)
        assertEquals("VALID", v.verdict!!.status)
        assertEquals("PREMISE", v.verdict!!.granularity)
        assertEquals(true, v.verdict!!.codesAgree)
        assertEquals("postcode", v.components.first().type)
        assertEquals("LA08A09DB09", v.postcode!!.code)
        assertEquals(NWaysLatLng(6.4475, 3.4721), v.location)
    }

    @Test
    fun placesNearby() = runTest {
        answer(fixture("places_nearby"))
        val res = client.placesNearby(NWaysLatLng(6.4474, 3.472), category = "bank", radiusM = 5000, limit = 3, pageToken = "abc", fields = listOf("name", "phone"))
        val req = server.takeRequest()
        assertEquals("/maps/v1/places/nearby", req.requestUrl!!.encodedPath)
        assertEquals("6.4474", req.q("lat"))
        assertEquals("bank", req.q("category"))
        assertEquals("5000", req.q("radius"))
        assertEquals("abc", req.q("pageToken"))
        assertEquals("name,phone", req.q("fields"))
        assertEquals(3, res.places.size)
        assertEquals("Access Bank", res.places[0].name)
        assertEquals("OPERATIONAL", res.places[0].businessStatus)
        assertEquals(2403.0, res.places[0].distanceM!!, 0.0)
        assertEquals("bzoz", res.nextPageToken)
    }

    @Test
    fun placeDetails() = runTest {
        answer(fixture("place_details_all"))
        val p = client.place("osm:n2987189855")
        assertEquals("/maps/v1/places/osm:n2987189855", server.takeRequest().path)
        assertEquals("Shoprite", p.name)
        assertEquals("+234 90 1400 0001", p.phone)
        assertEquals("Mo-Su 09:00-21:00", p.openingHours!!.text)
        assertEquals("listed", p.openingHours!!.source)
    }

    @Test
    fun route() = runTest {
        answer(fixture("routes_drive"))
        val res = client.route(
            origin = NWaysLatLng(6.4474, 3.472).asWaypoint(),
            destination = Waypoint.Postcode("LA08A09DB10"),
            mode = TravelMode.DRIVE,
            intermediates = listOf(Waypoint.GhanaPost("GA-183-8164"), Waypoint.PlusCode("6FR5CFWC+XR6")),
            routingPreference = RoutingPreference.TRAFFIC_AWARE,
            avoid = listOf(Avoid.TOLLS),
            fares = true,
        )
        val req = server.takeRequest()
        assertEquals("POST", req.method)
        assertEquals("/maps/v1/routes/compute", req.path)
        val body = req.bodyJson()
        assertEquals(6.4474, body["origin"]!!.jsonObject["lat"]!!.jsonPrimitive.double, 0.0)
        assertEquals("LA08A09DB10", body["destination"]!!.jsonObject["postcode"]!!.jsonPrimitive.content)
        val mids = body["intermediates"]!!.jsonArray
        assertEquals("GA-183-8164", mids[0].jsonObject["ghanaPost"]!!.jsonPrimitive.content)
        assertEquals("6FR5CFWC+XR6", mids[1].jsonObject["plusCode"]!!.jsonPrimitive.content)
        assertEquals("drive", body["mode"]!!.jsonPrimitive.content)
        assertEquals("traffic_aware", body["routingPreference"]!!.jsonPrimitive.content)
        assertEquals("tolls", body["avoid"]!!.jsonArray[0].jsonPrimitive.content)
        assertTrue(body["fares"]!!.jsonPrimitive.boolean)
        assertNull(body["alternatives"])

        assertEquals("drive", res.mode)
        val r = res.routes.single()
        assertEquals(1395.0, r.distanceM, 0.0)
        assertEquals(228.0, r.durationS, 0.0)
        assertEquals("estimated", r.speedSource)
        assertEquals(16, r.geometry.size)
        assertEquals(NWaysLatLng(6.4474, 3.472352), r.geometry.first())
        assertEquals(NWaysLatLng(6.444003, 3.479797), r.geometry.last())
        assertEquals(6, r.steps.size)
        assertEquals("depart_left", r.steps[0].maneuver)
        assertEquals(listOf("Victoria Arobieke Street"), r.steps[0].streetNames)
        assertEquals(1, r.legs.size)
        assertEquals("LA08A09DB10", res.waypoints[1].postcode)
    }

    @Test
    fun matrix() = runTest {
        answer(fixture("matrix"))
        val m = client.matrix(
            origins = listOf(Waypoint.Location(6.4474, 3.472), Waypoint.Postcode("LA08A09DB09")),
            destinations = listOf(Waypoint.Location(6.43, 3.42), Waypoint.Location(6.45, 3.4), Waypoint.Location(6.6, 3.35)),
        )
        val req = server.takeRequest()
        assertEquals("/maps/v1/routes/matrix", req.path)
        val body = req.bodyJson()
        assertEquals(2, body["origins"]!!.jsonArray.size)
        assertEquals(3, body["destinations"]!!.jsonArray.size)
        assertEquals("drive", body["mode"]!!.jsonPrimitive.content)
        assertEquals(6, m.elements.size)
        val e = m.element(1, 2)!!
        assertTrue(e.isOk)
        assertEquals(2820.0, e.durationS!!, 0.0)
        assertEquals(28195.0, e.distanceM!!, 0.0)
        assertEquals(NWaysLatLng(6.6, 3.35), m.destinations[2])
    }

    @Test
    fun fares() = runTest {
        answer(fixture("fares"))
        val f = client.fares(NWaysLatLng(6.4474, 3.472), NWaysLatLng(6.6018, 3.3515), modes = listOf("taxi", "okada"), at = "2026-10-15T08:30:00+01:00")
        val req = server.takeRequest()
        assertEquals("/maps/v1/fares/estimate", req.requestUrl!!.encodedPath)
        assertEquals("6.4474,3.472", req.q("from"))
        assertEquals("6.6018,3.3515", req.q("to"))
        assertEquals("taxi,okada", req.q("mode"))
        assertEquals("2026-10-15T08:30:00+01:00", req.q("at"))
        assertEquals("NGN", f.currency)
        assertEquals("NG-LA", f.region)
        assertEquals(4, f.estimates.size)
        val taxi = f.estimates[0]
        assertEquals("taxi", taxi.mode)
        assertEquals("₦8,150–15,200", taxi.text)
        assertTrue(taxi.charter)
        assertEquals("guide", taxi.basis)
        assertEquals(7750.0, taxi.raw["openingOffer"]!!.jsonPrimitive.double, 0.0)
        assertEquals("okada", f.notAllowed.single().mode)
        assertNotNull(f.notAllowed.single().raw["ban"])
    }

    @Test
    fun errorEnvelopeIsThrown() = runTest {
        answer(fixture("postcode_invalid"), 400)
        try {
            client.postcode("nope")
            fail("expected NWaysError")
        } catch (e: NWaysError) {
            assertEquals(400, e.httpStatus)
            assertEquals("INVALID_ARGUMENT", e.status)
            assertEquals("POSTCODE_INVALID", e.reason)
            assertTrue(e.message!!.startsWith("That isn't a NIPOST postcode"))
            assertFalse(e.isRetryable)
        }
    }

    @Test
    fun quotaErrorHonoursRetryAfter() = runTest {
        server.enqueue(
            MockResponse().setResponseCode(429).setHeader("Retry-After", "60")
                .setBody("""{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","reason":"QUOTA_EXCEEDED","message":"Daily quota used."}}"""),
        )
        try {
            client.geocode("Ikeja")
            fail("expected NWaysError")
        } catch (e: NWaysError) {
            assertEquals(429, e.httpStatus)
            assertEquals("QUOTA_EXCEEDED", e.reason)
            assertEquals(60L, e.retryAfterSeconds)
            assertTrue(e.isRetryable)
        }
    }

    @Test
    fun relayedRouteErrorIsThrown() = runTest {
        answer("""{"error":{"code":422,"status":"FAILED_PRECONDITION","reason":"NO_ROUTE","message":"No route."}}""", 422)
        try {
            client.route(Waypoint.Location(6.0, 3.0), Waypoint.Location(6.1, 3.1))
            fail("expected NWaysError")
        } catch (e: NWaysError) {
            assertEquals(422, e.httpStatus)
            assertEquals("NO_ROUTE", e.reason)
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
