//
//  ContentView.swift
//  AthrPlus
//
//  Root navigation controller switching smoothly between authentication and the main tab interface.
//

import SwiftUI

// MARK: - VehicleId Environment Key

private struct VehicleIdEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

public extension EnvironmentValues {
    var vehicleId: String? {
        get { self[VehicleIdEnvironmentKey.self] }
        set { self[VehicleIdEnvironmentKey.self] = newValue }
    }
}

// MARK: - ContentView

public struct ContentView: View {

    // MARK: - Environment & State

    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @ObservedObject private var preferences = Preferences.shared

    private var activeVehicleId: String? {
        preferences.selectedVehicleId
    }

    // MARK: - Initializer

    public init() {}

    // MARK: - Body

    public var body: some View {
        ZStack {
            if authViewModel.authState == .loggedIn || isLoggedIn {
                MainTabView(vehicleId: activeVehicleId)
                    .environment(\.vehicleId, activeVehicleId)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            } else {
                LoginView(viewModel: authViewModel)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authViewModel.authState)
        .animation(.easeInOut(duration: 0.35), value: isLoggedIn)
        .onAppear {
            authViewModel.checkExistingAuth()
            isLoggedIn = (authViewModel.authState == .loggedIn)
        }
        .onChange(of: authViewModel.authState) { newState in
            withAnimation(.easeInOut(duration: 0.35)) {
                isLoggedIn = (newState == .loggedIn)
            }
        }
    }
}

// MARK: - MainTabView

public struct MainTabView: View {

    public let vehicleId: String?
    @State private var selectedTab: Int = 0

    public init(vehicleId: String? = nil) {
        self.vehicleId = vehicleId
    }

    private var effectiveVehicleId: String {
        vehicleId ?? Preferences.shared.selectedVehicleId ?? ""
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            // Tab 2: Battery History
            BatteryHistoryView(vehicleId: vehicleId)
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            // Tab 3: Ride History
            RideHistoryView(vehicleId: effectiveVehicleId)
                .tabItem {
                    Label("Rides", systemImage: "car.fill")
                }
                .tag(2)

            // Tab 4: Scooter Map
            ScooterMapView(vehicleId: effectiveVehicleId)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(3)
        }
        .tint(Color(red: 0.0, green: 0.82, blue: 0.42))
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
