//
//  AppUpdateChecker.swift
//  AthrPlus
//
//  Checks GitHub releases API for latest Athr+ updates and handles version comparison.
//

import SwiftUI
import Foundation

/// Information about a remote release fetched from GitHub.
public struct UpdateInfo: Identifiable, Sendable {
    public var id: String { version }
    public let version: String
    public let releaseNotes: String
    public let downloadURL: URL?
    public let isNewer: Bool
    public let publishedAt: Date?

    public init(
        version: String,
        releaseNotes: String,
        downloadURL: URL?,
        isNewer: Bool,
        publishedAt: Date? = nil
    ) {
        self.version = version
        self.releaseNotes = releaseNotes
        self.downloadURL = downloadURL
        self.isNewer = isNewer
        self.publishedAt = publishedAt
    }
}

/// ObservableObject that queries GitHub repository releases to check for updates.
@MainActor
public final class AppUpdateChecker: ObservableObject {
    public static let repoOwner = "karmugilen"
    public static let repoName = "athr-plus"
    public static let releasesEndpoint = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"

    private let lastCheckedKey = "athr_last_update_check_timestamp"

    @Published public var isChecking: Bool = false
    @Published public var updateInfo: UpdateInfo? = nil
    @Published public var showUpdateAlert: Bool = false
    @Published public var isUpToDate: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var lastCheckedDate: Date? = nil

    public var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var currentBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public init() {
        if let timestamp = UserDefaults.standard.object(forKey: lastCheckedKey) as? Date {
            self.lastCheckedDate = timestamp
        }
    }

    /// Formatted description of the last update check time.
    public var formattedLastChecked: String {
        guard let date = lastCheckedDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Check the latest GitHub release.
    public func checkForUpdates(manual: Bool = true) async {
        guard !isChecking else { return }

        isChecking = true
        errorMessage = nil
        isUpToDate = false

        guard let url = URL(string: Self.releasesEndpoint) else {
            errorMessage = "Invalid GitHub releases URL."
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        // GitHub API requires a User-Agent header
        request.setValue("AthrPlus-iOS/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 404 {
                    // No releases published yet on this repository
                    isUpToDate = true
                    recordCheckTime()
                    isChecking = false
                    return
                }
                throw URLError(.badServerResponse)
            }

            // Parse GitHub Release payload
            struct GitHubRelease: Decodable {
                let tagName: String
                let name: String?
                let body: String?
                let htmlUrl: String
                let publishedAt: String?

                enum CodingKeys: String, CodingKey {
                    case tagName = "tag_name"
                    case name
                    case body
                    case htmlUrl = "html_url"
                    case publishedAt = "published_at"
                }
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, data: data)
            let releaseVersion = release.tagName
            let downloadURL = URL(string: release.htmlUrl)
            let notes = release.body ?? release.name ?? "New version available."

            let isNewer = Self.isVersion(releaseVersion, newerThan: currentAppVersion)

            let isoFormatter = ISO8601DateFormatter()
            let pubDate = release.publishedAt.flatMap { isoFormatter.date(from: $0) }

            let info = UpdateInfo(
                version: releaseVersion,
                releaseNotes: notes,
                downloadURL: downloadURL,
                isNewer: isNewer,
                publishedAt: pubDate
            )

            self.updateInfo = info
            self.isUpToDate = !isNewer
            recordCheckTime()

            if isNewer && manual {
                self.showUpdateAlert = true
            }
        } catch {
            if manual {
                self.errorMessage = "Could not check for updates. Please verify your connection."
            }
        }

        self.isChecking = false
    }

    private func recordCheckTime() {
        let now = Date()
        self.lastCheckedDate = now
        UserDefaults.standard.set(now, forKey: lastCheckedKey)
    }

    /// Compares two version strings (e.g., "v1.2.0" and "1.0.0").
    public static func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))

        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }

        let count = max(remoteParts.count, currentParts.count)
        for i in 0..<count {
            let remoteNum = i < remoteParts.count ? remoteParts[i] : 0
            let currentNum = i < currentParts.count ? currentParts[i] : 0
            if remoteNum > currentNum {
                return true
            } else if remoteNum < currentNum {
                return false
            }
        }
        return false
    }
}
