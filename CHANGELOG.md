# Changelog

## 1.0.0 — 2026-10-15 (not yet published)

First version of the N-Ways Maps native SDKs.

### Both platforms
- N-Ways map styles on MapLibre Native: `streets-light` / `streets-dark`, light/dark theme, `en` / `fr` labels,
  configurable base URL (default `https://nways.ng`).
- The API key (`X-NWays-Api-Key`), app identity and `X-NWays-Sdk` on every request to the N-Ways host — style,
  PMTiles, fonts, sprites, REST — and never to any other host, redirects included.
- Attribution "© N-Ways · © OpenStreetMap contributors · Protomaps" always on the map.
- Map defaults: Lagos (6.5244, 3.3792), zoom 11; camera kept over West Africa (lng −4.5…16.5, lat 2.5…15.5).
- REST client for the preview APIs: geocode, reverse, postcode, places, routes, fare estimate. Tolerant models
  with the raw JSON kept; `NWaysError` for the partner key envelope and the older `{error, code}` shape,
  with `Retry-After`.

### Android (`ng.nways:maps:1.0.0`)
- MapLibre Native Android 11.13.5. `X-Android-Package` and `X-Android-Cert` (SHA-1 of the signing certificate).
- `NWaysMaps.init`, `NWaysMaps.styleUrl`, `MapLibreMap.setNWaysStyle`, suspend REST client on OkHttp.

### iOS (Swift package `NWaysMaps`)
- MapLibre Native iOS 6.31.0. `X-Ios-Bundle-Identifier`.
- `NWaysMaps.configure`, `NWaysMaps.styleURL`, `NWaysMapView` (SwiftUI), `NWaysUIMapView` (UIKit),
  async/await REST client on URLSession.
