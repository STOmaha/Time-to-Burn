import Foundation
import SwiftUI
import CoreLocation

// MARK: - Centralized Logging System
class LogManager {
    static let shared = LogManager()
    
    private init() {}
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case app = "APP"
        case weather = "WEATHER"
        case location = "LOCATION"
        case onboarding = "ONBOARDING"
        case notifications = "NOTIFICATIONS"
        case settings = "SETTINGS"
        case timer = "TIMER"
        case search = "SEARCH"
        case data = "DATA"
        case ui = "UI"
        case auth = "AUTH"
        case supabase = "SUPABASE"
        case subscription = "SUBSCRIPTION"
        case sync = "SYNC"
        case developer = "DEVELOPER"

        var emoji: String {
            switch self {
            case .app: return "🚀"
            case .weather: return "🌤️"
            case .location: return "📍"
            case .onboarding: return "📚"
            case .notifications: return "🔔"
            case .settings: return "⚙️"
            case .timer: return "⏱️"
            case .search: return "🔍"
            case .data: return "📊"
            case .ui: return "🎨"
            case .auth: return "🔐"
            case .supabase: return "🗄️"
            case .subscription: return "💳"
            case .sync: return "🔄"
            case .developer: return "🔧"
            }
        }

        var color: String {
            switch self {
            case .app: return "🟦"
            case .weather: return "🟨"
            case .location: return "🟩"
            case .onboarding: return "🟪"
            case .notifications: return "🟧"
            case .settings: return "⬜"
            case .timer: return "🟥"
            case .search: return "🟫"
            case .data: return "🟩"
            case .ui: return "🟨"
            case .auth: return "🟦"
            case .supabase: return "🟩"
            case .subscription: return "🟪"
            case .sync: return "🟧"
            case .developer: return "⬛"
            }
        }
    }
    
    // MARK: - Log Levels
    enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Configuration
    private var isLoggingEnabled = true
    private var enabledCategories: Set<Category> = Set(Category.allCases)
    private var minimumLevel: Level = .debug
    
    // MARK: - Public Logging Methods
    
    /// Log with all parameters
    func log(_ level: Level = .info, category: Category, message: String, data: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        guard isLoggingEnabled,
              enabledCategories.contains(category),
              shouldLog(level: level) else { return }
        
        let timestamp = formatTimestamp(Date())
        let filename = extractFilename(from: file)
        let functionName = extractFunctionName(from: function)
        
        // Create formatted message
        var logMessage = "\(timestamp) \(category.color) \(category.emoji) [\(category.rawValue)] \(level.emoji) \(message)"
        
        // Add data if provided
        if let data = data, !data.isEmpty {
            logMessage += "\n   📋 Data: \(formatData(data))"
        }
        
        // Add location info for errors and critical logs
        if level == .error || level == .critical {
            logMessage += "\n   📂 \(filename):\(line) in \(functionName)()"
        }
        
        print(logMessage)
        
        // Add separator for better readability
        if level == .success || level == .error || level == .critical {
            print("   " + String(repeating: "─", count: 50))
        }
    }
    
    // MARK: - Convenience Methods
    
    func debug(_ category: Category, _ message: String, data: [String: Any]? = nil) {
        log(.debug, category: category, message: message, data: data)
    }
    
    func info(_ category: Category, _ message: String, data: [String: Any]? = nil) {
        log(.info, category: category, message: message, data: data)
    }
    
    func success(_ category: Category, _ message: String, data: [String: Any]? = nil) {
        log(.success, category: category, message: message, data: data)
    }
    
    func warning(_ category: Category, _ message: String, data: [String: Any]? = nil) {
        log(.warning, category: category, message: message, data: data)
    }
    
    func error(_ category: Category, _ message: String, data: [String: Any]? = nil) {
        log(.error, category: category, message: message, data: data)
    }
    
    func critical(_ category: Category, _ message: String, data: [String: Any]? = nil) {
        log(.critical, category: category, message: message, data: data)
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Log UV data with rich details
    func logUVData(_ uvData: UVData?, location: String? = nil) {
        guard let uvData = uvData else {
            warning(.weather, "UV data is nil")
            return
        }
        
        let uvEmoji = getUVEmoji(uvData.uvIndex)
        let category = getUVCategory(uvData.uvIndex)
        let timeToBurn = formatTimeToBurn(uvData.uvIndex)
        
        let data: [String: Any] = [
            "UV Index": "\(uvEmoji) \(uvData.uvIndex)",
            "Category": category,
            "Time to Burn": timeToBurn,
            "Cloud Cover": "\(Int(uvData.cloudCover * 100))%",
            "Cloud Condition": uvData.cloudCondition,
            "Location": location ?? "Unknown",
            "Timestamp": formatTime(uvData.date)
        ]
        
        success(.weather, "UV Data Updated", data: data)
    }
    
    /// Log location data with context
    func logLocation(_ location: CLLocation?, name: String? = nil, context: String = "Location Updated") {
        guard let location = location else {
            warning(.location, "Location is nil")
            return
        }
        
        let data: [String: Any] = [
            "Latitude": String(format: "%.4f", location.coordinate.latitude),
            "Longitude": String(format: "%.4f", location.coordinate.longitude),
            "Accuracy": "\(Int(location.horizontalAccuracy))m",
            "Name": name ?? "Unknown",
            "Age": "\(Int(Date().timeIntervalSince(location.timestamp)))s ago"
        ]
        
        success(.location, context, data: data)
    }
    
    /// Log onboarding progress
    func logOnboardingProgress(currentStep: Int, totalSteps: Int, stepName: String) {
        let progress = Int((Double(currentStep + 1) / Double(totalSteps)) * 100)
        let data: [String: Any] = [
            "Step": "\(currentStep + 1)/\(totalSteps)",
            "Progress": "\(progress)%",
            "Current Step": stepName
        ]
        
        info(.onboarding, "Onboarding Progress", data: data)
    }
    
    /// Log permission requests
    func logPermissionRequest(_ permission: String, granted: Bool, context: String = "") {
        let data: [String: Any] = [
            "Permission": permission,
            "Status": granted ? "✅ Granted" : "❌ Denied",
            "Context": context
        ]

        if granted {
            success(.notifications, "Permission Granted", data: data)
        } else {
            warning(.notifications, "Permission Denied", data: data)
        }
    }

    /// Log authentication events
    func logAuth(_ event: String, userId: String? = nil, email: String? = nil, isSuccess: Bool = true, errorMessage: String? = nil) {
        var data: [String: Any] = ["Event": event]
        if let userId = userId { data["User ID"] = String(userId.prefix(8)) + "..." }
        if let email = email { data["Email"] = email }
        if let error = errorMessage { data["Error"] = error }

        if isSuccess {
            success(.auth, event, data: data)
        } else {
            error(.auth, event, data: data)
        }
    }

    /// Log Supabase database operations
    func logSupabase(_ operation: String, table: String, isSuccess: Bool = true, rowCount: Int? = nil, errorMessage: String? = nil) {
        var data: [String: Any] = [
            "Operation": operation,
            "Table": table
        ]
        if let count = rowCount { data["Rows"] = count }
        if let error = errorMessage { data["Error"] = error }

        if isSuccess {
            success(.supabase, "\(operation) on \(table)", data: data)
        } else {
            self.error(.supabase, "\(operation) failed on \(table)", data: data)
        }
    }

    /// Log subscription events
    func logSubscription(_ event: String, plan: String? = nil, status: String? = nil, isSuccess: Bool = true) {
        var data: [String: Any] = ["Event": event]
        if let plan = plan { data["Plan"] = plan }
        if let status = status { data["Status"] = status }

        if isSuccess {
            success(.subscription, event, data: data)
        } else {
            error(.subscription, event, data: data)
        }
    }

    /// Log sync events
    func logSync(_ event: String, dataType: String? = nil, isSuccess: Bool = true, details: String? = nil) {
        var data: [String: Any] = ["Event": event]
        if let type = dataType { data["Data Type"] = type }
        if let details = details { data["Details"] = details }

        if isSuccess {
            success(.sync, event, data: data)
        } else {
            error(.sync, event, data: data)
        }
    }

    /// Log full flow with separator for major events
    func logFlowStart(_ flowName: String, category: Category = .app) {
        print("")
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║ \(category.emoji) \(flowName.uppercased().padding(toLength: 55, withPad: " ", startingAt: 0)) ║")
        print("╚══════════════════════════════════════════════════════════════╝")
    }

    func logFlowEnd(_ flowName: String, success: Bool, category: Category = .app) {
        let status = success ? "✅ COMPLETED" : "❌ FAILED"
        print("┌──────────────────────────────────────────────────────────────┐")
        print("│ \(category.emoji) \(flowName.uppercased()) - \(status.padding(toLength: 43, withPad: " ", startingAt: 0)) │")
        print("└──────────────────────────────────────────────────────────────┘")
        print("")
    }
    
    // MARK: - Configuration Methods
    
    func enableLogging(_ enabled: Bool = true) {
        isLoggingEnabled = enabled
        info(.app, enabled ? "Logging enabled" : "Logging disabled")
    }
    
    func setCategories(_ categories: Set<Category>) {
        enabledCategories = categories
        info(.app, "Logging categories updated", data: ["categories": categories.map(\.rawValue).joined(separator: ", ")])
    }
    
    func setMinimumLevel(_ level: Level) {
        minimumLevel = level
        info(.app, "Minimum log level set to \(level.rawValue)")
    }
    
    // MARK: - Private Helper Methods
    
    private func shouldLog(level: Level) -> Bool {
        let levels: [Level] = [.debug, .info, .success, .warning, .error, .critical]
        guard let currentIndex = levels.firstIndex(of: minimumLevel),
              let levelIndex = levels.firstIndex(of: level) else { return true }
        return levelIndex >= currentIndex
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func extractFilename(from path: String) -> String {
        return (path as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    }
    
    private func extractFunctionName(from function: String) -> String {
        if let index = function.firstIndex(of: "(") {
            return String(function[..<index])
        }
        return function
    }
    
    private func formatData(_ data: [String: Any]) -> String {
        return data.map { key, value in
            "\(key): \(value)"
        }.joined(separator: ", ")
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func getUVEmoji(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "🟢"
        case 3...5: return "🟡"
        case 6...7: return "🟠"
        case 8...10: return "🔴"
        default: return "🟣"
        }
    }
    
    private func getUVCategory(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
    
    private func formatTimeToBurn(_ uvIndex: Int) -> String {
        if uvIndex == 0 { return "No risk" }
        if uvIndex >= 12 { return "~5 mins" }
        let minutes = 60 - Int(round(Double(uvIndex - 1) * 55.0 / 11.0))
        return "~\(minutes) mins"
    }
}

// MARK: - Global Convenience Functions
let log = LogManager.shared

// Quick logging functions
func logDebug(_ category: LogManager.Category, _ message: String, data: [String: Any]? = nil) {
    LogManager.shared.debug(category, message, data: data)
}

func logInfo(_ category: LogManager.Category, _ message: String, data: [String: Any]? = nil) {
    LogManager.shared.info(category, message, data: data)
}

func logSuccess(_ category: LogManager.Category, _ message: String, data: [String: Any]? = nil) {
    LogManager.shared.success(category, message, data: data)
}

func logWarning(_ category: LogManager.Category, _ message: String, data: [String: Any]? = nil) {
    LogManager.shared.warning(category, message, data: data)
}

func logError(_ category: LogManager.Category, _ message: String, data: [String: Any]? = nil) {
    LogManager.shared.error(category, message, data: data)
}
