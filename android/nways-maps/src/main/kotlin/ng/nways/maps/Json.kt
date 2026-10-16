// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
package ng.nways.maps

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull

// Tolerant readers: a missing or differently-typed field is null, never an exception.

internal fun JsonObject.str(key: String): String? =
    (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

internal fun JsonObject.dbl(key: String): Double? = (this[key] as? JsonPrimitive)?.doubleOrNull

internal fun JsonObject.int(key: String): Int? =
    (this[key] as? JsonPrimitive)?.let { it.intOrNull ?: it.doubleOrNull?.toInt() }

internal fun JsonObject.bool(key: String): Boolean? = (this[key] as? JsonPrimitive)?.booleanOrNull

internal fun JsonObject.obj(key: String): JsonObject? = this[key] as? JsonObject

internal fun JsonObject.arr(key: String): JsonArray? = this[key] as? JsonArray

internal fun JsonObject.objects(key: String): List<JsonObject> = arr(key)?.filterIsInstance<JsonObject>().orEmpty()

internal fun JsonElement?.latLng(): NWaysLatLng? {
    val o = this as? JsonObject ?: return null
    val lat = o.dbl("lat") ?: return null
    val lng = o.dbl("lng") ?: o.dbl("lon") ?: return null
    return NWaysLatLng(lat, lng)
}

/** A `[lng, lat]` pair (GeoJSON order). */
internal fun JsonElement?.lngLatPair(): NWaysLatLng? {
    val a = this as? JsonArray ?: return null
    if (a.size < 2) return null
    val lng = (a[0] as? JsonPrimitive)?.doubleOrNull ?: return null
    val lat = (a[1] as? JsonPrimitive)?.doubleOrNull ?: return null
    return NWaysLatLng(lat, lng)
}

/** A GeoJSON Point (`{"type":"Point","coordinates":[lng,lat]}`), or a `{lat, lng}` object. */
internal fun JsonElement?.point(): NWaysLatLng? {
    val o = this as? JsonObject ?: return null
    return o["coordinates"].lngLatPair() ?: o.latLng()
}

/** A GeoJSON LineString's coordinates, as points in order. */
internal fun JsonElement?.line(): List<NWaysLatLng> {
    val o = this as? JsonObject ?: return emptyList()
    return o.arr("coordinates")?.mapNotNull { it.lngLatPair() }.orEmpty()
}

internal fun JsonObject.points(key: String): List<NWaysLatLng> = arr(key)?.mapNotNull { it.point() }.orEmpty()

internal fun JsonObject.strings(key: String): List<String> =
    arr(key)?.mapNotNull { (it as? JsonPrimitive)?.takeIf { p -> p.isString }?.content }.orEmpty()
