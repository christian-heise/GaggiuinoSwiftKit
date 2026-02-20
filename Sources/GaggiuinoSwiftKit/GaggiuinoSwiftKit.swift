//
//  GaggiuinoService.swift
//  GaggiuinoBuddy
//
//  Created by Christian Heise on 17.02.26.
//

//
//  GaggiuinoService.swift
//  GaggiuinoBuddy
//
//  Created by Christian Heise on 17.02.26.
//
//  Swift 6 Concurrency Architecture:
//
//  This service demonstrates proper Swift 6 concurrency patterns for a new app:
//
//  1. Struct-based service marked Sendable
//     - No mutable state means no need for actor isolation
//     - URLSession is already Sendable
//     - Simple and efficient for stateless operations
//
//  2. All data models are value types with Sendable
//     - Structs with only Sendable properties
//     - Compiler automatically infers Sendable conformance
//     - Safe to pass across any concurrency boundary
//
//  3. Generic constraints use Decodable only
//     - Swift 6 limitation: combining Decodable & Sendable in constraints
//       causes incorrect main-actor isolation inference
//     - Solution: Let compiler infer Sendable from concrete types
//     - All our types ARE Sendable, we just don't constrain the generic
//
//  4. Async/await throughout
//     - URLSession.data(for:) for network requests
//     - Structured concurrency with TaskGroup for parallel fetching
//     - No completion handlers or callbacks
//

import Foundation

// MARK: - Error

public enum GaggiuinoServiceError: Error, LocalizedError, Sendable {
    case invalidURL
    case connectionFailed(String)
    case timeout
    case notFound
    case invalidResponse
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .connectionFailed(let detail):
            return "Connection failed: \(detail)"
        case .timeout:
            return "Request timed out"
        case .notFound:
            return "Resource not found (404)"
        case .invalidResponse:
            return "Invalid response from Gaggiuino"
        case .decodingFailed(let detail):
            return "Failed to decode response: \(detail)"
        }
    }
}

// MARK: - Shot Models

public struct ShotDatapoints: Codable, Sendable {
    /// Raw pressure values — divide by 10 for bar (e.g. 90 → 9.0 bar)
    public let pressure: [Int]?
    /// Raw pump flow values — divide by 10 for mL/s
    public let pumpFlow: [Int]?
    /// Raw shot weight values — divide by 10 for grams
    public let shotWeight: [Int]?
    /// Raw target pressure values — divide by 10 for bar
    public let targetPressure: [Int]?
    /// Raw target pump flow values — divide by 10 for mL/s
    public let targetPumpFlow: [Int]?
    /// Raw target temperature — divide by 10 for °C (e.g. 900 → 90.0°C)
    public let targetTemperature: [Int]?
    /// Raw temperature — divide by 10 for °C (e.g. 898 → 89.8°C)
    public let temperature: [Int]?
    /// Raw time values — divide by 10 for seconds (e.g. 10 → 1.0s)
    public let timeInShot: [Int]?
    /// Raw water pumped values — divide by 10 for mL
    public let waterPumped: [Int]?
    /// Raw weight flow values — divide by 10 for g/s
    public let weightFlow: [Int]?
    
    // MARK: - Computed Properties (Scaled Values)
    
    /// Pressure in bar
    public var pressureInBar: [Double]? {
        pressure?.map { Double($0) / 10.0 }
    }
    
    /// Pump flow in mL/s
    public var pumpFlowInMLPerSecond: [Double]? {
        pumpFlow?.map { Double($0) / 10.0 }
    }
    
    /// Shot weight in grams
    public var shotWeightInGrams: [Double]? {
        shotWeight?.map { Double($0) / 10.0 }
    }
    
    /// Target pressure in bar
    public var targetPressureInBar: [Double]? {
        targetPressure?.map { Double($0) / 10.0 }
    }
    
    /// Target pump flow in mL/s
    public var targetPumpFlowInMLPerSecond: [Double]? {
        targetPumpFlow?.map { Double($0) / 10.0 }
    }
    
    /// Target temperature in °C
    public var targetTemperatureInCelsius: [Double]? {
        targetTemperature?.map { Double($0) / 10.0 }
    }
    
    /// Temperature in °C
    public var temperatureInCelsius: [Double]? {
        temperature?.map { Double($0) / 10.0 }
    }
    
    /// Time in shot as seconds
    public var timeInShotSeconds: [Double]? {
        timeInShot?.map { Double($0) / 10.0 }
    }
    
    /// Water pumped in mL
    public var waterPumpedInML: [Double]? {
        waterPumped?.map { Double($0) / 10.0 }
    }
    
    /// Weight flow in g/s
    public var weightFlowInGramsPerSecond: [Double]? {
        weightFlow?.map { Double($0) / 10.0 }
    }
}

public struct GaggiuinoShot: Codable, Sendable, Identifiable {
    public let id: Int
    /// Unix timestamp (seconds since epoch)
    public let timestamp: Int
    /// Shot duration — divide by 10 for seconds (e.g. 335 → 33.5s)
    public let duration: Int
    public let profile: GaggiuinoProfile
    public let datapoints: ShotDatapoints

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    public var durationSeconds: Double {
        Double(duration) / 10.0
    }
}

