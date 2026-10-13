import SwiftUI

/// The full Battery History screen for the Athr+ iOS app.
/// Presents time-range filtering, interactive Swift Charts visualization,
/// summary battery statistics, and detailed charging session breakdowns.
public struct BatteryHistoryView: View {

    // MARK: - Properties

    @StateObject private var viewModel = BatteryHistoryViewModel()
    public var vehicleId: String?

    // MARK: - Initializer

    public init(vehicleId: String? = nil) {
        self.vehicleId = vehicleId
    }

    // MARK: - Computed Properties

    private var effectiveVehicleId: String {
        if let vehicleId = vehicleId, !vehicleId.isEmpty {
            return vehicleId
        }
        if let storedId = Preferences.shared.selectedVehicleId, !storedId.isEmpty {
            return storedId
        }
        return "primary_vehicle"
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.samples.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.samples.isEmpty {
                    errorView(error: error)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Battery History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadHistory(vehicleId: effectiveVehicleId)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.loadHistory(vehicleId: effectiveVehicleId)
            }
            .refreshable {
                await viewModel.loadHistory(vehicleId: effectiveVehicleId)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Segmented Picker
                timeRangePicker

                // Interactive Battery Swift Charts View
                BatteryChartView(viewModel: viewModel)

                // Summary Stats Grid
                summaryStatsSection

                // Charging Sessions List Section
                chargingSessionsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.timeRange) {
            ForEach(BatteryHistoryViewModel.TimeRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.timeRange) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                viewModel.selectedSample = nil
            }
        }
    }

    // MARK: - Summary Stats Section

    private var summaryStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Current Battery %
                statCard(
                    title: "Current Level",
                    value: viewModel.currentPercentage.map { "\($0)%" } ?? "—",
                    subtitle: "Latest reading",
                    systemImage: "battery.100.bolt",
                    accentColor: Color.batteryColor(for: viewModel.currentPercentage ?? 0)
                )

                // Lowest % in Period
                statCard(
                    title: "Lowest Level",
                    value: "\(viewModel.minPercentage)%",
                    subtitle: "Min in \(viewModel.timeRange.displayName)",
                    systemImage: "arrow.down.circle.fill",
                    accentColor: .orange
                )

                // Highest % in Period
                statCard(
                    title: "Highest Level",
                    value: "\(viewModel.maxPercentage)%",
                    subtitle: "Max in \(viewModel.timeRange.displayName)",
                    systemImage: "arrow.up.circle.fill",
                    accentColor: .green
                )

                // Total Charging Sessions
                statCard(
                    title: "Sessions",
                    value: "\(viewModel.totalChargingSessionsCount)",
                    subtitle: viewModel.totalChargingSessionsCount == 1 ? "Session" : "Sessions",
                    systemImage: "bolt.circle.fill",
                    accentColor: .yellow
                )
            }

            // Time Spent Charging Card (Full Width)
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Time Charging")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.formattedTotalChargingTime)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Window")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.timeRange.fullTitle)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
    }

    private func statCard(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(.primary)

                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: - Charging Sessions List Section

    private var chargingSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Charging Sessions")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(viewModel.chargingSessions.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
            }

            if viewModel.chargingSessions.isEmpty {
                emptySessionsCard
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.chargingSessions.reversed().enumerated()), id: \.element.id) { index, session in
                        chargingSessionRow(session: session)

                        if index < viewModel.chargingSessions.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1.5)
            }
        }
    }

    private var emptySessionsCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("No Charging Activity")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text("No charging sessions occurred in the past \(viewModel.timeRange.displayName).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chargingSessionRow(session: ChargingSession) -> some View {
        HStack(spacing: 14) {
            // Left Icon Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.yellow.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }

            // Middle: Time and Duration
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.formattedDate)
                        .font(.caption.bold())
                        .foregroundColor(.primary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(session.formattedTimeRange)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(session.formattedDuration)
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())

                    Text("\(session.startPercentage)% → \(session.endPercentage)%")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Right: % Gained
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(session.percentageGained)%")
                    .font(.callout.weight(.heavy).monospacedDigit())
                    .foregroundColor(.green)

                Text("gained")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading battery history...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)

            Text("Unable to Load History")
                .font(.headline)
                .foregroundColor(.primary)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.loadHistory(vehicleId: effectiveVehicleId)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.green)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Previews

struct BatteryHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BatteryHistoryView()
                .preferredColorScheme(.light)

            BatteryHistoryView()
                .preferredColorScheme(.dark)
        }
    }
}
