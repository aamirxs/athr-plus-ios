//
//  WidgetTimelineProvider.swift
//  AthrPlusWidget
//
//  Timeline provider reading scooter telemetry snapshot from App Group UserDefaults.
//

import WidgetKit
import SwiftUI

// MARK: - WidgetEntry

public struct WidgetEntry: TimelineEntry {
    public let date: Date
    public let batteryPercentage: Int
    public let isCharging: Bool
    public let chargingState: String
    public let ranges: [String: Double]
    public let isConnected: Bool
    public let lastUpdated: Date
    public let chargeLimiterTarget: Int?

    public init(
        date: Date = Date(),
        batteryPercentage: Int,
        isCharging: Bool,
        chargingState: String,
        ranges: [String: Double],
        isConnected: Bool,
        lastUpdated: Date,
        chargeLimiterTarget: Int? = nil
    ) {
        self.date = date
        self.batteryPercentage = batteryPercentage
        self.isCharging = isCharging
        self.chargingState = chargingState
        self.ranges = ranges
        self.isConnected = isConnected
        self.lastUpdated = lastUpdated
        self.chargeLimiterTarget = chargeLimiterTarget
    }

    /// Default placeholder entry: 75% battery, not charging.
    public static var placeholder: WidgetEntry {
        WidgetEntry(
            date: Date(),
            batteryPercentage: 75,
            isCharging: false,
            chargingState: "Disconnected",
            ranges: [
                "eco": 85.0,
                "ride": 72.0,
                "sport": 60.0,
                "warp": 47.0
            ],
            isConnected: true,
            lastUpdated: Date(),
            chargeLimiterTarget: 80
        )
    }
}

// MARK: - WidgetTimelineProvider

public struct WidgetTimelineProvider: TimelineProvider {
    public typealias Entry = WidgetEntry

    public init() {}

    public func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry.placeholder
    }

    public func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(WidgetEntry.placeholder)
        } else {
            let entry = fetchLatestEntry() ?? WidgetEntry.placeholder
            completion(entry)
        }
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let currentDate = Date()
        let entry = fetchLatestEntry() ?? WidgetEntry.placeholder

        // Refresh after 30 seconds as specified
        let nextUpdateDate = Calendar.current.date(
            byAdding: .second,
            value: 30,
            to: currentDate
        ) ?? currentDate.addingTimeInterval(30)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }

    // MARK: - App Group Data Loading

    public func fetchLatestEntry() -> WidgetEntry? {
        let appGroupSuite = Constants.AppGroup.identifier
        let sharedDefaults = UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard

        let chargeLimiterTarget = sharedDefaults.bool(forKey: Preferences.Keys.chargeLimiterEnabled)
            ? sharedDefaults.integer(forKey: Preferences.Keys.chargeLimiterTarget)
            : nil

        guard let jsonString = sharedDefaults.string(forKey: Preferences.Keys.lastSnapshotJSON),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let snapshot = try? decoder.decode(VehicleSnapshot.self, from: jsonData) else {
            return nil
        }

        return WidgetEntry(
            date: Date(),
            batteryPercentage: snapshot.batteryPercentage,
            isCharging: snapshot.isCharging,
            chargingState: snapshot.chargingState,
            ranges: snapshot.ranges,
            isConnected: snapshot.isConnected,
            lastUpdated: snapshot.lastUpdatedDate,
            chargeLimiterTarget: chargeLimiterTarget
        )
    }
}
