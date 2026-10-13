import Foundation

public enum ChargeEstimator {
    /// Estimates remaining charging time in seconds to reach the target percentage.
    /// Handles edge cases: returns 0 if already at or above target, or if not charging (rate is zero or negative).
    public static func estimateChargeTime(
        currentPercent: Int,
        targetPercent: Int,
        chargingRatePerMinute: Double
    ) -> TimeInterval {
        guard currentPercent < targetPercent else { return 0 }
        guard chargingRatePerMinute > 0 else { return 0 }

        let deltaPercent = Double(targetPercent - currentPercent)
        let minutesNeeded = deltaPercent / chargingRatePerMinute
        return max(0, minutesNeeded * 60.0)
    }

    /// Filters samples to the last N hours relative to the most recent sample,
    /// sorts them in chronological order, and deduplicates consecutive or repeated timestamps.
    public static func selectHistorySamples(
        _ samples: [BatterySample],
        windowHours: Double
    ) -> [BatterySample] {
        guard !samples.isEmpty, windowHours > 0 else { return [] }

        guard let latestTimestamp = samples.map(\.timestamp).max() else {
            return []
        }

        let cutoff = latestTimestamp - (windowHours * 3600.0)
        let filtered = samples.filter { $0.timestamp >= cutoff }
        let sorted = filtered.sorted { $0.timestamp < $1.timestamp }

        var seenTimestamps = Set<TimeInterval>()
        var deduplicated: [BatterySample] = []

        for sample in sorted {
            if seenTimestamps.insert(sample.timestamp).inserted {
                deduplicated.append(sample)
            }
        }

        return deduplicated
    }

    /// Scales the base range according to the ride mode using predefined multipliers:
    /// Eco: 1.0, Ride: 0.85, Sport: 0.70, Warp: 0.55.
    public static func scaleRange(baseRange: Double, mode: RideMode) -> Double {
        guard baseRange > 0 else { return 0.0 }
        return max(0.0, baseRange * mode.rangeMultiplier)
    }

    /// Estimates the deadline date when the target battery percentage will be reached
    /// by calculating the active charging rate from recent telemetry samples.
    public static func estimateDeadline(
        currentPercent: Int,
        targetPercent: Int,
        samples: [BatterySample]
    ) -> Date? {
        guard currentPercent < targetPercent else {
            return Date()
        }

        let chargingSamples = samples
            .filter { $0.isCharging }
            .sorted { $0.timestamp < $1.timestamp }

        guard chargingSamples.count >= 2,
              let first = chargingSamples.first,
              let last = chargingSamples.last else {
            return nil
        }

        let deltaPercent = Double(last.percentage - first.percentage)
        let deltaSeconds = last.timestamp - first.timestamp

        guard deltaSeconds > 0, deltaPercent > 0 else {
            return nil
        }

        let deltaMinutes = deltaSeconds / 60.0
        let chargingRatePerMinute = deltaPercent / deltaMinutes

        let chargeDuration = estimateChargeTime(
            currentPercent: currentPercent,
            targetPercent: targetPercent,
            chargingRatePerMinute: chargingRatePerMinute
        )

        guard chargeDuration > 0 else {
            return nil
        }

        return Date().addingTimeInterval(chargeDuration)
    }
}
