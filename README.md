# Athr+ for iOS 🛵⚡

<p align="center">
  <b>An independent, restriction-free companion app and home-screen widget for Ather electric scooters, built natively for iOS with SwiftUI.</b>
</p>

---

## Overview

**Athr+ for iOS** is a 100% native recreation of the open-source [karmugilen/athr-plus](https://github.com/karmugilen/athr-plus) Android companion app. It gives Ather scooter owners unconstrained, restriction-free access to their vehicle’s telemetry:

- 🔋 **Live Battery & Scooter Status**: Real-time battery percentage with circular ring indicator, charging status, odometer, and per-mode estimated ranges (Eco, Ride, Sport, Warp).
- ⚡ **Smart Charge Limiter**: Set target percentage (50%–100%) with estimated completion deadlines and automatic remote stop command triggers.
- 📈 **24-Hour Battery History**: Interactive Swift Charts visualization with charging session breakdown, lowest/highest levels, and sample scrubbing.
- 🗺️ **Ride History & Telemetry**: Full ride list grouped by date, route map with polyline decoder, speed averages, top speed, and battery consumption stats.
- 📍 **Scooter & Phone Location Maps**: MapKit integration showing scooter location with one-tap Apple Maps navigation, plus live 1-second phone GPS tracking.
- 📱 **Home Screen Widgets (WidgetKit)**: Small and Medium home-screen widgets sharing telemetry via App Groups (`group.plus.athr.ios`).
- 🔄 **Background Synchronization**: `BGAppRefreshTask` and `BGProcessingTask` routines keeping battery and charge-limit checks running in the background.
- 🔐 **Secure Authentication**: International phone OTP login with country calling code picker (+91 India default) and Keychain JWT token persistence with auto-refresh.

---

## Architecture & Zero-Dependency Design

Athr+ iOS is engineered with the **Ponytail philosophy**: the simplest, leanest solution using exclusively Apple native standard library and frameworks:

| Feature | Android Version | Athr+ iOS Implementation | Framework |
|---|---|---|---|
| **UI** | Jetpack Compose (Material 3) | Native SwiftUI (iOS 16+) | `SwiftUI` |
| **Networking** | Retrofit + OkHttp | Actor-based URLSession + async/await | `Foundation` |
| **Persistence** | Room (SQLite) | SwiftData (`@Model`) | `SwiftData` |
| **Auth & Tokens** | DataStore | Apple Security Keychain | `Security` |
| **Maps & Routes** | Google Maps SDK | Apple MapKit | `MapKit` |
| **Charts** | MPAndroidChart | Swift Charts | `Charts` |
| **Widgets** | Glance | WidgetKit (`StaticConfiguration`) | `WidgetKit` |
| **Background** | WorkManager | BackgroundTasks (`BGTaskScheduler`) | `BackgroundTasks` |
| **Estimates Math** | Rust FFI (`ather-math` via JNI) | Pure Swift `ChargeEstimator` | `Foundation` |

**Zero third-party dependencies.** No CocoaPods, no Carthage, no heavy SPM packages required.

---

## Project Structure

```
AthrPlus/
├── AthrPlus.xcodeproj/                   # Pre-configured Xcode Project
│   └── project.pbxproj
├── project.yml                           # XcodeGen configuration (optional)
├── AthrPlus/                             # Main iOS App Target
│   ├── AthrPlusApp.swift                 # @main app entry, BGTask handlers
│   ├── ContentView.swift                 # Root navigation & TabView
│   ├── Info.plist                        # Permissions, background modes
│   ├── AthrPlus.entitlements             # App Groups capability
│   ├── Assets.xcassets/                  # App icon, accent color (#00B050)
│   ├── API/
│   │   ├── AtherAPI.swift                # URLSession actor service
│   │   ├── APIModels.swift               # Codable telemetry & vehicle models
│   │   ├── AuthInterceptor.swift         # Token refresh & 401 handling
│   │   └── APIError.swift                # Localized API errors
│   ├── Auth/
│   │   ├── AuthViewModel.swift           # Auth state machine & timer
│   │   ├── CountryCodePicker.swift       # Searchable dial codes (+91 default)
│   │   ├── LoginView.swift               # Phone number entry view
│   │   └── OTPView.swift                 # 6-digit SMS autofill OTP view
│   ├── Dashboard/
│   │   ├── DashboardViewModel.swift      # 5-second polling & state
│   │   ├── DashboardView.swift           # Main scrollable dashboard
│   │   ├── BatteryCard.swift             # Animated battery percentage ring
│   │   ├── ScooterInfoCard.swift         # Telemetry grid & mode ranges
│   │   └── ChargeLimiterCard.swift       # Target slider & stop trigger
│   ├── History/
│   │   ├── BatteryHistoryViewModel.swift # Telemetry filtering & clustering
│   │   ├── BatteryChartView.swift        # Swift Charts interactive graph
│   │   └── BatteryHistoryView.swift      # Full history view & sessions
│   ├── Map/
│   │   ├── ScooterMapView.swift          # Scooter GPS pin & Apple Maps link
│   │   └── PhoneLocationView.swift       # 1-second live GPS tracking
│   ├── Rides/
│   │   ├── RideHistoryView.swift         # Grouped ride logs
│   │   ├── RideDetailView.swift          # Ride stats & polyline map
│   │   └── RideMapView.swift             # Google polyline decoder on MapKit
│   ├── Settings/
│   │   ├── SettingsView.swift            # Preferences, UPI support, logout
│   │   └── AppUpdateChecker.swift        # GitHub release version checker
│   ├── Data/
│   │   ├── Models.swift                  # SwiftData @Model types
│   │   ├── KeychainHelper.swift          # Token Keychain wrapper
│   │   └── Preferences.swift             # App Group UserDefaults
│   ├── Math/
│   │   └── ChargeEstimator.swift         # Pure Swift estimation algorithms
│   └── Utilities/
│       ├── Constants.swift               # URLs, keys, intervals
│       └── Extensions.swift              # Battery colors, time formatting
├── AthrPlusWidget/                       # Home Screen Widget Extension Target
│   ├── AthrPlusWidgetBundle.swift        # @main widget bundle
│   ├── AthrPlusWidget.swift              # StaticConfiguration (.small, .medium)
│   ├── WidgetTimelineProvider.swift      # App Group snapshot decoder
│   ├── BatteryWidgetView.swift           # Small & medium SwiftUI widgets
│   ├── Info.plist
│   └── AthrPlusWidget.entitlements
└── AthrPlusTests/                        # Unit Test Target
    └── ChargeEstimatorTests.swift        # ChargeEstimator unit tests
```

---

## How to Build & Run (macOS / Xcode)

### Requirements
- Mac with macOS Ventura (13.0) or newer
- Xcode 15.0 or newer
- iOS 16.0+ deployment target

### Direct Xcode Build
1. Open `AthrPlus/AthrPlus.xcodeproj` in Xcode.
2. Select the `AthrPlus` scheme and choose your target simulator (e.g. **iPhone 16**).
3. Press `Cmd + R` to build and run.

### Running Unit Tests
In Xcode, press `Cmd + U` or run via command line:
```bash
xcodebuild test -project AthrPlus/AthrPlus.xcodeproj -scheme AthrPlus -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Optional: Regenerating Project with XcodeGen
If you prefer regenerating the `.xcodeproj` file cleanly from `project.yml`:
```bash
brew install xcodegen
cd AthrPlus
xcodegen generate
```

---

## Configuration & Customization

- **Ather API Endpoint**: Defined in `AthrPlus/Utilities/Constants.swift` (`Constants.API.baseURL`). Defaults to `https://api.atherenergy.com`.
- **App Group Identifier**: Set to `group.plus.athr.ios` in `Constants.AppGroup.identifier` and both `.entitlements` files.
- **Bundle ID**: Default is `plus.athr.ios` and `plus.athr.ios.widget`.

---

## License

Open-source under MIT License. Companion project for [karmugilen/athr-plus](https://github.com/karmugilen/athr-plus).
