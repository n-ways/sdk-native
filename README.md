# N-Ways Maps — native SDKs (Android and iOS)

Thin wrappers on [MapLibre Native](https://maplibre.org) that show N-Ways' maps of Nigeria, Ghana, Benin and Togo,
send your API key and app identity with every request to N-Ways (and to nowhere else), keep the
"© N-Ways · © OpenStreetMap contributors · Protomaps" credit on the map, and call the N-Ways REST APIs
(the stable partner API at `/maps/v1`: geocoding, reverse geocoding, NIPOST postcodes, GhanaPost GPS
addresses, autocomplete, address validation, places, routes, route matrices and fares).

**Status: 1.0.1.** iOS: a public Swift package (this repository, tag `1.0.1`). Android: built by
[JitPack](https://jitpack.io/#n-ways/sdk-native) from the tag (`com.github.n-ways:sdk-native:1.0.1`);
Maven Central (`ng.nways:maps`) follows once the namespace is verified. Every path the SDKs call is in one table, `NWaysPaths`, in each SDK. The partner API
answers only while the owners' partner switch is on; until then every call is refused as an invalid key (401).

| | Android | iOS |
|---|---|---|
| Package | `com.github.n-ways:sdk-native:1.0.1` on JitPack (`ng.nways:maps:1.0.1` from source; module `android/nways-maps`) | Swift package `NWaysMaps` (this repo's root) |
| MapLibre | `org.maplibre.gl:android-sdk:11.13.5` | `maplibre-gl-native-distribution` 6.31.0 |
| Minimum | Android 6.0 (API 23) | iOS 15 |
| Identity headers | `X-Android-Package`, `X-Android-Cert` (SHA-1) | `X-Ios-Bundle-Identifier` |

Restrict your key to your app in the N-Ways console: Android package name + the SHA-1 of the certificate the
store signs with, or the iOS bundle ID.

## Android

In your app:

```kotlin
repositories { google(); mavenCentral(); maven("https://jitpack.io") }
dependencies { implementation("com.github.n-ways:sdk-native:1.0.1") }
```

(From source instead: `cd android && ./gradlew :nways-maps:publishToMavenLocal`, then `repositories { mavenLocal() }`
and `implementation("ng.nways:maps:1.0.1")`.)

Use:

```kotlin
// Application.onCreate (or before the first MapView)
NWaysMaps.init(this, apiKey = "YOUR_API_KEY")

// A MapView over Lagos
val mapView = MapView(context, NWaysMapDefaults.mapOptions(context))
mapView.getMapAsync { map -> map.setNWaysStyle(Theme.LIGHT, lang = "en") { style -> /* layers… */ } }

// REST (suspend; throws NWaysError)
val found = NWaysMaps.client.geocode("Allen Avenue", near = NWaysLatLng(6.6018, 3.3515), limit = 5)
val trip = NWaysMaps.client.route(
    origin = NWaysLatLng(6.6018, 3.3515).asWaypoint(),
    destination = Waypoint.Postcode("LA08A09DB09"), // routes to the building's best entrance
    mode = TravelMode.OKADA,
)
val best = trip.routes.first() // distanceM, durationS, geometry: List<NWaysLatLng>, steps
```

Sample app: `android/sample`. Put your key in `android/local.properties` (never committed):
`nways.apiKey=…` (optional `nways.baseUrl=…`), then `./gradlew :sample:installDebug`.

Build and test: `cd android && ./gradlew :nways-maps:testDebugUnitTest :nways-maps:assembleRelease :sample:assembleDebug`
(JDK 17+; `sdk.dir` in `local.properties`).

## iOS

In Xcode, *File → Add Package Dependencies…* and enter `https://github.com/n-ways/sdk-native` (from 1.0.1); or in a
Package.swift: `.package(url: "https://github.com/n-ways/sdk-native", from: "1.0.1")` with the product `NWaysMaps`.
`import NWaysMaps` also gives you MapLibre's types.

```swift
import NWaysMaps

// At launch
NWaysMaps.configure(apiKey: "YOUR_API_KEY")

// SwiftUI
NWaysMapView(theme: .light, lang: "en") { mapView in /* keep it to add pins */ }

// UIKit
let map = NWaysUIMapView(frame: view.bounds, theme: .dark)

// REST (async; throws NWaysError)
let found = try await NWaysMaps.client.geocode("Allen Avenue", near: NWaysLatLng(lat: 6.6018, lng: 3.3515), limit: 5)
let trip = try await NWaysMaps.client.route(origin: .at(lat: 6.6018, lng: 3.3515),
                                            destination: .postcode("LA08A09DB09"), mode: .okada)
let best = trip.routes.first // distanceM, durationS, geometry: [NWaysLatLng], steps
```

Sample app: `Examples/ios/NWaysSample/NWaysSample.xcodeproj`. Put your key in
`Examples/ios/NWaysSample/Secrets.xcconfig` (git-ignored): `NWAYS_API_KEY = …`.

Build and test (iOS Simulator):

```sh
xcodebuild test -scheme NWaysMaps -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath ../.bin/ios-derived-sdk
xcodebuild build -project Examples/ios/NWaysSample/NWaysSample.xcodeproj -scheme NWaysSample \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath ../.bin/ios-derived-sdk
```

`swift test` on macOS doesn't work: MapLibre's binary is iOS-only.

## REST methods (both SDKs)

| Method | Endpoint |
|---|---|
| `geocode` | `GET /maps/v1/geocode` (q, near, country, limit, lang, fields) |
| `reverse` | `GET /maps/v1/reverse` (lat, lng, radius, lang) |
| `postcode` | `GET /maps/v1/postcodes/{code}` |
| `ghanaPost` | `GET /maps/v1/ghanapost/{code}` |
| `autocomplete` | `GET /maps/v1/autocomplete` (q, session, near, types, country, limit, lang) |
| `validateAddress` | `POST /maps/v1/addresses/validate` |
| `placesNearby` | `GET /maps/v1/places/nearby` (lat, lng, category, q, radius, limit, pageToken, fields) |
| `place` | `GET /maps/v1/places/{id}` |
| `route` | `POST /maps/v1/routes/compute` (waypoints: location, NIPOST postcode, GhanaPost, Plus Code) |
| `matrix` | `POST /maps/v1/routes/matrix` |
| `fares` | `GET /maps/v1/fares/estimate` (from, to, mode, at) |

The API sends GeoJSON (`[lng, lat]`); the models turn locations and lines into `NWaysLatLng`. Every model keeps the
whole JSON object in `raw`, so fields added later are still there.

## Errors

Both SDKs throw `NWaysError` with `httpStatus` (0 for a network failure), and from the partner error envelope
`status` (`INVALID_ARGUMENT`, `PERMISSION_DENIED`, `RESOURCE_EXHAUSTED`…) and `reason` (`API_KEY_SERVICE_BLOCKED`,
`NO_ROUTE`, `POSTCODE_INVALID`, `QUOTA_EXCEEDED`…), plus `message` and the `Retry-After` wait. (`code` is only set by
the older `{"error":"…","code":"…"}` shape.) Retry only when `isRetryable` (429, 5xx, network).

## Licence

Both SDKs are licensed under the [Apache License, Version 2.0](LICENSE) (`Apache-2.0`), Copyright 2026 N-WAYS
LIMITED; see [NOTICE](NOTICE) for the third-party libraries they depend on (MapLibre Native under BSD 2-Clause, OkHttp
and kotlinx under Apache 2.0).

The licence covers the code, not the maps and data it loads. N-Ways maps and data are built on OpenStreetMap,
© OpenStreetMap contributors, available under the [Open Database License (ODbL)](https://www.openstreetmap.org/copyright),
and keep that credit wherever they are shown (the SDKs keep it on the map). Calling the N-Ways APIs needs an API key
and is governed by the [N-Ways Maps Platform terms](https://nways.ng/developers/terms).
