import Foundation

// MARK: - Authentication Models

public struct NotificationMedium: Codable, Sendable {
    public let whatsapp: Bool
    public let sms: Bool

    public init(whatsapp: Bool = false, sms: Bool = true) {
        self.whatsapp = whatsapp
        self.sms = sms
    }
}

public struct OTPRequest: Codable, Sendable {
    public let email: String
    public let contactNo: String
    public let countryCode: String
    public let notificationMedium: NotificationMedium

    public init(phone: String, countryCode: String = "IN", notificationMedium: NotificationMedium = NotificationMedium()) {
        self.email = ""
        self.contactNo = phone
        self.countryCode = countryCode
        self.notificationMedium = notificationMedium
    }

    enum CodingKeys: String, CodingKey {
        case email
        case contactNo = "contact_no"
        case countryCode = "country_code"
        case notificationMedium = "notification_medium"
    }
}

public struct OTPResponse: Sendable {
    /// Server message, e.g. "OTP generated and stored successfully."
    public let message: String
    /// Remaining verification attempts (server tracks these per OTP session).
    public let attemptsLeft: Int?
    public let totalAttempts: Int?

    public init(message: String = "OTP sent successfully", attemptsLeft: Int? = nil, totalAttempts: Int? = nil) {
        self.message = message
        self.attemptsLeft = attemptsLeft
        self.totalAttempts = totalAttempts
    }
}

public struct VerifyOTPRequest: Codable, Sendable {
    public let email: String
    public let contactNo: String
    public let userOtp: String
    public let isMobileLogin: Bool
    public let countryCode: String

    public init(phone: String, otp: String, countryCode: String = "IN") {
        self.email = ""
        self.contactNo = phone
        self.userOtp = otp
        self.isMobileLogin = true
        self.countryCode = countryCode
    }

    enum CodingKeys: String, CodingKey {
        case email
        case contactNo = "contact_no"
        case userOtp
        case isMobileLogin = "is_mobile_login"
        case countryCode = "country_code"
    }
}

public struct AuthTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int

    public init(accessToken: String, refreshToken: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - Vehicle Models

public struct Vehicle: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let model: String
    public let registrationNumber: String
    public let color: String

    public init(id: String, name: String, model: String, registrationNumber: String, color: String) {
        self.id = id
        self.name = name
        self.model = model
        self.registrationNumber = registrationNumber
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case model
        case registrationNumber = "registration_number"
        case color
    }
}

public struct VehicleSnapshot: Codable, Sendable {
    public let batteryPercentage: Int
    public let isCharging: Bool
    public let chargingState: String
    public let latitude: Double
    public let longitude: Double
    public let odometer: Double
    public let ranges: [String: Double]
    public let lastUpdated: TimeInterval
    public let isConnected: Bool

    public init(
        batteryPercentage: Int,
        isCharging: Bool,
        chargingState: String,
        latitude: Double,
        longitude: Double,
        odometer: Double,
        ranges: [String: Double],
        lastUpdated: TimeInterval,
        isConnected: Bool
    ) {
        self.batteryPercentage = batteryPercentage
        self.isCharging = isCharging
        self.chargingState = chargingState
        self.latitude = latitude
        self.longitude = longitude
        self.odometer = odometer
        self.ranges = ranges
        self.lastUpdated = lastUpdated
        self.isConnected = isConnected
    }

    enum CodingKeys: String, CodingKey {
        case batteryPercentage = "battery_percentage"
        case isCharging = "is_charging"
        case chargingState = "charging_state"
        case latitude
        case longitude
        case odometer
        case ranges
        case lastUpdated = "last_updated"
        case isConnected = "is_connected"
    }

    public var lastUpdatedDate: Date {
        Date(timeIntervalSince1970: lastUpdated)
    }

    public func range(for mode: RideMode) -> Double? {
        ranges[mode.rawValue]
    }
}

public struct BatterySample: Codable, Identifiable, Hashable, Sendable {
    public var id: TimeInterval { timestamp }
    public let percentage: Int
    public let timestamp: TimeInterval
    public let isCharging: Bool
    public let source: String

    public init(percentage: Int, timestamp: TimeInterval, isCharging: Bool, source: String) {
        self.percentage = percentage
        self.timestamp = timestamp
        self.isCharging = isCharging
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case percentage
        case timestamp
        case isCharging = "is_charging"
        case source
    }

    public var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Ride Models

public struct Ride: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let distance: Double
    public let duration: TimeInterval
    public let averageSpeed: Double
    public let topSpeed: Double
    public let startBattery: Int
    public let endBattery: Int
    public let routePolyline: String?

