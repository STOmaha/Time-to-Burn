import Foundation
import SwiftUI
import WidgetKit

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Published Properties
    @Published var isMetricUnits: Bool {
        didSet {
            UserDefaults.standard.set(isMetricUnits, forKey: "isMetricUnits")
            logInfo(.settings, "Unit system changed", data: [
                "New System": isMetricUnits ? "🌍 Metric (°C, km)" : "🇺🇸 Imperial (°F, miles)",
                "Temperature": isMetricUnits ? "Celsius" : "Fahrenheit",
                "Distance": isMetricUnits ? "Kilometers" : "Miles"
            ])
        }
    }
    
    @Published var isDarkModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDarkModeEnabled, forKey: "isDarkModeEnabled")
            logInfo(.settings, "Dark mode preference changed", data: [
                "Mode": isDarkModeEnabled ? "🌙 Dark" : "☀️ Light",
                "Applied": "System-wide"
            ])
        }
    }
    
    @Published var is24HourClock: Bool {
        didSet {
            UserDefaults.standard.set(is24HourClock, forKey: "is24HourClock")
            
            // Trigger widget refresh when clock format changes
            WidgetCenter.shared.reloadAllTimelines()
            
            logInfo(.settings, "Clock format changed", data: [
                "Format": is24HourClock ? "⏰ 24-hour (15:30)" : "🕐 12-hour (3:30 PM)",
                "Widget Update": "✅ Refreshed"
            ])
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load settings from UserDefaults with defaults
        self.isMetricUnits = UserDefaults.standard.object(forKey: "isMetricUnits") as? Bool ?? true
        self.isDarkModeEnabled = UserDefaults.standard.object(forKey: "isDarkModeEnabled") as? Bool ?? true
        self.is24HourClock = UserDefaults.standard.object(forKey: "is24HourClock") as? Bool ?? false
        
        logInfo(.settings, "SettingsManager initialized", data: [
            "Units": isMetricUnits ? "🌍 Metric" : "🇺🇸 Imperial",
            "Dark Mode": isDarkModeEnabled ? "🌙 Enabled" : "☀️ Disabled",
            "Clock": is24HourClock ? "⏰ 24-hour" : "🕐 12-hour"
        ])
    }
    
    // MARK: - Public Methods
    func resetToDefaults() {
        isMetricUnits = true
        isDarkModeEnabled = true
        is24HourClock = false
        
        logInfo(.settings, "Settings reset to defaults", data: [
            "Units": "🌍 Metric",
            "Dark Mode": "🌙 Enabled",
            "Clock": "🕐 12-hour"
        ])
    }
    
    func exportSettings() -> [String: Any] {
        return [
            "isMetricUnits": isMetricUnits,
            "isDarkModeEnabled": isDarkModeEnabled,
            "is24HourClock": is24HourClock
        ]
    }
    
    func importSettings(_ settings: [String: Any]) {
        if let metric = settings["isMetricUnits"] as? Bool {
            isMetricUnits = metric
        }
        if let darkMode = settings["isDarkModeEnabled"] as? Bool {
            isDarkModeEnabled = darkMode
        }
        if let clock24h = settings["is24HourClock"] as? Bool {
            is24HourClock = clock24h
        }
        logSuccess(.settings, "Settings imported successfully")
    }
} 