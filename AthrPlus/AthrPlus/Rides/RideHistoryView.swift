//
//  RideHistoryView.swift
//  AthrPlus
//
//  Ride history view grouping rides by date with detailed telemetry rows and pull-to-refresh.
//

import SwiftUI

// MARK: - ViewModel

@MainActor
public final class RideHistoryViewModel: ObservableObject {
    @Published public var rides: [Ride] = []
    @Published public var isLoading: Bool = false
    @Published public var error: Error?

    public init(rides: [Ride] = []) {
        self.rides = rides
    }

    public func loadRides(vehicleId: String) async {
        guard !vehicleId.isEmpty else { return }

        isLoading = true
        error = nil

        do {
            let fetchedRides = try await AtherAPI.shared.getRides(vehicleId: vehicleId)
            self.rides = fetchedRides.sorted(by: { $0.startTime > $1.startTime })
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

// MARK: - RideHistoryView

public struct RideHistoryView: View {
    @StateObject private var viewModel = RideHistoryViewModel()
    public let vehicleId: String

    public init(vehicleId: String = Preferences.shared.selectedVehicleId ?? "") {
        self.vehicleId = vehicleId
    }

    // MARK: - Section Data Structure

    private struct DaySection: Identifiable {
        let id: Date
        let title: String
        let rides: [Ride]
    }

    private var sections: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.rides) { ride in
            calendar.startOfDay(for: Date(timeIntervalSince1970: ride.startTime))
        }

        let sortedKeys = grouped.keys.sorted(by: >)

        return sortedKeys.map { dayDate in
            DaySection(
                id: dayDate,
                title: sectionHeaderTitle(for: dayDate, calendar: calendar),
                rides: grouped[dayDate]?.sorted(by: { $0.startTime > $1.startTime }) ?? []
            )
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.rides.isEmpty {
                        ProgressView("Loading rides...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !viewModel.isLoading && viewModel.rides.isEmpty {
                        emptyStateView
                    } else {
                        ridesListView
                    }
                }
            }
            .navigationTitle("Rides")
            .refreshable {
                await viewModel.loadRides(vehicleId: vehicleId)
            }
            .task {
                if viewModel.rides.isEmpty {
                    await viewModel.loadRides(vehicleId: vehicleId)
                }
            }
        }
    }

    // MARK: - Rides List View

    private var ridesListView: some View {
        List {
            ForEach(sections) { section in
                Section(header: Text(section.title).font(.subheadline).fontWeight(.semibold)) {
                    ForEach(section.rides) { ride in
                        NavigationLink(destination: RideDetailView(ride: ride, vehicleId: vehicleId)) {
                            RideRowView(ride: ride)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.cardBackground)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemFill))
                    .frame(width: 80, height: 80)

                Image(systemName: "scooter")
                    .font(.system(size: 38))
                    .foregroundColor(Color(red: 0.0, green: 0.82, blue: 0.42))
            }

            VStack(spacing: 6) {
                Text("No rides yet")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Your completed rides and trip telemetry will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    await viewModel.loadRides(vehicleId: vehicleId)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Section Title Helper

    private func sectionHeaderTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - RideRowView

private struct RideRowView: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Date & Bold Distance
            HStack(alignment: .firstTextBaseline) {
                Text(formatRowDate(ride.startTime))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: "%.1f km", ride.distance))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            // Bottom Row: Duration, Battery Usage Indicator, Avg Speed
            HStack(spacing: 12) {
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatDuration(Int(ride.duration)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Battery Usage with colored indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.batteryColor(for: ride.endBattery))
                        .frame(width: 7, height: 7)

                    Text("\(ride.startBattery)% → \(ride.endBattery)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Average Speed
                HStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f km/h", ride.averageSpeed))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRowDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
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
