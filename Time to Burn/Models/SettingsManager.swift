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
            print("🌍 [SettingsManager] Units changed to: \(isMetricUnits ? "Metric" : "Imperial")")
        }
    }
    
    @Published var isDarkModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDarkModeEnabled, forKey: "isDarkModeEnabled")
            print("🌙 [SettingsManager] Dark mode changed to: \(isDarkModeEnabled ? "Enabled" : "Disabled")")
        }
    }
    
    @Published var is24HourClock: Bool {
        didSet {
            UserDefaults.standard.set(is24HourClock, forKey: "is24HourClock")
            print("🕐 [SettingsManager] Clock format changed to: \(is24HourClock ? "24-hour" : "12-hour")")
            
            // Trigger widget refresh when clock format changes
            WidgetCenter.shared.reloadAllTimelines()
            print("🕐 [SettingsManager] 🔄 Widget timelines reloaded due to clock format change")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load settings from UserDefaults with defaults
        self.isMetricUnits = UserDefaults.standard.object(forKey: "isMetricUnits") as? Bool ?? true
        self.isDarkModeEnabled = UserDefaults.standard.object(forKey: "isDarkModeEnabled") as? Bool ?? true
        self.is24HourClock = UserDefaults.standard.object(forKey: "is24HourClock") as? Bool ?? false
        
        print("⚙️ [SettingsManager] Initialized with Metric: \(isMetricUnits), Dark Mode: \(isDarkModeEnabled), 24h Clock: \(is24HourClock)")
    }
    
    // MARK: - Public Methods
    func resetToDefaults() {
        isMetricUnits = true
        isDarkModeEnabled = true
        is24HourClock = false
        print("🔄 [SettingsManager] Reset to default settings")
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
        print("📥 [SettingsManager] Imported settings")
    }
} 