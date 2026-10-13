//
//  Models.swift
//  AthrPlus
//
//  SwiftData models for local persistence of battery records and ride history.
//

import Foundation
import SwiftData

@Model
public final class BatteryRecord {
    public var percentage: Int
    public var timestamp: Date
    public var isCharging: Bool
    public var source: String

    public init(
        percentage: Int,
        timestamp: Date = Date(),
        isCharging: Bool = false,
        source: String = "sync"
    ) {
        self.percentage = percentage
        self.timestamp = timestamp
        self.isCharging = isCharging
        self.source = source
    }

    public convenience init(from sample: BatterySample) {
        self.init(
            percentage: sample.percentage,
            timestamp: sample.date,
            isCharging: sample.isCharging,
            source: sample.source
        )
    }
}

@Model
public final class CachedRide {
    @Attribute(.unique) public var rideId: String
    public var startTime: Date
    public var endTime: Date
    public var distance: Double
    public var duration: Int
    public var averageSpeed: Double
    public var topSpeed: Double
    public var startBattery: Int
    public var endBattery: Int
    public var routePolyline: String?

    public init(
        rideId: String,
        startTime: Date,
        endTime: Date,
        distance: Double,
        duration: Int,
        averageSpeed: Double,
        topSpeed: Double,
        startBattery: Int,
        endBattery: Int,
        routePolyline: String? = nil
    ) {
        self.rideId = rideId
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.duration = duration
        self.averageSpeed = averageSpeed
        self.topSpeed = topSpeed
        self.startBattery = startBattery
        self.endBattery = endBattery
        self.routePolyline = routePolyline
    }

    public convenience init(from ride: Ride) {
        self.init(
            rideId: ride.id,
            startTime: ride.startDate,
            endTime: ride.endDate,
            distance: ride.distance,
            duration: Int(ride.duration),
            averageSpeed: ride.averageSpeed,
            topSpeed: ride.topSpeed,
            startBattery: ride.startBattery,
            endBattery: ride.endBattery,
            routePolyline: ride.routePolyline
        )
    }
}

// MARK: - ModelContainer Configuration

public enum ModelContainerFactory {
    public static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BatteryRecord.self,
            CachedRide.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()
}
