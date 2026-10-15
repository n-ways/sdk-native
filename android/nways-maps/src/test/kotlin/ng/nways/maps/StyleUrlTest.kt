package ng.nways.maps

import org.junit.Assert.assertEquals
import org.junit.Test

class StyleUrlTest {
    @Test
    fun defaultLightEnglish() {
        assertEquals(
            "https://nways.ng/maps/v1/styles/streets-light.json",
            NWaysMaps.buildStyleUrl(NWaysMaps.DEFAULT_BASE_URL, Theme.LIGHT.styleId),
        )
    }

    @Test
    fun darkFrench() {
        assertEquals(
            "https://nways.ng/maps/v1/styles/streets-dark.json?lang=fr",
            NWaysMaps.buildStyleUrl("https://nways.ng", Theme.DARK.styleId, "fr"),
        )
    }

    @Test
    fun langIsNormalised() {
        assertEquals(
            "https://nways.ng/maps/v1/styles/streets-light.json?lang=fr",
            NWaysMaps.buildStyleUrl("https://nways.ng", NWaysMaps.STYLE_STREETS_LIGHT, " FR "),
        )
    }

    @Test
    fun customBaseUrlWithPathAndTrailingSlash() {
        assertEquals(
            "https://maps.example.com/nways/maps/v1/styles/streets-light.json",
            NWaysMaps.buildStyleUrl("https://maps.example.com/nways/", NWaysMaps.STYLE_STREETS_LIGHT),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsBadLang() {
        NWaysMaps.buildStyleUrl("https://nways.ng", NWaysMaps.STYLE_STREETS_LIGHT, "fr&x=1")
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsBadStyleId() {
        NWaysMaps.buildStyleUrl("https://nways.ng", "../secret", "en")
    }

    @Test
    fun themesMapToStyleIds() {
        assertEquals("streets-light", Theme.LIGHT.styleId)
        assertEquals("streets-dark", Theme.DARK.styleId)
    }
}
