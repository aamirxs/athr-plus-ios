//
//  ScooterInfoCard.swift
//  AthrPlus
//
//  Card displaying scooter identity, telemetry grid (odometer, location, connection, registration),
//  and mode-specific estimated range pills.
//

import SwiftUI

public struct ScooterInfoCard: View {

    // MARK: - Properties

    public let vehicle: Vehicle?
    public let snapshot: VehicleSnapshot
    public var onViewMap: (() -> Void)?

    // MARK: - Initializer

    public init(
        vehicle: Vehicle?,
        snapshot: VehicleSnapshot,
        onViewMap: (() -> Void)? = nil
    ) {
        self.vehicle = vehicle
        self.snapshot = snapshot
        self.onViewMap = onViewMap
    }

    // MARK: - Formatted Values

    private var formattedOdometer: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formattedNumber = formatter.string(from: NSNumber(value: Int(snapshot.odometer))) ?? "\(Int(snapshot.odometer))"
        return "\(formattedNumber) km"
    }

    private func rangeForMode(_ mode: RideMode) -> Double {
        if let recordedRange = snapshot.range(for: mode) {
            return recordedRange
        }
        // Fallback estimated range based on Ather 450X 105km standard Eco capacity
        let baseEco = (Double(snapshot.batteryPercentage) / 100.0) * 105.0
        return ChargeEstimator.scaleRange(baseRange: baseEco, mode: mode)
    }

    private func colorForMode(_ mode: RideMode) -> Color {
        switch mode {
        case .eco:
            return .green
        case .ride:
            return .blue
        case .sport:
            return .orange
        case .warp:
            return .red
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Scooter Name & Model
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle?.name ?? "Ather Scooter")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primary)

                    Text(vehicle?.model ?? "450X Gen 3")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let colorName = vehicle?.color, !colorName.isEmpty {
                    Text(colorName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: .systemGray5))
                        .clipShape(Capsule())
                }
            }

            Divider()

            // Telemetry Grid (2 Columns)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 14
            ) {
                // Odometer
                infoCell(
                    icon: "gauge",
                    iconColor: .indigo,
                    title: "Odometer",
                    valueView: AnyView(
                        Text(formattedOdometer)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    )
                )

                // Location with tappable link
                infoCell(
                    icon: "location.fill",
                    iconColor: .blue,
                    title: "Location",
                    valueView: AnyView(
                        Button {
                            onViewMap?()
                        } label: {
                            HStack(spacing: 3) {
                                Text("View on Map")
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundColor(.accentColor)
                        }
                    )
                )

                // Connection
                infoCell(
                    icon: "antenna.radiowaves.left.and.right",
                    iconColor: snapshot.isConnected ? .green : .gray,
                    title: "Connection",
                    valueView: AnyView(
                        Text(snapshot.isConnected ? "Online" : "Offline")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(snapshot.isConnected ? .primary : .secondary)
                    )
                )

                // Registration
                infoCell(
                    icon: "car.fill",
                    iconColor: .orange,
                    title: "Registration",
                    valueView: AnyView(
                        Text(vehicle?.registrationNumber.isEmpty == false ? vehicle!.registrationNumber : "—")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    )
                )
            }

            Divider()

            // Per-Mode Range Section
            VStack(alignment: .leading, spacing: 10) {
                Text("ESTIMATED RANGE")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(RideMode.allCases) { mode in
                        modeRangePill(mode: mode)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
    }

    // MARK: - Subviews

    private func infoCell(icon: String, iconColor: Color, title: String, valueView: AnyView) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                valueView
            }

            Spacer(minLength: 0)
        }
    }

    private func modeRangePill(mode: RideMode) -> some View {
        let modeColor = colorForMode(mode)
        let modeRange = rangeForMode(mode)

        return VStack(spacing: 3) {
            Text(mode.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundColor(modeColor)

            Text("\(Int(modeRange)) km")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(modeColor.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(modeColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.displayName) mode estimated range: \(Int(modeRange)) kilometers")
    }
}
