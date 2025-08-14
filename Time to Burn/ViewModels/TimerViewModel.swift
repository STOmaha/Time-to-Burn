import Foundation
import SwiftUI
import UserNotifications
import ActivityKit
import WidgetKit
import Combine
import AudioToolbox

@MainActor
class TimerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isTimerRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var totalExposureTime: TimeInterval = 0
    @Published var currentUVIndex: Int = 0
    @Published var timeToBurn: Int = 0
    @Published var sunscreenReapplyTime: TimeInterval = 0
    @Published var lastSunscreenApplication: Date?
    @Published var isUVZero = false
    @Published var currentState: UVExposureState = .notStarted
    @Published var sunscreenStatus: SunscreenStatus?
    @Published var uvChangeNotification: String?
    @Published var sunscreenTimerRemaining: TimeInterval = 0
    @Published var isSunscreenActive: Bool = false
    @Published var shouldShowSunscreenPrompt: Bool = false
    
    // MARK: - Private Properties
    private let uvTimer = UVExposureTimer()
    private let notificationManager = NotificationManager.shared
    private let sharedDataManager = MainAppSharedDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies for location and weather data
    private var locationManager: LocationManager?
    private var weatherViewModel: WeatherViewModel?
    
    // Background timer persistence using system clock
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Live Activity
    private var uvExposureActivity: Activity<UVExposureAttributes>?
    private var liveActivityUpdateTimer: Timer?
    
    // MARK: - Initialization
    init() {
        print("⏰ [TimerViewModel] 🚀 Initializing...")
        
        setupBindings()
        loadPersistedData()
        setupBackgroundHandling()
        setupBackgroundDailyReset()
        setupExposureExceededListener()
        setupSunscreenExpiredListener()
        // Don't update shared data until we have real weather data
        // updateSharedData() will be called when dependencies are set
        
        print("⏰ [TimerViewModel] ✅ Initialization complete")
    }
    
    // MARK: - Dependency Injection
    func setDependencies(locationManager: LocationManager, weatherViewModel: WeatherViewModel) {
        self.locationManager = locationManager
        self.weatherViewModel = weatherViewModel
        
        print("⏰ [TimerViewModel] 🔗 Dependencies set")
        
        // Listen for weather data flow state changes
        weatherViewModel.$dataFlowState
            .sink { [weak self] state in
                if state == .weatherLoaded {
                    print("⏰ [TimerViewModel] ✅ Weather data loaded, updating shared data...")
                    self?.updateSharedData()
                    
                    // Force widget refresh when weather data is loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("⏰ [TimerViewModel] 🔄 Triggering widget refresh after weather data load")
                        WidgetCenter.shared.reloadAllTimelines()
                        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
                    }
                }
            }
            .store(in: &cancellables)
        
        // Also listen for weather data updates (for refreshes)
        weatherViewModel.$lastUpdated
            .sink { [weak self] _ in
                if weatherViewModel.dataFlowState == .weatherLoaded {
                    self?.updateSharedData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind UV timer properties to published properties
        uvTimer.$currentState
            .assign(to: \.currentState, on: self)
            .store(in: &cancellables)
        
        uvTimer.$elapsedTime
            .assign(to: \.elapsedTime, on: self)
            .store(in: &cancellables)
        
        uvTimer.$totalExposureTime
            .assign(to: \.totalExposureTime, on: self)
            .store(in: &cancellables)
        
        uvTimer.$currentUVIndex
            .assign(to: \.currentUVIndex, on: self)
            .store(in: &cancellables)
        
        uvTimer.$timeToBurn
            .assign(to: \.timeToBurn, on: self)
            .store(in: &cancellables)
        
        uvTimer.$timeToBurn
            .sink { [weak self] _ in
                self?.updateLiveActivity()
            }
            .store(in: &cancellables)
        
        uvTimer.$sunscreenStatus
            .assign(to: \.sunscreenStatus, on: self)
            .store(in: &cancellables)
        
        uvTimer.$uvChangeNotification
            .assign(to: \.uvChangeNotification, on: self)
            .store(in: &cancellables)
        
        // Update computed properties when state changes
        uvTimer.$currentState
            .sink { [weak self] _ in
                self?.isTimerRunning = self?.uvTimer.isTimerRunning ?? false
                self?.isUVZero = self?.uvTimer.isUVZero ?? false
            }
            .store(in: &cancellables)
        
        uvTimer.$currentUVIndex
            .sink { [weak self] _ in
                self?.isUVZero = self?.uvTimer.isUVZero ?? false
            }
            .store(in: &cancellables)
        
        // Update Live Activity when timer updates (every second)
        uvTimer.$elapsedTime
            .sink { [weak self] _ in
                self?.updateLiveActivity()
            }
            .store(in: &cancellables)
        
        uvTimer.$totalExposureTime
            .sink { [weak self] _ in
                self?.updateLiveActivity()
            }
            .store(in: &cancellables)
        
        // Also update Live Activity when UV index changes
        uvTimer.$currentUVIndex
            .sink { [weak self] _ in
                self?.updateLiveActivity()
            }
            .store(in: &cancellables)
        
        // Update sunscreen reapply time and timer
        uvTimer.$sunscreenStatus
            .sink { [weak self] status in
                self?.sunscreenReapplyTime = status?.timeRemaining ?? 0
                self?.lastSunscreenApplication = status?.applicationTime
                self?.isSunscreenActive = status?.isActive ?? false
                self?.sunscreenTimerRemaining = status?.timeRemaining ?? 0
                self?.updateLiveActivity()
            }
            .store(in: &cancellables)
        
        // Update sunscreen timer every second when active
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if self?.isSunscreenActive == true {
                    self?.sunscreenTimerRemaining = self?.sunscreenStatus?.timeRemaining ?? 0
                    self?.updateLiveActivity()
                }
            }
            .store(in: &cancellables)
        
        // Check for sunscreen prompt when exposure reaches halfway
        Publishers.CombineLatest3(
            uvTimer.$elapsedTime,
            uvTimer.$totalExposureTime,
            uvTimer.$timeToBurn
        )
        .sink { [weak self] elapsedTime, totalExposureTime, timeToBurn in
            let progress = timeToBurn > 0 ? min((totalExposureTime + elapsedTime) / TimeInterval(timeToBurn), 1.0) : 0.0
            self?.shouldShowSunscreenPrompt = progress >= 0.5 && !(self?.isSunscreenActive ?? false)
            self?.updateLiveActivity()
        }
        .store(in: &cancellables)
        
        // Update shared data when timer changes
        Publishers.CombineLatest4(
            uvTimer.$currentState,
            uvTimer.$elapsedTime,
            uvTimer.$totalExposureTime,
            uvTimer.$currentUVIndex
        )
        .sink { [weak self] _, _, _, _ in
            self?.updateSharedData()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Timer Control
    func startTimer() {
        uvTimer.startTimer()
        startLiveActivity()
        scheduleNotifications()
        savePersistedData()
    }
    
    func pauseTimer() {
        uvTimer.pauseTimer()
        stopLiveActivity()
        endBackgroundTask()
        savePersistedData()
    }
    
    func resumeTimer() {
        uvTimer.resumeTimer()
        startLiveActivity()
        savePersistedData()
    }
    
    func resetTimer() {
        uvTimer.resetTimer()
        stopLiveActivity()
        endBackgroundTask()
        savePersistedData()
    }
    
    func applySunscreen() {
        uvTimer.applySunscreen()
        
        // Start or update Live Activity for sunscreen countdown
        if uvExposureActivity == nil {
            // Start new Live Activity if none exists
            startLiveActivity()
        } else {
            // Update existing Live Activity
            updateLiveActivity()
        }
        
        // Schedule sunscreen reminder
        if let status = sunscreenStatus {
            notificationManager.scheduleSunscreenReminder(at: status.reapplyTime)
        }
        
        savePersistedData()
    }
    
    func cancelSunscreenTimer() {
        uvTimer.cancelSunscreenTimer()
        
        // Update Live Activity or stop it if no timer is running
        if isTimerRunning {
            updateLiveActivity()
        } else {
            stopLiveActivity()
        }
        
        // Cancel any scheduled sunscreen reminders
        notificationManager.cancelSunscreenReminders()
        
        savePersistedData()
    }
    
    // MARK: - Time Adjustment Methods
    func adjustUnrecordedSunTime(_ adjustment: TimeInterval) {
        // Adjust the total exposure time to account for unrecorded sun exposure
        // Positive values add time, negative values subtract time
        let newTotalExposure = totalExposureTime + adjustment
        totalExposureTime = max(0, newTotalExposure)
        
        // Update the UV timer's total exposure time
        uvTimer.totalExposureTime = totalExposureTime
        
        // Save the adjusted data
        savePersistedData()
        updateSharedData()
        updateLiveActivity()
        
        print("⏰ [TimerViewModel] ☀️ Adjusted unrecorded sun time by \(adjustment) seconds. New total: \(totalExposureTime)")
    }
    
    func adjustShadeTime(_ adjustment: TimeInterval) {
        // Adjust the total exposure time to account for time spent in shade
        // Positive values add time (more shade = less exposure), negative values subtract time
        let newTotalExposure = totalExposureTime - adjustment
        totalExposureTime = max(0, newTotalExposure)
        
        // Update the UV timer's total exposure time
        uvTimer.totalExposureTime = totalExposureTime
        
        // Save the adjusted data
        savePersistedData()
        updateSharedData()
        updateLiveActivity()
        
        print("⏰ [TimerViewModel] 🌳 Adjusted shade time by \(adjustment) seconds. New total: \(totalExposureTime)")
    }
    
    // MARK: - UV Index Updates
    func updateUVIndex(_ uvIndex: Int) {
        uvTimer.updateUVIndex(uvIndex)
        // Ensure Live Activity is always updated after UV change and recalculation
        updateLiveActivity()
        // Update shared data for widget when UV changes
        updateSharedData()
    }
    
    // MARK: - Exposure Exceeded Handling
    private func setupExposureExceededListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExposureExceeded),
            name: .exposureExceeded,
            object: nil
        )
    }
    
    // MARK: - Sunscreen Expired Alarm Handling
    private func setupSunscreenExpiredListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSunscreenExpired),
            name: .sunscreenExpired,
            object: nil
        )
    }
    
    @objc private func handleExposureExceeded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uvIndex = userInfo["uvIndex"] as? Int,
              let previousUV = userInfo["previousUV"] as? Int,
              let timeToBurn = userInfo["timeToBurn"] as? Int else {
            return
        }
        
        print("⏰ [TimerViewModel] 🚨 Exposure exceeded due to UV increase: \(previousUV) → \(uvIndex)")
        
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Schedule system notification
        notificationManager.scheduleExposureWarning(
            warningType: .exceeded,
            timeToBurn: timeToBurn
        )
        
        // Trigger additional haptic feedback for urgency
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        }
        
        // Check if sunscreen should be applied
        checkSunscreenApplicationNeeded()
        
        // Update Live Activity immediately
        updateLiveActivity()
    }
    
    @objc private func handleSunscreenExpired(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let applicationTime = userInfo["applicationTime"] as? Date,
              let reapplyTime = userInfo["reapplyTime"] as? Date else {
            return
        }
        
        print("⏰ [TimerViewModel] 🚨 Sunscreen timer expired! Application: \(applicationTime), Reapply: \(reapplyTime)")
        
        // Trigger multiple haptic feedback for alarm effect
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            impactFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            impactFeedback.impactOccurred()
        }
        
        // Play alarm sound
        playAlarmSound()
        
        // Show alarm modal
        showSunscreenAlarmModal()
        
        // Schedule system notification as backup
        notificationManager.scheduleSunscreenExpiredAlert()
        
        // Update Live Activity to reflect the automatic resume
        updateLiveActivity()
        updateSharedData()
    }
    
    private func playAlarmSound() {
        // Play a custom alarm sound
        AudioServicesPlaySystemSound(1005) // System sound for alarm
    }
    
    private func showSunscreenAlarmModal() {
        // This will be handled by the UI layer
        // The modal will be shown in the main view
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showSunscreenAlarm, object: nil)
        }
    }
    
    private func checkSunscreenApplicationNeeded() {
        // If no sunscreen is active and exposure is exceeded, prompt for sunscreen
        if !isSunscreenActive && currentState == .exceeded {
            print("⏰ [TimerViewModel] 🧴 Prompting for sunscreen application due to exceeded exposure")
            
            // Show sunscreen prompt in UI
            shouldShowSunscreenPrompt = true
            
            // Schedule sunscreen reminder notification
            notificationManager.scheduleSunscreenReminder(at: Date())
        }
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
        
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    @objc private func appWillEnterForeground() {
        guard isTimerRunning else { return }
        
        // Update Live Activity
        updateLiveActivity()
        
        // Refresh location and weather data when coming back to foreground
        if let weatherViewModel = weatherViewModel {
            Task {
                await weatherViewModel.refreshData()
            }
        }
        
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Live Activity
    private func getUVColor(for uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2:
            return "green"
        case 3...5:
            return "yellow"
        case 6...7:
            return "orange"
        case 8...10:
            return "red"
        case 11...:
            return "purple"
        default:
            return "gray"
        }
    }
    
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = UVExposureAttributes(
            uvIndex: currentUVIndex,
            maxExposureTime: timeToBurn,
            sunscreenReapplyTime: sunscreenStatus?.reapplyTime ?? Date()
        )
        
        let contentState = UVExposureAttributes.ContentState(
            elapsedTime: elapsedTime,
            totalExposureTime: totalExposureTime,
            isTimerRunning: isTimerRunning,
            lastSunscreenApplication: lastSunscreenApplication,
            uvChangeNotification: uvChangeNotification,
            sunscreenTimerRemaining: sunscreenTimerRemaining,
            isSunscreenActive: isSunscreenActive,
            exposureProgress: uvTimer.exposureProgress,
            shouldShowSunscreenPrompt: shouldShowSunscreenPrompt,
            sunscreenExpirationTime: sunscreenStatus?.reapplyTime,
            sunscreenProgress: sunscreenStatus != nil ? max(0, 1.0 - (sunscreenTimerRemaining / (2 * 60 * 60))) : 0.0,
            currentUVIndex: currentUVIndex,
            currentUVColor: getUVColor(for: currentUVIndex)
        )
        
        do {
            uvExposureActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil),
                pushType: nil
            )
            
            // Start frequent Live Activity updates
            startLiveActivityUpdateTimer()
            
            print("⏰ [TimerViewModel] 🚀 Live Activity started - Sunscreen active: \(isSunscreenActive), Timer running: \(isTimerRunning)")
        } catch {
            print("⏰ [TimerViewModel] ❌ Failed to start Live Activity: \(error)")
        }
    }
    
    private func updateLiveActivity() {
        Task {
            let contentState = UVExposureAttributes.ContentState(
                elapsedTime: elapsedTime,
                totalExposureTime: totalExposureTime,
                isTimerRunning: isTimerRunning,
                lastSunscreenApplication: lastSunscreenApplication,
                uvChangeNotification: uvChangeNotification,
                sunscreenTimerRemaining: sunscreenTimerRemaining,
                isSunscreenActive: isSunscreenActive,
                exposureProgress: uvTimer.exposureProgress,
                shouldShowSunscreenPrompt: shouldShowSunscreenPrompt,
                sunscreenExpirationTime: sunscreenStatus?.reapplyTime,
                sunscreenProgress: sunscreenStatus != nil ? max(0, 1.0 - (sunscreenTimerRemaining / (2 * 60 * 60))) : 0.0,
                currentUVIndex: currentUVIndex,
                currentUVColor: getUVColor(for: currentUVIndex)
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
                lastSunscreenApplication: lastSunscreenApplication,
                uvChangeNotification: uvChangeNotification,
                sunscreenTimerRemaining: sunscreenTimerRemaining,
                isSunscreenActive: isSunscreenActive,
                exposureProgress: uvTimer.exposureProgress,
                shouldShowSunscreenPrompt: shouldShowSunscreenPrompt,
                sunscreenExpirationTime: sunscreenStatus?.reapplyTime,
                sunscreenProgress: sunscreenStatus != nil ? max(0, 1.0 - (sunscreenTimerRemaining / (2 * 60 * 60))) : 0.0,
                currentUVIndex: currentUVIndex,
                currentUVColor: getUVColor(for: currentUVIndex)
            )
            
            await uvExposureActivity?.end(ActivityContent(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
            uvExposureActivity = nil
            
            // Stop Live Activity update timer
            stopLiveActivityUpdateTimer()
        }
    }
    
    private func startLiveActivityUpdateTimer() {
        // Stop existing timer if running
        stopLiveActivityUpdateTimer()
        
        // Update Live Activity every 2 seconds for smooth updates
        liveActivityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateLiveActivity()
            }
        }
    }
    
    private func stopLiveActivityUpdateTimer() {
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
    }
    
    // MARK: - Notifications
    private func scheduleNotifications() {
        // Schedule sunscreen reminder if not already scheduled
        if sunscreenStatus == nil {
            notificationManager.scheduleSunscreenReminder(at: Date().addingTimeInterval(2 * 60 * 60))
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
        
        // Check for daily reset - if last sunscreen application was on a different day, reset it
        checkAndResetDailySunscreen()
        
        // Restore UV timer state
        uvTimer.updateUVIndex(currentUVIndex)
        
        // Note: Timer will only start when user explicitly starts it
        // No automatic timer restoration on app launch
        // Reset timer running state to ensure user must manually start
        isTimerRunning = false
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
    
    // MARK: - Daily Reset Logic
    private func checkAndResetDailySunscreen() {
        guard let lastApplication = lastSunscreenApplication else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Check if the last sunscreen application was on a different day
        if !calendar.isDate(lastApplication, inSameDayAs: today) {
            print("⏰ [TimerViewModel] 🌅 Daily reset: Last sunscreen application was on \(lastApplication), resetting for new day")
            
            // Reset sunscreen status
            lastSunscreenApplication = nil
            sunscreenReapplyTime = 0
            isSunscreenActive = false
            sunscreenTimerRemaining = 0
            
            // Reset the UV timer's sunscreen status
            uvTimer.cancelSunscreenTimer()
            
            // Update shared data and widget
            updateSharedData()
            refreshWidget()
        }
    }
    
    // MARK: - App Lifecycle Handling
    func handleAppBecameActive() {
        // Check for daily reset when app becomes active
        checkAndResetDailySunscreen()
        
        // Schedule daily summary if enabled
        notificationManager.scheduleDailySummaryIfNeeded()
    }
    
    // MARK: - Background Daily Reset
    private func setupBackgroundDailyReset() {
        // Calculate time until next midnight
        let calendar = Calendar.current
        let now = Date()
        
        // Get tomorrow's midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let timeUntilMidnight = midnight.timeIntervalSince(now)
        
        print("⏰ [TimerViewModel] 🌅 Setting up background daily reset for \(midnight) (in \(timeUntilMidnight/3600) hours)")
        
        // Schedule timer for midnight
        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilMidnight) { [weak self] in
            self?.performDailyReset()
            // Set up the next midnight reset
            self?.setupBackgroundDailyReset()
        }
    }
    
    private func performDailyReset() {
        print("⏰ [TimerViewModel] 🌅 Performing scheduled daily reset at midnight")
        
        // Reset sunscreen status
        lastSunscreenApplication = nil
        sunscreenReapplyTime = 0
        isSunscreenActive = false
        sunscreenTimerRemaining = 0
        
        // Reset the UV timer's sunscreen status
        uvTimer.cancelSunscreenTimer()
        
        // Save the reset state
        savePersistedData()
        
        // Update shared data and widget
        updateSharedData()
        refreshWidget()
        
        // Schedule daily summary for the new day if enabled
        notificationManager.scheduleDailySummaryIfNeeded()
        
        print("⏰ [TimerViewModel] ✅ Daily reset completed")
    }
    
    // MARK: - Shared Data Management
    private func updateSharedData() {
        // Only update shared data if we have real weather data
        guard let weatherViewModel = weatherViewModel,
              weatherViewModel.lastUpdated != nil else {
            print("⏰ [TimerViewModel] ⏳ Waiting for real weather data before updating shared data")
            return
        }
        
        // Use the current UV data from WeatherViewModel, not the cached TimerViewModel data
        let currentUVFromWeather = weatherViewModel.getCurrentUVIndex()
        let currentUVData = weatherViewModel.getCurrentUVData()
        
        let locationName = locationManager?.locationName ?? "Unknown Location"
        let lastUpdated = weatherViewModel.lastUpdated ?? Date()
        let todayHourlyData = weatherViewModel.hourlyUVData
        
        // Calculate time to burn based on current UV index from weather data
        let calculatedTimeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: currentUVFromWeather)
        
        print("⏰ [TimerViewModel] 📊 Widget Data - UV: \(currentUVFromWeather), Time to Burn: \(calculatedTimeToBurn/60)min, Location: \(locationName)")
        
        let exposureStatus: SharedUVData.ExposureStatus
        if currentUVFromWeather == 0 {
            exposureStatus = .noUV
        } else {
            let totalExposure = totalExposureTime + elapsedTime
            let maxExposure = TimeInterval(calculatedTimeToBurn)
            
            if totalExposure >= maxExposure {
                exposureStatus = .exceeded
            } else if totalExposure >= maxExposure * 0.8 {
                exposureStatus = .warning
            } else {
                exposureStatus = .safe
            }
        }
        
        let _ = SharedUVData(
            currentUVIndex: currentUVFromWeather,
            timeToBurn: calculatedTimeToBurn,
            elapsedTime: elapsedTime,
            totalExposureTime: totalExposureTime,
            isTimerRunning: isTimerRunning,
            lastSunscreenApplication: lastSunscreenApplication,
            sunscreenReapplyTimeRemaining: getSunscreenReapplyTimeRemaining(),
            exposureStatus: exposureStatus,
            exposureProgress: getExposureProgress(),
            locationName: locationName,
            lastUpdated: lastUpdated,
            hourlyUVData: todayHourlyData,
            currentCloudCover: currentUVData?.cloudCover ?? 0,
            currentCloudCondition: currentUVData?.cloudCondition ?? "Clear"
        )
        
        // Save shared data
        // TODO: Re-enable shared data saving after fixing crash
        // sharedDataManager.saveSharedData(sharedData)
        print("⏰ [TimerViewModel] ✅ Shared data saving disabled - investigating crash")
        
        // Refresh widget
        refreshWidget()
    }
    
    // MARK: - Widget Refresh
    // TODO: Re-enable widget functionality after fixing crash
    func refreshWidget() {
        print("⏰ [TimerViewModel] 📱 Widget refresh disabled - investigating crash")
        // WidgetCenter.shared.reloadAllTimelines()
        // WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
    }
    
    // MARK: - Aggressive Widget Refresh
    // TODO: Re-enable widget functionality after fixing crash
    func forceAggressiveWidgetRefresh() {
        print("⏰ [TimerViewModel] 🔄 Force aggressive widget refresh disabled - investigating crash")
        
        updateSharedData()
        
        // Multiple refresh attempts with delays
        // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        //     WidgetCenter.shared.reloadAllTimelines()
        // }
        
        // DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        //     WidgetCenter.shared.reloadAllTimelines()
        // }
    }
    
    // MARK: - Debug Methods
    func testWidgetData() {
        print("⏰ [TimerViewModel] 🧪 Testing widget data")
        
        currentUVIndex = 7
        timeToBurn = 120
        elapsedTime = 30
        totalExposureTime = 15
        isTimerRunning = true
        
        updateSharedData()
        print("⏰ [TimerViewModel] ✅ Test data saved")
    }
    
    // MARK: - Widget Status Check
    // TODO: Re-enable widget functionality after fixing crash
    func checkWidgetStatus() {
        print("⏰ [TimerViewModel] 🔍 Widget status check disabled - investigating crash")
        
        // WidgetCenter.shared.getCurrentConfigurations { result in
        //     switch result {
        //     case .success(let configurations):
        //         print("⏰ [TimerViewModel] 📱 Found \(configurations.count) widget configurations")
        //         if configurations.isEmpty {
        //             print("⏰ [TimerViewModel] ⚠️  WARNING - No widgets found! Add widget to home screen.")
        //         }
        //     case .failure(let error):
        //         print("⏰ [TimerViewModel] ❌ Error checking widgets: \(error)")
        //     }
        // }
        
        let sharedData = MainAppSharedDataManager.shared.loadSharedData()
        if let data = sharedData {
            print("⏰ [TimerViewModel] ✅ Shared data accessible - UV: \(data.currentUVIndex)")
        } else {
            print("⏰ [TimerViewModel] ⚠️  WARNING - Shared data not accessible!")
        }
    }
    
    // MARK: - Helper Methods
    func formatTime(_ timeInterval: TimeInterval) -> String {
        uvTimer.formatTime(timeInterval)
    }
    
    func getExposureStatus() -> (message: String, color: Color) {
        let status = uvTimer.getExposureStatus()
        let color: Color
        switch status.color {
        case "green": color = .green
        case "orange": color = .orange
        case "red": color = .red
        default: color = .green
        }
        return (status.message, color)
    }
    
    func getExposureProgress() -> Double {
        uvTimer.exposureProgress
    }
    
    func getSunscreenReapplyTimeRemaining() -> TimeInterval {
        sunscreenStatus?.timeRemaining ?? 0
    }
    
    func getRemainingTime() -> String {
        uvTimer.formatRemainingTime()
    }
    
    // MARK: - UV Data Sync
    func syncWithCurrentUVData(uvIndex: Int) {
        print("⏰ [TimerViewModel] 🔄 Syncing with UV data - UV: \(uvIndex)")
        updateUVIndex(uvIndex)
        // Redundant but safe: ensure Live Activity is updated
        updateLiveActivity()
    }
    
    // MARK: - Manual Widget Test
    func forceWidgetRefresh() {
        print("⏰ [TimerViewModel] 🔄 Manual widget refresh triggered")
        
        // Update shared data first
        updateSharedData()
        
        // Force widget refresh with multiple approaches
        print("⏰ [TimerViewModel] 📱 Calling WidgetCenter.shared.reloadAllTimelines()")
        WidgetCenter.shared.reloadAllTimelines()
        
        print("⏰ [TimerViewModel] 📱 Calling WidgetCenter.shared.reloadTimelines(ofKind: TimeToBurnWidget)")
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
        
        // Check available widgets
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let configurations):
                print("⏰ [TimerViewModel] 📱 Available widget configurations: \(configurations.count)")
                for config in configurations {
                    print("⏰ [TimerViewModel] 📱 Widget kind: \(config.kind)")
                }
            case .failure(let error):
                print("⏰ [TimerViewModel] ❌ Error getting widget configurations: \(error)")
            }
        }
        
        // Also try a delayed refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⏰ [TimerViewModel] ⏰ Delayed widget refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        print("⏰ [TimerViewModel] ✅ Manual test completed")
    }
    
    // MARK: - Enhanced Widget Refresh with Debug
    func forceEnhancedWidgetRefresh() {
        print("⏰ [TimerViewModel] 🚀 Enhanced widget refresh triggered")
        
        // First, update shared data
        print("⏰ [TimerViewModel] 💾 Updating shared data...")
        updateSharedData()
        
        // Check current shared data
        let sharedData = MainAppSharedDataManager.shared.loadSharedData()
        if let data = sharedData {
            print("⏰ [TimerViewModel] ✅ Shared data verified:")
            print("   📊 UV Index: \(data.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(data.timeToBurn / 60)min")
            print("   📍 Location: \(data.locationName)")
            print("   ──────────────────────────────────────")
        } else {
            print("⏰ [TimerViewModel] ❌ Shared data not available!")
        }
        
        // Force immediate widget refresh
        print("⏰ [TimerViewModel] 📱 Forcing immediate widget refresh...")
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
        
        // Check widget configurations
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let configurations):
                print("⏰ [TimerViewModel] 📱 Widget Status Report:")
                print("   📊 Total configurations: \(configurations.count)")
                
                if configurations.isEmpty {
                    print("   ⚠️  WARNING: No widgets found! Add widget to home screen.")
                } else {
                    for (index, config) in configurations.enumerated() {
                        print("   📱 Widget \(index + 1): \(config.kind)")
                    }
                }
                print("   ──────────────────────────────────────")
            case .failure(let error):
                print("⏰ [TimerViewModel] ❌ Error checking widgets: \(error)")
            }
        }
        
        // Multiple delayed refreshes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("⏰ [TimerViewModel] ⏰ 1-second delayed refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("⏰ [TimerViewModel] ⏰ 3-second delayed refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("⏰ [TimerViewModel] ⏰ 5-second delayed refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        print("⏰ [TimerViewModel] ✅ Enhanced widget refresh completed")
    }
    
    // MARK: - Simple Widget Test
    func simpleWidgetTest() {
        print("⏰ [TimerViewModel] 🧪 Simple widget test started")
        
        // Save some test data
        let testData = SharedUVData(
            currentUVIndex: 7,
            timeToBurn: 1800, // 30 minutes
            elapsedTime: 300, // 5 minutes
            totalExposureTime: 600, // 10 minutes
            isTimerRunning: true,
            lastSunscreenApplication: Date(),
            sunscreenReapplyTimeRemaining: 1200,
            exposureStatus: .warning,
            exposureProgress: 0.5,
            locationName: "Test Location",
            lastUpdated: Date(),
            hourlyUVData: nil
        )
        
        MainAppSharedDataManager.shared.saveSharedData(testData)
        
        // Force widget refresh
        print("⏰ [TimerViewModel] 📱 Calling WidgetCenter.shared.reloadAllTimelines()")
        WidgetCenter.shared.reloadAllTimelines()
        
        print("⏰ [TimerViewModel] 📱 Calling WidgetCenter.shared.reloadTimelines(ofKind: TimeToBurnWidget)")
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
        
        print("⏰ [TimerViewModel] ✅ Simple widget test completed")
    }
    
    // MARK: - Widget Data Test
    func testWidgetDataFlow() {
        print("⏰ [TimerViewModel] 🧪 Testing widget data flow...")
        
        // Create test data with current time
        let testData = SharedUVData(
            currentUVIndex: 8,
            timeToBurn: 1800, // 30 minutes
            elapsedTime: 600, // 10 minutes
            totalExposureTime: 900, // 15 minutes
            isTimerRunning: false,
            lastSunscreenApplication: nil,
            sunscreenReapplyTimeRemaining: 0,
            exposureStatus: .warning,
            exposureProgress: 0.6,
            locationName: "Test Location",
            lastUpdated: Date(),
            hourlyUVData: nil
        )
        
        // Save to all possible locations
        print("⏰ [TimerViewModel] 💾 Saving test data...")
        
        // Save via shared data manager
        // TODO: Re-enable shared data saving after fixing crash
        // MainAppSharedDataManager.shared.saveSharedData(testData)
        print("⏰ [TimerViewModel] ✅ Test data saving disabled - investigating crash")
        
        // Save directly to app group
        if let encoded = try? JSONEncoder().encode(testData) {
            if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
                userDefaults.set(encoded, forKey: "sharedUVData")
                userDefaults.synchronize()
                print("⏰ [TimerViewModel] ✅ Saved to app group UserDefaults")
            }
            
            // Save to standard UserDefaults as backup
            UserDefaults.standard.set(encoded, forKey: "sharedUVData")
            print("⏰ [TimerViewModel] ✅ Saved to standard UserDefaults")
        }
        
        // Force widget refresh
        print("⏰ [TimerViewModel] 📱 Forcing widget refresh...")
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
        
        print("⏰ [TimerViewModel] ✅ Widget data flow test completed")
    }
    
    // MARK: - Comprehensive Widget Test
    func comprehensiveWidgetTest() {
        print("⏰ [TimerViewModel] 🔬 Comprehensive widget test started")
        
        // Test 1: Check if widget extension is available
        print("⏰ [TimerViewModel] 🔍 Test 1: Checking widget availability...")
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let configurations):
                print("⏰ [TimerViewModel] ✅ Widget configurations found: \(configurations.count)")
                for config in configurations {
                    print("⏰ [TimerViewModel] 📱 Widget: \(config.kind)")
                }
            case .failure(let error):
                print("⏰ [TimerViewModel] ❌ Error getting widget configurations: \(error)")
            }
        }
        
        // Test 2: Save test data to multiple locations
        print("⏰ [TimerViewModel] 🔍 Test 2: Saving test data...")
        let testData = SharedUVData(
            currentUVIndex: 9,
            timeToBurn: 1200, // 20 minutes
            elapsedTime: 600, // 10 minutes
            totalExposureTime: 900, // 15 minutes
            isTimerRunning: false,
            lastSunscreenApplication: nil,
            sunscreenReapplyTimeRemaining: 0,
            exposureStatus: .exceeded,
            exposureProgress: 0.8,
            locationName: "Test Location",
            lastUpdated: Date(),
            hourlyUVData: nil
        )
        
        // Save to app group
        if let encoded = try? JSONEncoder().encode(testData) {
            if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
                userDefaults.set(encoded, forKey: "sharedUVData")
                print("⏰ [TimerViewModel] ✅ Saved to app group UserDefaults")
            } else {
                print("⏰ [TimerViewModel] ❌ Failed to save to app group UserDefaults")
            }
            
            // Save to standard UserDefaults
            UserDefaults.standard.set(encoded, forKey: "sharedUVData")
            print("⏰ [TimerViewModel] ✅ Saved to standard UserDefaults")
            
            // Save to alternative app group
            if let altUserDefaults = UserDefaults(suiteName: "group.Time-to-Burn.shared") {
                altUserDefaults.set(encoded, forKey: "sharedUVData")
                print("⏰ [TimerViewModel] ✅ Saved to alternative app group UserDefaults")
            } else {
                print("⏰ [TimerViewModel] ❌ Failed to save to alternative app group UserDefaults")
            }
        }
        
        // Test 3: Force widget refresh multiple times
        print("⏰ [TimerViewModel] 🔍 Test 3: Forcing widget refresh...")
        
        // Immediate refresh
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
        
        // Delayed refreshes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("⏰ [TimerViewModel] ⏰ 1-second delayed refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("⏰ [TimerViewModel] ⏰ 3-second delayed refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("⏰ [TimerViewModel] ⏰ 5-second delayed refresh")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        print("⏰ [TimerViewModel] ✅ Comprehensive widget test completed")
    }
    
    // MARK: - Live Activity Actions
    func openTimerTab() {
        // This will be handled by the app's deep linking system
        NotificationCenter.default.post(name: .openTimerTab, object: nil)
    }
    
    func applySunscreenFromLiveActivity() {
        applySunscreen()
        openTimerTab()
    }
    
    // MARK: - Live Activity Testing Methods
    func testStartLiveActivity() {
        print("⏰ [TimerViewModel] 🧪 Testing Live Activity start...")
        startLiveActivity()
    }
    
    func testUpdateLiveActivity() {
        print("⏰ [TimerViewModel] 🧪 Testing Live Activity update...")
        updateLiveActivity()
    }
    
    func testStopLiveActivity() {
        print("⏰ [TimerViewModel] 🧪 Testing Live Activity stop...")
        stopLiveActivity()
    }
    
    // MARK: - Notification Testing
    func testNotifications() {
        print("⏰ [TimerViewModel] 🧪 Testing notifications...")
        
        // Test notification permission
        Task {
            await notificationManager.forceRequestNotificationPermission()
            
            // Send test notification
            notificationManager.sendTestNotification()
            
            // Test sunscreen expired alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.notificationManager.scheduleSunscreenExpiredAlert()
            }
            
            // Test exposure warning
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                self.notificationManager.scheduleExposureWarning(warningType: .exceeded, timeToBurn: 1800)
            }
        }
        
        print("⏰ [TimerViewModel] ✅ Notification tests scheduled")
    }
    

}

// MARK: - Notification Names
extension Notification.Name {
    static let openTimerTab = Notification.Name("openTimerTab")
    static let exposureExceeded = Notification.Name("exposureExceeded")
    static let sunscreenExpired = Notification.Name("sunscreenExpired")
    static let showSunscreenAlarm = Notification.Name("showSunscreenAlarm")
    static let chartTimeSelected = Notification.Name("chartTimeSelected")
    static let chartTimeDeselected = Notification.Name("chartTimeDeselected")
} 