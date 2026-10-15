package ng.nways.maps

/**
 * Every REST path the SDK calls, in one place.
 *
 * TODO(maps/v1): the partner endpoints are moving under `/maps/v1/...` (being built in
 * backend/internal/httpapi right now). When they answer, change these paths here — and in
 * the iOS SDK's `NWaysPaths` — and nowhere else. Don't guess the new paths before then.
 */
public object NWaysPaths {
    public const val GEOCODE: String = "v1/geocode"
    public const val REVERSE: String = "v1/reverse"
    public const val POSTCODES: String = "v1/postcodes" // + /{code}
    public const val PLACES: String = "v1/places"
    public const val ROUTES: String = "v1/routes"
    public const val FARES_ESTIMATE: String = "v1/fares/estimate"
}
