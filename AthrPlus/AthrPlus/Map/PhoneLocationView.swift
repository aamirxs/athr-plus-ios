//
//  PhoneLocationView.swift
//  AthrPlus
//
//  Live phone location tracking with accuracy circle, telemetry overlays,
//  and user following / free scroll toggling.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - PhoneLocationManager

@MainActor
public final class PhoneLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var updateTimer: Timer?

    @Published public var currentLocation: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus
    @Published public var isFollowingUser: Bool = true

    override public init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1.0 // Every meter
    }

    public func startTracking() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        manager.startUpdatingLocation()

        // Ensure location updates every second while the view is active
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let loc = self.manager.location {
                    self.currentLocation = loc
                }
            }
        }
    }

    public func stopTracking() {
        updateTimer?.invalidate()
        updateTimer = nil
        manager.stopUpdatingLocation()
    }

    public func toggleFollowing() {
        isFollowingUser.toggle()
    }

    // MARK: - CLLocationManagerDelegate

    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = latest
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log or handle silent location lookup failures
    }
}

// MARK: - PhoneLiveMapView Representable

public struct PhoneLiveMapView: UIViewRepresentable {
    public let location: CLLocation?
    public let isFollowingUser: Bool
    public let onUserInteraction: () -> Void

    public init(
        location: CLLocation?,
        isFollowingUser: Bool,
        onUserInteraction: @escaping () -> Void
    ) {
        self.location = location
        self.isFollowingUser = isFollowingUser
        self.onUserInteraction = onUserInteraction
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onUserInteraction: onUserInteraction)
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll

        // Add pan gesture recognizer to detect manual user scroll
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        return mapView
    }

    public func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update accuracy overlay circle
        uiView.removeOverlays(uiView.overlays)

        guard let location = location else { return }

        // Add current accuracy circle
        let accuracyRadius = max(5.0, location.horizontalAccuracy)
        let circle = MKCircle(center: location.coordinate, radius: accuracyRadius)
        uiView.addOverlay(circle)

        // Center on user if following
        if isFollowingUser {
            let spanMeters = max(250.0, accuracyRadius * 4.0)
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: spanMeters,
                longitudinalMeters: spanMeters
            )
            uiView.setRegion(region, animated: true)
        }
    }

    public final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let onUserInteraction: () -> Void

        init(onUserInteraction: @escaping () -> Void) {
            self.onUserInteraction = onUserInteraction
        }

        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                onUserInteraction()
            }
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// MARK: - PhoneLocationView

public struct PhoneLocationView: View {
    @StateObject private var locationManager = PhoneLocationManager()

    public init() {}

    private var speedKmh: Double {
        guard let speed = locationManager.currentLocation?.speed, speed >= 0 else {
            return 0.0
        }
        return speed * 3.6
    }

    private var altitudeMeters: Double {
        locationManager.currentLocation?.altitude ?? 0.0
    }

    private var accuracyMeters: Double {
        guard let acc = locationManager.currentLocation?.horizontalAccuracy, acc >= 0 else {
            return 0.0
        }
        return acc
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Full Screen Map with User Location and Accuracy Circle
                PhoneLiveMapView(
                    location: locationManager.currentLocation,
                    isFollowingUser: locationManager.isFollowingUser,
                    onUserInteraction: {
                        if locationManager.isFollowingUser {
                            locationManager.isFollowingUser = false
                        }
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // Overlays
                VStack(spacing: 12) {
                    // Top Telemetry Stats (Speed, Altitude, Accuracy)
                    telemetryHeaderOverlay

                    Spacer()

                    // Bottom Floating Control and Coordinate Bar
                    bottomCoordinateBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

                // Permission Warning if Denied
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    permissionDeniedBanner
                }
            }
            .navigationTitle("Phone Location")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationManager.startTracking()
            }
            .onDisappear {
                locationManager.stopTracking()
            }
        }
    }

    // MARK: - Telemetry Header Overlay

    private var telemetryHeaderOverlay: some View {
        HStack(spacing: 10) {
            // Speed Display Overlay
            TelemetryPill(
                icon: "speedometer",
                iconColor: .blue,
                title: "Speed",
                value: String(format: "%.1f km/h", speedKmh)
            )

            // Altitude Display
            TelemetryPill(
                icon: "mountain.2.fill",
                iconColor: .purple,
                title: "Altitude",
                value: String(format: "%.0f m", altitudeMeters)
            )

            // Accuracy Display
            TelemetryPill(
                icon: "scope",
                iconColor: Color(red: 0.0, green: 0.82, blue: 0.42),
                title: "Accuracy",
                value: String(format: "±%.0f m", accuracyMeters)
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Bottom Coordinate & Follow Controls Bar

    private var bottomCoordinateBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                // Lat / Lon Formatted Display
                VStack(alignment: .leading, spacing: 3) {
                    Text("Coordinates")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    if let coord = locationManager.currentLocation?.coordinate {
                        Text(formatCoordinates(lat: coord.latitude, lon: coord.longitude))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    } else {
                        Text("Acquiring GPS fix...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Toggle Follow / Free Scroll Button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        locationManager.toggleFollowing()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: locationManager.isFollowingUser ? "location.fill" : "location")
                            .font(.system(size: 14, weight: .semibold))

                        Text(locationManager.isFollowingUser ? "Following" : "Free Scroll")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        locationManager.isFollowingUser
                            ? Color(red: 0.0, green: 0.82, blue: 0.42)
                            : Color(uiColor: .systemFill)
                    )
                    .foregroundColor(locationManager.isFollowingUser ? .white : .primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    // MARK: - Permission Denied Banner

    private var permissionDeniedBanner: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .font(.title2)
                .foregroundColor(.red)

            Text("Location Access Denied")
                .font(.headline)

            Text("Please enable location permissions in Settings to view your live GPS position.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsUrl)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(24)
    }

    // MARK: - Format Coordinate Helper

    private func formatCoordinates(lat: Double, lon: Double) -> String {
        let latSuffix = lat >= 0 ? "N" : "S"
        let lonSuffix = lon >= 0 ? "E" : "W"
        return String(format: "%.5f° %@, %.5f° %@", abs(lat), latSuffix, abs(lon), lonSuffix)
    }
}

// MARK: - Telemetry Pill View

private struct TelemetryPill: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
