//
//  SettingsView.swift
//  AthrPlus
//
//  Settings screen with Account, Charge Limiter, Updates, Support, and About sections.
//

import SwiftUI

/// Settings view providing configuration, charge limiter options, updates, and account management.
public struct SettingsView: View {
    @ObservedObject public var authViewModel: AuthViewModel
    @ObservedObject private var preferences = Preferences.shared
    @StateObject private var updateChecker = AppUpdateChecker()

    // Persistent Settings
    @AppStorage("vehicleName") private var vehicleName: String = "Ather 450X"
    @AppStorage(AuthViewModel.baseURLKey) private var apiBaseURL: String = AuthViewModel.defaultBaseURL

    // UI State
    @State private var showLogoutConfirmation: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var didCopyUPI: Bool = false

    // Constants
    private let upiID = "karmugilen@upi"
    private let githubURL = URL(string: "https://github.com/karmugilen/athr-plus")!
    private let brandGreen = Color(red: 0.13, green: 0.77, blue: 0.36)

    public init(authViewModel: AuthViewModel = AuthViewModel()) {
        self.authViewModel = authViewModel
    }

    private var displayPhoneNumber: String {
        if !authViewModel.phone.isEmpty {
            return authViewModel.fullPhoneNumber
        } else if let saved = KeychainHelper.shared.loadString(forKey: AuthViewModel.userPhoneKey), !saved.isEmpty {
            return saved
        }
        return "Not Connected"
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Account Section
                Section {
                    HStack {
                        Label("Vehicle Name", systemImage: "scooter")
                        Spacer()
                        TextField("Vehicle Name", text: $vehicleName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Phone Number", systemImage: "phone")
                        Spacer()
                        Text(displayPhoneNumber)
                            .foregroundColor(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }

                    HStack {
                        Label("API Endpoint", systemImage: "server.rack")
                        Spacer()
                        TextField("https://...", text: $apiBaseURL)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                            .font(.caption.monospaced())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Customize your scooter profile and backend connection endpoint.")
                }

                // MARK: - Charge Limiter Section
                Section {
                    Toggle(isOn: $preferences.chargeLimiterEnabled) {
                        Label("Enable Charge Limiter", systemImage: "bolt.badge.checkmark")
                    }
                    .tint(brandGreen)

                    if preferences.chargeLimiterEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Target Charge Limit")
                                Spacer()
                                Text("\(preferences.chargeLimiterTarget)%")
                                    .fontWeight(.bold)
                                    .foregroundColor(brandGreen)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(preferences.chargeLimiterTarget) },
                                    set: { preferences.chargeLimiterTarget = Int($0) }
                                ),
                                in: 50...100,
                                step: 5
                            )
                            .tint(brandGreen)
                            .accessibilityLabel("Charge Limit Target")
                            .accessibilityValue("\(preferences.chargeLimiterTarget) percent")

                            HStack {
                                Text("50%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("100%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Charge Limiter")
                } footer: {
                    Text("Alerts or pauses smart charging when your scooter battery reaches the target percentage to extend long-term battery lifespan.")
                }

                // MARK: - App Updates Section
                Section {
                    HStack {
                        Label("Current Version", systemImage: "info.circle")
                        Spacer()
                        Text("\(updateChecker.currentAppVersion) (\(updateChecker.currentBuildNumber))")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Last Checked", systemImage: "clock")
                        Spacer()
                        Text(updateChecker.formattedLastChecked)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        Task {
                            await updateChecker.checkForUpdates(manual: true)
                        }
                    } label: {
                        HStack {
                            if updateChecker.isChecking {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text("Checking for updates...")
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(brandGreen)
                                Text("Check for Updates")
                                    .foregroundColor(brandGreen)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .disabled(updateChecker.isChecking)

                    if updateChecker.isUpToDate {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(brandGreen)
                            Text("Athr+ is up to date")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if let update = updateChecker.updateInfo, update.isNewer {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                                Text("Update Available: \(update.version)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                            }
                            if let url = update.downloadURL {
                                Link(destination: url) {
                                    Text("Download Release")
                                        .font(.caption.bold())
                                        .foregroundColor(brandGreen)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("App Updates")
                }

                // MARK: - Support the Project Section
                Section {
                    HStack {
                        Label("UPI ID", systemImage: "indianrupeesign.circle")
                        Spacer()
                        Text(upiID)
                            .font(.callout.monospaced())
                            .foregroundColor(.secondary)

                        Button {
                            copyUPI()
                        } label: {
                            Image(systemName: didCopyUPI ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundColor(didCopyUPI ? brandGreen : .secondary)
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Copy UPI ID")
                    }

                    Button {
                        openUPI()
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                            Text("Support via UPI")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Support the Project")
                } footer: {
                    Text("Athr+ is a 100% free and open-source project. Community contributions help sustain ongoing development and cloud infrastructure.")
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(updateChecker.currentAppVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(updateChecker.currentBuildNumber)
                            .foregroundColor(.secondary)
                    }

                    Link(destination: githubURL) {
                        HStack {
                            Label("View on GitHub", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Athr+ is an open-source community companion app for Ather electric scooters. It is not affiliated with or endorsed by Ather Energy Pvt. Ltd.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                } header: {
                    Text("About")
                }

                // MARK: - Log Out Section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Log Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    authViewModel.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out? Your session and cached scooter credentials will be removed.")
            }
            .alert(
                "Update Available",
                isPresented: $updateChecker.showUpdateAlert
            ) {
                if let url = updateChecker.updateInfo?.downloadURL {
                    Link("Download", destination: url)
                }
                Button("Later", role: .cancel) {}
            } message: {
                if let info = updateChecker.updateInfo {
                    Text("Version \(info.version) is now available.\n\n\(info.releaseNotes)")
                } else {
                    Text("A new release of Athr+ is available.")
                }
            }
            .alert(
                "UPI ID Copied",
                isPresented: $showCopiedAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("UPI ID (\(upiID)) has been copied to your clipboard.")
            }
        }
    }

    private func copyUPI() {
        UIPasteboard.general.string = upiID
        didCopyUPI = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            didCopyUPI = false
        }
    }

    private func openUPI() {
        let encodedUPI = upiID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? upiID
        let upiURLString = "upi://pay?pa=\(encodedUPI)&pn=AthrPlus&cu=INR"

        if let url = URL(string: upiURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // UPI app not available, copy ID to clipboard and notify user
            copyUPI()
            showCopiedAlert = true
        }
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
