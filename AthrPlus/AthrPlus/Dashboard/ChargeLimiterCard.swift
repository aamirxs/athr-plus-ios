//
//  ChargeLimiterCard.swift
//  AthrPlus
//
//  Charge limiter control card featuring target adjustment, visual progress,
//  completion estimates, and smart charging stop action.
//

import SwiftUI

public struct ChargeLimiterCard: View {

    // MARK: - Properties

    @Binding public var isEnabled: Bool
    @Binding public var targetPercentage: Int
    public let currentPercentage: Int
    public let isCharging: Bool
    public let estimatedCompletion: Date?
    public var onStopCharging: () -> Void
    public var onTargetChanged: ((Int) -> Void)?

    // MARK: - Initializer

    public init(
        isEnabled: Binding<Bool>,
        targetPercentage: Binding<Int>,
        currentPercentage: Int,
        isCharging: Bool,
        estimatedCompletion: Date?,
        onStopCharging: @escaping () -> Void,
        onTargetChanged: ((Int) -> Void)? = nil
    ) {
        self._isEnabled = isEnabled
        self._targetPercentage = targetPercentage
        self.currentPercentage = currentPercentage
        self.isCharging = isCharging
        self.estimatedCompletion = estimatedCompletion
        self.onStopCharging = onStopCharging
        self.onTargetChanged = onTargetChanged
    }

    // MARK: - Computed Properties

    private var brandGreen: Color {
        Color(red: 0.13, green: 0.77, blue: 0.36)
    }

    private var formattedEstimate: String {
        guard isCharging else {
            return "Connect charger to charge towards \(targetPercentage)%"
        }

        if currentPercentage >= targetPercentage {
            return "Charge limit reached"
        }

        guard let completion = estimatedCompletion else {
            return "Estimating completion time..."
        }

        let remainingSeconds = completion.timeIntervalSinceNow
        if remainingSeconds <= 0 {
            return "Reaching target shortly"
        }

        let minutes = max(1, Int(remainingSeconds / 60))
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let timeString = timeFormatter.string(from: completion)

        let calendar = Calendar.current
        let dayPrefix = calendar.isDateInToday(completion) ? "Today at" : "Tomorrow at"

        if minutes < 60 {
            return "~\(minutes) min (\(dayPrefix) \(timeString))"
        } else {
            let hours = minutes / 60
            let remMinutes = minutes % 60
            let durationText = remMinutes == 0 ? "\(hours)h" : "\(hours)h \(remMinutes)m"
            return "~\(durationText) (\(dayPrefix) \(timeString))"
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Title and Toggle
            HStack {
                ZStack {
                    Circle()
                        .fill(brandGreen.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "bolt.badge.checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(brandGreen)
                }

                Text("Charge Limiter")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(brandGreen)
            }

            if isEnabled {
                enabledView
            } else {
                disabledView
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1.5)
        .animation(.easeInOut(duration: 0.25), value: isEnabled)
    }

    // MARK: - Subviews

    private var disabledView: some View {
        Text("Limits maximum charging level to prevent battery degradation and preserve cell health over time.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.top, 2)
    }

    private var enabledView: some View {
        VStack(spacing: 16) {
            Divider()

            // Current % -> Target % Visual
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)

                    Text("\(currentPercentage)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("TARGET")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(brandGreen)

                    Text("\(targetPercentage)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(brandGreen)
                }
            }
            .padding(.horizontal, 8)

            // Progress Bar (Current vs Target)
            progressBarView

            // Target Slider (50% - 100%, step: 5)
            VStack(spacing: 6) {
                Slider(
                    value: Binding<Double>(
                        get: { Double(targetPercentage) },
                        set: { newValue in
                            let stepped = Int((newValue / 5.0).rounded() * 5.0)
                            targetPercentage = stepped
                            onTargetChanged?(stepped)
                        }
                    ),
                    in: 50...100,
                    step: 5
                )
                .tint(brandGreen)
                .accessibilityLabel("Target Charge Limit")
                .accessibilityValue("\(targetPercentage) percent")

                HStack {
                    Text("50%")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Quick Preset Chips
                    HStack(spacing: 6) {
                        presetChip(80)
                        presetChip(90)
                        presetChip(100)
                    }

                    Spacer()

                    Text("100%")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }

            // Completion Estimate Row
            HStack(spacing: 8) {
                Image(systemName: isCharging ? "timer" : "powerplug")
                    .font(.caption.weight(.bold))
                    .foregroundColor(isCharging ? brandGreen : .secondary)

                Text(formattedEstimate)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isCharging && currentPercentage >= targetPercentage ? brandGreen : .secondary)

                Spacer()
            }
            .padding(.horizontal, 4)

            // "Stop Charging" Button (when charging and at/above target)
            if isCharging && currentPercentage >= targetPercentage {
                Button(action: onStopCharging) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                            .font(.subheadline.weight(.bold))
                        Text("Stop Charging")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, 4)
                .accessibilityLabel("Stop scooter charging")
            }
        }
    }

    private var progressBarView: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let currentWidth = max(0, min(totalWidth, totalWidth * CGFloat(currentPercentage) / 100.0))
            let targetX = max(0, min(totalWidth, totalWidth * CGFloat(targetPercentage) / 100.0))

            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(height: 10)

                // Current Charge Fill
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.batteryColor(for: currentPercentage))
                    .frame(width: currentWidth, height: 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPercentage)

                // Target Marker Indicator
                Rectangle()
                    .fill(brandGreen)
                    .frame(width: 3, height: 16)
                    .position(x: targetX, y: 5)
            }
        }
        .frame(height: 16)
        .padding(.horizontal, 4)
    }

    private func presetChip(_ value: Int) -> some View {
        Button {
            targetPercentage = value
            onTargetChanged?(value)
        } label: {
            Text("\(value)%")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(targetPercentage == value ? brandGreen.opacity(0.18) : Color(uiColor: .systemGray6))
                .foregroundColor(targetPercentage == value ? brandGreen : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
