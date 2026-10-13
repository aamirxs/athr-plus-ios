import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case tokenExpired
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String?)
    case noData

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The requested URL is invalid."
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .networkError(let error):
            return "Network connection error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to process data from server: \(error.localizedDescription)"
        case .serverError(let code, let message):
            if let message = message, !message.isEmpty {
                return "Server error (\(code)): \(message)"
            }
            return "Server responded with status code \(code)."
        case .noData:
            return "No data received from the server."
        }
    }
}
