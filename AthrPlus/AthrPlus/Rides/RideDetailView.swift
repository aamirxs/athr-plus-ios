//
//  RideDetailView.swift
//  AthrPlus
//
//  Detailed view for a single ride featuring route map, telemetry stats, and battery breakdown.
//

import SwiftUI
import MapKit

public struct RideDetailView: View {
    public let ride: Ride
    public let vehicleId: String

    @State private var detailedRide: RideDetail?
    @State private var isLoadingDetail: Bool = false
    @Environment(\.dismiss) private var dismiss

    public init(ride: Ride, vehicleId: String = "") {
        self.ride = ride
        self.vehicleId = vehicleId
    }

    private var activePolyline: String? {
        detailedRide?.routePolyline ?? ride.routePolyline
    }

    private var currentRide: Ride {
        detailedRide?.ride ?? ride
    }

    public var body: some View {
        GeometryReader { geometry in
            let mapHeight = max(260.0, geometry.size.height * 0.45)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Top Map (Half Screen)
                    ZStack(alignment: .topTrailing) {
                        RideMapView(polylineString: activePolyline)
                            .frame(height: mapHeight)

                        if isLoadingDetail {
                            ProgressView()
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(12)
                        }
                    }

                    // MARK: - Stats & Content
                    VStack(spacing: 16) {
                        // Date and Overview Header
                        headerCard

                        // Battery Indicator Section
                        batteryBarSection

                        // Telemetry Stats Grid
                        statsGridSection

                        // Timing Card
                        timeCardSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Rides")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .task {
            await loadDetailIfNeeded()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatHeaderDate(currentRide.startTime))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(formatTimeRange(start: currentRide.startTime, end: currentRide.endTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f km", currentRide.distance))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(formatDuration(Int(currentRide.duration)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Battery Indicator Bar

    private var batteryBarSection: some View {
        let start = min(100, max(0, currentRide.startBattery))
        let end = min(100, max(0, currentRide.endBattery))
        let used = max(0, start - end)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .foregroundColor(Color.batteryColor(for: end))
                    Text("Battery Usage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("-\(used)% used")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            // Continuous Visual Battery Bar
            GeometryReader { barGeo in
                let totalWidth = barGeo.size.width
                let remainingWidth = totalWidth * (CGFloat(end) / 100.0)
                let usedWidth = totalWidth * (CGFloat(used) / 100.0)

                ZStack(alignment: .leading) {
                    // Full capacity track (0 - 100%)
                    Capsule()
                        .fill(Color(uiColor: .systemFill))

                    // Remaining battery track (0 - endBattery%)
                    Capsule()
                        .fill(Color(uiColor: .tertiaryLabel))
                        .frame(width: remainingWidth)

                    // Green section highlighting battery used during ride (endBattery -> startBattery)
                    Capsule()
                        .fill(Color(red: 0.0, green: 0.82, blue: 0.42))
                        .frame(width: max(2, usedWidth))
                        .offset(x: remainingWidth)
                }
            }
            .frame(height: 14)

            // Labels under the bar
            HStack {
                Text("End: \(end)%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.0, green: 0.82, blue: 0.42))
                        .frame(width: 8, height: 8)
                    Text("Trip Drain: \(used)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Start: \(start)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Stats Grid Section

    private var statsGridSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        let usedBattery = max(0, currentRide.startBattery - currentRide.endBattery)

        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(
                icon: "location.north.line.fill",
                iconColor: .blue,
                title: "Distance",
                value: String(format: "%.1f km", currentRide.distance)
            )

            StatCard(
                icon: "clock.fill",
                iconColor: .orange,
                title: "Duration",
                value: formatDuration(Int(currentRide.duration))
            )

            StatCard(
                icon: "gauge.medium",
                iconColor: .teal,
                title: "Avg Speed",
                value: String(format: "%.1f km/h", currentRide.averageSpeed)
            )

            StatCard(
                icon: "speedometer",
                iconColor: .purple,
                title: "Top Speed",
                value: String(format: "%.1f km/h", currentRide.topSpeed)
            )

            StatCard(
                icon: "bolt.fill",
                iconColor: Color(red: 0.0, green: 0.82, blue: 0.42),
                title: "Battery Used",
                value: "\(usedBattery)%"
            )

            if let elevation = detailedRide?.elevationGain {
                StatCard(
                    icon: "arrow.up.right",
                    iconColor: .indigo,
                    title: "Elevation Gain",
                    value: String(format: "%.0f m", elevation)
                )
            } else if let lean = detailedRide?.maxLeanAngle {
                StatCard(
                    icon: "angle",
                    iconColor: .pink,
                    title: "Max Lean",
                    value: String(format: "%.1f°", lean)
                )
            } else {
                StatCard(
                    icon: "battery.100.bolt",
                    iconColor: .green,
                    title: "Start → End",
                    value: "\(currentRide.startBattery)% → \(currentRide.endBattery)%"
                )
            }
        }
    }

    // MARK: - Time Card Section

    private var timeCardSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.0, green: 0.82, blue: 0.42))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTimeOnly(currentRide.startTime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("End Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTimeOnly(currentRide.endTime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Helpers & Data Loading

    private func loadDetailIfNeeded() async {
        guard !vehicleId.isEmpty else { return }
        isLoadingDetail = true
        do {
            let detail = try await AtherAPI.shared.getRideDetail(vehicleId: vehicleId, rideId: ride.id)
            await MainActor.run {
                self.detailedRide = detail
                self.isLoadingDetail = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingDetail = false
            }
        }
    }

    private func formatHeaderDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func formatTimeRange(start: TimeInterval, end: TimeInterval) -> String {
        let s = formatTimeOnly(start)
        let e = formatTimeOnly(end)
        return "\(s) - \(e)"
    }

    private func formatTimeOnly(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(max(1, seconds))s"
        }
    }
}

// MARK: - StatCard View Component

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
