//
//  GaggiuinoServiceTests.swift
//  GaggiuinoSwiftKit
//
//  Tests for GaggiuinoService network operations
//

import Testing
import Foundation
@testable import GaggiuinoSwiftKit

@Suite("GaggiuinoService Tests")
struct GaggiuinoServiceTests {
    
    // MARK: - Service Initialization Tests
    
    @Test("Service initializes with default baseURL")
    func testDefaultInitialization() {
        let service = GaggiuinoService()
        #expect(service.baseURL == "http://gaggiuino.local")
    }
    
    @Test("Service initializes with custom baseURL")
    func testCustomBaseURL() {
        let service = GaggiuinoService(baseURL: "http://192.168.1.100")
        #expect(service.baseURL == "http://192.168.1.100")
    }
    
    @Test("Service trims trailing slash from baseURL")
    func testBaseURLTrimsTrailingSlash() {
        let service = GaggiuinoService(baseURL: "http://gaggiuino.local/")
        #expect(service.baseURL == "http://gaggiuino.local")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("GaggiuinoServiceError provides localized descriptions")
    func testErrorDescriptions() {
        let errors: [(GaggiuinoServiceError, String)] = [
            (.invalidURL, "Invalid URL configuration"),
            (.connectionFailed("Test"), "Connection failed: Test"),
            (.timeout, "Request timed out"),
            (.notFound, "Resource not found (404)"),
            (.invalidResponse, "Invalid response from Gaggiuino"),
            (.decodingFailed("Test"), "Failed to decode response: Test")
        ]
        
        for (error, expectedDescription) in errors {
            #expect(error.errorDescription == expectedDescription)
        }
    }
    
    // MARK: - Data Model Tests
    
    @Test("ShotDatapoints initializes with nil values")
    func testShotDatapointsNilValues() {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let datapoints = try? JSONDecoder().decode(ShotDatapoints.self, from: data)
        
        #expect(datapoints != nil)
        #expect(datapoints?.pressure == nil)
        #expect(datapoints?.temperature == nil)
    }
    
    @Test("GaggiuinoShot date conversion works correctly")
    func testShotDateConversion() throws {
        let timestamp = 1708185600 // Feb 17, 2024, 16:00:00 UTC
        let json = """
        {
            "id": 1,
            "timestamp": \(timestamp),
            "duration": 300,
            "profile": {"id": 1, "name": "Test"},
            "datapoints": {}
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let shot = try JSONDecoder().decode(GaggiuinoShot.self, from: data)
        
        #expect(shot.date.timeIntervalSince1970 == Double(timestamp))
    }
    
    @Test("GaggiuinoShot duration conversion to seconds works correctly")
    func testShotDurationConversion() throws {
        let json = """
        {
            "id": 1,
            "timestamp": 1708185600,
            "duration": 285,
            "profile": {"id": 1, "name": "Test"},
            "datapoints": {}
        }
        """
        
        let data = try #require(json.data(using: .utf8))
        let shot = try JSONDecoder().decode(GaggiuinoShot.self, from: data)
        
        #expect(shot.durationSeconds == 28.5)
    }
    
    // MARK: - Sendable Conformance Tests
    
    @Test("GaggiuinoService is Sendable")
    func testServiceIsSendable() {
        let service = GaggiuinoService()
        
        // This test verifies that GaggiuinoService can be passed across concurrency boundaries
        Task {
            let _ = service.baseURL
        }
    }
    
    @Test("Data models are Sendable")
    func testModelsAreSendable() {
        // This test verifies all models conform to Sendable
        let _: any Sendable = ShotDatapoints(
            pressure: nil,
            pumpFlow: nil,
            shotWeight: nil,
            targetPressure: nil,
            targetPumpFlow: nil,
            targetTemperature: nil,
            temperature: nil,
            timeInShot: nil,
            waterPumped: nil,
            weightFlow: nil
        )
    }
}
