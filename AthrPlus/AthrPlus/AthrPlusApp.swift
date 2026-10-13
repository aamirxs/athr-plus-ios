//
//  AthrPlusApp.swift
//  AthrPlus
//
//  Main application entry point for Athr+.
//

import SwiftUI
import BackgroundTasks
import SwiftData

@main
struct AthrPlusApp: App {

    // MARK: - State & Storage

    @AppStorage("isLoggedIn") var isLoggedIn = false
    @StateObject var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    // Background Task Identifiers
    private static let refreshTaskId = Constants.BackgroundTasks.refreshIdentifier
    private static let processingTaskId = Constants.BackgroundTasks.snapshotSyncIdentifier

    // MARK: - App Initialization

    init() {
        registerBackgroundTasks()
    }

    // MARK: - Scene Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .modelContainer(ModelContainerFactory.sharedModelContainer)
                .onAppear {
                    registerBGTaskSchedulerHandlers()
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        Self.scheduleSnapshotRefresh()
                        Self.scheduleChargeLimiter()
                    case .active:
                        authViewModel.checkExistingAuth()
                    default:
                        break
                    }
                }
                .onChange(of: authViewModel.authState) { newAuthState in
                    isLoggedIn = (newAuthState == .loggedIn)
                    Preferences.shared.isLoggedIn = isLoggedIn
                }
        }
    }

    // MARK: - Background Task Registration

    /// Registers background task launch handlers with BGTaskScheduler during app launch.
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Self.handleSnapshotRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskId,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Self.handleChargeLimiter(task: processingTask)
        }
    }

    /// Secondary registration hook called on view appearance.
    private func registerBGTaskSchedulerHandlers() {
        Self.scheduleSnapshotRefresh()
        Self.scheduleChargeLimiter()
    }

    // MARK: - Background Task Handlers

    private static func handleSnapshotRefresh(task: BGAppRefreshTask) {
        scheduleSnapshotRefresh()

        let refreshOperation = Task {
            guard let vehicleId = Preferences.shared.selectedVehicleId, !vehicleId.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }

            do {
                _ = try await AtherAPI.shared.getSnapshot(vehicleId: vehicleId)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            refreshOperation.cancel()
        }
    }

    private static func handleChargeLimiter(task: BGProcessingTask) {
        scheduleChargeLimiter()

        let limiterOperation = Task {
            guard Preferences.shared.chargeLimiterEnabled,
                  let vehicleId = Preferences.shared.selectedVehicleId,
                  !vehicleId.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }

            do {
                let snapshot = try await AtherAPI.shared.getSnapshot(vehicleId: vehicleId)
                let target = Preferences.shared.chargeLimiterTarget

                if snapshot.isCharging && snapshot.batteryPercentage >= target {
                    try await AtherAPI.shared.sendCommand(vehicleId: vehicleId, command: .stopCharging)
                }
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            limiterOperation.cancel()
        }
    }

    // MARK: - Background Task Scheduling

    /// Submits a BGAppRefreshTaskRequest for periodic snapshot polling.
    public static func scheduleSnapshotRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Task scheduling may fail in simulator or without entitlements
        }
    }

    /// Submits a BGProcessingTaskRequest for charge limiter background monitoring.
    public static func scheduleChargeLimiter() {
        let request = BGProcessingTaskRequest(identifier: processingTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Task scheduling may fail in simulator or without entitlements
        }
    }
}
