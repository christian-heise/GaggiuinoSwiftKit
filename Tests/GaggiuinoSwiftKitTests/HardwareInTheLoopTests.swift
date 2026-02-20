//
//  HardwareInTheLoopTests.swift
//  GaggiuinoSwiftKit
//
//  Hardware-in-the-loop tests for real Gaggiuino hardware
//
//  SAFETY: These tests are READ-ONLY and do not modify any machine settings,
//  profiles, or trigger any brewing operations. They only fetch data.
//
//  To run these tests:
//  1. Turn on your Gaggiuino machine
//  2. Ensure it's connected to your local network
//  3. Run: GAGGIUINO_HIL_TESTS=1 swift test
//
//  To use a custom IP instead of gaggiuino.local:
//  GAGGIUINO_HIL_TESTS=1 GAGGIUINO_URL=http://192.168.1.100 swift test
//

import Testing
import Foundation
@testable import GaggiuinoSwiftKit

@Suite("Hardware-in-the-Loop Tests (Safe Read-Only)", .enabled(if: ProcessInfo.processInfo.environment["GAGGIUINO_HIL_TESTS"] == "1"))
struct HardwareInTheLoopTests {
    
    // Service instance configured for the actual hardware
    let service: GaggiuinoService
    
    init() {
        let baseURL = ProcessInfo.processInfo.environment["GAGGIUINO_URL"] ?? GaggiuinoService.defaultBaseURL
        service = GaggiuinoService(baseURL: baseURL)
    }
    
    // MARK: - Health Check
    
    @Test("Machine is reachable and healthy")
    func testMachineHealth() async throws {
        // Use machine status endpoint as health check since /api/health doesn't exist
        let status = try await service.getMachineStatus()
        #expect(status.profileName.isEmpty == false, "Machine should be reachable at \(service.baseURL)")
    }
    
    // MARK: - Machine Status (Read-Only)
    
    @Test("Can fetch current machine status")
    func testGetMachineStatus() async throws {
        let status = try await service.getMachineStatus()
        
        // Verify the data is reasonable
        #expect(status.temperature >= 0 && status.temperature <= 150, "Temperature should be in reasonable range")
        #expect(status.targetTemperature >= 0 && status.targetTemperature <= 150, "Target temp should be in reasonable range")
        #expect(status.pressure >= 0 && status.pressure <= 15, "Pressure should be 0-15 bar")
        #expect(status.waterLevel >= 0 && status.waterLevel <= 100, "Water level should be 0-100%")
        #expect(status.profileName.isEmpty == false, "Profile name should not be empty")
        
        print("📊 Machine Status:")
        print("   Temperature: \(status.temperature)°C (target: \(status.targetTemperature)°C)")
        print("   Pressure: \(status.pressure) bar")
        print("   Water Level: \(status.waterLevel)%")
        print("   Active Profile: \(status.profileName)")
        print("   Uptime: \(status.upTime) seconds")
    }
    
    // MARK: - Shot Data (Read-Only)
    
    @Test("Can fetch latest shot ID")
    func testGetLatestShotId() async throws {
        let latestId = try await service.getLatestShotId()
        #expect(latestId > 0, "Latest shot ID should be positive")
        print("📸 Latest shot ID: \(latestId)")
    }
    
    @Test("Can fetch latest shot data")
    func testGetLatestShot() async throws {
        let shot = try await service.getLatestShot()
        
        // Verify shot data structure
        #expect(shot.id > 0)
        #expect(shot.duration > 0, "Shot duration should be positive")
        #expect(shot.timestamp > 0, "Timestamp should be valid")
        #expect(shot.profile.name.isEmpty == false, "Profile name should exist")
        
        print("📸 Latest Shot:")
        print("   ID: \(shot.id)")
        print("   Date: \(shot.date)")
        print("   Duration: \(shot.durationSeconds) seconds")
        print("   Profile: \(shot.profile.name)")
        
        // Check if we have datapoints
        if let pressure = shot.datapoints.pressureInBar, !pressure.isEmpty {
            print("   Max Pressure: \(pressure.max() ?? 0) bar")
        }
        if let temp = shot.datapoints.temperatureInCelsius, !temp.isEmpty {
            print("   Avg Temperature: \(temp.reduce(0, +) / Double(temp.count))°C")
        }
    }
    
    @Test("Can fetch specific shot by ID")
    func testGetShotById() async throws {
        let latestId = try await service.getLatestShotId()
        let shot = try await service.getShot(id: latestId)
        
        #expect(shot.id == latestId)
        print("✅ Successfully fetched shot #\(latestId)")
    }
    
    @Test("Can fetch recent shots")
    func testGetRecentShots() async throws {
        let shots = try await service.getRecentShots(limit: 5)
        
        #expect(shots.count > 0, "Should have at least one shot")
        #expect(shots.count <= 5, "Should not exceed requested limit")
        
        // Verify shots are sorted by ID
        let sortedIds = shots.map(\.id).sorted()
        #expect(shots.map(\.id) == sortedIds, "Shots should be sorted by ID")
        
        print("📊 Recent \(shots.count) shots:")
        for shot in shots {
            print("   Shot #\(shot.id): \(shot.durationSeconds)s - \(shot.profile.name)")
        }
    }
    
    // MARK: - Profiles (Read-Only)
    
    @Test("Can fetch all profiles")
    func testGetProfiles() async throws {
        let profiles = try await service.getProfiles()
        
        #expect(profiles.count > 0, "Machine should have at least one profile")
        
        // Find the selected profile
        let selectedProfile = profiles.first(where: { $0.selected == true })
        
        print("☕️ Found \(profiles.count) profiles:")
        for profile in profiles {
            let marker = profile.selected == true ? "✓" : " "
            print("   [\(marker)] \(profile.name) (ID: \(profile.id))")
            if let temp = profile.waterTemperature {
                print("       Water Temp: \(temp)°C")
            }
            if let phases = profile.phases {
                print("       Phases: \(phases.count)")
            }
        }
        
        if let selected = selectedProfile {
            print("   Currently active: \(selected.name)")
        }
    }
    
    // MARK: - Data Validation
    
    @Test("Shot datapoints scaling is correct")
    func testShotDatapointsScaling() async throws {
        let shot = try await service.getLatestShot()
        
        // Verify that scaled values are reasonable
        if let pressure = shot.datapoints.pressureInBar {
            for p in pressure {
                #expect(p >= 0 && p <= 15, "Pressure should be 0-15 bar, got \(p)")
            }
        }
        
        if let temp = shot.datapoints.temperatureInCelsius {
            for t in temp {
                #expect(t >= 0 && t <= 150, "Temperature should be 0-150°C, got \(t)")
            }
        }
        
        if let weight = shot.datapoints.shotWeightInGrams {
            for w in weight {
                #expect(w >= 0 && w <= 100, "Shot weight should be 0-100g, got \(w)")
            }
        }
        
        print("✅ All datapoint scaling is within expected ranges")
    }
}
