import Foundation

/// Every path the SDK calls on the N-Ways Maps Platform's stable partner API (`/maps/v1`),
/// in one place. Kept in step with the Android SDK's `NWaysPaths`.
public enum NWaysPaths {
    public static let styles = "maps/v1/styles" // + /{styleID}.json
    public static let geocode = "maps/v1/geocode"
    public static let reverse = "maps/v1/reverse"
    public static let postcodes = "maps/v1/postcodes" // + /{code}
    public static let ghanaPost = "maps/v1/ghanapost" // + /{code}
    public static let autocomplete = "maps/v1/autocomplete"
    public static let addressesValidate = "maps/v1/addresses/validate"
    public static let placesNearby = "maps/v1/places/nearby"
    public static let places = "maps/v1/places" // + /{id}
    public static let routesCompute = "maps/v1/routes/compute"
    public static let routesMatrix = "maps/v1/routes/matrix"
    public static let faresEstimate = "maps/v1/fares/estimate"
}
