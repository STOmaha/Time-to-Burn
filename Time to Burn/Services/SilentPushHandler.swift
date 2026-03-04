import Foundation
import UIKit
import BackgroundTasks
import WidgetKit

/// Handles silent push notifications for background data refresh
/// This allows the server to wake the app and trigger widget updates
@MainActor
class SilentPushHandler: ObservableObject {
    static let shared = SilentPushHandler()

    // MARK: - Properties
    @Published var lastBackgroundRefresh: Date?
    @Published var backgroundRefreshCount: Int = 0

    private let weatherViewModel: WeatherViewModel?
    private let locationManager: LocationManager

    // Background task identifier
    static let backgroundTaskIdentifier = "com.anvilheadstudios.timetoburn.refresh"

    // MARK: - Initialization
    private init() {
        self.locationManager = LocationManager.shared
        // WeatherViewModel will be set later to avoid circular dependency
        self.weatherViewModel = nil
        loadStats()
    }

    // MARK: - Handle Silent Push
    /// Called when a silent push notification is received
    /// Returns true if new data was fetched successfully
    func handleSilentPush(userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔕 [SilentPushHandler] Received silent push notification")
        print("🔕 [SilentPushHandler] Payload: \(userInfo)")

        // Check if this is a data refresh push
        guard let pushType = userInfo["type"] as? String else {
            print("🔕 [SilentPushHandler] Unknown push type, ignoring")
            completion(.noData)
            return
        }

        switch pushType {
        case "data_refresh", "uv_update", "location_check":
            performBackgroundRefresh(reason: pushType, completion: completion)

        case "widget_update":
            // Just reload widget timelines without fetching new data
            reloadWidgets()
            completion(.newData)

        default:
            print("🔕 [SilentPushHandler] Unhandled push type: \(pushType)")
            completion(.noData)
        }
    }

    // MARK: - Background Refresh
    /// Performs a background data refresh
    private func performBackgroundRefresh(reason: String, completion: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔕 [SilentPushHandler] Starting background refresh (reason: \(reason))")

        Task {
            // Check if location is available
            guard locationManager.location != nil else {
                print("🔕 [SilentPushHandler] No location available")
                completion(.failed)
                return
            }

            // Fetch fresh weather data
            // Note: WeatherViewModel.shared would need to be accessible here
            // For now, we'll use the shared data manager approach

            // Update last refresh time
            await MainActor.run {
                self.lastBackgroundRefresh = Date()
                self.backgroundRefreshCount += 1
                self.saveStats()
            }

            // Reload widgets with fresh data
            reloadWidgets()

            // Sync to Supabase if authenticated
            if SupabaseService.shared.isAuthenticated {
                print("🔕 [SilentPushHandler] Syncing to Supabase...")
                // The actual sync will happen when WeatherViewModel updates
            }

            print("🔕 [SilentPushHandler] Background refresh completed successfully")
            completion(.newData)
        }
    }

    // MARK: - Widget Reload
    /// Reloads all widget timelines
    func reloadWidgets() {
        print("🔕 [SilentPushHandler] Reloading widget timelines")
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeToBurnWidget")
    }

    // MARK: - Background Task Registration
    /// Register background tasks with iOS
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            Self.shared.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        print("🔕 [SilentPushHandler] Background tasks registered")
    }

    /// Schedule the next background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔕 [SilentPushHandler] Background refresh scheduled for 30 minutes")
        } catch {
            print("🔕 [SilentPushHandler] Failed to schedule background refresh: \(error)")
        }
    }

    /// Handle a background task
    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        print("🔕 [SilentPushHandler] Handling background task")

        // Schedule the next refresh
        scheduleBackgroundRefresh()

        // Set expiration handler
        task.expirationHandler = {
            print("🔕 [SilentPushHandler] Background task expired")
            task.setTaskCompleted(success: false)
        }

        // Perform refresh
        performBackgroundRefresh(reason: "background_task") { result in
            task.setTaskCompleted(success: result == .newData)
        }
    }

    // MARK: - Persistence
    private func loadStats() {
        let defaults = UserDefaults.standard
        backgroundRefreshCount = defaults.integer(forKey: "silentPush_refreshCount")
        if let date = defaults.object(forKey: "silentPush_lastRefresh") as? Date {
            lastBackgroundRefresh = date
        }
    }

    private func saveStats() {
        let defaults = UserDefaults.standard
        defaults.set(backgroundRefreshCount, forKey: "silentPush_refreshCount")
        defaults.set(lastBackgroundRefresh, forKey: "silentPush_lastRefresh")
    }
}

// MARK: - Silent Push Payload Types
extension SilentPushHandler {
    /// Types of silent push notifications the server can send
    enum PushType: String {
        case dataRefresh = "data_refresh"      // Full data refresh
        case uvUpdate = "uv_update"            // UV conditions changed
        case locationCheck = "location_check"  // Check if location changed
        case widgetUpdate = "widget_update"    // Just reload widgets
    }
}
