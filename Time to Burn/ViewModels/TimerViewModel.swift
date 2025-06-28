import Foundation
import SwiftUI

class TimerViewModel: ObservableObject {
    @Published var isTimerRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var totalExposureTime: TimeInterval = 0
    @Published var currentUVIndex: Int = 0
    @Published var timeToBurn: Int = 0
    @Published var sunscreenReapplyTime: TimeInterval = 0
    @Published var lastSunscreenApplication: Date?
    
    private var timer: Timer?
    private let sunscreenReapplyInterval: TimeInterval = 2 * 60 * 60 // 2 hours in seconds
    
    init() {
        calculateTimeToBurn()
    }
    
    func startTimer() {
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.elapsedTime += 1
            self.totalExposureTime += 1
            self.checkSunscreenReapply()
        }
    }
    
    func pauseTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func resetTimer() {
        pauseTimer()
        elapsedTime = 0
        totalExposureTime = 0
        lastSunscreenApplication = nil
        sunscreenReapplyTime = 0
    }
    
    func updateUVIndex(_ uvIndex: Int) {
        currentUVIndex = uvIndex
        calculateTimeToBurn()
    }
    
    private func calculateTimeToBurn() {
        timeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: currentUVIndex)
    }
    
    private func checkSunscreenReapply() {
        guard let lastApplication = lastSunscreenApplication else {
            sunscreenReapplyTime = sunscreenReapplyInterval
            return
        }
        
        let timeSinceLastApplication = Date().timeIntervalSince(lastApplication)
        sunscreenReapplyTime = max(0, sunscreenReapplyInterval - timeSinceLastApplication)
    }
    
    func applySunscreen() {
        lastSunscreenApplication = Date()
        sunscreenReapplyTime = sunscreenReapplyInterval
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func getExposureProgress() -> Double {
        guard timeToBurn > 0 else { return 0 }
        return min(Double(elapsedTime) / (Double(timeToBurn) * 60.0), 1.0)
    }
    
    func getExposureStatus() -> ExposureStatus {
        let progress = getExposureProgress()
        
        if progress >= 1.0 {
            return .exceeded
        } else if progress >= 0.8 {
            return .warning
        } else {
            return .safe
        }
    }
    
    enum ExposureStatus {
        case safe
        case warning
        case exceeded
        
        var color: Color {
            switch self {
            case .safe:
                return .green
            case .warning:
                return .orange
            case .exceeded:
                return .red
            }
        }
        
        var message: String {
            switch self {
            case .safe:
                return "Safe Exposure"
            case .warning:
                return "Approaching Limit"
            case .exceeded:
                return "Exposure Exceeded"
            }
        }
    }
} 