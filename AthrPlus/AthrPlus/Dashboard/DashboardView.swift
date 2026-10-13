//
//  DashboardView.swift
//  AthrPlus
//
//  Primary dashboard view for Athr+, displaying battery progress, charge limiter controls,
//  scooter telemetry details, and shortcuts to history, rides, and location maps.
//

import SwiftUI

public struct DashboardView: View {

    // MARK: - View Model

    @StateObject private var viewModel = DashboardViewModel()

    // MARK: - Navigation Sheets

    @State private var showSettingsSheet: Bool = false
    @State private var showHistorySheet: Bool = false
    @State private var showRidesSheet: Bool = false
    @State private var showMapSheet: Bool = false

    // MARK: - Initializer

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if let snapshot = viewModel.snapshot {
                    dashboardContent(snapshot: snapshot)
                } else if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(message: error)
                } else {
                    loadingView
                }
            }
            .navigationTitle("Athr+")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .sheet(isPresented: $showHistorySheet) {
                NavigationStack {
                    BatteryChartView(viewModel: BatteryHistoryViewModel())
                        .navigationTitle("Battery History")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showHistorySheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showRidesSheet) {
                NavigationStack {
                    RideHistoryView(vehicleId: viewModel.selectedVehicle?.id ?? "")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showRidesSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showMapSheet) {
                NavigationStack {
                    ScooterMapView(
                        vehicleId: viewModel.selectedVehicle?.id ?? "",
                        initialSnapshot: viewModel.snapshot
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showMapSheet = false }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }

    // MARK: - Main Content

    private func dashboardContent(snapshot: VehicleSnapshot) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Prominent Battery Status Card
                BatteryCard(snapshot: snapshot)

                // Charge Limiter Controls
                ChargeLimiterCard(
                    isEnabled: $viewModel.chargeLimiterEnabled,
                    targetPercentage: $viewModel.chargeLimiterTarget,
                    currentPercentage: snapshot.batteryPercentage,
                    isCharging: snapshot.isCharging,
                    estimatedCompletion: viewModel.estimatedChargeCompletion,
                    onStopCharging: {
                        Task {
                            await viewModel.stopCharging()
                        }
                    },
                    onTargetChanged: { newTarget in
                        viewModel.updateChargeLimiterTarget(newTarget)
                    }
                )

                // Scooter Information & Range Card
                ScooterInfoCard(
                    vehicle: viewModel.selectedVehicle,
                    snapshot: snapshot,
                    onViewMap: {
                        showMapSheet = true
                    }
                )

                // Quick Action Buttons Row
                quickActionsRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.loadVehicles()
        }
    }

    // MARK: - Quick Action Buttons

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            // History Button
            quickActionButton(
                title: "History",
                icon: "chart.bar.fill",
                color: .indigo
            ) {
                showHistorySheet = true
            }

            // Rides Button
            quickActionButton(
                title: "Rides",
                icon: "car.fill",
                color: .orange
            ) {
                showRidesSheet = true
            }

            // Map Button
            quickActionButton(
                title: "Map",
                icon: "map.fill",
                color: .blue
            ) {
                showMapSheet = true
            }
        }
    }

    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) button")
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Connecting to scooter...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Connection Failed")
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.loadVehicles()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    DashboardView()
}
