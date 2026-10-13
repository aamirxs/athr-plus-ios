import Foundation

public final class AuthInterceptor: @unchecked Sendable {
    public static let shared = AuthInterceptor()

    private let session: URLSession
    private let lock = NSLock()
    private var refreshTask: Task<AuthTokens, Error>?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Executes an HTTP request, adding the Bearer token if available.
    /// If a 401 Unauthorized status is returned, attempts a thread-safe token refresh and retries the request once.
    public func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var signedRequest = request
        if let token = KeychainHelper.shared.loadAccessToken() {
            signedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: signedRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            // Perform or wait for thread-safe token refresh
            let newTokens = try await refreshToken()

            // Retry the original request with the freshly acquired token
            var retryRequest = request
            retryRequest.setValue("Bearer \(newTokens.accessToken)", forHTTPHeaderField: "Authorization")

            let (retryData, retryResponse) = try await session.data(for: retryRequest)
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }

            if retryHttpResponse.statusCode == 401 {
                throw APIError.tokenExpired
            }

            return (retryData, retryHttpResponse)
        }

        return (data, httpResponse)
    }

    /// Thread-safe token refresh ensuring only one network refresh call executes at any given time.
    public func refreshToken() async throws -> AuthTokens {
        lock.lock()
        if let ongoingTask = refreshTask {
            lock.unlock()
            return try await ongoingTask.value
        }

        let task = Task<AuthTokens, Error> {
            defer {
                lock.lock()
                refreshTask = nil
                lock.unlock()
            }
            return try await performTokenRefresh()
        }

        refreshTask = task
        lock.unlock()

        return try await task.value
    }

    private func performTokenRefresh() async throws -> AuthTokens {
        guard let refreshToken = KeychainHelper.shared.loadRefreshToken() else {
            throw APIError.unauthorized
        }

        guard let url = URL(string: "\(Constants.API.baseURL)/\(Constants.API.version)/auth/refresh") else {
            throw APIError.invalidURL
        }

        var refreshRequest = URLRequest(url: url)
        refreshRequest.httpMethod = "POST"
        refreshRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        refreshRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        refreshRequest.setValue("UTF-8", forHTTPHeaderField: "Accept-Charset")
        refreshRequest.setValue(Constants.HTTPHeaders.source, forHTTPHeaderField: "Source")
        refreshRequest.setValue(Constants.HTTPHeaders.platform, forHTTPHeaderField: "X-Platform")
        refreshRequest.setValue(Constants.HTTPHeaders.platformVersion, forHTTPHeaderField: "X-Platform-Version")
        refreshRequest.setValue(Constants.HTTPHeaders.userAgent, forHTTPHeaderField: "User-Agent")

        let body = ["refresh_token": refreshToken]
        refreshRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: refreshRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                try? KeychainHelper.shared.clearTokens()
                throw APIError.tokenExpired
            }
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let tokens: AuthTokens
        do {
            tokens = try decoder.decode(AuthTokens.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }

        try KeychainHelper.shared.saveTokens(tokens)
        return tokens
    }
}
