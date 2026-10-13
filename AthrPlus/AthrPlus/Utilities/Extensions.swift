import SwiftUI

// MARK: - Date Extensions

public extension Date {
    /// Formats the date as a short relative time string (e.g. "just now", "2m ago", "1h ago", "3d ago").
    func relativeTimeString(relativeTo referenceDate: Date = Date()) -> String {
        let seconds = Int(referenceDate.timeIntervalSince(self))

        if seconds < 0 {
            return "just now"
        } else if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else if seconds < 604800 {
            let days = seconds / 86400
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }

    /// Convenience relative time string compared to current date.
    var relativeTime: String {
        relativeTimeString(relativeTo: Date())
    }
}

// MARK: - Double Extensions

public extension Double {
    /// Formats double as distance in kilometers with 1 decimal place (e.g. "12.4 km").
    var distanceKmString: String {
        String(format: "%.1f km", self)
    }

    /// Formats double as speed in km/h (e.g. "45 km/h").
    var speedKmhString: String {
        String(format: "%.0f km/h", self)
    }

    /// Formats double as speed in km/h with 1 decimal place (e.g. "45.2 km/h").
    var speedExactKmhString: String {
        String(format: "%.1f km/h", self)
    }
}

// MARK: - Color Extensions

public extension Color {
    static let batteryGreen = Color.green
    static let batteryYellow = Color.yellow
    static let batteryRed = Color.red

    /// Returns standard battery status color: Green >60%, Yellow 20-60%, Red <20%.
    static func batteryColor(for percentage: Int) -> Color {
        switch percentage {
        case 61...100:
            return .batteryGreen
        case 20...60:
            return .batteryYellow
        default:
            return .batteryRed
        }
    }

    /// Adaptive card background color for light and dark mode.
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
}

// MARK: - View Modifiers for Card Styling

public struct CardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public var elevation: CGFloat

    public init(cornerRadius: CGFloat = 16, padding: CGFloat = 16, elevation: CGFloat = 2) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.elevation = elevation
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: elevation, x: 0, y: elevation / 2)
    }
}

public extension View {
    /// Applies a clean, material-inspired card container with rounded corners, padding, and subtle shadow.
    func cardStyle(cornerRadius: CGFloat = 16, padding: CGFloat = 16, elevation: CGFloat = 2) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, padding: padding, elevation: elevation))
    }
}
