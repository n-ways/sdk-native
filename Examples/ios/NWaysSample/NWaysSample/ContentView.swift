// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import SwiftUI
import NWaysMaps

/// One screen: an N-Ways map of Lagos, a light/dark toggle, and a geocoding button.
struct ContentView: View {
    @State private var dark = false
    @State private var status = ""
    @State private var busy = false
    /// The map view, once made. A plain holder: it isn't view state.
    @State private var holder = MapHolder()

    var body: some View {
        ZStack(alignment: .top) {
            NWaysMapView(theme: dark ? .dark : .light, onMapCreated: { holder.map = $0 })
                .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack {
                    Button(dark ? "Light map" : "Dark map") { dark.toggle() }
                    Button("Geocode Allen Avenue") { Task { await geocodeAllenAvenue() } }
                        .disabled(busy)
                }
                .buttonStyle(.borderedProminent)

                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.top, 8)
        }
    }

    @MainActor
    private func geocodeAllenAvenue() async {
        busy = true
        defer { busy = false }
        do {
            let res = try await NWaysMaps.client.geocode("Allen Avenue", near: NWaysLatLng(lat: 6.6018, lng: 3.3515), limit: 1)
            guard let first = res.results.first, let loc = first.location else {
                status = "Nothing found"
                return
            }
            status = first.label
            guard let map = holder.map else { return }
            let pin = MLNPointAnnotation()
            pin.coordinate = loc.coordinate
            pin.title = first.name
            pin.subtitle = first.formattedAddress
            map.removeAnnotations(map.annotations ?? [])
            map.addAnnotation(pin)
            map.setCenter(loc.coordinate, zoomLevel: 15, animated: true)
        } catch let e as NWaysError {
            status = "\(e.reason ?? e.code ?? "HTTP \(e.httpStatus)"): \(e.message)"
        } catch {
            status = error.localizedDescription
        }
    }
}

final class MapHolder {
    weak var map: MLNMapView?
}
