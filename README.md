# N-Ways Maps — native SDKs (Android and iOS)

Thin wrappers on [MapLibre Native](https://maplibre.org) that show N-Ways' maps of Nigeria, Ghana, Benin and Togo,
send your API key and app identity with every request to N-Ways (and to nowhere else), keep the
"© N-Ways · © OpenStreetMap contributors · Protomaps" credit on the map, and call the N-Ways REST APIs
(geocoding, reverse geocoding, NIPOST postcodes, places, routes, fares).

**Status: 1.0.0, not yet published.** There is no Maven Central artifact, CocoaPod or public Swift package yet:
build from source as below. The REST APIs are in preview and their paths will move to `/maps/v1/...`
(see `NWaysPaths` in each SDK).

| | Android | iOS |
|---|---|---|
| Package | `ng.nways:maps:1.0.0` (module `android/nways-maps`) | Swift package `NWaysMaps` (this repo's root) |
| MapLibre | `org.maplibre.gl:android-sdk:11.13.5` | `maplibre-gl-native-distribution` 6.31.0 |
| Minimum | Android 6.0 (API 23) | iOS 15 |
| Identity headers | `X-Android-Package`, `X-Android-Cert` (SHA-1) | `X-Ios-Bundle-Identifier` |

Restrict your key to your app in the N-Ways console: Android package name + the SHA-1 of the certificate the
store signs with, or the iOS bundle ID.

## Android

Install from source: `cd android && ./gradlew :nways-maps:publishToMavenLocal`, then in your app:

```kotlin
repositories { mavenLocal() }
dependencies { implementation("ng.nways:maps:1.0.0") }
```

Use:

```kotlin
// Application.onCreate (or before the first MapView)
NWaysMaps.init(this, apiKey = "YOUR_API_KEY")

// A MapView over Lagos
val mapView = MapView(context, NWaysMapDefaults.mapOptions(context))
mapView.getMapAsync { map -> map.setNWaysStyle(Theme.LIGHT, lang = "en") { style -> /* layers… */ } }

// REST (suspend; throws NWaysError)
val found = NWaysMaps.client.geocode("Allen Avenue", limit = 5, near = NWaysLatLng(6.6018, 3.3515))
val route = NWaysMaps.client.routes(NWaysLatLng(6.6018, 3.3515), NWaysLatLng(6.4541, 3.3947), TravelMode.MOTORCYCLE)
```

Sample app: `android/sample`. Put your key in `android/local.properties` (never committed):
`nways.apiKey=…` (optional `nways.baseUrl=…`), then `./gradlew :sample:installDebug`.

Build and test: `cd android && ./gradlew :nways-maps:testDebugUnitTest :nways-maps:assembleRelease :sample:assembleDebug`
(JDK 17+; `sdk.dir` in `local.properties`).

## iOS

Install from source: in Xcode, *File → Add Package Dependencies… → Add Local…* and pick this folder
(or `.package(path: "…/sdk-native")` in a Package.swift). `import NWaysMaps` also gives you MapLibre's types.

```swift
import NWaysMaps

// At launch
NWaysMaps.configure(apiKey: "YOUR_API_KEY")

// SwiftUI
NWaysMapView(theme: .light, lang: "en") { mapView in /* keep it to add pins */ }

// UIKit
let map = NWaysUIMapView(frame: view.bounds, theme: .dark)

// REST (async; throws NWaysError)
let found = try await NWaysMaps.client.geocode("Allen Avenue", limit: 5, near: NWaysLatLng(lat: 6.6018, lng: 3.3515))
let route = try await NWaysMaps.client.routes(from: NWaysLatLng(lat: 6.6018, lng: 3.3515),
                                              to: NWaysLatLng(lat: 6.4541, lng: 3.3947), mode: .motorcycle)
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

## Errors

Both SDKs throw `NWaysError` with `httpStatus` (0 for a network failure), `status` and `reason` for key and quota
errors (`PERMISSION_DENIED` / `API_KEY_SERVICE_BLOCKED`…), `code` for API errors (`no_route`, `postcode_unknown`…),
`message`, and the `Retry-After` wait. Retry only when `isRetryable` (429, 5xx, network).

## Licence

UNLICENSED — all rights reserved, N-Ways. See `LICENSE`.
