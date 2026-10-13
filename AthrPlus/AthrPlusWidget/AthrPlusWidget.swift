//
//  AthrPlusWidget.swift
//  AthrPlusWidget
//
//  Widget configuration for Athr+ Battery widget supporting small and medium families.
//

import WidgetKit
import SwiftUI

public struct AthrPlusWidget: Widget {
    public static let kind: String = "AthrPlusWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: WidgetTimelineProvider()
        ) { entry in
            BatteryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Athr+ Battery")
        .description("Battery status for your Ather scooter")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
