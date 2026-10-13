import SwiftUI
import Charts

/// A Swift Charts view displaying historical battery percentage telemetry over time,
/// including visual charging session highlights, measured vs. cached distinction,
/// and interactive scrubbing for detailed sample inspection.
public struct BatteryChartView: View {

    // MARK: - Properties

    @ObservedObject public var viewModel: BatteryHistoryViewModel

    // MARK: - Initializer

    public init(viewModel: BatteryHistoryViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with legend and selection dismissal
            chartHeader

            if viewModel.filteredSamples.isEmpty {
                emptyStateView
            } else {
                chartContainer
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1.5)
    }

    // MARK: - Subviews

    private var chartHeader: some View {
        HStack(alignment: .center) {
            // Legend
            HStack(spacing: 12) {
                legendItem(
                    color: Color.green,
                    title: "Measured",
                    shape: .circle(filled: true)
                )

                legendItem(
                    color: Color.green.opacity(0.45),
                    title: "Cached",
                    shape: .circle(filled: false)
                )

                legendItem(
                    color: Color.green.opacity(0.2),
                    title: "Charging",
                    shape: .rectangle
                )
            }

            Spacer()

            if viewModel.selectedSample != nil {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.selectedSample = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Reset")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var chartContainer: some View {
        Chart {
            // 1. Charging Sessions Background Highlights
            ForEach(viewModel.chargingSessions) { session in
                RectangleMark(
                    xStart: .value("Session Start", session.startDate),
                    xEnd: .value("Session End", session.endDate),
                    yStart: .value("Min Battery", 0),
                    yEnd: .value("Max Battery", 100)
                )
                .foregroundStyle(Color.green.opacity(0.12))
            }

            // 2. Area Under Battery Line (Gradient Fill)
            ForEach(viewModel.filteredSamples) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("Battery %", sample.percentage)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.32),
                            Color.green.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // 3. Line for Battery Percentage
            ForEach(viewModel.filteredSamples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Battery %", sample.percentage)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.green,
                            Color(hue: 0.38, saturation: 0.85, brightness: 0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }

            // 4. Point Marks for Individual Telemetry Samples
            ForEach(viewModel.filteredSamples) { sample in
                PointMark(
                    x: .value("Time", sample.date),
                    y: .value("Battery %", sample.percentage)
                )
                .symbolSize(pointSymbolSize(for: sample))
                .foregroundStyle(pointColor(for: sample))
            }

            // 5. Interactive Scrubbing / Selection Overlay Indicator
            if let selected = viewModel.selectedSample {
                RuleMark(x: .value("Selected Time", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .annotation(
                        position: .top,
                        alignment: .center,
                        spacing: 8
                    ) {
                        sampleDetailPopup(for: selected)
                    }

                // Outer Halo
                PointMark(
                    x: .value("Selected Point Time", selected.date),
                    y: .value("Selected Point Battery", selected.percentage)
                )
                .symbolSize(110)
                .foregroundStyle(Color.primary.opacity(0.2))

                // Core Dot
                PointMark(
                    x: .value("Selected Core Time", selected.date),
                    y: .value("Selected Core Battery", selected.percentage)
                )
                .symbolSize(50)
                .foregroundStyle(selected.isCharging ? Color.yellow : Color.green)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel {
                    if let percentage = value.as(Int.self) {
                        Text("\(percentage)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisDesiredCount)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.12))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let location = gesture.location
                                guard let date: Date = proxy.value(atX: location.x) else { return }

                                if let closest = closestSample(to: date, in: viewModel.filteredSamples) {
                                    if viewModel.selectedSample?.id != closest.id {
                                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                                            viewModel.selectedSample = closest
                                        }
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 260)
        .animation(.easeInOut(duration: 0.35), value: viewModel.timeRange)
        .animation(.easeInOut(duration: 0.35), value: viewModel.samples.count)
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 38))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No Battery History")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            Text("No telemetry samples recorded for the past \(viewModel.timeRange.displayName).")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }

    // MARK: - Popup Annotation

    @ViewBuilder
    private func sampleDetailPopup(for sample: BatterySample) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.batteryColor(for: sample.percentage))
                    .frame(width: 8, height: 8)

                Text("\(sample.percentage)%")
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundColor(.primary)

                if sample.isCharging {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text("Charging")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.16))
                    .clipShape(Capsule())
                }
            }

            HStack(spacing: 6) {
                Text(formattedTime(sample.date))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(sample.source.capitalized)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(sample.source.lowercased() == "measured" ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
        )
    }

    // MARK: - Helpers

    private enum LegendShape {
        case circle(filled: Bool)
        case rectangle
    }

    @ViewBuilder
    private func legendItem(color: Color, title: String, shape: LegendShape) -> some View {
        HStack(spacing: 5) {
            switch shape {
            case .circle(let filled):
                if filled {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .background(Circle().fill(color.opacity(0.3)))
                        .frame(width: 7, height: 7)
                }
            case .rectangle:
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 12, height: 8)
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func pointSymbolSize(for sample: BatterySample) -> CGFloat {
        if viewModel.selectedSample?.id == sample.id {
            return 80
        }
        return sample.isCharging ? 36 : 18
    }

    private func pointColor(for sample: BatterySample) -> Color {
        let isMeasured = sample.source.lowercased() == "measured"
        let baseColor = sample.isCharging ? Color.yellow : Color.green
        return baseColor.opacity(isMeasured ? 1.0 : 0.45)
    }

    private var xAxisDesiredCount: Int {
        switch viewModel.timeRange {
        case .sixHours:
            return 5
        case .twelveHours:
            return 6
        case .twentyFourHours:
            return 6
        }
    }

    private func closestSample(to date: Date, in samples: [BatterySample]) -> BatterySample? {
        samples.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct BatteryChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BatteryChartView(viewModel: BatteryHistoryViewModel.mock())
                .padding()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.light)

            BatteryChartView(viewModel: BatteryHistoryViewModel.mock())
                .padding()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
        }
    }
}
