//
//  DashboardViewModel.swift
//  AthrPlus
//
//  ViewModel managing live scooter telemetry, polling, and charge limits.
//

import Foundation
import Combine

@MainActor
public final class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var snapshot: VehicleSnapshot?
    @Published public var selectedVehicle: Vehicle?
    @Published public var vehicles: [Vehicle] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String?
    @Published public var chargeLimiterTarget: Int
    @Published public var chargeLimiterEnabled: Bool
    @Published public var estimatedChargeCompletion: Date?

    // MARK: - Private Properties

    private var pollingTask: Task<Void, Never>?
    private var recentSamples: [BatterySample] = []
    private let api: AtherAPI
    private let preferences: Preferences

    // MARK: - Initializer

    public init(
        api: AtherAPI = .shared,
        preferences: Preferences = .shared
    ) {
        self.api = api
        self.preferences = preferences
        self.chargeLimiterTarget = preferences.chargeLimiterTarget
        self.chargeLimiterEnabled = preferences.chargeLimiterEnabled
        self.snapshot = preferences.loadLastSnapshot()

        if let cachedSnapshot = self.snapshot {
            recalculateEstimatedChargeCompletion(for: cachedSnapshot)
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Polling Lifecycle

    /// Starts polling vehicle snapshot every 5 seconds using Task.sleep.
    public func startPolling() {
        stopPolling()

        pollingTask = Task { [weak self] in
            guard let self = self else { return }

            // Ensure vehicles are loaded first if needed
            if self.vehicles.isEmpty {
                await self.loadVehicles()
            } else {
                await self.refreshCurrentSnapshot()
            }

            while !Task.isCancelled {
                do {
                    let intervalNanos = UInt64(Constants.snapshotPollingInterval * 1_000_000_000)
                    try await Task.sleep(nanoseconds: intervalNanos)
                } catch {
                    break
                }

                if Task.isCancelled { break }
                await self.refreshCurrentSnapshot()
            }
        }
    }

    /// Cancels active snapshot polling task.
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Vehicle Management

    /// Fetches all vehicles linked to the user account and selects the first (or previously saved).
    public func loadVehicles() async {
        isLoading = (snapshot == nil)
        error = nil

        do {
            let fetchedVehicles = try await api.getVehicles()
            self.vehicles = fetchedVehicles

            if let savedId = preferences.selectedVehicleId,
               let matched = fetchedVehicles.first(where: { $0.id == savedId }) {
                self.selectedVehicle = matched
            } else if let first = fetchedVehicles.first {
                self.selectedVehicle = first
                preferences.selectedVehicleId = first.id
            }

            if let vehicle = self.selectedVehicle {
                await fetchSnapshot(for: vehicle.id)
            }
        } catch {
            self.error = error.localizedDescription
        }

        self.isLoading = false
    }

    /// Selects a specific vehicle and fetches its live snapshot.
    public func selectVehicle(_ vehicle: Vehicle) async {
        self.selectedVehicle = vehicle
        self.preferences.selectedVehicleId = vehicle.id
        await fetchSnapshot(for: vehicle.id)
    }

    // MARK: - Snapshot Refresh

    private func refreshCurrentSnapshot() async {
        guard let vehicleId = selectedVehicle?.id else {
            if !vehicles.isEmpty {
                selectedVehicle = vehicles.first
                preferences.selectedVehicleId = vehicles.first?.id
            } else {
                return
            }
            guard let id = selectedVehicle?.id else { return }
            await fetchSnapshot(for: id)
            return
        }

        await fetchSnapshot(for: vehicleId)
    }

    private func fetchSnapshot(for vehicleId: String) async {
        do {
            let snap = try await api.getSnapshot(vehicleId: vehicleId)
            self.snapshot = snap
            self.error = nil

            // If charging, update recent samples for accurate deadline calculation
            if snap.isCharging {
                if let history = try? await api.getBatteryHistory(vehicleId: vehicleId) {
                    self.recentSamples = history
                }
            }

            recalculateEstimatedChargeCompletion(for: snap)

            // Auto-stop charging if charge limiter is active and reached target
            if chargeLimiterEnabled && snap.isCharging && snap.batteryPercentage >= chargeLimiterTarget {
                await stopCharging()
            }
        } catch {
            // Only update error if we don't have existing snapshot to avoid UI jitter
            if self.snapshot == nil {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Charge Limiter Controls

    /// Toggles charge limiter and sends corresponding start or stop command.
    public func toggleChargeLimiter() async {
        chargeLimiterEnabled.toggle()
        preferences.chargeLimiterEnabled = chargeLimiterEnabled

        if let snap = snapshot {
            recalculateEstimatedChargeCompletion(for: snap)
        }

        guard let vehicleId = selectedVehicle?.id else { return }

        // Send stop command if limiter enabled and currently charging at or above target
        if chargeLimiterEnabled, let snap = snapshot, snap.isCharging, snap.batteryPercentage >= chargeLimiterTarget {
            await stopCharging()
            return
        }

        // Toggle vehicle charging state via Ather API
        let command: VehicleCommand = (snapshot?.isCharging == true) ? .stopCharging : .startCharging
        do {
            try await api.sendCommand(vehicleId: vehicleId, command: command)
            let updated = try await api.getSnapshot(vehicleId: vehicleId)
            self.snapshot = updated
            recalculateEstimatedChargeCompletion(for: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Updates charge limit target percentage, saves to Preferences, and recalculates deadline estimate.
    public func updateChargeLimiterTarget(_ target: Int) {
        let clampedTarget = min(100, max(50, target))
        self.chargeLimiterTarget = clampedTarget
        self.preferences.chargeLimiterTarget = clampedTarget

        if let snap = snapshot {
            recalculateEstimatedChargeCompletion(for: snap)
        }
    }

    /// Stops smart charging on the active scooter.
    public func stopCharging() async {
        guard let vehicleId = selectedVehicle?.id else { return }

        do {
            try await api.sendCommand(vehicleId: vehicleId, command: .stopCharging)
            let updated = try await api.getSnapshot(vehicleId: vehicleId)
            self.snapshot = updated
            recalculateEstimatedChargeCompletion(for: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Charge Estimation

    private func recalculateEstimatedChargeCompletion(for snap: VehicleSnapshot) {
        guard snap.isCharging else {
            self.estimatedChargeCompletion = nil
            return
        }

        guard snap.batteryPercentage < chargeLimiterTarget else {
            self.estimatedChargeCompletion = Date()
            return
        }

        // Attempt estimation from recent samples
        if !recentSamples.isEmpty,
           let deadline = ChargeEstimator.estimateDeadline(
               currentPercent: snap.batteryPercentage,
               targetPercent: chargeLimiterTarget,
               samples: recentSamples
           ) {
            self.estimatedChargeCompletion = deadline
            return
        }

        // Fallback calculation using standard Ather home charger rate (~0.65% per minute)
        let neededSeconds = ChargeEstimator.estimateChargeTime(
            currentPercent: snap.batteryPercentage,
            targetPercent: chargeLimiterTarget,
            chargingRatePerMinute: 0.65
        )

        if neededSeconds > 0 {
            self.estimatedChargeCompletion = Date().addingTimeInterval(neededSeconds)
        } else {
            self.estimatedChargeCompletion = nil
        }
    }
}