// MARK: - Profile Models

public struct ProfileStopConditions: Codable, Sendable {
    public let pressureAbove: Double?
    public let pressureBelow: Double?
    public let time: Int?
    public let weight: Double?
    public let waterPumpedInPhase: Int?
}

public struct ProfilePhaseTarget: Codable, Sendable {
    public let curve: String
    public let end: Double
    public let start: Double?
    public let time: Int?
}

public struct ProfilePhase: Codable, Sendable {
    public let restriction: Double?
    public let skip: Bool
    public let stopConditions: ProfileStopConditions
    public let target: ProfilePhaseTarget
    /// Either "PRESSURE" or "FLOW"
    public let type: String
}

public struct ProfileRecipe: Codable, Sendable {
    public let coffeeIn: Double?
    public let ratio: Double?
}

public struct GaggiuinoProfile: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let selected: Bool?
    /// Target water temperature in °C
    public let waterTemperature: Int?
    public let phases: [ProfilePhase]?
    /// e.g. {"weight": 50.0} — global stop conditions for the profile
    public let globalStopConditions: [String: Double]?
    public let recipe: ProfileRecipe?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, selected, waterTemperature, phases, globalStopConditions, recipe
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Handle selected as either Bool or String
        if container.contains(.selected) {
            selected = try? container.decodeFlexibleBool(forKey: .selected)
        } else {
            selected = nil
        }
        
        waterTemperature = try container.decodeIfPresent(Int.self, forKey: .waterTemperature)
        phases = try container.decodeIfPresent([ProfilePhase].self, forKey: .phases)
        globalStopConditions = try container.decodeIfPresent([String: Double].self, forKey: .globalStopConditions)
        recipe = try container.decodeIfPresent(ProfileRecipe.self, forKey: .recipe)
    }
}

// MARK: - Machine Status

/// Live status of the Gaggiuino machine.
/// Note: numeric fields are returned as strings by the API and decoded here.
public struct MachineStatus: Decodable, Sendable {
    public let profileId: Int
    public let profileName: String
    /// Current boiler temperature in °C
    public let temperature: Double
    /// Target boiler temperature in °C
    public let targetTemperature: Double
    /// Current pressure in bar
    public let pressure: Double
    /// Water level percentage (0–100)
    public let waterLevel: Int
    /// Weight on scales in grams
    public let weight: Double
    public let brewSwitchState: Bool
    public let steamSwitchState: Bool
    /// Machine uptime in seconds
    public let upTime: Int

    private enum CodingKeys: String, CodingKey {
        case profileId, profileName, temperature, targetTemperature
        case pressure, waterLevel, weight
        case brewSwitchState, steamSwitchState, upTime
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profileName = try c.decode(String.self, forKey: .profileName)
        brewSwitchState = try c.decodeFlexibleBool(forKey: .brewSwitchState)
        steamSwitchState = try c.decodeFlexibleBool(forKey: .steamSwitchState)
        profileId = try c.decodeFlexibleInt(forKey: .profileId)
        upTime = try c.decodeFlexibleInt(forKey: .upTime)
        waterLevel = try c.decodeFlexibleInt(forKey: .waterLevel)
        temperature = try c.decodeFlexibleDouble(forKey: .temperature)
        targetTemperature = try c.decodeFlexibleDouble(forKey: .targetTemperature)
        pressure = try c.decodeFlexibleDouble(forKey: .pressure)
        weight = try c.decodeFlexibleDouble(forKey: .weight)
    }
}

// MARK: - Private Helpers

private struct LatestShotResponse: Decodable, Sendable {
    let lastShotId: Int

    private enum CodingKeys: CodingKey {
        case lastShotId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastShotId = try c.decodeFlexibleInt(forKey: .lastShotId)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let int = try? decode(Int.self, forKey: key) { return int }
        let string = try decode(String.self, forKey: key)
        guard let int = Int(string) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Cannot convert '\(string)' to Int"
            )
        }
        return int
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let double = try? decode(Double.self, forKey: key) { return double }
        let string = try decode(String.self, forKey: key)
        guard let double = Double(string) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Cannot convert '\(string)' to Double"
            )
        }
        return double
    }
    
    func decodeFlexibleBool(forKey key: Key) throws -> Bool {
        if let bool = try? decode(Bool.self, forKey: key) { return bool }
        let string = try decode(String.self, forKey: key)
        switch string.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default:
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Cannot convert '\(string)' to Bool"
            )
        }
    }
}

// MARK: - Service
/// A network service for communicating with Gaggiuino espresso machines.
///
/// This service is thread-safe and can be used from any isolation domain.
/// It uses immutable configuration and URLSession (which is Sendable) for all operations.
public struct GaggiuinoService: Sendable {
    /// Default URL for Gaggiuino machines on local network
    public static let defaultBaseURL = "http://gaggiuino.local"
    
