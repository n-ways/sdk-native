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
- REST client for the stable partner API (`/maps/v1`): `geocode`, `reverse`, `postcode`, `ghanaPost`,
  `autocomplete` (session tokens), `validateAddress`, `placesNearby` (page tokens), `place`, `route`
  (origin/destination/intermediates as a location, NIPOST postcode, GhanaPost GPS address or Plus Code),
  `matrix` and `fares`. All paths in one table (`NWaysPaths`). Tolerant models with the raw JSON kept;
  GeoJSON locations and lines become `NWaysLatLng`.
- `NWaysError` from the partner error envelope (`status`, `reason`, `message`) with `Retry-After`; the older
  `{error, code}` shape is still read.

### Android (`ng.nways:maps:1.0.0`)
- MapLibre Native Android 11.13.5. `X-Android-Package` and `X-Android-Cert` (SHA-1 of the signing certificate).
- `NWaysMaps.init`, `NWaysMaps.styleUrl`, `MapLibreMap.setNWaysStyle`, suspend REST client on OkHttp; `Waypoint`, `TravelMode`, `RoutingPreference`, `Avoid`.

### iOS (Swift package `NWaysMaps`)
- MapLibre Native iOS 6.31.0. `X-Ios-Bundle-Identifier`.
- `NWaysMaps.configure`, `NWaysMaps.styleURL`, `NWaysMapView` (SwiftUI), `NWaysUIMapView` (UIKit),
  async/await REST client on URLSession; `NWaysWaypoint`, `NWaysTravelMode`, `NWaysRoutingPreference`, `NWaysAvoid`.
