//
//  ModelDecodingTests.swift
//  GaggiuinoSwiftKit
//
//  Tests for decoding JSON responses from Gaggiuino API
//

import Testing
import Foundation
@testable import GaggiuinoSwiftKit

@Suite("Model Decoding Tests")
struct ModelDecodingTests {
    
    // MARK: - ShotDatapoints Tests
    
    @Test("ShotDatapoints decodes from JSON correctly")
    func testShotDatapointsDecoding() throws {
        let json = """
        {
            "pressure": [90, 92, 94],
            "pumpFlow": [15, 20, 25],
            "shotWeight": [180, 200, 220],
            "temperature": [898, 900, 902],
            "timeInShot": [1000, 2000, 3000]
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let datapoints = try JSONDecoder().decode(ShotDatapoints.self, from: data)
        
        #expect(datapoints.pressure == [90, 92, 94])
        #expect(datapoints.pumpFlow == [15, 20, 25])
        #expect(datapoints.shotWeight == [180, 200, 220])
        #expect(datapoints.temperature == [898, 900, 902])
        #expect(datapoints.timeInShot == [1000, 2000, 3000])
    }
    
    @Test("ShotDatapoints computed properties scale values correctly")
    func testShotDatapointsComputedProperties() throws {
        let json = """
        {
            "pressure": [90],
            "pumpFlow": [25],
            "shotWeight": [200],
            "temperature": [900],
            "timeInShot": [3000],
            "waterPumped": [400],
            "weightFlow": [15]
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let datapoints = try JSONDecoder().decode(ShotDatapoints.self, from: data)
        
        // Test scaling: divide by 10
        #expect(datapoints.pressureInBar == [9.0])
        #expect(datapoints.pumpFlowInMLPerSecond == [2.5])
        #expect(datapoints.shotWeightInGrams == [20.0])
        #expect(datapoints.temperatureInCelsius == [90.0])
        #expect(datapoints.waterPumpedInML == [40.0])
        #expect(datapoints.weightFlowInGramsPerSecond == [1.5])
        
        // Test time scaling: divide by 10 (deciseconds to seconds)
        #expect(datapoints.timeInShotSeconds == [300.0])
    }
    
    // MARK: - GaggiuinoShot Tests
    
    @Test("GaggiuinoShot decodes from JSON correctly")
    func testGaggiuinoShotDecoding() throws {
        let json = """
        {
            "id": 42,
            "timestamp": 1708185600,
            "duration": 285,
            "profile": {
                "id": 1,
                "name": "Blooming Espresso",
                "selected": true,
                "waterTemperature": 93
            },
            "datapoints": {
                "pressure": [90],
                "temperature": [900]
            }
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let shot = try JSONDecoder().decode(GaggiuinoShot.self, from: data)
        
        #expect(shot.id == 42)
        #expect(shot.timestamp == 1708185600)
        #expect(shot.duration == 285)
        #expect(shot.profile.name == "Blooming Espresso")
        #expect(shot.durationSeconds == 28.5)
    }
    
    // MARK: - MachineStatus Tests
    
    @Test("MachineStatus decodes numeric strings correctly")
    func testMachineStatusDecodingWithStringNumbers() throws {
        let json = """
        {
            "profileId": "1",
            "profileName": "Blooming Espresso",
            "temperature": "92.5",
            "targetTemperature": "93.0",
            "pressure": "9.2",
            "waterLevel": "85",
            "weight": "18.5",
            "brewSwitchState": true,
            "steamSwitchState": false,
            "upTime": "3600"
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let status = try JSONDecoder().decode(MachineStatus.self, from: data)
        
        #expect(status.profileId == 1)
        #expect(status.profileName == "Blooming Espresso")
        #expect(status.temperature == 92.5)
        #expect(status.targetTemperature == 93.0)
        #expect(status.pressure == 9.2)
        #expect(status.waterLevel == 85)
        #expect(status.weight == 18.5)
        #expect(status.brewSwitchState == true)
        #expect(status.steamSwitchState == false)
        #expect(status.upTime == 3600)
    }
    
    @Test("MachineStatus decodes native numbers correctly")
    func testMachineStatusDecodingWithNativeNumbers() throws {
        let json = """
        {
            "profileId": 1,
            "profileName": "Test Profile",
            "temperature": 92.5,
            "targetTemperature": 93.0,
            "pressure": 9.2,
            "waterLevel": 85,
            "weight": 18.5,
            "brewSwitchState": false,
            "steamSwitchState": false,
            "upTime": 3600
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let status = try JSONDecoder().decode(MachineStatus.self, from: data)
        
        #expect(status.profileId == 1)
        #expect(status.temperature == 92.5)
        #expect(status.upTime == 3600)
    }
    
    // MARK: - Profile Tests
    
    @Test("GaggiuinoProfile decodes from JSON correctly")
    func testProfileDecoding() throws {
        let json = """
        {
            "id": 5,
            "name": "Blooming Espresso",
            "selected": true,
            "waterTemperature": 93,
            "phases": [
                {
                    "restriction": 0.0,
                    "skip": false,
                    "stopConditions": {
                        "time": 10000,
                        "pressureAbove": 3.0,
                        "weight": null
                    },
                    "target": {
                        "curve": "LINEAR",
                        "end": 9.0,
                        "start": 3.0,
                        "time": 8000
                    },
                    "type": "PRESSURE"
                }
            ],
            "globalStopConditions": {
                "weight": 36.0
            }
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let profile = try JSONDecoder().decode(GaggiuinoProfile.self, from: data)
        
        #expect(profile.id == 5)
        #expect(profile.name == "Blooming Espresso")
        #expect(profile.selected == true)
        #expect(profile.waterTemperature == 93)
        #expect(profile.phases?.count == 1)
        #expect(profile.phases?.first?.type == "PRESSURE")
        #expect(profile.phases?.first?.target.curve == "LINEAR")
        #expect(profile.globalStopConditions?["weight"] == 36.0)
    }
    
    // MARK: - Error Cases
    
    @Test("MachineStatus throws error on invalid string-to-number conversion")
    func testMachineStatusInvalidNumberString() throws {
        let json = """
        {
            "profileId": "not-a-number",
            "profileName": "Test",
            "temperature": "92.5",
            "targetTemperature": "93.0",
            "pressure": "9.2",
            "waterLevel": "85",
            "weight": "18.5",
            "brewSwitchState": true,
            "steamSwitchState": false,
            "upTime": "3600"
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MachineStatus.self, from: data)
        }
    }
}
