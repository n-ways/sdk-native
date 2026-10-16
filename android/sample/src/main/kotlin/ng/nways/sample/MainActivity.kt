// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
package ng.nways.sample

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Toast
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import ng.nways.maps.NWaysError
import ng.nways.maps.NWaysLatLng
import ng.nways.maps.NWaysMapDefaults
import ng.nways.maps.NWaysMaps
import ng.nways.maps.Theme
import ng.nways.maps.setNWaysStyle
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.PropertyFactory.circleColor
import org.maplibre.android.style.layers.PropertyFactory.circleRadius
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeColor
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeWidth
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Point

/** One screen: an N-Ways map of Lagos, a light/dark toggle, and a geocoding button. */
class MainActivity : Activity() {
    private val scope = MainScope()
    private lateinit var mapView: MapView
    private var map: MapLibreMap? = null
    private var theme = Theme.LIGHT
    private var marker: LatLng? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NWaysMaps.init(this, BuildConfig.NWAYS_API_KEY, BuildConfig.NWAYS_BASE_URL)
        if (BuildConfig.NWAYS_API_KEY == "YOUR_API_KEY") {
            Toast.makeText(this, R.string.no_key, Toast.LENGTH_LONG).show()
        }

        mapView = MapView(this, NWaysMapDefaults.mapOptions(this))
        mapView.onCreate(savedInstanceState)
        mapView.getMapAsync { m ->
            map = m
            applyStyle()
        }

        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(Button(context).apply {
                setText(R.string.toggle_theme)
                setOnClickListener {
                    theme = if (theme == Theme.LIGHT) Theme.DARK else Theme.LIGHT
                    applyStyle()
                }
            })
            addView(Button(context).apply {
                setText(R.string.geocode_allen)
                setOnClickListener { geocodeAllenAvenue() }
            })
        }
        setContentView(FrameLayout(this).apply {
            addView(mapView)
            addView(
                buttons,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.TOP or Gravity.CENTER_HORIZONTAL,
                ).apply { topMargin = (48 * resources.displayMetrics.density).toInt() },
            )
        })
    }

    private fun applyStyle() {
        map?.setNWaysStyle(theme) { style -> marker?.let { showMarker(style, it) } }
    }

    private fun geocodeAllenAvenue() {
        scope.launch {
            try {
                val res = NWaysMaps.client.geocode("Allen Avenue", limit = 1, near = NWaysLatLng(6.6018, 3.3515))
                val loc = res.results.firstOrNull()?.location
                if (loc == null) {
                    Toast.makeText(this@MainActivity, R.string.no_results, Toast.LENGTH_SHORT).show()
                    return@launch
                }
                val at = LatLng(loc.lat, loc.lng)
                marker = at
                map?.style?.let { showMarker(it, at) }
                map?.animateCamera(CameraUpdateFactory.newLatLngZoom(at, 15.0))
                Toast.makeText(this@MainActivity, res.results.first().label, Toast.LENGTH_SHORT).show()
            } catch (e: NWaysError) {
                val why = e.reason ?: e.code ?: "HTTP ${e.httpStatus}"
                Toast.makeText(this@MainActivity, "$why: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }

    /** A circle layer instead of MapLibre's deprecated Marker API. */
    private fun showMarker(style: Style, at: LatLng) {
        val point = Point.fromLngLat(at.longitude, at.latitude)
        val source = style.getSourceAs<GeoJsonSource>(MARKER_ID)
        if (source != null) {
            source.setGeoJson(point)
            return
        }
        style.addSource(GeoJsonSource(MARKER_ID, point))
        style.addLayer(
            CircleLayer(MARKER_ID, MARKER_ID).withProperties(
                circleRadius(9f),
                circleColor("#0b7a3e"),
                circleStrokeColor("#ffffff"),
                circleStrokeWidth(3f),
            ),
        )
    }

    override fun onStart() { super.onStart(); mapView.onStart() }
    override fun onResume() { super.onResume(); mapView.onResume() }
    override fun onPause() { mapView.onPause(); super.onPause() }
    override fun onStop() { mapView.onStop(); super.onStop() }
    override fun onLowMemory() { super.onLowMemory(); mapView.onLowMemory() }
    override fun onSaveInstanceState(outState: Bundle) { super.onSaveInstanceState(outState); mapView.onSaveInstanceState(outState) }

    override fun onDestroy() {
        scope.cancel()
        mapView.onDestroy()
        super.onDestroy()
    }

    private companion object {
        const val MARKER_ID = "sample-marker"
    }
}