    public init(
        id: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        distance: Double,
        duration: TimeInterval,
        averageSpeed: Double,
        topSpeed: Double,
        startBattery: Int,
        endBattery: Int,
        routePolyline: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.duration = duration
        self.averageSpeed = averageSpeed
        self.topSpeed = topSpeed
        self.startBattery = startBattery
        self.endBattery = endBattery
        self.routePolyline = routePolyline
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case distance
        case duration
        case averageSpeed = "average_speed"
        case topSpeed = "top_speed"
        case startBattery = "start_battery"
        case endBattery = "end_battery"
        case routePolyline = "route_polyline"
    }

    public var startDate: Date {
        Date(timeIntervalSince1970: startTime)
    }

    public var endDate: Date {
        Date(timeIntervalSince1970: endTime)
    }

    public var batteryConsumed: Int {
        max(0, startBattery - endBattery)
    }
}

public struct RideCoordinate: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: TimeInterval?
    public let speed: Double?
    public let elevation: Double?

    public init(
        latitude: Double,
        longitude: Double,
        timestamp: TimeInterval? = nil,
        speed: Double? = nil,
        elevation: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
        self.elevation = elevation
    }

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case timestamp
        case speed
        case elevation
    }
}

public struct RideDetail: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let distance: Double
    public let duration: TimeInterval
    public let averageSpeed: Double
    public let topSpeed: Double
    public let startBattery: Int
    public let endBattery: Int
    public let routePolyline: String?
    public let coordinates: [RideCoordinate]
    public let elevationGain: Double?
    public let maxLeanAngle: Double?

    public init(
        id: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        distance: Double,
        duration: TimeInterval,
        averageSpeed: Double,
        topSpeed: Double,
        startBattery: Int,
        endBattery: Int,
        routePolyline: String? = nil,
        coordinates: [RideCoordinate] = [],
        elevationGain: Double? = nil,
        maxLeanAngle: Double? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.duration = duration
        self.averageSpeed = averageSpeed
        self.topSpeed = topSpeed
        self.startBattery = startBattery
        self.endBattery = endBattery
        self.routePolyline = routePolyline
        self.coordinates = coordinates
        self.elevationGain = elevationGain
        self.maxLeanAngle = maxLeanAngle
    }

    public init(
        ride: Ride,
        coordinates: [RideCoordinate] = [],
        elevationGain: Double? = nil,
        maxLeanAngle: Double? = nil
    ) {
        self.id = ride.id
        self.startTime = ride.startTime
        self.endTime = ride.endTime
        self.distance = ride.distance
        self.duration = ride.duration
        self.averageSpeed = ride.averageSpeed
        self.topSpeed = ride.topSpeed
        self.startBattery = ride.startBattery
        self.endBattery = ride.endBattery
        self.routePolyline = ride.routePolyline
        self.coordinates = coordinates
        self.elevationGain = elevationGain
        self.maxLeanAngle = maxLeanAngle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case distance
        case duration
        case averageSpeed = "average_speed"
        case topSpeed = "top_speed"
        case startBattery = "start_battery"
        case endBattery = "end_battery"
        case routePolyline = "route_polyline"
        case coordinates
        case elevationGain = "elevation_gain"
        case maxLeanAngle = "max_lean_angle"
    }

    public var ride: Ride {
        Ride(
            id: id,
            startTime: startTime,
            endTime: endTime,
            distance: distance,
            duration: duration,
            averageSpeed: averageSpeed,
            topSpeed: topSpeed,
            startBattery: startBattery,
            endBattery: endBattery,
            routePolyline: routePolyline
        )
    }
}

// MARK: - Commands & Modes

public enum VehicleCommand: String, Codable, CaseIterable, Sendable {
    case startCharging = "START_CHARGING"
    case stopCharging = "STOP_CHARGING"

    public var displayName: String {
        switch self {
        case .startCharging:
            return "Start Charging"
        case .stopCharging:
            return "Stop Charging"
        }
    }
}

public struct CommandRequest: Codable, Sendable {
    public let command: String

    public init(command: String) {
        self.command = command
    }

    public init(command: VehicleCommand) {
        self.command = command.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case command
    }
}

public enum RideMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case eco
    case ride
    case sport
    case warp

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .eco:
            return "Eco"
        case .ride:
            return "Ride"
        case .sport:
            return "Sport"
        case .warp:
            return "Warp"
        }
    }

    public var rangeMultiplier: Double {
        switch self {
        case .eco:
            return 1.0
        case .ride:
            return 0.85
        case .sport:
            return 0.70
        case .warp:
            return 0.55
        }
    }
}