    /// Default timeout for individual requests (seconds)
    public static let defaultRequestTimeout: TimeInterval = 5
    
    /// Default timeout for entire resource download (seconds)
    public static let defaultResourceTimeout: TimeInterval = 10
    
    public let baseURL: String
    private let session: URLSession

    public init(
        baseURL: String = GaggiuinoService.defaultBaseURL,
        requestTimeout: TimeInterval = GaggiuinoService.defaultRequestTimeout,
        resourceTimeout: TimeInterval = GaggiuinoService.defaultResourceTimeout
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        self.session = URLSession(configuration: config)
    }

    private var apiBase: String { "\(baseURL)/api" }

    // MARK: - System

    /// Returns the current live status of the machine.
    public func getMachineStatus() async throws -> MachineStatus {
        // API returns array with single element, unwrap it
        let statuses: [MachineStatus] = try await get("/system/status")
        guard let status = statuses.first else {
            throw GaggiuinoServiceError.invalidResponse
        }
        return status
    }

    /// Returns true if the Gaggiuino API is reachable and healthy.
    /// Note: Uses the status endpoint as the /health endpoint is not available on all firmware versions.
    public func isHealthy() async -> Bool {
        do {
            _ = try await getMachineStatus()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Shots

    /// Returns the ID of the most recently pulled shot.
    public func getLatestShotId() async throws -> Int {
        // API returns array with single element, unwrap it
        let results: [LatestShotResponse] = try await get("/shots/latest")
        guard let result = results.first else {
            throw GaggiuinoServiceError.invalidResponse
        }
        return result.lastShotId
    }

    /// Fetches a specific shot by its ID.
    public func getShot(id: Int) async throws -> GaggiuinoShot {
        try await get("/shots/\(id)")
    }

    /// Fetches the most recently pulled shot.
    public func getLatestShot() async throws -> GaggiuinoShot {
        let latestId = try await getLatestShotId()
        return try await getShot(id: latestId)
    }
    
    /// Fetches multiple shots by their IDs.
    public func getShots(ids: [Int]) async throws -> [GaggiuinoShot] {
        try await withThrowingTaskGroup(of: GaggiuinoShot.self) { group in
            for id in ids {
                group.addTask {
                    try await self.getShot(id: id)
                }
            }
            
            var shots: [GaggiuinoShot] = []
            for try await shot in group {
                shots.append(shot)
            }
            return shots.sorted { $0.id < $1.id }
        }
    }
    
    /// Fetches a range of recent shots. Returns up to `limit` shots, starting from the most recent.
    public func getRecentShots(limit: Int = 10) async throws -> [GaggiuinoShot] {
        let latestId = try await getLatestShotId()
        let startId = max(1, latestId - limit + 1)
        let ids = Array(startId...latestId)
        return try await getShots(ids: ids)
    }

    // MARK: - Profiles

    /// Returns all available brewing profiles stored on the machine.
    public func getProfiles() async throws -> [GaggiuinoProfile] {
        try await get("/profiles/all")
    }

    /// Selects a profile by ID, making it the active profile on the machine.
    @discardableResult
    public func selectProfile(id: Int) async throws -> Bool {
        try await post("/profile-select/\(id)")
    }

    /// Deletes a profile by ID.
    @discardableResult
    public func deleteProfile(id: Int) async throws -> Bool {
        try await delete("/profile-select/\(id)")
    }

    // MARK: - Request Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let urlString = "\(apiBase)\(path)"
        guard let url = URL(string: urlString) else {
            throw GaggiuinoServiceError.invalidURL
        }
        let data = try await perform(url: url, method: "GET")
        return try decode(data)
    }

    @discardableResult
    private func post(_ path: String) async throws -> Bool {
        guard let url = URL(string: "\(apiBase)\(path)") else {
            throw GaggiuinoServiceError.invalidURL
        }
        _ = try await perform(url: url, method: "POST")
        return true
    }

    @discardableResult
    private func delete(_ path: String) async throws -> Bool {
        guard let url = URL(string: "\(apiBase)\(path)") else {
            throw GaggiuinoServiceError.invalidURL
        }
        _ = try await perform(url: url, method: "DELETE")
        return true
    }

    private func postJSON(_ path: String, body: Data) async throws {
        guard let url = URL(string: "\(apiBase)\(path)") else {
            throw GaggiuinoServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await performRequest(request)
    }

    private func perform(url: URL, method: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GaggiuinoServiceError.invalidResponse
            }
            
            // Validate HTTP status code
            switch http.statusCode {
            case 200...299:
                // Success range
                return data
            case 404:
                throw GaggiuinoServiceError.notFound
            default:
                throw GaggiuinoServiceError.connectionFailed("HTTP \(http.statusCode)")
            }
        } catch let error as GaggiuinoServiceError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw GaggiuinoServiceError.timeout
            }
            throw GaggiuinoServiceError.connectionFailed(urlError.localizedDescription)
        } catch {
            throw GaggiuinoServiceError.connectionFailed(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GaggiuinoServiceError.decodingFailed(error.localizedDescription)
        }
    }
}
