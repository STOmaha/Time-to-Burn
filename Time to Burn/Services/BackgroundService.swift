import Foundation
import BackgroundTasks
import CoreLocation

class BackgroundService {
    static let shared = BackgroundService()

    // This identifier MUST be added to the Info.plist under "Permitted background task scheduler identifiers"
    let backgroundTaskIdentifier = "Time-to-Burn.Time-to-Burn.fetchUV"

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        // First, request "Always" authorization if we don't have it.
        locationManager.requestAlwaysAuthorization()

        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        
        // Find the next 8 AM
        guard let nextTriggerDate = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else {
            print("BackgroundService: Could not calculate next 8 AM trigger date.")
            return
        }
        
        request.earliestBeginDate = nextTriggerDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundService: Task scheduled successfully for \(nextTriggerDate)")
        } catch {
            print("BackgroundService: Could not schedule app refresh: \(error.localizedDescription)")
        }
    }
    
    func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        print("BackgroundService: Cancelled all tasks with identifier \(backgroundTaskIdentifier)")
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next day's task immediately
        scheduleAppRefresh()

        let workTask = Task {
            let notificationService = NotificationService()
            // Create view model on the main actor to avoid concurrency errors.
            let weatherViewModel = await MainActor.run {
                WeatherViewModel(notificationService: notificationService)
            }

            do {
                // Check for cancellation before starting network requests.
                try Task.checkCancellation()
                let location = try await requestLocation()
                
                try Task.checkCancellation()
                let (summary, hourlyData, threshold) = await weatherViewModel.fetchSummaryData(for: location)
                
                if let summary = summary, let hourlyData = hourlyData, let threshold = threshold {
                    notificationService.sendUVHighlightNotification(summary: summary, hourlyData: hourlyData, threshold: threshold)
                    task.setTaskCompleted(success: true)
                } else {
                    print("BackgroundService: Failed to fetch summary data.")
                    task.setTaskCompleted(success: false)
                }
            } catch is CancellationError {
                // The task was cancelled, probably by the expiration handler.
                // Clean up the view model's work.
                await weatherViewModel.cancelTasks()
                print("BackgroundService: Task was cancelled and cleaned up.")
                task.setTaskCompleted(success: false)
            } catch {
                print("BackgroundService: Background task failed with an error: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            // When the system is about to kill the task, we must cancel our async work.
            workTask.cancel()
        }
    }

    private func requestLocation() async throws -> CLLocation {
        let delegate = LocationDelegate()
        locationManager.delegate = delegate
        
        // Check authorization
        let status = locationManager.authorizationStatus
        if status != .authorizedAlways {
            print("BackgroundService: 'Always' location access not granted (\(status.rawValue)).")
            throw LocationError.unauthorized
        }
        
        locationManager.requestLocation()
        
        return try await withCheckedThrowingContinuation { continuation in
            delegate.onLocationUpdate = { location in
                continuation.resume(returning: location)
            }
            delegate.onError = { error in
                continuation.resume(throwing: error)
            }
        }
    }
}

// A helper delegate class to handle async location fetching
private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            onLocationUpdate?(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // This delegate is for one-off requests, so we don't need to handle this here.
    }
}

enum LocationError: Error {
    case unauthorized
} 