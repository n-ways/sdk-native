// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import Foundation
import SwiftUI
import UIKit
import MapLibre

/// Source id of the empty source that carries the N-Ways credit.
public let nwaysAttributionSourceID = "nways-attribution"

public extension MLNStyle {
    /// Adds an empty source whose attribution is ``NWaysMaps/attributionHTML``, so MapLibre's
    /// attribution lists N-Ways, OpenStreetMap and Protomaps even if the style lacks them.
    /// No layer uses it, so it loads nothing. Call it from `mapView(_:didFinishLoading:)`.
    func addNWaysAttribution() {
        guard source(withIdentifier: nwaysAttributionSourceID) == nil else { return }
        let base = (NWaysMaps.configuration?.baseURL ?? NWaysMaps.defaultBaseURL).absoluteString
        let source = MLNVectorTileSource(
            identifier: nwaysAttributionSourceID,
            tileURLTemplates: ["\(base)/maps/v1/attribution/{z}/{x}/{y}.pbf"],
            options: [
                .attributionHTMLString: NWaysMaps.attributionHTML,
                .minimumZoomLevel: 0,
                .maximumZoomLevel: 0,
            ]
        )
        addSource(source)
    }
}

public extension MLNMapView {
    /// Shows N-Ways' map: the style for `theme` and `lang`, the camera kept over West
    /// Africa, and the attribution button on. Add the credit with
    /// ``MapLibre/MLNStyle/addNWaysAttribution()`` when the style loads (``NWaysMapDelegate``
    /// and ``NWaysUIMapView`` do it for you).
    func setNWaysStyle(theme: NWaysTheme = .light, lang: String = "en") {
        showsAttributionButton = true
        maximumScreenBounds = NWaysMaps.westAfricaBounds
        styleURL = NWaysMaps.styleURL(theme: theme, lang: lang)
    }
}

/// A map view delegate that adds the N-Ways credit each time a style loads, then calls
/// ``onStyleLoaded``. Subclass it (call `super`) or set the closure.
open class NWaysMapDelegate: NSObject, MLNMapViewDelegate {
    public var onStyleLoaded: ((MLNMapView, MLNStyle) -> Void)?

    public init(onStyleLoaded: ((MLNMapView, MLNStyle) -> Void)? = nil) {
        self.onStyleLoaded = onStyleLoaded
    }

    open func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        style.addNWaysAttribution()
        onStyleLoaded?(mapView, style)
    }
}

/// UIKit: an `MLNMapView` showing N-Ways' map over Lagos, with the credit added on every
/// style load. If you set your own `delegate`, call `style.addNWaysAttribution()` in its
/// `mapView(_:didFinishLoading:)`, or subclass ``NWaysMapDelegate``.
open class NWaysUIMapView: MLNMapView {
    /// The delegate set at init; kept here because `MLNMapView.delegate` is weak.
    public let nwaysDelegate: NWaysMapDelegate

    public init(frame: CGRect, theme: NWaysTheme = .light, lang: String = "en",
                center: CLLocationCoordinate2D = NWaysMaps.defaultCenter, zoomLevel: Double = NWaysMaps.defaultZoom) {
        nwaysDelegate = NWaysMapDelegate()
        super.init(frame: frame, styleURL: NWaysMaps.styleURL(theme: theme, lang: lang))
        delegate = nwaysDelegate
        setNWaysStyle(theme: theme, lang: lang)
        setCenter(center, zoomLevel: zoomLevel, animated: false)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("Use init(frame:theme:lang:)")
    }
}

/// SwiftUI: N-Ways' map. Changing `theme` or `lang` reloads the style.
///
/// ```swift
/// NWaysMapView(theme: dark ? .dark : .light) { mapView in self.mapView = mapView }
/// ```
public struct NWaysMapView: UIViewRepresentable {
    public var theme: NWaysTheme
    public var lang: String
    public var center: CLLocationCoordinate2D
    public var zoomLevel: Double
    public var onMapCreated: ((MLNMapView) -> Void)?
    public var onStyleLoaded: ((MLNMapView, MLNStyle) -> Void)?

    public init(theme: NWaysTheme = .light, lang: String = "en",
                center: CLLocationCoordinate2D = NWaysMaps.defaultCenter, zoomLevel: Double = NWaysMaps.defaultZoom,
                onMapCreated: ((MLNMapView) -> Void)? = nil,
                onStyleLoaded: ((MLNMapView, MLNStyle) -> Void)? = nil) {
        self.theme = theme
        self.lang = lang
        self.center = center
        self.zoomLevel = zoomLevel
        self.onMapCreated = onMapCreated
        self.onStyleLoaded = onStyleLoaded
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: NWaysMaps.styleURL(theme: theme, lang: lang))
        map.delegate = context.coordinator.delegate
        map.setNWaysStyle(theme: theme, lang: lang)
        map.setCenter(center, zoomLevel: zoomLevel, animated: false)
        context.coordinator.styleKey = styleKey
        context.coordinator.delegate.onStyleLoaded = onStyleLoaded
        onMapCreated?(map)
        return map
    }

    public func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.delegate.onStyleLoaded = onStyleLoaded
        if context.coordinator.styleKey != styleKey {
            context.coordinator.styleKey = styleKey
            map.setNWaysStyle(theme: theme, lang: lang)
        }
    }

    private var styleKey: String { "\(theme.rawValue)/\(lang)" }

    public final class Coordinator {
        let delegate = NWaysMapDelegate()
        var styleKey = ""
    }
}
