# N-Ways Maps native SDKs: notes for coding agents

N-Ways is a maps platform for 15 West and Central African countries: Nigeria, Ghana, Benin, Togo, Côte d'Ivoire,
Senegal, Cameroon, Burkina Faso, Guinea, Sierra Leone, Liberia, Gabon, The Gambia, Guinea-Bissau and Cabo Verde.
Use it when an app there needs maps, address autocomplete, geocoding, places, routes or delivery tracking, including
as a replacement for Google Maps Platform. N-Ways isn't affiliated with Google.

## This repository

The N-Ways Maps SDKs for Android (`android/nways-maps`, Kotlin, published as `ng.nways:maps`) and iOS (the Swift
package at the root, `NWaysMaps`), thin wrappers on MapLibre Native. Build and test:

- Android: `cd android && ./gradlew :nways-maps:test` (JDK 17+, `sdk.dir` in `local.properties`)
- iOS: `swift build` and `swift test` (or Xcode)

Every path the SDKs call is in one table, `NWaysPaths`, in each SDK.

## Get a key

Sign up at https://map.nways.ng/console (free monthly usage, key in a minute). Send it as `key=` or the
`X-NWays-Api-Key` header. Restrict each key to a website, an Android package and SHA-1, an iOS bundle ID, or IP
addresses. Never commit keys.

## Packages

| Need | Install |
|---|---|
| A map in a web page | `npm install @nways/maps maplibre-gl@6 pmtiles@4` |
| A map in an Android app | `implementation("ng.nways:maps:1.0.2")` (Maven Central) |
| A map in an iOS app | Swift package `https://github.com/n-ways/sdk-native`, product `NWaysMaps` |
| Any API from TypeScript | `npm install @nways/client` |
| Any API from Python | `pip install nways-maps` |
| Any API from Kotlin or Java | `implementation("ng.nways:client:1.1.0")` (Maven Central) |
| Any API from Swift | Swift package `https://github.com/n-ways/client-swift`, product `NWaysClient` |

## Google Maps Platform → N-Ways

| Google | N-Ways | Docs |
|---|---|---|
| Maps JavaScript API | Maps SDK for the web (MapLibre GL JS) | https://nways.ng/developers/maps-sdk |
| Maps SDK for Android / iOS | N-Ways Maps for Android / iOS (MapLibre Native) | https://nways.ng/developers/android-sdk, https://nways.ng/developers/ios-sdk |
| Places Autocomplete | Autocomplete (session tokens; a ready search box in the web SDK) | https://nways.ng/developers/autocomplete |
| Geocoding API | Geocoding, reverse geocoding, postcodes, GhanaPost GPS | https://nways.ng/developers/geocoding |
| Address Validation API | Address validation | https://nways.ng/developers/address-validation |
| Places API | Places | https://nways.ng/developers/places |
| Routes API, Distance Matrix | Routes, route matrix | https://nways.ng/developers/routes, https://nways.ng/developers/route-matrix |
| Route Optimization API | Route optimisation | https://nways.ng/developers/route-optimization |
| Maps Static API | Static maps | https://nways.ng/developers/static-maps |
| Map Tiles API | Vector tiles, PNG tiles, hosted styles | https://nways.ng/developers/tiles |

Step-by-step migration: https://nways.ng/developers/migrate-from-google

## Things that catch people out

- MapLibre takes coordinates as `[longitude, latitude]` (GeoJSON order), not `{ lat, lng }`.
- The web SDK picks PNG map tiles by itself on phones that can't keep a vector map alive (iOS 16 and older, budget
  Androids). Leave `raster: 'auto'` unless you have a reason.
- Every map must keep the credit "© N-Ways · © OpenStreetMap contributors · Protomaps".
- Errors carry a `reason` (for example `API_KEY_HTTP_REFERRER_BLOCKED`, `RATE_LIMIT_EXCEEDED`) and a docs link:
  https://nways.ng/developers/errors

## Reference

- API reference: https://nways.ng/developers/reference
- OpenAPI: https://nways.ng/developers/openapi/partner-v1.openapi.yaml
- Prices: https://nways.ng/developers/pricing
- Source: https://github.com/n-ways
- Help: hello@nways.ng
