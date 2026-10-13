import Foundation

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

public actor AtherAPI {
    public static let shared = AtherAPI()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let interceptor: AuthInterceptor
    private let keychain: KeychainHelper

    public init(
        session: URLSession = .shared,
        interceptor: AuthInterceptor = .shared,
        keychain: KeychainHelper = .shared
    ) {
        self.session = session
        self.interceptor = interceptor
        self.keychain = keychain

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc
    }

    // MARK: - Private Request Helper

    private func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let urlString: String
        if endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://") {
            urlString = endpoint
        } else {
            let cleanEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
            urlString = "\(Constants.API.baseURL)/\(Constants.API.version)/\(cleanEndpoint)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = Constants.API.defaultTimeout

        if let body = body {
            do {
                urlRequest.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.networkError(error)
            }
        }

        let data: Data
        let httpResponse: HTTPURLResponse

        if authenticated {
            (data, httpResponse) = try await interceptor.execute(urlRequest)
        } else {
            let (rawData, rawResponse) = try await session.data(for: urlRequest)
            guard let http = rawResponse as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }
            data = rawData
            httpResponse = http
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        guard !data.isEmpty else {
            throw APIError.noData
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Public Methods

    /// Sends an OTP to the given phone number.
    public func sendOTP(phone: String, countryCode: String = Constants.Defaults.countryCode) async throws -> OTPResponse {
        let requestBody = OTPRequest(phone: phone, countryCode: countryCode)
        return try await request("auth/otp/send", method: "POST", body: requestBody, authenticated: false)
    }

    /// Verifies the OTP, saves received tokens to Keychain, and returns the tokens.
    public func verifyOTP(phone: String, otp: String, requestId: String) async throws -> AuthTokens {
        let requestBody = VerifyOTPRequest(phone: phone, otp: otp, requestId: requestId)
        let tokens: AuthTokens = try await request("auth/otp/verify", method: "POST", body: requestBody, authenticated: false)

        try keychain.saveTokens(tokens)
        await MainActor.run {
            Preferences.shared.isLoggedIn = true
        }

        return tokens
    }

    /// Explicitly refreshes auth tokens and updates Keychain.
    public func refreshToken() async throws -> AuthTokens {
        try await interceptor.refreshToken()
    }

    /// Fetches all vehicles linked to the authenticated user account.
    public func getVehicles() async throws -> [Vehicle] {
        try await request("user/vehicles", method: "GET", body: nil, authenticated: true)
    }

    /// Fetches the live vehicle snapshot and updates the shared widget cache.
    public func getSnapshot(vehicleId: String) async throws -> VehicleSnapshot {
        let snapshot: VehicleSnapshot = try await request("vehicles/\(vehicleId)/snapshot", method: "GET", body: nil, authenticated: true)

        await MainActor.run {
            Preferences.shared.saveLastSnapshot(snapshot)
        }

        return snapshot
    }

    /// Sends a vehicle control command (e.g. start or stop charging).
    public func sendCommand(vehicleId: String, command: VehicleCommand) async throws {
        let requestBody = CommandRequest(command: command)
        let _: EmptyResponse = try await request("vehicles/\(vehicleId)/command", method: "POST", body: requestBody, authenticated: true)
    }

    /// Fetches historical battery telemetry samples for a vehicle.
    public func getBatteryHistory(vehicleId: String) async throws -> [BatterySample] {
        try await request("vehicles/\(vehicleId)/battery/history", method: "GET", body: nil, authenticated: true)
    }

    /// Fetches the list of completed rides for a vehicle.
    public func getRides(vehicleId: String) async throws -> [Ride] {
        try await request("vehicles/\(vehicleId)/rides", method: "GET", body: nil, authenticated: true)
    }

    /// Fetches full route and telemetry details for a specific ride.
    public func getRideDetail(vehicleId: String, rideId: String) async throws -> RideDetail {
        try await request("vehicles/\(vehicleId)/rides/\(rideId)", method: "GET", body: nil, authenticated: true)
    }

    /// Clears stored tokens and resets user preferences on sign out.
    public nonisolated func logout() throws {
        try keychain.clearTokens()
        Task { @MainActor in
            Preferences.shared.reset()
        }
    }
}
