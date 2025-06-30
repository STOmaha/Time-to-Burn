import Foundation
import SwiftUI
import UserNotifications
import ActivityKit

@MainActor
class TimerViewModel: ObservableObject {
    @Published var isTimerRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var totalExposureTime: TimeInterval = 0
    @Published var currentUVIndex: Int = 0
    @Published var timeToBurn: Int = 0
    @Published var sunscreenReapplyTime: TimeInterval = 0
    @Published var lastSunscreenApplication: Date?
    @Published var isUVZero = false
    
    private var timer: Timer?
    private let sunscreenReapplyInterval: TimeInterval = 2 * 60 * 60 // 2 hours in seconds
    private let notificationManager = NotificationManager.shared
    
    // Background timer persistence using system clock
    private var timerStartTime: Date?
    private var lastBackgroundTime: Date?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Live Activity
    private var uvExposureActivity: Activity<UVExposureAttributes>?
    
    init() {
        calculateTimeToBurn()
        loadPersistedData()
        setupBackgroundHandling()
    }
    
    // MARK: - Timer Control
    func startTimer() {
        guard currentUVIndex > 0 else {
            isUVZero = true
            return
        }
        
        isUVZero = false
        isTimerRunning = true
        timerStartTime = Date()
        lastBackgroundTime = Date()
        
        // Start foreground timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
        
        // Start Live Activity
        startLiveActivity()
        
        // Schedule notifications
        scheduleNotifications()
        
        savePersistedData()
    }
    
    func pauseTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        
        // Update total exposure time
        if let startTime = timerStartTime {
            totalExposureTime += Date().timeIntervalSince(startTime)
            timerStartTime = nil
        }
        
        // Stop Live Activity
        stopLiveActivity()
        
        // End background task
        endBackgroundTask()
        
