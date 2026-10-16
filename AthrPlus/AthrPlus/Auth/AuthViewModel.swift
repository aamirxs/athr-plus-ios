//
//  AuthViewModel.swift
//  AthrPlus
//
//  Authentication state management and API communication for Athr+.
//

import SwiftUI
import Foundation

/// Authentication state representing the user's progress through the login flow.
public enum AuthState: String, Codable, Equatable, Sendable {
    case loggedOut
    case otpSent
    case loggedIn
}

/// ObservableObject managing user authentication flow, OTP verification, and Keychain token persistence.
@MainActor
public final class AuthViewModel: ObservableObject {
    public static let userPhoneKey = "athr_user_phone"
    public static let baseURLKey = "athr_api_base_url"
    public static let defaultBaseURL = Constants.API.baseURL

    // Published view state
    @Published public var phone: String = ""
    @Published public var countryCode: CountryCode = .india
    @Published public var otp: String = ""
    @Published public var isLoading: Bool = false
    @Published public var error: String? = nil
    @Published public var authState: AuthState = .loggedOut
    @Published public var resendCountdown: Int = 30
    @Published public var showTokenLoginSheet: Bool = false
    @Published public var tokenInput: String = ""
    @Published public var showAppCheckSheet: Bool = false
    @Published public var appCheckTokenInput: String = ""
    @Published public var appCheckDebugTokenInput: String = ""

    // Internal task for countdown management
    private var countdownTask: Task<Void, Never>?

    public init() {
        checkExistingAuth()
        loadAppCheckSettings()
    }

    private func loadAppCheckSettings() {
        if let token = KeychainHelper.shared.loadString(forKey: Constants.Keychain.appCheckTokenKey) {
            self.appCheckTokenInput = token
        }
        if let debugToken = KeychainHelper.shared.loadString(forKey: Constants.Keychain.appCheckDebugTokenKey) {
            self.appCheckDebugTokenInput = debugToken
        }
    }

    deinit {
        countdownTask?.cancel()
    }

    /// Checks Keychain and Preferences for existing credentials to restore logged-in state.
    public func checkExistingAuth() {
        if KeychainHelper.shared.loadAccessToken() != nil || Preferences.shared.isLoggedIn {
            self.authState = .loggedIn
            if let savedPhone = KeychainHelper.shared.loadString(forKey: Self.userPhoneKey) {
                // If saved with country code, strip and set country
                self.phone = savedPhone
            }
        } else {
            self.authState = .loggedOut
        }
    }

    // MARK: - Phone Number Formatting & Validation

    /// Sanitize phone string when pasted or entered: strip spaces, +, and leading zeros.
    public func updatePhoneNumber(_ rawValue: String) {
        var digits = rawValue.filter { $0.isNumber }

        // Strip country dialing code if user pasted full international number matching selected dial code
        let dialDigits = countryCode.dialCode.filter { $0.isNumber }
        if digits.hasPrefix(dialDigits) && digits.count > countryCode.expectedPhoneLength {
            digits = String(digits.dropFirst(dialDigits.count))
        }

        // Strip leading trunk zero (e.g. 09876543210 -> 9876543210) if exceeds target length
        if digits.hasPrefix("0") && digits.count > countryCode.expectedPhoneLength {
            digits = String(digits.dropFirst())
        }

        // Limit to expected length
        if digits.count > countryCode.expectedPhoneLength {
            digits = String(digits.prefix(countryCode.expectedPhoneLength))
        }

        self.phone = digits
    }

    /// Validates phone number against expected digit length for selected country.
    public var isPhoneValid: Bool {
        let digits = phone.filter { $0.isNumber }
        return digits.count == countryCode.expectedPhoneLength
    }

    /// Full E.164 formatted telephone number (e.g., "+919876543210").
    public var fullPhoneNumber: String {
        let cleanDigits = phone.filter { $0.isNumber }
        return "\(countryCode.dialCode)\(cleanDigits)"
    }

    /// Human-readable masked phone number for OTP display (e.g., "+91 98••••••10").
    public var maskedPhoneNumber: String {
        let clean = phone.filter { $0.isNumber }
        guard clean.count >= 4 else {
            return "\(countryCode.dialCode) \(clean)"
        }
        let prefix = clean.prefix(2)
        let suffix = clean.suffix(2)
        let maskCount = max(0, clean.count - 4)
        let masked = String(repeating: "•", count: maskCount)
        return "\(countryCode.dialCode) \(prefix)\(masked)\(suffix)"
    }

