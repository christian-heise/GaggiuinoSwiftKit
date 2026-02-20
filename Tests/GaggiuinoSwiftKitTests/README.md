# GaggiuinoSwiftKit Tests

This package includes three types of tests:

## 1. Model Decoding Tests (`ModelDecodingTests.swift`)

Tests for JSON decoding and data model validation.

**Coverage:**
- ShotDatapoints decoding and computed properties
- GaggiuinoShot decoding and conversions
- MachineStatus flexible decoding (strings and numbers)
- GaggiuinoProfile with nested structures
- Error handling for invalid data

**Run:** `swift test --filter ModelDecodingTests`

## 2. Service Tests (`GaggiuinoServiceTests.swift`)

Unit tests for the GaggiuinoService without real hardware.

**Coverage:**
- Service initialization and configuration
- Error descriptions
- Sendable conformance
- Data model initialization

**Run:** `swift test --filter GaggiuinoServiceTests`

## 3. Hardware-in-the-Loop Tests (`HardwareInTheLoopTests.swift`)

**⚠️ IMPORTANT: These tests require a real Gaggiuino machine on your network.**

### Safety Guarantees

These tests are **100% READ-ONLY** and will NOT:
- ❌ Modify any profiles
- ❌ Change any settings
- ❌ Trigger brewing operations
- ❌ Update boiler parameters
- ❌ Delete any data

They ONLY:
- ✅ Fetch machine status
- ✅ Read shot history
- ✅ List profiles
- ✅ Read settings

### Prerequisites

1. **Turn on your Gaggiuino machine**
2. **Connect it to your local network** (same WiFi as your computer)
3. **Verify connectivity:** Open `http://gaggiuino.local` in your browser

### Running HIL Tests

**Basic usage (using default `gaggiuino.local`):**
```bash
cd GaggiuinoSwiftKit
GAGGIUINO_HIL_TESTS=1 swift test --filter HardwareInTheLoopTests
```

**Using a custom IP address:**
```bash
GAGGIUINO_HIL_TESTS=1 GAGGIUINO_URL=http://192.168.1.100 swift test --filter HardwareInTheLoopTests
```

**Run all tests (unit + HIL):**
```bash
GAGGIUINO_HIL_TESTS=1 swift test
```

### What the Tests Do

1. **Health Check** - Verifies the machine is reachable
2. **Machine Status** - Fetches current temperature, pressure, water level
3. **Shot Data** - Reads latest shot and recent shot history
4. **Profiles** - Lists all brewing profiles on the machine
5. **Data Validation** - Verifies that data scaling is correct

### Expected Output

When running HIL tests, you'll see detailed output like:

```
📊 Machine Status:
   Temperature: 92.3°C (target: 93.0°C)
   Pressure: 0.2 bar
   Water Level: 85%
   Active Profile: Blooming Espresso
   Uptime: 3600 seconds

📸 Latest Shot:
   ID: 42
   Date: 2024-02-17 16:00:00
   Duration: 28.5 seconds
   Profile: Blooming Espresso
   Max Pressure: 9.2 bar
   Avg Temperature: 92.1°C

☕️ Found 8 profiles:
   [✓] Blooming Espresso (ID: 5)
   [ ] Turbo (ID: 3)
   ...
```

### Troubleshooting

**"Machine should be reachable" failure:**
- Ensure your Gaggiuino is powered on
- Verify you're on the same WiFi network
- Try accessing `http://gaggiuino.local` in a browser
- If that doesn't work, find the IP address and use `GAGGIUINO_URL`

**"Resource not found (404)" errors:**
- Your Gaggiuino firmware might be outdated
- Check that the web interface is accessible
- Verify API endpoints match your firmware version

**Connection timeout:**
- Check firewall settings
- Ensure the machine isn't in deep sleep mode
- Try pinging the machine: `ping gaggiuino.local`

## Running All Tests

**Unit tests only (no hardware required):**
```bash
swift test --filter "ModelDecodingTests|GaggiuinoServiceTests"
```

**All tests including HIL:**
```bash
GAGGIUINO_HIL_TESTS=1 swift test
```

## Test Statistics

- **Model Decoding Tests:** 7 tests
- **Service Tests:** 9 tests  
- **HIL Tests:** 8 tests (disabled by default)
- **Total:** 24 tests
