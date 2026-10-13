//
//  RideMapView.swift
//  AthrPlus
//
//  MapKit view displaying decoded ride routes with start/end markers and auto-zoom.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Polyline Decoder

/// Decodes a Google encoded polyline string into an array of 2D coordinates.
public func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
    guard !encoded.isEmpty else { return [] }

    var coordinates: [CLLocationCoordinate2D] = []
    let utf8 = encoded.utf8
    var index = utf8.startIndex
    var lat: Int = 0
    var lng: Int = 0

    while index < utf8.endIndex {
        // Decode latitude delta
        var byte: Int = 0
        var shift: Int = 0
        var result: Int = 0
        repeat {
            guard index < utf8.endIndex else { return coordinates }
            byte = Int(utf8[index]) - 63
            index = utf8.index(after: index)
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20
        let deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
        lat += deltaLat

        // Decode longitude delta
        shift = 0
        result = 0
        repeat {
            guard index < utf8.endIndex else { return coordinates }
            byte = Int(utf8[index]) - 63
            index = utf8.index(after: index)
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20
        let deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
        lng += deltaLng

        let latitude = Double(lat) / 100000.0
        let longitude = Double(lng) / 100000.0

        if (-90.0...90.0).contains(latitude) && (-180.0...180.0).contains(longitude) {
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }

    return coordinates
}

// MARK: - RideMKMapView Representable

public struct RideMKMapView: UIViewRepresentable {
    public let coordinates: [CLLocationCoordinate2D]
    public var edgePadding: UIEdgeInsets = UIEdgeInsets(top: 48, left: 48, bottom: 48, right: 48)

    public init(coordinates: [CLLocationCoordinate2D], edgePadding: UIEdgeInsets = UIEdgeInsets(top: 48, left: 48, bottom: 48, right: 48)) {
        self.coordinates = coordinates
        self.edgePadding = edgePadding
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    public func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)

        guard !coordinates.isEmpty else { return }

        // Polyline overlay
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.addOverlay(polyline)

        // Start pin (green)
        if let startCoord = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = startCoord
            startAnnotation.title = "Start"
            uiView.addAnnotation(startAnnotation)
        }

        // End pin (red)
        if coordinates.count > 1, let endCoord = coordinates.last {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = endCoord
            endAnnotation.title = "End"
            uiView.addAnnotation(endAnnotation)
        }

        // Auto-zoom to fit polyline
        if coordinates.count == 1 {
            let region = MKCoordinateRegion(
                center: coordinates[0],
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            uiView.setRegion(region, animated: false)
        } else {
            let mapRect = polyline.boundingMapRect
            if !mapRect.isNull && !mapRect.isEmpty {
                uiView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: false)
            }
        }
    }

    public final class Coordinator: NSObject, MKMapViewDelegate {
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // Ather Electric Green
                renderer.strokeColor = UIColor(red: 0.0, green: 0.82, blue: 0.42, alpha: 1.0)
                renderer.lineWidth = 4.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "RideEndpointMarker"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            marker.annotation = annotation
            marker.canShowCallout = true

            if annotation.title == "Start" {
                marker.markerTintColor = UIColor(red: 0.0, green: 0.82, blue: 0.42, alpha: 1.0)
                marker.glyphImage = UIImage(systemName: "flag.fill")
            } else if annotation.title == "End" {
                marker.markerTintColor = UIColor.systemRed
                marker.glyphImage = UIImage(systemName: "flag.checkered")
            }

            return marker
        }
    }
}

// MARK: - RideMapView

public struct RideMapView: View {
    public let polylineString: String?

    public init(polylineString: String?) {
        self.polylineString = polylineString
    }

    public init(routePolyline: String?) {
        self.polylineString = routePolyline
    }

    private var coordinates: [CLLocationCoordinate2D] {
        guard let polylineString = polylineString, !polylineString.isEmpty else {
            return []
        }
        return decodePolyline(polylineString)
    }

    public var body: some View {
        Group {
            if coordinates.isEmpty {
                RouteUnavailablePlaceholder()
            } else {
                RideMKMapView(coordinates: coordinates)
            }
        }
    }
}

// MARK: - Fallback Placeholder

private struct RouteUnavailablePlaceholder: View {
    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)

            VStack(spacing: 10) {
                Image(systemName: "map.slash")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.secondary)

                Text("Route not available")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("No GPS route data was recorded for this ride.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding()
        }
    }
}
