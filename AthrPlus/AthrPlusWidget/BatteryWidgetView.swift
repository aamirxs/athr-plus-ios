//
//  BatteryWidgetView.swift
//  AthrPlusWidget
//
//  Polished, information-dense SwiftUI views for Athr+ small and medium home screen widgets.
//

import WidgetKit
import SwiftUI

// MARK: - Color Helper

private func batteryLevelColor(for percentage: Int) -> Color {
    switch percentage {
    case 61...100:
        return Color(red: 0.0, green: 0.82, blue: 0.42) // Ather electric green
    case 20...60:
        return Color(red: 1.0, green: 0.75, blue: 0.0) // Battery caution yellow
    default:
        return Color(red: 0.95, green: 0.25, blue: 0.2) // Critical red
    }
}

// MARK: - Root Widget Entry View

public struct BatteryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    public let entry: WidgetEntry

    public init(entry: WidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallBatteryWidgetView(entry: entry)
            case .systemMedium:
                MediumBatteryWidgetView(entry: entry)
            default:
                SmallBatteryWidgetView(entry: entry)
            }
        }
        .containerBackgroundIfAvailable()
    }
}

// MARK: - Small Widget View

public struct SmallBatteryWidgetView: View {
    public let entry: WidgetEntry

    public init(entry: WidgetEntry) {
        self.entry = entry
    }

    private var ecoRangeKm: Int {
        Int(entry.ranges["eco"] ?? entry.ranges["ECO"] ?? 85.0)
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Header Row: Status dot & Charging indicator
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.isConnected ? batteryLevelColor(for: entry.batteryPercentage) : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text("Athr+")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if entry.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(batteryLevelColor(for: entry.batteryPercentage))
                        .widgetAccentable()
                }
            }

            Spacer(minLength: 0)

            // Battery Percentage (large, bold, centered)
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.batteryPercentage)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Small battery bar underneath (colored by level)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.18))
                        Capsule()
                            .fill(batteryLevelColor(for: entry.batteryPercentage))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(entry.batteryPercentage) / 100.0)))
                            .widgetAccentable()
                    }
                }
                .frame(height: 5)
            }

            Spacer(minLength: 0)

            // Primary Mode Range
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundColor(batteryLevelColor(for: entry.batteryPercentage))
                Text("Eco: \(ecoRangeKm) km")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Last sync time at bottom (small, gray)
            Text("Updated \(entry.lastUpdated.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
    }
}

// MARK: - Medium Widget View

public struct MediumBatteryWidgetView: View {
    public let entry: WidgetEntry

    public init(entry: WidgetEntry) {
        self.entry = entry
    }

    private var ecoKm: Int { Int(entry.ranges["eco"] ?? entry.ranges["ECO"] ?? 85.0) }
    private var rideKm: Int { Int(entry.ranges["ride"] ?? entry.ranges["RIDE"] ?? 72.0) }
    private var sportKm: Int { Int(entry.ranges["sport"] ?? entry.ranges["SPORT"] ?? 60.0) }
    private var warpKm: Int { Int(entry.ranges["warp"] ?? entry.ranges["WARP"] ?? 47.0) }

    public var body: some View {
        HStack(spacing: 16) {
            // Left Side: Battery % with ring/bar and charging indicator
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 8)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(100, max(0, entry.batteryPercentage))) / 100.0)
                        .stroke(
                            batteryLevelColor(for: entry.batteryPercentage),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()

                    VStack(spacing: 1) {
                        if entry.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(batteryLevelColor(for: entry.batteryPercentage))
                                .widgetAccentable()
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(entry.batteryPercentage)")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Text(entry.isCharging ? "Charging" : (entry.isConnected ? "Connected" : "Parked"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 82, height: 82)

                // Subtitle indicator
                Text(entry.chargingState.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 90)

            // Right Side: Mode ranges, connection status, sync time, limiter
            VStack(alignment: .leading, spacing: 6) {
                // Connection status dot + text & last sync time
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.isConnected ? batteryLevelColor(for: entry.batteryPercentage) : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(entry.isConnected ? "Live Telemetry" : "Cached")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Updated \(entry.lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                // Per-mode ranges in compact rows
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        ModeRangePill(mode: "Eco", range: ecoKm, color: Color(red: 0.0, green: 0.82, blue: 0.42))
                        ModeRangePill(mode: "Ride", range: rideKm, color: Color.blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ModeRangePill(mode: "Sport", range: sportKm, color: Color.orange)
                        ModeRangePill(mode: "Warp", range: warpKm, color: Color.purple)
                    }
                }

                // Charge Limiter Bar if active (showing current → target)
                if let target = entry.chargeLimiterTarget {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Charge Limit")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(entry.batteryPercentage)% → \(target)%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(batteryLevelColor(for: entry.batteryPercentage))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.18))

                                Capsule()
                                    .fill(batteryLevelColor(for: entry.batteryPercentage))
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(entry.batteryPercentage) / 100.0)))
                                    .widgetAccentable()

                                // Target indicator pin
                                Rectangle()
                                    .fill(Color.primary)
                                    .frame(width: 2, height: 8)
                                    .offset(x: max(0, min(geo.size.width - 2, geo.size.width * CGFloat(target) / 100.0 - 1)))
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Mode Range Pill View

private struct ModeRangePill: View {
    let mode: String
    let range: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(mode)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Spacer(minLength: 2)
            Text("\(range) km")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Compatibility Background Modifier

private extension View {
    @ViewBuilder
    func containerBackgroundIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(Color(uiColor: .systemBackground), for: .widget)
        } else {
            self.background(Color(uiColor: .systemBackground))
        }
    }
}
