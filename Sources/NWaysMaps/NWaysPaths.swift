import Foundation

/// Every REST path the SDK calls, in one place.
///
/// TODO(maps/v1): the partner endpoints are moving under `/maps/v1/...` (being built in
/// backend/internal/httpapi right now). When they answer, change these paths here — and in
/// the Android SDK's `NWaysPaths` — and nowhere else. Don't guess the new paths before then.
public enum NWaysPaths {
    public static let geocode = "v1/geocode"
    public static let reverse = "v1/reverse"
    public static let postcodes = "v1/postcodes" // + /{code}
    public static let places = "v1/places"
    public static let routes = "v1/routes"
    public static let faresEstimate = "v1/fares/estimate"
}