    // MARK: - Auth Operations

    /// Validates the entered phone number and sends OTP request to Ather API.
    public func sendOTP() async {
        guard isPhoneValid else {
            self.error = "Please enter a valid \(countryCode.expectedPhoneLength)-digit phone number."
            return
        }

        self.isLoading = true
        self.error = nil

        do {
            let nationalNumber = phone.filter { $0.isNumber }
            _ = try await AtherAPI.shared.sendOTP(
                phone: nationalNumber,
                countryCode: countryCode.id
            )

            self.authState = .otpSent
            self.otp = ""
            startResendCountdown()
        } catch {
            self.error = error.localizedDescription
        }

        self.isLoading = false
    }

    /// Verifies the OTP, saves JWT tokens to Keychain, and updates authState to .loggedIn.
    public func verifyOTP() async {
        let cleanOtp = otp.filter { $0.isNumber }
        guard cleanOtp.count == 6 else {
            self.error = "Please enter the complete 6-digit verification code."
            return
        }

        self.isLoading = true
        self.error = nil

        do {
            let nationalNumber = phone.filter { $0.isNumber }
            _ = try await AtherAPI.shared.verifyOTP(
                phone: nationalNumber,
                otp: cleanOtp,
                countryCode: countryCode.id
            )

            try? KeychainHelper.shared.saveString(fullPhoneNumber, forKey: Self.userPhoneKey)

            countdownTask?.cancel()
            self.authState = .loggedIn
            self.otp = ""
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }

        self.isLoading = false
    }

    /// Logs in using a pre-existing Ather Bearer token.
    public func loginWithToken(_ rawToken: String) async {
        let clean = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "Bearer ", with: "", options: .caseInsensitive)
        guard !clean.isEmpty else {
            self.error = "Please paste a valid Ather authentication token."
            return
        }
        self.isLoading = true
        self.error = nil

        do {
            let tokens = AuthTokens(accessToken: clean, refreshToken: clean, expiresIn: 2592000)
            try await AtherAPI.shared.saveTokens(tokens)
            countdownTask?.cancel()
            self.authState = .loggedIn
            self.showTokenLoginSheet = false
            self.tokenInput = ""
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }

        self.isLoading = false
    }

    /// Saves a raw Firebase App Check JWT token.
    public func saveAppCheckToken(_ rawToken: String) async {
        let clean = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isLoading = true
        self.error = nil
        do {
            try await AtherAPI.shared.setAppCheckToken(clean.isEmpty ? nil : clean)
            self.appCheckTokenInput = clean
            self.showAppCheckSheet = false
        } catch {
            self.error = error.localizedDescription
        }
        self.isLoading = false
    }

    /// Exchanges a Firebase Debug Token UUID for an App Check JWT.
    public func exchangeAppCheckDebugToken(_ debugToken: String) async {
        let clean = debugToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            self.error = "Please enter a valid Firebase debug token UUID."
            return
        }
        self.isLoading = true
        self.error = nil
        do {
            let jwt = try await AtherAPI.shared.exchangeDebugToken(clean)
            self.appCheckTokenInput = jwt
            self.appCheckDebugTokenInput = clean
            self.showAppCheckSheet = false
        } catch {
            self.error = error.localizedDescription
        }
        self.isLoading = false
    }

    /// Resends the verification code if the countdown has expired.
    public func resendOTP() async {
        guard resendCountdown == 0 else { return }
        await sendOTP()
    }

    /// Logs out the user, cancels any active timers, and purges stored credentials from Keychain.
    public func logout() {
        countdownTask?.cancel()
        try? AtherAPI.shared.logout()
        try? KeychainHelper.shared.delete(forKey: Self.userPhoneKey)

        self.otp = ""
        self.resendCountdown = 0
        self.error = nil
        self.authState = .loggedOut
    }

    // MARK: - Resend Timer Management

    /// Initiates a 30-second countdown for the OTP resend button.
    public func startResendCountdown() {
        countdownTask?.cancel()
        resendCountdown = 30
        countdownTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while self.resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                self.resendCountdown -= 1
            }
        }
    }
}
