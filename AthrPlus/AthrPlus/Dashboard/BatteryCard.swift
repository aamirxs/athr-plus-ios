//
//  BatteryCard.swift
//  AthrPlus
//
//  Prominent battery telemetry card featuring circular progress, live charging indicators,
//  and connection state.
//

import SwiftUI

public struct BatteryCard: View {

    // MARK: - Properties

    public let snapshot: VehicleSnapshot

    @State private var isPulsing: Bool = false

    // MARK: - Initializer

    public init(snapshot: VehicleSnapshot) {
        self.snapshot = snapshot
    }

    // MARK: - Computed Properties

    private var batteryColor: Color {
        Color.batteryColor(for: snapshot.batteryPercentage)
    }

    private var progressValue: CGFloat {
        min(1.0, max(0.0, CGFloat(snapshot.batteryPercentage) / 100.0))
    }

    private var chargingStateText: String {
        if snapshot.isCharging {
            return "Charging"
        } else if snapshot.batteryPercentage >= 100 {
            return "Full"
        } else {
            return "Not Charging"
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 18) {
            // Circular Battery Ring
            ZStack {
                // Background Track
                Circle()
                    .stroke(
                        Color(uiColor: .systemGray5),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 176, height: 176)

                // Animated Progress Ring
                Circle()
                    .trim(from: 0.0, to: progressValue)
                    .stroke(
                        batteryColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 176, height: 176)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: snapshot.batteryPercentage)

                // Center Battery Info
                VStack(spacing: 4) {
                    if snapshot.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(batteryColor)
                            .scaleEffect(isPulsing ? 1.25 : 0.95)
                            .opacity(isPulsing ? 1.0 : 0.6)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isPulsing
                            )
                    }

                    Text("\(snapshot.batteryPercentage)%")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())

                    Text(chargingStateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(snapshot.isCharging ? batteryColor : .secondary)
                }
            }
            .padding(.top, 6)

            // Connection & Last Updated Footer
            HStack(spacing: 6) {
                // Connection Status Dot
                Circle()
                    .fill(snapshot.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(snapshot.isConnected ? "Connected" : "Disconnected")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Relative Updated Time
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(snapshot.lastUpdatedDate.relativeTime)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
        .onAppear {
            if snapshot.isCharging {
                isPulsing = true
            }
        }
        .onChange(of: snapshot.isCharging) { charging in
            isPulsing = charging
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery level \(snapshot.batteryPercentage) percent, \(chargingStateText), \(snapshot.isConnected ? "Scooter connected" : "Scooter disconnected")")
    }
}
