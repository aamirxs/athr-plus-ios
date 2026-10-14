import Foundation

public enum Constants {
    public enum API {
        public static let baseURL = "https://cerberus.ather.io"
        public static let version = "v1"
        public static let defaultTimeout: TimeInterval = 20.0
        public static let generateOtpURL = "https://cerberus.ather.io/api/v2/req/9a11"
        public static let verifyOtpURL = "https://cerberus.ather.io/api/v2/req/4c33"
    }

    public enum HTTPHeaders {
        public static let source = "ATHER_APP_IOS/13.5.1"
        public static let platform = "iOS"
        public static let platformVersion = "17.5.1"
        public static let userAgent = "ktor-client"
    }

    public enum Keychain {
        public static let serviceName = "com.athrplus.ios.keychain"
        public static let accessTokenKey = "athr_access_token"
        public static let refreshTokenKey = "athr_refresh_token"
    }

    public enum AppGroup {
        public static let identifier = "group.plus.athr.ios"
    }

    public enum Polling {
        public static let snapshotInterval: TimeInterval = 5.0
        public static let widgetRefreshInterval: TimeInterval = 30.0
    }

    public static let snapshotPollingInterval: TimeInterval = Polling.snapshotInterval

    public enum BackgroundTasks {
        public static let refreshIdentifier = "group.plus.athr.ios.refresh"
        public static let snapshotSyncIdentifier = "group.plus.athr.ios.snapshot"
    }

    public enum Defaults {
        public static let countryCode = "+91"
        public static let countryId = "IN"
        public static let chargeTarget = 80
    }

    // Top-level aliases for direct access
    public static let apiBaseURL = API.baseURL
    public static let apiVersion = API.version
    public static let keychainService = Keychain.serviceName
    public static let appGroupIdentifier = AppGroup.identifier
    public static let widgetRefreshInterval: TimeInterval = Polling.widgetRefreshInterval
    public static let defaultCountryCode = Defaults.countryCode
}
