import Foundation
import Combine

public final class Preferences: ObservableObject {
    public static let shared = Preferences()

    public enum Keys {
        public static let selectedVehicleId = "selectedVehicleId"
        public static let chargeLimiterTarget = "chargeLimiterTarget"
        public static let chargeLimiterEnabled = "chargeLimiterEnabled"
        public static let lastSnapshotJSON = "lastSnapshotJSON"
        public static let isLoggedIn = "isLoggedIn"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaults(suiteName: Constants.AppGroup.identifier) ?? .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.chargeLimiterTarget: Constants.Defaults.chargeTarget,
            Keys.chargeLimiterEnabled: false,
            Keys.isLoggedIn: false
        ])

        self._selectedVehicleId = Published(initialValue: defaults.string(forKey: Keys.selectedVehicleId))
        self._chargeLimiterTarget = Published(initialValue: defaults.object(forKey: Keys.chargeLimiterTarget) as? Int ?? Constants.Defaults.chargeTarget)
        self._chargeLimiterEnabled = Published(initialValue: defaults.bool(forKey: Keys.chargeLimiterEnabled))
        self._lastSnapshotJSON = Published(initialValue: defaults.string(forKey: Keys.lastSnapshotJSON))
        self._isLoggedIn = Published(initialValue: defaults.bool(forKey: Keys.isLoggedIn))
    }

    @Published public var selectedVehicleId: String? {
        didSet {
            defaults.set(selectedVehicleId, forKey: Keys.selectedVehicleId)
        }
    }

    @Published public var chargeLimiterTarget: Int {
        didSet {
            defaults.set(chargeLimiterTarget, forKey: Keys.chargeLimiterTarget)
        }
    }

    @Published public var chargeLimiterEnabled: Bool {
        didSet {
            defaults.set(chargeLimiterEnabled, forKey: Keys.chargeLimiterEnabled)
        }
    }

    @Published public var lastSnapshotJSON: String? {
        didSet {
            defaults.set(lastSnapshotJSON, forKey: Keys.lastSnapshotJSON)
        }
    }

    @Published public var isLoggedIn: Bool {
        didSet {
            defaults.set(isLoggedIn, forKey: Keys.isLoggedIn)
        }
    }

    /// Saves snapshot as JSON string into shared UserDefaults for widgets.
    public func saveLastSnapshot(_ snapshot: VehicleSnapshot) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(snapshot),
           let jsonString = String(data: data, encoding: .utf8) {
            self.lastSnapshotJSON = jsonString
        }
    }

    /// Loads the cached snapshot from the JSON string.
    public func loadLastSnapshot() -> VehicleSnapshot? {
        guard let jsonString = lastSnapshotJSON,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(VehicleSnapshot.self, from: data)
    }

    /// Clears user session preferences upon logout.
    public func reset() {
        selectedVehicleId = nil
        chargeLimiterTarget = Constants.Defaults.chargeTarget
        chargeLimiterEnabled = false
        lastSnapshotJSON = nil
        isLoggedIn = false
    }
}
