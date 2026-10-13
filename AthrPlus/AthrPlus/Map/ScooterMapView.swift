//
//  ScooterMapView.swift
//  AthrPlus
//
//  Full-screen map displaying the scooter's live location with re-centering,
//  Apple Maps navigation, and relative time updates.
//

import SwiftUI
import MapKit

// MARK: - Annotation Item

private struct ScooterMapPin: Identifiable {
    let id = "scooter_pin"
    let coordinate: CLLocationCoordinate2D
}

// MARK: - ScooterMapView

public struct ScooterMapView: View {
    public let vehicleId: String
    @State private var snapshot: VehicleSnapshot?
    @State private var region: MKCoordinateRegion
    @State private var isRefreshing: Bool = false
    @State private var hasInitializedRegion: Bool = false

    public init(
        vehicleId: String = Preferences.shared.selectedVehicleId ?? "",
        initialSnapshot: VehicleSnapshot? = nil
    ) {
        self.vehicleId = vehicleId
        let initialCoord = CLLocationCoordinate2D(
            latitude: initialSnapshot?.latitude ?? 0.0,
            longitude: initialSnapshot?.longitude ?? 0.0
        )
        self._snapshot = State(initialValue: initialSnapshot)
        self._region = State(
            initialValue: MKCoordinateRegion(
                center: initialCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
        )
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let s = snapshot else { return nil }
        guard isCoordinateValid(lat: s.latitude, lon: s.longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude)
    }

    private func isCoordinateValid(lat: Double, lon: Double) -> Bool {
        !(lat == 0.0 && lon == 0.0) && (-90.0...90.0).contains(lat) && (-180.0...180.0).contains(lon)
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if let coordinate = currentCoordinate {
                    // Full-screen Map with Scooter Annotation
                    Map(
                        coordinateRegion: $region,
                        showsUserLocation: true,
                        annotationItems: [ScooterMapPin(coordinate: coordinate)]
                    ) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            scooterAnnotationMarker
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)

                    // Bottom Floating Control Overlay
                    bottomCardOverlay(coordinate: coordinate)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                } else {
                    // Location Unavailable State
                    locationUnavailableView
                }
            }
            .navigationTitle("Scooter Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await refreshLocation()
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing || vehicleId.isEmpty)
                }
            }
            .task {
                if snapshot == nil {
                    snapshot = Preferences.shared.loadLastSnapshot()
                }
                if let coord = currentCoordinate, !hasInitializedRegion {
                    region.center = coord
                    hasInitializedRegion = true
                }
                await refreshLocation()
            }
        }
    }

    // MARK: - Scooter Annotation Marker

    private var scooterAnnotationMarker: some View {
        VStack(spacing: 0) {
            ZStack {
                // Pulse background ring
                Circle()
                    .fill(Color(red: 0.0, green: 0.82, blue: 0.42).opacity(0.22))
                    .frame(width: 54, height: 54)

                // Main circular marker
                Circle()
                    .fill(Color(red: 0.0, green: 0.82, blue: 0.42))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)

                // bolt.car.fill symbol
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Downward pointing pin tip
            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 8)
                .rotationEffect(.degrees(180))
                .foregroundColor(Color(red: 0.0, green: 0.82, blue: 0.42))
                .offset(y: -3)
        }
    }

    // MARK: - Bottom Floating Card Overlay

    private func bottomCardOverlay(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 14) {
            // Header: Status & Relative Time
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot?.isConnected == true ? Color(red: 0.0, green: 0.82, blue: 0.42) : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(snapshot?.isConnected == true ? "Connected" : "Parked")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    if let battery = snapshot?.batteryPercentage {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(battery)% Battery")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                if let date = snapshot?.lastUpdatedDate {
                    Text("Last updated: \(date.relativeTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                // Re-center on Scooter
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                        )
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Re-center")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemFill))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Open in Apple Maps
                Button {
                    openInAppleMaps(coordinate: coordinate)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Navigate")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.0, green: 0.82, blue: 0.42))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    // MARK: - Location Unavailable State

    private var locationUnavailableView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemFill))
                    .frame(width: 80, height: 80)

                Image(systemName: "location.slash.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 6) {
                Text("Location Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("GPS coordinates are unavailable or your scooter is currently offline.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    await refreshLocation()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.0, green: 0.82, blue: 0.42))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Helper Methods

    private func refreshLocation() async {
        guard !vehicleId.isEmpty else { return }
        isRefreshing = true

        do {
            let updated = try await AtherAPI.shared.getSnapshot(vehicleId: vehicleId)
            await MainActor.run {
                self.snapshot = updated
                if isCoordinateValid(lat: updated.latitude, lon: updated.longitude) {
                    let coord = CLLocationCoordinate2D(latitude: updated.latitude, longitude: updated.longitude)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        self.region.center = coord
                    }
                }
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }

    private func openInAppleMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "My Ather Scooter"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
