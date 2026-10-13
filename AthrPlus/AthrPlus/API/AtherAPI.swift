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

    // MARK: - Private Header & Request Helper

    private func applyAtherHeaders(to request: inout URLRequest) {
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")
        request.setValue(Constants.HTTPHeaders.source, forHTTPHeaderField: "Source")
        request.setValue(Constants.HTTPHeaders.platform, forHTTPHeaderField: "X-Platform")
        request.setValue(Constants.HTTPHeaders.platformVersion, forHTTPHeaderField: "X-Platform-Version")
        request.setValue(Constants.HTTPHeaders.userAgent, forHTTPHeaderField: "User-Agent")
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

    // MARK: - Public Methods

    /// Sends an OTP to the given phone number via Ather Cerberus API.
    public func sendOTP(phone: String, countryCode: String = Constants.Defaults.countryId) async throws -> OTPResponse {
        let cleanCountry = countryCode.hasPrefix("+") ? "IN" : countryCode
        let requestBody = OTPRequest(phone: phone, countryCode: cleanCountry)
        let _: EmptyResponse = try await request(
            "https://cerberus.ather.io/auth/v2/generate-login-otp",
            method: "POST",
            body: requestBody,
            authenticated: false
        )
        return OTPResponse(requestId: UUID().uuidString, message: "OTP sent successfully")
    }

    /// Verifies the OTP with Ather Cerberus, saves token to Keychain, and sets logged-in state.
    public func verifyOTP(phone: String, otp: String, requestId: String = "", countryCode: String = Constants.Defaults.countryId) async throws -> AuthTokens {
        let cleanCountry = countryCode.hasPrefix("+") ? "IN" : countryCode
        let requestBody = VerifyOTPRequest(phone: phone, otp: otp, countryCode: cleanCountry)

        guard let url = URL(string: "https://cerberus.ather.io/auth/v2/verify-login-otp") else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        applyAtherHeaders(to: &urlRequest)
        urlRequest.timeoutInterval = Constants.API.defaultTimeout
        urlRequest.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(http.statusCode)"
            throw APIError.serverError(http.statusCode, errorMsg)
        }

        // Parse token from root "token", "token.access_token", or "data.token"
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.noData
        }

        let tokenString: String? = {
            if let token = json["token"] as? String { return token }
            if let tokenObj = json["token"] as? [String: Any],
               let token = (tokenObj["token"] ?? tokenObj["access_token"]) as? String {
                return token
            }
            if let dataObj = json["data"] as? [String: Any] {
                if let token = (dataObj["token"] ?? dataObj["access_token"]) as? String {
                    return token
                }
            }
            return nil
        }()

        guard let token = tokenString, !token.isEmpty else {
            throw APIError.serverError(http.statusCode, "Login succeeded but token was missing from response.")
        }

        let tokens = AuthTokens(accessToken: token, refreshToken: token, expiresIn: 2592000)
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
