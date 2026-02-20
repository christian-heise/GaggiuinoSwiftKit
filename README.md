# GaggiuinoSwiftKit

A modern Swift package for communicating with [Gaggiuino](https://github.com/Zer0-bit/gaggiuino) espresso machines over your local network.

[![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20|%20macOS%20|%20watchOS%20|%20tvOS%20|%20visionOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)

## Features

- ✅ **Swift 6 Concurrency** - Built with modern async/await patterns and strict concurrency checking
- ✅ **Type-Safe API** - Fully typed models for shots, profiles, settings, and machine status
- ✅ **Zero Dependencies** - Pure Swift implementation using only Foundation
- ✅ **Comprehensive Testing** - 24 tests including hardware-in-the-loop validation
- ✅ **Sendable-Safe** - All types are `Sendable` for safe concurrent access
- ✅ **Computed Properties** - Automatic scaling of raw values (pressure in bar, temperature in °C, etc.)
- ✅ **Flexible Decoding** - Handles both string and numeric API responses
- ✅ **Cross-Platform** - Works on iOS, macOS, watchOS, tvOS, and visionOS

## Requirements

- iOS 18.0+ / macOS 15.0+ / watchOS 11.0+ / tvOS 18.0+ / visionOS 2.0+
- Swift 6.0+
- Xcode 16.0+
- A Gaggiuino-equipped espresso machine on your local network

## Installation

### Swift Package Manager

Add GaggiuinoSwiftKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christian-heise/GaggiuinoSwiftKit.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies...
2. Enter package URL: `https://github.com/christian-heise/GaggiuinoSwiftKit.git`
3. Select version and add to your target

## Quick Start

```swift
import GaggiuinoSwiftKit

// Create service instance
let service = GaggiuinoService()

// Or with custom URL
let service = GaggiuinoService(baseURL: "http://192.168.1.100")

// Check if machine is reachable
if await service.isHealthy() {
    print("✅ Connected to Gaggiuino!")
}

// Get current machine status
let status = try await service.getMachineStatus()
print("Temperature: \(status.temperature)°C")
print("Pressure: \(status.pressure) bar")
print("Active Profile: \(status.profileName)")

// Fetch latest shot
let shot = try await service.getLatestShot()
print("Shot duration: \(shot.durationSeconds) seconds")
if let maxPressure = shot.datapoints.pressureInBar?.max() {
    print("Max pressure: \(maxPressure) bar")
}

// List all profiles
let profiles = try await service.getProfiles()
for profile in profiles {
    let marker = profile.selected == true ? "✓" : " "
    print("[\(marker)] \(profile.name)")
}
```

## Usage Examples

### Fetching Shot Data

```swift
// Get the most recent shot
let latestShot = try await service.getLatestShot()

// Get a specific shot by ID
let shot = try await service.getShot(id: 42)

// Get recent shots (default limit: 10)
let recentShots = try await service.getRecentShots(limit: 5)

// Access shot data with automatic scaling
if let pressureData = shot.datapoints.pressureInBar {
    let avgPressure = pressureData.reduce(0, +) / Double(pressureData.count)
    print("Average pressure: \(avgPressure) bar")
}

if let temps = shot.datapoints.temperatureInCelsius {
    print("Temperature range: \(temps.min()!) - \(temps.max()!)°C")
}
```

### Working with Profiles

```swift
// List all profiles
let profiles = try await service.getProfiles()

// Find active profile
let activeProfile = profiles.first { $0.selected == true }

// Examine profile details
if let profile = activeProfile {
    print("Profile: \(profile.name)")
    print("Water temp: \(profile.waterTemperature ?? 0)°C")
    
    if let phases = profile.phases {
        for (index, phase) in phases.enumerated() {
            print("Phase \(index + 1): \(phase.type)")
            print("  Target: \(phase.target.end)")
        }
    }
}

// Switch to a different profile
try await service.selectProfile(id: 5)
```

### Live Machine Status

```swift
// Poll machine status in real-time
Task {
    while true {
        let status = try await service.getMachineStatus()
        print("🌡️ \(status.temperature)°C | 💧 \(status.waterLevel)% | ⚡️ \(status.pressure) bar")
        
        try await Task.sleep(for: .seconds(1))
    }
}
```

### Error Handling

```swift
do {
    let shot = try await service.getLatestShot()
    print("Got shot #\(shot.id)")
} catch GaggiuinoServiceError.timeout {
    print("Request timed out - is the machine on?")
} catch GaggiuinoServiceError.notFound {
    print("No shots found")
} catch GaggiuinoServiceError.connectionFailed(let detail) {
    print("Connection failed: \(detail)")
} catch {
    print("Unexpected error: \(error)")
}
```

## API Reference

### GaggiuinoService

The main service class for communicating with Gaggiuino machines.

#### Initialization

```swift
init(
    baseURL: String = "http://gaggiuino.local",
    requestTimeout: TimeInterval = 5,
    resourceTimeout: TimeInterval = 10
)
```

#### System Methods

- `isHealthy() async -> Bool` - Check if machine is reachable
- `getMachineStatus() async throws -> MachineStatus` - Get current live status

#### Shot Methods

- `getLatestShotId() async throws -> Int` - Get ID of most recent shot
- `getLatestShot() async throws -> GaggiuinoShot` - Fetch latest shot
- `getShot(id: Int) async throws -> GaggiuinoShot` - Fetch specific shot
- `getShots(ids: [Int]) async throws -> [GaggiuinoShot]` - Fetch multiple shots
- `getRecentShots(limit: Int = 10) async throws -> [GaggiuinoShot]` - Fetch recent shots

#### Profile Methods

- `getProfiles() async throws -> [GaggiuinoProfile]` - List all profiles
- `selectProfile(id: Int) async throws -> Bool` - Activate a profile
- `deleteProfile(id: Int) async throws -> Bool` - Delete a profile

### Data Models

#### GaggiuinoShot
```swift
struct GaggiuinoShot: Codable, Sendable, Identifiable {
    let id: Int
    let timestamp: Int           // Unix timestamp
    let duration: Int            // Deciseconds (divide by 10 for seconds)
    let profile: GaggiuinoProfile
    let datapoints: ShotDatapoints
    
    var date: Date               // Computed
    var durationSeconds: Double  // Computed
}
```

#### ShotDatapoints

All raw values (pressure, temperature, weight, flow) are stored as integers and automatically scaled via computed properties:

```swift
// Raw values (as stored by API)
let pressure: [Int]?          // Raw: 90 = 9.0 bar

// Scaled computed properties (already converted to proper units)
var pressureInBar: [Double]?              // In bar
var temperatureInCelsius: [Double]?       // In °C
var shotWeightInGrams: [Double]?          // In grams
var pumpFlowInMLPerSecond: [Double]?      // In mL/s
var timeInShotSeconds: [Double]?          // In seconds
```

#### MachineStatus
```swift
struct MachineStatus: Decodable, Sendable {
    let profileId: Int
    let profileName: String
    let temperature: Double       // °C
    let targetTemperature: Double // °C
    let pressure: Double          // bar
    let waterLevel: Int           // 0-100%
    let weight: Double            // grams
    let brewSwitchState: Bool
    let steamSwitchState: Bool
    let upTime: Int               // seconds
}
```

#### GaggiuinoProfile
```swift
struct GaggiuinoProfile: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let selected: Bool?
    let waterTemperature: Int?    // °C
    let phases: [ProfilePhase]?
    let globalStopConditions: [String: Double]?
}
```

### Error Types

```swift
enum GaggiuinoServiceError: Error, LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case timeout
    case notFound
    case invalidResponse
    case decodingFailed(String)
}
```

## Testing

The package includes 24 comprehensive tests:

```bash
# Run all unit tests
swift test

# Run specific test suites
swift test --filter ModelDecodingTests
swift test --filter GaggiuinoServiceTests

# Run hardware-in-the-loop tests (requires real machine)
GAGGIUINO_HIL_TESTS=1 swift test --filter HardwareInTheLoopTests

# With custom machine URL
GAGGIUINO_HIL_TESTS=1 GAGGIUINO_URL=http://192.168.1.100 swift test
```

### Test Coverage

- **Model Decoding** (7 tests) - JSON parsing, computed properties, flexible type handling
- **Service** (9 tests) - Initialization, error handling, Sendable conformance
- **Hardware-in-the-Loop** (8 tests) - Real machine integration (safe, read-only)

## Architecture

GaggiuinoSwiftKit is built with Swift 6 strict concurrency in mind:

- **Struct-based service** - No mutable state, simple and efficient
- **Sendable everywhere** - Safe to use across concurrency boundaries
- **Async/await throughout** - Modern Swift concurrency patterns
- **No external dependencies** - Just Foundation and URLSession

### Swift 6 Concurrency

All types properly conform to `Sendable`:

```swift
// The service is Sendable (no mutable state)
let service = GaggiuinoService()

Task {
    let shot = try await service.getLatestShot()
    // Safe to pass across concurrency boundaries
    await someActor.process(shot)
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Clone the repository
2. Open `Package.swift` in Xcode
3. Run tests: `swift test`
4. Make your changes
5. Ensure all tests pass
6. Submit a PR

### Running HIL Tests

If you have a Gaggiuino machine:

1. Turn on your machine
2. Ensure it's on the same network
3. Run: `GAGGIUINO_HIL_TESTS=1 swift test`

## License

GaggiuinoSwiftKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Credits

- **Gaggiuino Project**: https://github.com/Zer0-bit/gaggiuino
- Built with ❤️ for the home espresso community

## Support

- 🐛 Found a bug? [Open an issue](https://github.com/christian-heise/GaggiuinoSwiftKit/issues)
- 💡 Have a feature request? [Start a discussion](https://github.com/christian-heise/GaggiuinoSwiftKit/discussions)
- ☕ Questions? Check out the [Gaggiuino community](https://github.com/Zer0-bit/gaggiuino)

---

**Note**: This package requires a Gaggiuino-equipped espresso machine on your local network. Visit the [Gaggiuino project](https://github.com/Zer0-bit/gaggiuino) to learn how to upgrade your Gaggia Classic Pro.
