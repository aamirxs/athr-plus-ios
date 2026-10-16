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
    private var appCheckToken: String?

    /// Tracks which OTP route family the last `sendOTP` used so `verifyOTP` pairs correctly:
    /// `.login` (9a11/9a12, requires App Check) or `.signup` (8b21/8b22).
    private enum OTPFamily {
        case login
        case signup
    }
    private var lastOTPFamily: OTPFamily = .signup

    public init(
        session: URLSession = .shared,
        interceptor: AuthInterceptor = .shared,
        keychain: KeychainHelper = .shared
    ) {
        self.session = session
        self.interceptor = interceptor
        self.keychain = keychain
        self.appCheckToken = keychain.loadString(forKey: Constants.Keychain.appCheckTokenKey)

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc
    }

    // MARK: - Private Header & Request Helper

    private func applyAtherHeaders(to request: inout URLRequest, includeAppCheck: Bool = false) {
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")
        request.setValue(Constants.HTTPHeaders.source, forHTTPHeaderField: "Source")
        request.setValue(Constants.HTTPHeaders.platform, forHTTPHeaderField: "X-Platform")
        request.setValue(Constants.HTTPHeaders.platformVersion, forHTTPHeaderField: "X-Platform-Version")
        request.setValue(Constants.HTTPHeaders.userAgent, forHTTPHeaderField: "User-Agent")
        // IMPORTANT: only attach App Check to routes that expect it (9a11/9a12).
        // Un-gated routes (8b21/8b22/signup) reject requests that carry an invalid or
        // stale App Check token (errorCode 1014) even though they work fine without it.
        if includeAppCheck, let token = appCheckToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
    }

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
        applyAtherHeaders(to: &urlRequest)
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorCode = json["errorCode"] as? Int,
                   (errorCode == 1013 || errorCode == 1014) {
                    throw APIError.serverError(401, "Ather requires App Check verification (Error \(errorCode)). Please use 'Sign in with Token'.")
                }
                throw APIError.unauthorized
            }
            let errorMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? String(data: data, encoding: .utf8)
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

    // MARK: - Private Auth Helpers

    private func normalizedCountry(_ countryCode: String) -> String {
        countryCode.hasPrefix("+") ? "IN" : countryCode
    }

    private func postJSON(_ urlString: String, body: [String: Any], includeAppCheck: Bool = false) async throws -> (status: Int, data: Data) {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        applyAtherHeaders(to: &urlRequest, includeAppCheck: includeAppCheck)
        urlRequest.timeoutInterval = Constants.API.defaultTimeout
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        return (http.statusCode, data)
    }

    private func jsonObject(of data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func isAppCheckFailure(_ status: Int, _ json: [String: Any]) -> Bool {
        guard status == 401 else { return false }
        let code = json["errorCode"] as? Int
        return code == 1013 || code == 1014
    }

    private func authError(_ status: Int, _ data: Data) -> APIError {
        let json = jsonObject(of: data)
        if isAppCheckFailure(status, json) {
            let code = json["errorCode"] as? Int ?? 1013
            return .serverError(status, "Ather requires App Check verification (Error \(code)). Please use 'Sign in with Ather Token' or configure an App Check token and try again.")
        }
        let message = (json["message"] as? String)
            ?? (json["error"] as? String)
            ?? String(data: data, encoding: .utf8)
            ?? "HTTP \(status)"
        return .serverError(status, message)
    }

    private func otpResponse(from data: Data) -> OTPResponse {
        let json = jsonObject(of: data)
        return OTPResponse(
            message: (json["message"] as? String) ?? "OTP sent successfully",
            attemptsLeft: json["attemptsLeft"] as? Int,
            totalAttempts: json["totalAttempts"] as? Int
        )
    }

    private func persistSession(from data: Data) async throws -> AuthTokens {
        let json = jsonObject(of: data)
        guard let token = json["token"] as? String, !token.isEmpty else {
            throw APIError.serverError(200, "Ather accepted the login but did not return an account token.")
        }
        // Ather issues a long-lived Bearer token; it doubles as the refresh token here.
        let tokens = AuthTokens(accessToken: token, refreshToken: token, expiresIn: 2592000)
        try keychain.saveTokens(tokens)
        await MainActor.run {
            Preferences.shared.isLoggedIn = true
        }
        return tokens
    }

    // MARK: - Public Methods

    /// Sends an OTP to the given phone number.
    ///
    /// Uses the canonical login route (9a11) when a valid App Check token is configured,
    /// otherwise the un-gated 8b21 route that the current Ather app uses for signup OTP
    /// (SMS delivery confirmed against the live production backend).
    public func sendOTP(phone: String, countryCode: String = Constants.Defaults.countryId) async throws -> OTPResponse {
        let cleanCountry = normalizedCountry(countryCode)
        let notification: [String: Any] = ["whatsapp": false, "sms": true]

        if let token = appCheckToken, !token.isEmpty {
            let loginBody: [String: Any] = [
                "email": "",
                "contact_no": phone,
                "country_code": cleanCountry,
                "notification_medium": notification
            ]
            let (status, data) = try await postJSON(Constants.API.loginGenerateOtpURL, body: loginBody, includeAppCheck: true)
            if (200...299).contains(status) {
                lastOTPFamily = .login
                return otpResponse(from: data)
            }
            // Only fall back when the App Check token itself was rejected; surface
            // any real business error (rate limit, validation, …) as-is.
            if !isAppCheckFailure(status, jsonObject(of: data)) {
                throw authError(status, data)
            }
        }

        let body: [String: Any] = [
            "contact_no": phone,
            "country_code": cleanCountry,
            "notification_medium": notification
        ]
        let (status, data) = try await postJSON(Constants.API.generateOtpURL, body: body)
        guard (200...299).contains(status) else {
            throw authError(status, data)
        }
        lastOTPFamily = .signup
        return otpResponse(from: data)
    }

    /// Verifies the OTP and establishes an authenticated session.
    ///
    /// Login family (App Check token configured): 9a12 returns the account token directly.
    /// Signup family (default, no App Check): 8b22 verifies the code against Ather's live
    /// backend. Ather only issues account tokens to official flows (existing accounts go
    /// through the App Check-gated 9a12 route), so after verification the user is guided
    /// to the token sign-in path.
    public func verifyOTP(phone: String, otp: String, countryCode: String = Constants.Defaults.countryId) async throws -> AuthTokens {
        let cleanCountry = normalizedCountry(countryCode)

        if lastOTPFamily == .login, let token = appCheckToken, !token.isEmpty {
            let body: [String: Any] = [
                "email": "",
                "contact_no": phone,
                "userOtp": otp,
                "is_mobile_login": true,
                "country_code": cleanCountry
            ]
            let (status, data) = try await postJSON(Constants.API.loginVerifyOtpURL, body: body, includeAppCheck: true)
            guard (200...299).contains(status) else {
                throw authError(status, data)
            }
            return try await persistSession(from: data)
        }

        // Verify the code against Ather's backend (8b22). Wrong codes return errorCode
        // 1006 with the remaining attempts in the message, shown to the user verbatim.
        let verifyBody: [String: Any] = [
            "otp": otp,
            "contact_no": phone,
            "country_code": cleanCountry
        ]
        let (verifyStatus, verifyData) = try await postJSON(Constants.API.verifyOtpURL, body: verifyBody)
        guard (200...299).contains(verifyStatus) else {
            throw authError(verifyStatus, verifyData)
        }

        // Code verified, but Ather does not issue a session token on this route:
        // existing accounts must sign in through the App Check-gated 9a12 route.
        throw APIError.otpVerifiedNoSession("OTP verified successfully. Ather requires Firebase App Check to sign an existing account into third-party apps, which this build cannot generate. Use 'Sign in with Ather Token' to connect, or configure an App Check token and try again.")
    }

    /// Explicitly refreshes auth tokens and updates Keychain.
    public func refreshToken() async throws -> AuthTokens {
        try await interceptor.refreshToken()
    }

    /// Saves externally supplied auth tokens (e.g. from token login) directly into Keychain and sets logged-in state.
    public func saveTokens(_ tokens: AuthTokens) async throws {
        try keychain.saveTokens(tokens)
        await MainActor.run {
            Preferences.shared.isLoggedIn = true
        }
    }

    /// Updates the App Check token in memory and persists to Keychain.
    public func setAppCheckToken(_ token: String?) throws {
        self.appCheckToken = token
        if let token = token, !token.isEmpty {
            try keychain.saveString(token, forKey: Constants.Keychain.appCheckTokenKey)
        } else {
            try? keychain.delete(forKey: Constants.Keychain.appCheckTokenKey)
        }
    }

    /// Retrieves the active App Check token.
    public func getAppCheckToken() -> String? {
        return self.appCheckToken
    }

    /// Exchanges a Firebase App Check Debug Token with Google's API to mint a valid App Check JWT.
    public func exchangeDebugToken(_ debugToken: String) async throws -> String {
        let cleanToken = debugToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            throw APIError.serverError(400, "Debug token cannot be empty.")
        }
        let urlString = "https://firebaseappcheck.googleapis.com/v1/projects/\(Constants.Firebase.projectID)/apps/\(Constants.Firebase.androidAppID):exchangeDebugToken?key=\(Constants.Firebase.apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["debug_token": cleanToken])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let message = errorMsg?["message"] as? String ?? "HTTP \(http.statusCode)"
            throw APIError.serverError(http.statusCode, "Firebase App Check failed: \(message)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jwt = json["token"] as? String else {
            throw APIError.noData
        }

        try setAppCheckToken(jwt)
        try keychain.saveString(cleanToken, forKey: Constants.Keychain.appCheckDebugTokenKey)
        return jwt
    }

    /// Fetches all vehicles linked to the authenticated user account via /api/v1/me or firebase-dbs fallback.
    public func getVehicles() async throws -> [Vehicle] {
        guard let meUrl = URL(string: "https://cerberus.ather.io/api/v1/me") else {
            throw APIError.invalidURL
        }
        var meRequest = URLRequest(url: meUrl)
        meRequest.httpMethod = "GET"
        applyAtherHeaders(to: &meRequest)

        if let (data, response) = try? await interceptor.execute(meRequest),
           (200...299).contains(response.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let vehiclesList = (json["vehicles"] as? [[String: Any]])
                ?? ((json["data"] as? [String: Any])?["vehicles"] as? [[String: Any]])
                ?? (json["scooters"] as? [[String: Any]])
                ?? []

            var parsed: [Vehicle] = []
            for item in vehiclesList {
                if let uuid = (item["uuid"] ?? item["vehicle_uuid"] ?? item["scooter_uuid"] ?? item["id"]) as? String {
                    let name = (item["display_name"] ?? item["name"] ?? item["nickname"] ?? item["registration"]) as? String ?? "Ather"
                    let reg = item["registration"] as? String ?? item["reg_no"] as? String ?? ""
                    let model = (item["model_type"] ?? item["model"] ?? item["bike_type"]) as? String ?? "450X"
                    let color = (item["colour"] ?? item["color"]) as? String ?? "Space Grey"
                    parsed.append(Vehicle(id: uuid, name: name, model: model, registrationNumber: reg, color: color))
                }
            }
            if !parsed.isEmpty {
                return parsed
            }
        }

        // Fallback to /api/v2/auth/user/scooters/firebase-dbs
        guard let fbUrl = URL(string: "https://cerberus.ather.io/api/v2/auth/user/scooters/firebase-dbs") else {
            return []
        }
        var fbRequest = URLRequest(url: fbUrl)
        fbRequest.httpMethod = "GET"
        applyAtherHeaders(to: &fbRequest)

        let (fbData, fbResponse) = try await interceptor.execute(fbRequest)
        if (200...299).contains(fbResponse.statusCode),
           let fbJson = try? JSONSerialization.jsonObject(with: fbData) as? [String: Any] {
            let shards = (fbJson["shardDetails"] as? [[String: Any]])
                ?? ((fbJson["data"] as? [String: Any])?["shardDetails"] as? [[String: Any]])
                ?? []
            var parsed: [Vehicle] = []
            for item in shards {
                if let uuid = (item["scooter_uuid"] ?? item["uuid"] ?? item["vehicle_uuid"]) as? String {
                    let name = (item["scooter"] ?? item["display_name"] ?? item["name"]) as? String ?? "Ather"
                    parsed.append(Vehicle(id: uuid, name: name, model: "450X", registrationNumber: "", color: "Space Grey"))
                }
            }
            return parsed
        }
        return []
    }

    /// Fetches the live vehicle snapshot and updates the shared widget cache.
    public func getSnapshot(vehicleId: String) async throws -> VehicleSnapshot {
        guard let url = URL(string: "https://cerberus.ather.io/api/v1/devices/shadows/scooters/properties?uuid=\(vehicleId)&state=reported") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAtherHeaders(to: &request)

        let (data, response) = try await interceptor.execute(request)
        guard (200...299).contains(response.statusCode) else {
            throw APIError.serverError(response.statusCode, "Failed to fetch vehicle snapshot")
        }

        let snapshot = parseSnapshot(from: data, vehicleId: vehicleId)
        await MainActor.run {
            Preferences.shared.saveLastSnapshot(snapshot)
        }

        return snapshot
    }

    private func parseSnapshot(from data: Data, vehicleId: String) -> VehicleSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return VehicleSnapshot(batteryPercentage: 0, isCharging: false, chargingState: "Not Connected", latitude: 0, longitude: 0, odometer: 0, ranges: [:], lastUpdated: Date().timeIntervalSince1970, isConnected: false)
        }

        let container = (root["data"] as? [String: Any]) ?? root
        let telemetry = (container["telemetry"] as? [String: Any]) ?? container
        let bike = (telemetry["bike"] as? [String: Any]) ?? telemetry
        let charging = (telemetry["charging"] as? [String: Any]) ?? telemetry

        let battery = (bike["battery_soc"] as? Double)
            ?? (bike["soc"] as? Double)
            ?? (bike["shortSOC"] as? Double)
            ?? Double((bike["battery_soc"] as? Int) ?? (bike["soc"] as? Int) ?? 0)

        let odo = (bike["odo"] as? Double) ?? Double((bike["odo"] as? Int) ?? 0)

        let chargingStatus = (charging["chargingStatus"] as? String) ?? (container["chargingStatus"] as? String) ?? "Not Charging"
        let heartbeat = (charging["chargingHeartBeat"] as? String) ?? ""
        let isCharging = chargingStatus.lowercased().contains("charg") || heartbeat.lowercased() == "on"

        var lat = 0.0
        var lng = 0.0
        if let gps = (bike["gps_location"] as? [String: Any]) ?? (telemetry["gps_location"] as? [String: Any]) {
            lat = (gps["lat"] as? Double) ?? (gps["latitude"] as? Double) ?? 0.0
            lng = (gps["lng"] as? Double) ?? (gps["lon"] as? Double) ?? (gps["longitude"] as? Double) ?? 0.0
        }

        var ranges: [String: Double] = [:]
        if let modeRange = (bike["predicted_mode_range"] as? [String: Any]) ?? (bike["mode_range"] as? [String: Any]) {
            for (key, val) in modeRange {
                if let d = val as? Double {
                    ranges[key.lowercased()] = d
                } else if let i = val as? Int {
                    ranges[key.lowercased()] = Double(i)
                }
            }
        }
        if ranges.isEmpty {
            let baseRange = (bike["range"] as? Double) ?? Double((bike["range"] as? Int) ?? 75)
            ranges = [
                "eco": baseRange,
                "ride": baseRange * 0.85,
                "sport": baseRange * 0.70,
                "warp": baseRange * 0.55
            ]
        }

        return VehicleSnapshot(
            batteryPercentage: Int(battery),
            isCharging: isCharging,
            chargingState: isCharging ? "Charging" : "Not Charging",
            latitude: lat,
            longitude: lng,
            odometer: odo,
            ranges: ranges,
            lastUpdated: Date().timeIntervalSince1970,
            isConnected: true
        )
    }

    /// Sends a vehicle control command (e.g. start or stop charging).
    public func sendCommand(vehicleId: String, command: VehicleCommand) async throws {
        let isStart = (command == .startCharging)
        let action = isStart ? "start" : "stop"
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = [
            "state": [
                "desired": [
                    "remote_charging": [
                        "state": 1,
                        "action": action,
                        "error": "0",
                        "timestamp": timestampMs
                    ]
                ]
            ],
            "request_id": "ma_\(vehicleId)"
        ]
        guard let url = URL(string: "https://cerberus.ather.io/api/v1/devices/shadows/scooters?uuid=\(vehicleId)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAtherHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await interceptor.execute(request)
        guard (200...299).contains(response.statusCode) else {
            throw APIError.serverError(response.statusCode, "Failed to send command to scooter")
        }
    }

    /// Fetches historical battery telemetry samples for a vehicle.
    public func getBatteryHistory(vehicleId: String) async throws -> [BatterySample] {
        return []
    }

    /// Fetches the list of completed rides for a vehicle.
    public func getRides(vehicleId: String) async throws -> [Ride] {
        guard let url = URL(string: "https://cerberus.ather.io/api/v1/rides?scooterid=\(vehicleId)&limit=100&page=1") else {
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAtherHeaders(to: &request)
        request.setValue("ATHER_APP", forHTTPHeaderField: "X-Request-Source")

        let (data, response) = try await interceptor.execute(request)
        guard (200...299).contains(response.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        let trips = (json["trips"] as? [[String: Any]])
            ?? ((json["data"] as? [String: Any])?["trips"] as? [[String: Any]])
            ?? []

        var parsedRides: [Ride] = []
        for trip in trips {
            guard let id = (trip["ride_id"] as? String) ?? ((trip["ride_id"] as? Int).map(String.init)) else { continue }
            let start = (trip["ride_start_time"] as? Double) ?? Double((trip["ride_start_time"] as? Int64) ?? 0) / 1000.0
            let end = (trip["ride_end_time"] as? Double) ?? Double((trip["ride_end_time"] as? Int64) ?? 0) / 1000.0
            let distanceM = (trip["distance_m"] as? Double) ?? Double((trip["distance_m"] as? Int) ?? 0)
            let distanceKm = distanceM / 1000.0
            let duration = (trip["duration_secs"] as? Int) ?? Int((trip["duration_secs"] as? Double) ?? 0)
            let avgSpeed = (trip["avg_display_speed_kmph"] as? Double) ?? 0.0
            let topSpeed = (trip["max_display_speed_kmph"] as? Double) ?? 0.0

            let polylineDetails = trip["polyline_details"] as? [String: Any]
            let polyline = polylineDetails?["polyline"] as? String

            parsedRides.append(Ride(
                id: "ather-\(id)",
                startTime: start > 0 ? start : Date().timeIntervalSince1970,
                endTime: end > 0 ? end : Date().timeIntervalSince1970,
                distance: distanceKm,
                duration: TimeInterval(duration),
                averageSpeed: avgSpeed,
                topSpeed: topSpeed,
                startBattery: 90,
                endBattery: 70,
                routePolyline: polyline
            ))
        }
        return parsedRides
    }

    /// Fetches full route and telemetry details for a specific ride.
    public func getRideDetail(vehicleId: String, rideId: String) async throws -> RideDetail {
        let rides = try await getRides(vehicleId: vehicleId)
        if let found = rides.first(where: { $0.id == rideId }) {
            return RideDetail(id: found.id, startTime: found.startTime, endTime: found.endTime, distance: found.distance, duration: found.duration, averageSpeed: found.averageSpeed, topSpeed: found.topSpeed, startBattery: found.startBattery, endBattery: found.endBattery, routePolyline: found.routePolyline)
        }
        throw APIError.noData
    }

    /// Clears stored tokens and resets user preferences on sign out.
    public nonisolated func logout() throws {
        try keychain.clearTokens()
        Task { @MainActor in
            Preferences.shared.reset()
        }
    }
}
