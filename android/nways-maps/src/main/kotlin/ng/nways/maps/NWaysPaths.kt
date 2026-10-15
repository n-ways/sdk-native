package ng.nways.maps

/**
 * Every path the SDK calls on the N-Ways Maps Platform's stable partner API (`/maps/v1`),
 * in one place. Kept in step with the iOS SDK's `NWaysPaths`.
 */
public object NWaysPaths {
    public const val STYLES: String = "maps/v1/styles" // + /{styleId}.json
    public const val GEOCODE: String = "maps/v1/geocode"
    public const val REVERSE: String = "maps/v1/reverse"
    public const val POSTCODES: String = "maps/v1/postcodes" // + /{code}
    public const val GHANAPOST: String = "maps/v1/ghanapost" // + /{code}
    public const val AUTOCOMPLETE: String = "maps/v1/autocomplete"
    public const val ADDRESSES_VALIDATE: String = "maps/v1/addresses/validate"
    public const val PLACES_NEARBY: String = "maps/v1/places/nearby"
    public const val PLACES: String = "maps/v1/places" // + /{id}
    public const val ROUTES_COMPUTE: String = "maps/v1/routes/compute"
    public const val ROUTES_MATRIX: String = "maps/v1/routes/matrix"
    public const val FARES_ESTIMATE: String = "maps/v1/fares/estimate"
}
