//
//  ChargeEstimatorTests.swift
//  AthrPlusTests
//
//  Unit tests verifying ChargeEstimator logic for time estimation, filtering, scaling, and deadline calculation.
//

import XCTest
@testable import AthrPlus

final class ChargeEstimatorTests: XCTestCase {

    /// Normal charging case: 50% to 80% at 0.5% per minute = 60 minutes.
    func testEstimateChargeTime_normalCase() {
        let seconds = ChargeEstimator.estimateChargeTime(
            currentPercent: 50,
            targetPercent: 80,
            chargingRatePerMinute: 0.5
        )
        let minutes = seconds / 60.0
        XCTAssertEqual(minutes, 60.0, accuracy: 0.001, "Charging 30% at 0.5%/min should take exactly 60 minutes.")
    }

    /// When current percentage is already at or above target, remaining time must be 0.
    func testEstimateChargeTime_alreadyAtTarget() {
        let aboveTarget = ChargeEstimator.estimateChargeTime(
            currentPercent: 85,
            targetPercent: 80,
            chargingRatePerMinute: 0.5
        )
        XCTAssertEqual(aboveTarget, 0, "Already above target should return 0 seconds.")

        let atTarget = ChargeEstimator.estimateChargeTime(
            currentPercent: 80,
            targetPercent: 80,
            chargingRatePerMinute: 0.5
        )
        XCTAssertEqual(atTarget, 0, "Already at exact target should return 0 seconds.")
    }

    /// Zero or negative rate should return infinity or 0 (not charging).
    func testEstimateChargeTime_zeroRate() {
        let result = ChargeEstimator.estimateChargeTime(
            currentPercent: 50,
            targetPercent: 80,
            chargingRatePerMinute: 0.0
        )
        XCTAssertTrue(
            result.isInfinite || result == 0 || result > 100_000,
            "Zero rate should indicate infinity or 0 if inactive."
        )
    }

    /// Filtering history samples: only preserves samples within the last 24 hours relative to the latest sample.
    func testSelectHistorySamples_filters24Hours() {
        let referenceTime = 1_000_000.0
        let sampleOld = BatterySample(
            percentage: 40,
            timestamp: referenceTime - (25.0 * 3600.0),
            isCharging: false,
            source: "test"
        )
        let sampleWithin24h = BatterySample(
            percentage: 60,
            timestamp: referenceTime - (12.0 * 3600.0),
            isCharging: true,
            source: "test"
        )
        let sampleLatest = BatterySample(
            percentage: 75,
            timestamp: referenceTime,
            isCharging: false,
            source: "test"
        )

        let filtered = ChargeEstimator.selectHistorySamples([sampleOld, sampleWithin24h, sampleLatest], windowHours: 24.0)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(where: { $0.percentage == 60 }))
        XCTAssertTrue(filtered.contains(where: { $0.percentage == 75 }))
        XCTAssertFalse(filtered.contains(where: { $0.percentage == 40 }))
    }

    /// Deduplication removes samples with the same timestamp.
    func testSelectHistorySamples_deduplicates() {
        let timestamp = 1_000_000.0
        let sample1 = BatterySample(percentage: 50, timestamp: timestamp, isCharging: false, source: "test")
        let sampleDuplicate = BatterySample(percentage: 52, timestamp: timestamp, isCharging: false, source: "test")
        let sample2 = BatterySample(percentage: 55, timestamp: timestamp + 300.0, isCharging: true, source: "test")

        let result = ChargeEstimator.selectHistorySamples([sample1, sampleDuplicate, sample2], windowHours: 24.0)

        XCTAssertEqual(result.count, 2, "Duplicate timestamp sample should be removed.")
        XCTAssertEqual(result[0].timestamp, timestamp)
        XCTAssertEqual(result[1].timestamp, timestamp + 300.0)
    }

    /// Verifies range scaling across all 4 ride modes: eco=1.0x, ride=0.85x, sport=0.7x, warp=0.55x.
    func testScaleRange_allModes() {
        let baseRange = 100.0
        let eco = ChargeEstimator.scaleRange(baseRange: baseRange, mode: .eco)
        let ride = ChargeEstimator.scaleRange(baseRange: baseRange, mode: .ride)
        let sport = ChargeEstimator.scaleRange(baseRange: baseRange, mode: .sport)
        let warp = ChargeEstimator.scaleRange(baseRange: baseRange, mode: .warp)

        XCTAssertEqual(eco, 100.0, accuracy: 0.001, "Eco multiplier should be 1.0x")
        XCTAssertEqual(ride, 85.0, accuracy: 0.001, "Ride multiplier should be 0.85x")
        XCTAssertEqual(sport, 70.0, accuracy: 0.001, "Sport multiplier should be 0.70x")
        XCTAssertEqual(warp, 55.0, accuracy: 0.001, "Warp multiplier should be 0.55x")
    }

    /// Derives charging rate from recent samples and computes target deadline.
    func testEstimateDeadline_withSamples() {
        let baseTime = 1_000_000.0
        // 50% at baseTime
        let s1 = BatterySample(percentage: 50, timestamp: baseTime, isCharging: true, source: "test")
        // 65% at baseTime + 1800s (30 mins) -> 15% gained in 30 mins = 0.5%/min
        let s2 = BatterySample(percentage: 65, timestamp: baseTime + 1800.0, isCharging: true, source: "test")

        // Target: 80%. Remaining: 80 - 65 = 15%. At 0.5%/min -> 30 min (1800s).
        let deadline = ChargeEstimator.estimateDeadline(
            currentPercent: 65,
            targetPercent: 80,
            samples: [s1, s2]
        )

        XCTAssertNotNil(deadline, "Should successfully calculate a deadline date.")
        if let deadline = deadline {
            let remainingSeconds = deadline.timeIntervalSince(Date())
            XCTAssertEqual(remainingSeconds, 1800.0, accuracy: 2.0, "Expected remaining time to be ~1800 seconds (30 minutes).")
        }
    }
}
