import Foundation
import Combine

/// Represents the current state of UV exposure
enum UVExposureState {
    case notStarted
    case running
    case paused
    case sunscreenApplied
    case exceeded
}

/// Represents sunscreen application status
struct SunscreenStatus {
    let applicationTime: Date
    let reapplyTime: Date
    let isActive: Bool
    
    var timeRemaining: TimeInterval {
        max(0, reapplyTime.timeIntervalSinceNow)
    }
    
    var isExpired: Bool {
        Date() >= reapplyTime
    }
}

/// Core timer model for UV exposure tracking
class UVExposureTimer: ObservableObject {
    // MARK: - Published Properties
    @Published var currentState: UVExposureState = .notStarted
    @Published var currentUVIndex: Int = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var totalExposureTime: TimeInterval = 0
    @Published var timeToBurn: Int = 0
    @Published var sunscreenStatus: SunscreenStatus?
    @Published var uvChangeNotification: String?
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var sunscreenTimer: Timer?
    private var sessionStartTime: Date?
    private var lastUVChangeTime: Date?
    private var exposureAtLastUVChange: TimeInterval = 0
    
    // MARK: - Constants
    private let sunscreenReapplyInterval: TimeInterval = 2 * 60 * 60 // 2 hours
    private let timerUpdateInterval: TimeInterval = 1.0 // 1 second updates
    
    // MARK: - Computed Properties
    var remainingTime: TimeInterval {
        let currentTotalExposure = totalExposureTime + elapsedTime
        return max(0, TimeInterval(timeToBurn) - currentTotalExposure)
    }
    
    var exposureProgress: Double {
        guard timeToBurn > 0 else { return 0.0 }
        let currentTotalExposure = totalExposureTime + elapsedTime
        return min(currentTotalExposure / TimeInterval(timeToBurn), 1.0)
    }
    
    var isTimerRunning: Bool {
        currentState == .running
    }
    
    var isUVZero: Bool {
        currentUVIndex == 0
    }
    
    // MARK: - Initialization
    init() {
        calculateTimeToBurn()
    }
    
    // MARK: - Timer Control
    func startTimer() {
        guard currentUVIndex > 0 else {
            currentState = .notStarted
            return
        }
        
        currentState = .running
        sessionStartTime = Date()
        lastUVChangeTime = Date()
        exposureAtLastUVChange = totalExposureTime
        
        startInternalTimer()
    }
    
    func pauseTimer() {
        currentState = .paused
        stopInternalTimer()
        
        // Update total exposure time
        if let startTime = sessionStartTime {
            totalExposureTime += Date().timeIntervalSince(startTime)
            sessionStartTime = nil
        }
    }
    
    func resumeTimer() {
        guard currentUVIndex > 0 else { return }
        
        currentState = .running
        sessionStartTime = Date()
        startInternalTimer()
    }
    
    func resetTimer() {
        stopInternalTimer()
        stopSunscreenTimer()
        currentState = .notStarted
        elapsedTime = 0
        totalExposureTime = 0
        sessionStartTime = nil
        lastUVChangeTime = nil
        exposureAtLastUVChange = 0
        sunscreenStatus = nil
    }
    
    // MARK: - UV Index Management
    func updateUVIndex(_ newUVIndex: Int) {
        let previousUV = currentUVIndex
        currentUVIndex = newUVIndex
        
        // Handle UV 0 (no exposure)
        if newUVIndex == 0 {
            if isTimerRunning {
                pauseTimer()
            }
            currentState = .notStarted
            calculateTimeToBurn()
            return
        }
        
        // Update exposure time if UV changed while timer was running
        if isTimerRunning && previousUV != newUVIndex {
            updateExposureForUVChange(previousUV: previousUV, newUV: newUVIndex)
        }
        
        // Recalculate time to burn
        calculateTimeToBurn()
        
        // Check if exposure limit exceeded with new UV level
        let currentTotalExposure = totalExposureTime + elapsedTime
        if currentTotalExposure >= TimeInterval(timeToBurn) {
            currentState = .exceeded
            stopInternalTimer()
            uvChangeNotification = "⚠️ UV \(newUVIndex) - Exposure limit exceeded!"
            
            // Trigger exposure exceeded notification
            NotificationCenter.default.post(
                name: .exposureExceeded,
                object: nil,
                userInfo: [
                    "uvIndex": newUVIndex,
                    "previousUV": previousUV,
                    "timeToBurn": timeToBurn
                ]
            )
        }
    }
    
    // MARK: - Sunscreen Management
    func applySunscreen() {
        let applicationTime = Date()
        let reapplyTime = applicationTime.addingTimeInterval(sunscreenReapplyInterval)
        
        sunscreenStatus = SunscreenStatus(
            applicationTime: applicationTime,
            reapplyTime: reapplyTime,
            isActive: true
        )
        
        // Pause UV exposure timer
        if isTimerRunning {
            pauseTimer()
            currentState = .sunscreenApplied
        }
        
        // Reset session for new sunscreen application
        sessionStartTime = nil
        lastUVChangeTime = nil
        exposureAtLastUVChange = 0
        
        // Start sunscreen timer
        startSunscreenTimer()
    }
    
