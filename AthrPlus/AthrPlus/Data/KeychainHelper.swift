import Foundation
import Security

public enum KeychainError: LocalizedError {
    case duplicateItem
    case itemNotFound
    case unhandledError(status: OSStatus)
    case stringConversionError

    public var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "The item already exists in the keychain."
        case .itemNotFound:
            return "The requested item was not found in the keychain."
        case .unhandledError(let status):
            return "Keychain operation failed with status code \(status)."
        case .stringConversionError:
            return "Failed to convert string to UTF-8 data."
        }
    }
}

public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()

    private let service: String

    public init(service: String = Constants.Keychain.serviceName) {
        self.service = service
    }

    public func save(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        case errSecItemNotFound:
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    public func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        return data
    }

    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Convenience Methods

    public func saveString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.stringConversionError
        }
        try save(data: data, forKey: key)
    }

    public func loadString(forKey key: String) -> String? {
        guard let data = load(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func saveTokens(_ tokens: AuthTokens) throws {
        try saveString(tokens.accessToken, forKey: Constants.Keychain.accessTokenKey)
        try saveString(tokens.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
    }

    public func loadAccessToken() -> String? {
        loadString(forKey: Constants.Keychain.accessTokenKey)
    }

    public func loadRefreshToken() -> String? {
        loadString(forKey: Constants.Keychain.refreshTokenKey)
    }

    public func clearTokens() throws {
        try delete(forKey: Constants.Keychain.accessTokenKey)
        try delete(forKey: Constants.Keychain.refreshTokenKey)
    }

    // MARK: - Key-Value Convenience (Non-throwing)

    @discardableResult
    public func save(key: String, value: String) -> Bool {
        do {
            try saveString(value, forKey: key)
            return true
        } catch {
            return false
        }
    }

    public func read(key: String) -> String? {
        loadString(forKey: key)
    }

    @discardableResult
    public func delete(key: String) -> Bool {
        do {
            try delete(forKey: key)
            return true
        } catch {
            return false
        }
    }
}
