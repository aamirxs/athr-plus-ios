//
//  LoginView.swift
//  AthrPlus
//
//  Phone number login screen with country code picker and modern layout.
//

import SwiftUI

/// Phone number authentication screen for Athr+.
public struct LoginView: View {
    @ObservedObject public var viewModel: AuthViewModel
    @State private var showingCountryPicker: Bool = false
    @FocusState private var isPhoneFocused: Bool

    // Brand accent color
    private let brandGreen = Color(red: 0.13, green: 0.77, blue: 0.36)

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPhoneFocused = false
                    }

                ScrollView {
                    VStack(spacing: 36) {
                        Spacer(minLength: 24)

                        // App Branding Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(brandGreen.opacity(0.15))
                                    .frame(width: 96, height: 96)

                                Image(systemName: "bolt.car.fill")
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundColor(brandGreen)
                                    .accessibilityHidden(true)
                            }
                            .padding(.bottom, 4)

                            Text("Athr+")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Your scooter companion")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)

                        // Phone Input Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Mobile Number")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)

                            HStack(spacing: 10) {
                                // Country Code Selector Button
                                Button {
                                    isPhoneFocused = false
                                    showingCountryPicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(viewModel.countryCode.flag)
                                            .font(.title3)
                                        Text(viewModel.countryCode.dialCode)
                                            .font(.body.monospacedDigit())
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Image(systemName: "chevron.down")
                                            .font(.caption2.bold())
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .accessibilityLabel("Country code \(viewModel.countryCode.dialCode), \(viewModel.countryCode.name)")
                                .accessibilityHint("Double tap to choose another country")

                                // Phone Number TextField
                                HStack {
                                    TextField("Phone number", text: Binding(
                                        get: { viewModel.phone },
                                        set: { viewModel.updatePhoneNumber($0) }
                                    ))
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                                    .focused($isPhoneFocused)
                                    .font(.body.monospacedDigit())

                                    if !viewModel.phone.isEmpty {
                                        Button {
                                            viewModel.phone = ""
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.subheadline)
                                        }
                                        .accessibilityLabel("Clear phone number")
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }

                            // Input validation hint
                            if !viewModel.phone.isEmpty && !viewModel.isPhoneValid {
                                Text("Expected \(viewModel.countryCode.expectedPhoneLength) digits")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                        .padding(.horizontal, 20)

                        // Action Button - Send OTP
                        Button {
                            isPhoneFocused = false
                            Task {
                                await viewModel.sendOTP()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Send OTP")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(viewModel.isPhoneValid && !viewModel.isLoading ? brandGreen : brandGreen.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: viewModel.isPhoneValid ? brandGreen.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!viewModel.isPhoneValid || viewModel.isLoading)
                        .padding(.horizontal, 20)

                        // Alternative Sign-in Options
                        VStack(spacing: 12) {
                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 1)
                                Text("ALTERNATIVE LOGIN OPTIONS")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)

                            // Option 1: Ather Bearer token (required for existing accounts)
                            Button {
                                isPhoneFocused = false
                                viewModel.showTokenLoginSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "key.fill")
                                        .font(.subheadline)
                                    Text("Sign in with Ather Token")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 20)

                            // Option 2: Firebase App Check setup
                            Button {
                                isPhoneFocused = false
                                viewModel.showAppCheckSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.checkmark.fill")
                                        .font(.caption)
                                    Text("App Check Setup")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.secondary)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 20)
                        }

                        // Privacy & Terms Notice
                        Text("By proceeding, you agree to connect Athr+ to your scooter account.")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)

                        Text("Athr+ v1.0.6 (Build 7)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 4)

                        Spacer(minLength: 24)
                    }
                }

                // Loading Overlay
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 14) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.3)
                            Text("Connecting...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                        .padding(24)
                        .background(Color(.systemGray6).opacity(0.95))
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
                    .transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(
                isPresented: Binding(
                    get: { viewModel.authState == .otpSent },
                    set: { if !$0 && viewModel.authState == .otpSent { viewModel.authState = .loggedOut } }
                )
            ) {
                OTPView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountryCodePickerView(selectedCountry: $viewModel.countryCode)
            }
            .sheet(isPresented: $viewModel.showTokenLoginSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Ather Account Token")
                            .font(.headline)
                            .padding(.top, 8)

                        Text("Ather's servers enforce Firebase App Check on account sign-in for third-party apps. The OTP screen confirms your number, but completing the login requires your Ather Bearer token — paste it below to connect directly.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("TOKEN")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                    Button("Paste from Clipboard") {
                                        viewModel.tokenInput = clip
                                    }
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(brandGreen)
                                }
                            }

                            TextEditor(text: $viewModel.tokenInput)
                                .frame(height: 110)
                                .font(.system(.footnote, design: .monospaced))
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Button {
                            Task {
                                await viewModel.loginWithToken(viewModel.tokenInput)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Connect Scooter")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(!viewModel.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? brandGreen : brandGreen.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("How to obtain your token:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("• Option A: From Android app data (/data/data/com.athermobileapp/shared_prefs/)\n• Option B: Via HTTP proxy (PCAPdroid, Reqable, or Proxyman) on your phone when opening the official Ather app.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground).opacity(0.7))
                        .cornerRadius(10)

                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle("Token Sign In")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                viewModel.showTokenLoginSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showAppCheckSheet) {
                AppCheckSheetView(viewModel: viewModel)
            }
            .alert(
                "Authentication Notice",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.error = nil } }
                )
            ) {
                if (viewModel.error?.contains("App Check") == true) || (viewModel.error?.contains("already exists") == true) || (viewModel.error?.contains("1013") == true) || (viewModel.error?.contains("1014") == true) {
                    Button("Sign in with Ather Token") {
                        viewModel.error = nil
                        viewModel.showTokenLoginSheet = true
                    }
                    Button("App Check Setup") {
                        viewModel.error = nil
                        viewModel.showAppCheckSheet = true
                    }
                }
                Button("OK", role: .cancel) {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "An error occurred. Please try again.")
            }
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
