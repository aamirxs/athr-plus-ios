import Foundation
import SwiftUI
import Combine

// MARK: - Charging Session Model

/// Represents a contiguous period during which the scooter was actively charging.
public struct ChargingSession: Identifiable, Hashable, Sendable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let startPercentage: Int
    public let endPercentage: Int
    public let samples: [BatterySample]

    public init(
        id: String = UUID().uuidString,
        startDate: Date,
        endDate: Date,
        startPercentage: Int,
        endPercentage: Int,
        samples: [BatterySample] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
        self.samples = samples
    }

    /// Battery percentage gained during the session.
    public var percentageGained: Int {
        max(0, endPercentage - startPercentage)
    }

    /// Duration of the charging session in seconds.
    public var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    /// Human-readable duration string (e.g. "45m", "1h 15m").
    public var formattedDuration: String {
        let totalMinutes = Int(duration / 60)
        if totalMinutes < 60 {
            return "\(max(1, totalMinutes))m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
    }

    /// Formatted time window (e.g. "10:15 AM – 11:30 AM").
    public var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    /// Formatted calendar date of the session (e.g. "Today", "Yesterday", or "Oct 13").
    public var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) {
            return "Today"
        } else if calendar.isDateInYesterday(startDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: startDate)
        }
    }
}

// MARK: - Battery History View Model

@MainActor
public final class BatteryHistoryViewModel: ObservableObject {

    // MARK: - Time Range Enum

    public enum TimeRange: String, CaseIterable, Identifiable, Sendable {
        case sixHours = "6h"
        case twelveHours = "12h"
        case twentyFourHours = "24h"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .sixHours: return "6h"
            case .twelveHours: return "12h"
            case .twentyFourHours: return "24h"
            }
        }

        public var fullTitle: String {
            switch self {
            case .sixHours: return "6 Hours"
            case .twelveHours: return "12 Hours"
            case .twentyFourHours: return "24 Hours"
            }
        }

        public var hours: Double {
            switch self {
            case .sixHours: return 6.0
            case .twelveHours: return 12.0
            case .twentyFourHours: return 24.0
            }
        }
    }

    // MARK: - Published Properties

    @Published public var samples: [BatterySample] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String?
    @Published public var selectedSample: BatterySample?
    @Published public var timeRange: TimeRange = .twentyFourHours

    // MARK: - Initializer

    public init(samples: [BatterySample] = []) {
        self.samples = samples
    }

    // MARK: - Actions

    /// Loads historical telemetry samples for the given vehicle, filtering to relevant 24-hour samples.
    public func loadHistory(vehicleId: String) async {
        isLoading = true
        error = nil

        do {
            let fetched = try await AtherAPI.shared.getBatteryHistory(vehicleId: vehicleId)
            let filtered = ChargeEstimator.selectHistorySamples(fetched, windowHours: 24.0)
            self.samples = filtered
            self.isLoading = false

            // Clear selected sample if it's no longer part of the dataset
            if let selected = self.selectedSample, !filtered.contains(where: { $0.id == selected.id }) {
                self.selectedSample = nil
            }
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }

    // MARK: - Computed Properties

    /// Samples filtered according to the currently selected time range.
    public var filteredSamples: [BatterySample] {
        guard !samples.isEmpty else { return [] }
        return ChargeEstimator.selectHistorySamples(samples, windowHours: timeRange.hours)
    }

    /// Groups consecutive charging telemetry samples into discrete charging sessions.
    public var chargingSessions: [ChargingSession] {
        guard !filteredSamples.isEmpty else { return [] }

        // Sort chronologically ascending
        let sorted = filteredSamples.sorted { $0.timestamp < $1.timestamp }
        var sessions: [ChargingSession] = []
        var currentCluster: [BatterySample] = []

        // Max gap allowed between samples in the same charging session (30 minutes)
        let maxGapSeconds: TimeInterval = 1800

        for sample in sorted {
            if sample.isCharging {
                if let lastSample = currentCluster.last {
                    if sample.timestamp - lastSample.timestamp > maxGapSeconds {
                        // Finalize prior cluster due to time gap
                        if let session = buildSession(from: currentCluster) {
                            sessions.append(session)
                        }
                        currentCluster = [sample]
                    } else {
                        currentCluster.append(sample)
                    }
                } else {
                    currentCluster = [sample]
                }
            } else {
                if !currentCluster.isEmpty {
                    if let session = buildSession(from: currentCluster) {
                        sessions.append(session)
                    }
                    currentCluster = []
                }
            }
        }

        // Finalize any open cluster
        if !currentCluster.isEmpty, let session = buildSession(from: currentCluster) {
            sessions.append(session)
        }

        return sessions
    }

    private func buildSession(from cluster: [BatterySample]) -> ChargingSession? {
        guard let first = cluster.first, let last = cluster.last else { return nil }

        let startDate = first.date
        // Provide at least a nominal 5-minute interval if only one sample was captured
        let endDate = cluster.count == 1 ? startDate.addingTimeInterval(300) : last.date
        let sessionId = "session_\(Int(first.timestamp))_\(Int(last.timestamp))"

        return ChargingSession(
            id: sessionId,
            startDate: startDate,
            endDate: endDate,
            startPercentage: first.percentage,
            endPercentage: last.percentage,
            samples: cluster
        )
    }

    /// Minimum battery percentage recorded in the active time range.
    public var minPercentage: Int {
        guard !filteredSamples.isEmpty else { return 0 }
        return filteredSamples.map(\.percentage).min() ?? 0
    }

    /// Maximum battery percentage recorded in the active time range.
    public var maxPercentage: Int {
        guard !filteredSamples.isEmpty else { return 100 }
        return filteredSamples.map(\.percentage).max() ?? 100
    }

    /// Most recently recorded battery percentage.
    public var currentPercentage: Int? {
        filteredSamples.last?.percentage ?? samples.last?.percentage
    }

    /// Total count of charging sessions in the active time range.
    public var totalChargingSessionsCount: Int {
        chargingSessions.count
    }

    /// Cumulative time spent charging across all sessions in the active window.
    public var totalChargingDuration: TimeInterval {
        chargingSessions.reduce(0) { $0 + $1.duration }
    }

    /// Formatted total charging duration (e.g. "2h 15m" or "45m").
    public var formattedTotalChargingTime: String {
        let totalMinutes = Int(totalChargingDuration / 60)
        if totalMinutes == 0 {
            return "0m"
        } else if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Mock Data Helper for Previews & Testing

extension BatteryHistoryViewModel {
    public static func mock() -> BatteryHistoryViewModel {
        let now = Date().timeIntervalSince1970
        var mockSamples: [BatterySample] = []

        // Generate 48 samples over 24 hours (1 every 30 minutes)
        for i in 0..<48 {
            let timestamp = now - Double(47 - i) * 1800.0
            let pct: Int
            let isCharging: Bool
            let source: String = (i % 4 == 0) ? "cached" : "measured"

            if i < 18 {
                // Riding down from 92% to 34%
                pct = max(34, 92 - Int(Double(i) * 3.2))
                isCharging = false
            } else if i < 32 {
                // Charging session from 34% up to 86%
                pct = min(86, 34 + Int(Double(i - 18) * 3.7))
                isCharging = true
            } else {
                // Slight discharge and idle: 86% down to 78%
                pct = max(78, 86 - Int(Double(i - 32) * 0.5))
                isCharging = false
            }

            mockSamples.append(BatterySample(
                percentage: pct,
                timestamp: timestamp,
                isCharging: isCharging,
                source: source
            ))
        }

        return BatteryHistoryViewModel(samples: mockSamples)
    }
}
