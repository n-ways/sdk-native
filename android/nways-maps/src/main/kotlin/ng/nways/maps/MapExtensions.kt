// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
package ng.nways.maps

import android.content.Context
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.Style
import org.maplibre.android.style.sources.TileSet
import org.maplibre.android.style.sources.VectorSource

/** Where N-Ways maps start, and how far they go. */
public object NWaysMapDefaults {
    /** Lagos. */
    public const val CENTER_LAT: Double = 6.5244
    public const val CENTER_LNG: Double = 3.3792
    public const val ZOOM: Double = 11.0

    /** Every country N-Ways covers, Cabo Verde to Cameroon and Gabon, with room around them. */
    public const val WEST: Double = -27.0
    public const val SOUTH: Double = -5.5
    public const val EAST: Double = 17.5
    public const val NORTH: Double = 18.5

    @JvmStatic
    public val center: LatLng get() = LatLng(CENTER_LAT, CENTER_LNG)

    @JvmStatic
    public val bounds: LatLngBounds get() = LatLngBounds.from(NORTH, EAST, SOUTH, WEST)

    @JvmStatic
    public val camera: CameraPosition get() = CameraPosition.Builder().target(center).zoom(ZOOM).build()

    /** Map options for a `MapView(context, options)`: Lagos, attribution and logo on. */
    @JvmStatic
    public fun mapOptions(context: Context): MapLibreMapOptions =
        MapLibreMapOptions.createFromAttributes(context)
            .camera(camera)
            .attributionEnabled(true)
            .logoEnabled(true)
}

/** Source id of the empty source that carries the N-Ways credit. */
public const val NWAYS_ATTRIBUTION_SOURCE_ID: String = "nways-attribution"

/**
 * Shows N-Ways' map: sets the style for [theme] and [lang], keeps the camera over West
 * Africa and the attribution button on, and adds the N-Ways credit even if the style
 * lacks it. [NWaysMaps.init] must have been called.
 */
@JvmOverloads
public fun MapLibreMap.setNWaysStyle(
    theme: Theme = Theme.LIGHT,
    lang: String = "en",
    onLoaded: ((Style) -> Unit)? = null,
) {
    uiSettings.isAttributionEnabled = true
    setLatLngBoundsForCameraTarget(NWaysMapDefaults.bounds)
    setStyle(Style.Builder().fromUri(NWaysMaps.styleUrl(theme, lang))) { style ->
        style.addNWaysAttribution()
        onLoaded?.invoke(style)
    }
}

/**
 * Adds an empty source whose attribution is [NWaysMaps.ATTRIBUTION_HTML], so MapLibre's
 * attribution lists N-Ways, OpenStreetMap and Protomaps. No layer uses it, so it loads nothing.
 */
public fun Style.addNWaysAttribution() {
    if (getSource(NWAYS_ATTRIBUTION_SOURCE_ID) != null) return
    val base = NWaysMaps.config.baseUrl.toString().trimEnd('/')
    val tiles = TileSet("2.2.0", "$base/maps/v1/attribution/{z}/{x}/{y}.pbf").apply {
        attribution = NWaysMaps.ATTRIBUTION_HTML
        minZoom = 0f
        maxZoom = 0f
    }
    addSource(VectorSource(NWAYS_ATTRIBUTION_SOURCE_ID, tiles))
}