        savePersistedData()
    }
    
    func resetTimer() {
        pauseTimer()
        elapsedTime = 0
        totalExposureTime = 0
        lastSunscreenApplication = nil
        sunscreenReapplyTime = 0
        timerStartTime = nil
        lastBackgroundTime = nil
        
        savePersistedData()
    }
    
    func applySunscreen() {
        lastSunscreenApplication = Date()
        sunscreenReapplyTime = Date().timeIntervalSinceReferenceDate + sunscreenReapplyInterval
        
        // Reset elapsed time for new sunscreen application
        elapsedTime = 0
        if timerStartTime != nil {
            timerStartTime = Date()
        }
        
        // Update Live Activity
        updateLiveActivity()
        
        // Schedule sunscreen reminder
        notificationManager.scheduleSunscreenReminder(at: Date().addingTimeInterval(sunscreenReapplyInterval))
        
        savePersistedData()
    }
    
    // MARK: - UV Index Updates
    func updateUVIndex(_ uvIndex: Int) {
        let previousUV = currentUVIndex
        currentUVIndex = uvIndex
        
        // Handle UV 0 (infinity)
        if uvIndex == 0 {
            isUVZero = true
            if isTimerRunning {
                pauseTimer()
            }
            return
        } else {
            isUVZero = false
        }
        
        // Recalculate time to burn
        calculateTimeToBurn()
        
        // If UV changed significantly, update Live Activity
        if abs(previousUV - uvIndex) >= 1 {
            updateLiveActivity()
        }
        
        // Check if we should start timer (UV >= 1)
        if uvIndex >= 1 && !isTimerRunning && !isUVZero {
            startTimer()
        }
    }
    
    private func calculateTimeToBurn() {
        if currentUVIndex == 0 {
            timeToBurn = Int.max // Infinity
        } else {
            timeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: currentUVIndex)
        }
    }
    
    // MARK: - Timer Updates
    private func updateTimer() {
        guard let startTime = timerStartTime else { return }
        
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Check for sunscreen reapply
        if let lastApplication = lastSunscreenApplication {
            let timeSinceApplication = Date().timeIntervalSince(lastApplication)
            if timeSinceApplication >= sunscreenReapplyInterval {
                // Trigger sunscreen reminder
                notificationManager.scheduleSunscreenReminder(at: Date())
            }
        }
        
        // Check exposure warnings
        let totalExposure = totalExposureTime + elapsedTime
        let maxExposure = TimeInterval(timeToBurn)
        
        if totalExposure >= maxExposure * 0.8 && totalExposure < maxExposure {
            // Approaching limit
            notificationManager.scheduleExposureWarning(warningType: .approaching, timeToBurn: timeToBurn)
        } else if totalExposure >= maxExposure {
            // Exceeded limit
            notificationManager.scheduleExposureWarning(warningType: .exceeded, timeToBurn: timeToBurn)
        }
        
        // Update Live Activity
        updateLiveActivity()
    }
    
    // MARK: - Background Handling
    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        guard isTimerRunning else { return }
        
        lastBackgroundTime = Date()
        
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    @objc private func appWillEnterForeground() {
        guard isTimerRunning, let _ = lastBackgroundTime else { return }
        
        // Update elapsed time
        if let startTime = timerStartTime {
            elapsedTime = Date().timeIntervalSince(startTime)
        }
        
        // Update Live Activity
        updateLiveActivity()
        
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Live Activity
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = UVExposureAttributes(
            uvIndex: currentUVIndex,
            maxExposureTime: timeToBurn,
            sunscreenReapplyTime: lastSunscreenApplication?.addingTimeInterval(sunscreenReapplyInterval) ?? Date()
        )
        
        let contentState = UVExposureAttributes.ContentState(
            elapsedTime: elapsedTime,
            totalExposureTime: totalExposureTime,
            isTimerRunning: isTimerRunning,
            lastSunscreenApplication: lastSunscreenApplication
        )
        
        do {
            uvExposureActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    private func updateLiveActivity() {
        Task {
            let contentState = UVExposureAttributes.ContentState(
                elapsedTime: elapsedTime,
                totalExposureTime: totalExposureTime,
                isTimerRunning: isTimerRunning,
                lastSunscreenApplication: lastSunscreenApplication
            )
            
            await uvExposureActivity?.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }
    
    private func stopLiveActivity() {
        Task {
            let contentState = UVExposureAttributes.ContentState(
                elapsedTime: elapsedTime,
                totalExposureTime: totalExposureTime,
                isTimerRunning: false,
                lastSunscreenApplication: lastSunscreenApplication
            )
            
            await uvExposureActivity?.end(ActivityContent(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
            uvExposureActivity = nil
        }
    }
    
    // MARK: - Notifications
    private func scheduleNotifications() {
        // Schedule sunscreen reminder if not already scheduled
        if lastSunscreenApplication == nil {
            notificationManager.scheduleSunscreenReminder(at: Date().addingTimeInterval(sunscreenReapplyInterval))
        }
    }
    
    // MARK: - Persistence
    private func loadPersistedData() {
        let defaults = UserDefaults.standard
        elapsedTime = defaults.double(forKey: "timerElapsedTime")
        totalExposureTime = defaults.double(forKey: "timerTotalExposureTime")
        currentUVIndex = defaults.integer(forKey: "timerCurrentUVIndex")
        isTimerRunning = defaults.bool(forKey: "timerIsRunning")
        
        if let lastApplicationTime = defaults.object(forKey: "timerLastSunscreenApplication") as? Date {
            lastSunscreenApplication = lastApplicationTime
        }
        
        sunscreenReapplyTime = defaults.double(forKey: "timerSunscreenReapplyTime")
        
        // Restore timer if it was running
        if isTimerRunning {
            startTimer()
        }
    }
    
    private func savePersistedData() {
        let defaults = UserDefaults.standard
        defaults.set(elapsedTime, forKey: "timerElapsedTime")
        defaults.set(totalExposureTime, forKey: "timerTotalExposureTime")
        defaults.set(currentUVIndex, forKey: "timerCurrentUVIndex")
        defaults.set(isTimerRunning, forKey: "timerIsRunning")
        defaults.set(lastSunscreenApplication, forKey: "timerLastSunscreenApplication")
        defaults.set(sunscreenReapplyTime, forKey: "timerSunscreenReapplyTime")
    }
    
    // MARK: - Helper Methods
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func getExposureStatus() -> (message: String, color: Color) {
        let totalExposure = totalExposureTime + elapsedTime
        let maxExposure = TimeInterval(timeToBurn)
        
        if currentUVIndex == 0 {
            return ("Safe", .green)
        } else if totalExposure >= maxExposure {
            return ("Exceeded", .red)
        } else if totalExposure >= maxExposure * 0.8 {
            return ("Warning", .orange)
        } else {
            return ("Safe", .green)
        }
    }
    
    func getExposureProgress() -> Double {
        if currentUVIndex == 0 {
            return 0.0
        }
        
        let totalExposure = totalExposureTime + elapsedTime
        let maxExposure = TimeInterval(timeToBurn)
        
        return min(totalExposure / maxExposure, 1.0)
    }
    
    func getSunscreenReapplyTimeRemaining() -> TimeInterval {
        guard let lastApplication = lastSunscreenApplication else {
            return sunscreenReapplyInterval
        }
        
        let timeSinceApplication = Date().timeIntervalSince(lastApplication)
        return max(0, sunscreenReapplyInterval - timeSinceApplication)
    }
} 