    func checkSunscreenExpiration() {
        guard let status = sunscreenStatus, status.isExpired else { return }
        
        // Sunscreen has expired, trigger alarm
        print("🧴 [UVExposureTimer] 🚨 Sunscreen timer expired!")
        
        // Post notification for sunscreen expiration alarm
        NotificationCenter.default.post(
            name: .sunscreenExpired,
            object: nil,
            userInfo: [
                "applicationTime": status.applicationTime,
                "reapplyTime": status.reapplyTime
            ]
        )
        
        // Automatically resume UV exposure tracking
        sunscreenStatus = nil
        if currentState == .sunscreenApplied {
            currentState = .paused
        }
        
        // Stop sunscreen timer
        stopSunscreenTimer()
        
        // Resume UV exposure timer if UV is present
        if currentUVIndex > 0 {
            print("🧴 [UVExposureTimer] 🔄 Automatically resuming UV exposure tracking")
            resumeTimer()
        }
    }
    
    func cancelSunscreenTimer() {
        sunscreenStatus = nil
        stopSunscreenTimer()
        
        // Resume UV exposure tracking if timer was paused for sunscreen
        if currentState == .sunscreenApplied {
            currentState = .paused
        }
    }
    
    // MARK: - Private Methods
    private func startInternalTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: timerUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    private func stopInternalTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startSunscreenTimer() {
        stopSunscreenTimer()
        
        // Update sunscreen timer every second
        sunscreenTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSunscreenTimer()
        }
    }
    
    private func stopSunscreenTimer() {
        sunscreenTimer?.invalidate()
        sunscreenTimer = nil
    }
    
    private func updateSunscreenTimer() {
        // This will trigger the published property update
        // The TimerViewModel will handle the Live Activity update
    }
    
    private func updateTimer() {
        guard let startTime = sessionStartTime else { return }
        
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Update total exposure time in real-time for progress calculation
        let currentTotalExposure = totalExposureTime + elapsedTime
        
        // Check sunscreen expiration
        checkSunscreenExpiration()
        
        // Check if exposure limit exceeded
        if currentTotalExposure >= TimeInterval(timeToBurn) {
            currentState = .exceeded
            stopInternalTimer()
            
            // Trigger exposure exceeded notification
            NotificationCenter.default.post(
                name: .exposureExceeded,
                object: nil,
                userInfo: [
                    "uvIndex": currentUVIndex,
                    "previousUV": currentUVIndex, // Same UV since this is normal timer update
                    "timeToBurn": timeToBurn
                ]
            )
        }
    }
    
    private func updateExposureForUVChange(previousUV: Int, newUV: Int) {
        guard let startTime = sessionStartTime else { return }
        
        // Calculate exposure time at previous UV level
        let exposureAtPreviousUV = Date().timeIntervalSince(startTime)
        
        // Convert exposure time to equivalent time at new UV level
        // Higher UV levels cause more damage, so we need to scale the exposure time
        let previousTimeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: previousUV)
        let newTimeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: newUV)
        
        // Calculate what percentage of the previous UV's limit was reached
        let exposurePercentage = exposureAtPreviousUV / TimeInterval(previousTimeToBurn)
        
        // Convert that percentage to equivalent time at the new UV level
        let equivalentExposureAtNewUV = exposurePercentage * TimeInterval(newTimeToBurn)
        
        // Update total exposure time with the converted equivalent exposure
        totalExposureTime = exposureAtLastUVChange + equivalentExposureAtNewUV
        
        // Update tracking for new UV level
        lastUVChangeTime = Date()
        exposureAtLastUVChange = totalExposureTime
        
        // Reset session start time to now, so elapsed time starts fresh for new UV level
        sessionStartTime = Date()
        elapsedTime = 0
        
        // Calculate remaining time with new UV level
        let remainingTime = max(0, TimeInterval(newTimeToBurn) - totalExposureTime)
        
        // Provide user notification about UV change
        if newUV > previousUV {
            uvChangeNotification = "☀️ UV increased to \(newUV) - Time remaining: \(formatTime(remainingTime))"
        } else if newUV < previousUV {
            uvChangeNotification = "🌤️ UV decreased to \(newUV) - Time remaining: \(formatTime(remainingTime))"
        }
        
        // Clear notification after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.uvChangeNotification = nil
        }
    }
    
    private func calculateTimeToBurn() {
        if currentUVIndex == 0 {
            timeToBurn = Int.max
        } else {
            timeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: currentUVIndex)
        }
    }
    
    // MARK: - Time Formatting
    func formatTime(_ timeInterval: TimeInterval) -> String {
        return UnitConverter.shared.formatTime(timeInterval, style: .standard)
    }
    
    func formatRemainingTime() -> String {
        formatTime(remainingTime)
    }
    
    // MARK: - Exposure Status
    func getExposureStatus() -> (message: String, color: String) {
        if currentUVIndex == 0 {
            return ("Safe", "green")
        } else if currentState == .exceeded {
            return ("Exceeded", "red")
        } else if exposureProgress >= 0.8 {
            return ("Warning", "orange")
        } else {
            return ("Safe", "green")
        }
    }
} 