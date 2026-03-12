import Foundation
import CoreLocation
import SwiftUI

/// Background Sync Service - Handles smart UV data syncing to Supabase
@MainActor
class BackgroundSyncService: ObservableObject {
    static let shared = BackgroundSyncService()
    
    // MARK: - Properties
    @Published var lastSyncTime: Date?
    @Published var nextSyncTime: Date?
    @Published var isSyncing = false
    
    private var lastSyncedLocation: CLLocation?
    private var lastSyncedUV: Int?
    private var recommendedSyncInterval: TimeInterval = 3600 // Default: 1 hour
    
    // Sync interval constants (in seconds)
    private let minSyncInterval: TimeInterval = 900 // 15 minutes
    private let maxSyncInterval: TimeInterval = 7200 // 2 hours
    
    // Distance threshold for significant location change (5km)
    private let significantDistanceThreshold: Double = 5000 // 5km in meters

    // Track if first sync message has been logged to prevent spam
    private var firstSyncLogged = false

    // Jitter to prevent thundering herd (many users syncing simultaneously)
    private let jitterFactorKey = "sync_jitter_factor"

    /// Stable per-user jitter factor (0-10% of interval) persisted across app restarts
    /// This spreads Supabase sync requests across time to avoid coordinated spikes
    private var userSyncJitterFactor: Double {
        if let stored = UserDefaults.standard.object(forKey: jitterFactorKey) as? Double, stored > 0 {
            return stored
        }
        // Generate stable random factor (0-10%)
        let factor = Double.random(in: 0...0.10)
        UserDefaults.standard.set(factor, forKey: jitterFactorKey)
        return factor
    }

    /// Add jitter to an interval to spread sync requests across users
    private func addJitter(to interval: TimeInterval) -> TimeInterval {
        let jitter = interval * userSyncJitterFactor
        // Also add small random variance (±30 seconds) per sync
        let variance = Double.random(in: -30...30)
        return interval + jitter + variance
    }

    private init() {
        print("🔄 [BackgroundSyncService] Initialized")
    }
    
    // MARK: - Smart Interval Calculation
    
    /// Calculate whether sync should happen now based on various factors
    func shouldSyncNow(currentUV: Int, threshold: Int, currentLocation: CLLocation) -> Bool {
        // Always sync if user moved significantly
        if let lastLocation = lastSyncedLocation {
            let distance = currentLocation.distance(from: lastLocation)
            if distance > significantDistanceThreshold {
                print("📍 [BackgroundSyncService] Significant location change detected: \(Int(distance/1000))km")
                return true
            }
        }
        
        // Always sync if this is first sync (only log once)
        guard let lastSync = lastSyncTime else {
            if !firstSyncLogged {
                print("🔄 [BackgroundSyncService] First sync - proceeding")
                firstSyncLogged = true
            }
            return true
        }
        
        // Check if enough time has passed since last sync
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        let interval = calculateSyncInterval(currentUV: currentUV, threshold: threshold)
        
        if timeSinceLastSync >= interval {
            print("⏰ [BackgroundSyncService] Sync interval reached (\(Int(timeSinceLastSync/60))min)")
            return true
        }
        
        // Check if UV changed significantly (±2 UV index)
        if let lastUV = lastSyncedUV, abs(currentUV - lastUV) >= 2 {
            print("☀️ [BackgroundSyncService] Significant UV change detected: \(lastUV) → \(currentUV)")
            return true
        }
        
        print("⏭️ [BackgroundSyncService] Sync not needed yet. Next sync in \(Int((interval - timeSinceLastSync)/60))min")
        return false
    }
    
    /// Calculate smart sync interval based on UV proximity to threshold
    /// Includes jitter to prevent thundering herd at scale
    private func calculateSyncInterval(currentUV: Int, threshold: Int) -> TimeInterval {
        let difference = abs(currentUV - threshold)

        let baseInterval: TimeInterval

        switch difference {
        case 0:
            // At threshold: check every 15 minutes
            baseInterval = 900
        case 1:
            // Very close (±1): check every 30 minutes
            baseInterval = 1800
        case 2...3:
            // Close (±2-3): check every hour
            baseInterval = 3600
        default:
            // Far (>3): check every 2 hours
            baseInterval = 7200
        }

        // Add user-specific jitter to spread requests across users
        let jitteredInterval = addJitter(to: baseInterval)
        recommendedSyncInterval = jitteredInterval

        return jitteredInterval
    }
    
    // MARK: - Sync Methods
    
    /// Sync UV data to Supabase
    func syncUVData(
        location: CLLocation,
        locationName: String,
        currentUV: Int,
        adjustedUV: Int,
        environmentalFactors: EnvironmentalFactors,
        threshold: Int
    ) async {
        // Check if sync is needed
        guard shouldSyncNow(currentUV: currentUV, threshold: threshold, currentLocation: location) else {
            return
        }
        
        // Prevent concurrent syncs
        guard !isSyncing else {
            print("⏳ [BackgroundSyncService] Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        print("🔄 [BackgroundSyncService] Starting sync...")
        print("   📍 Location: \(locationName)")
        print("   ☀️ UV: \(currentUV) (adjusted: \(adjustedUV))")
        print("   🎯 Threshold: \(threshold)")
        
        do {
            // Sync to Supabase
            try await SupabaseService.shared.updateUserLocation(
                location: location,
                locationName: locationName,
                currentUV: currentUV,
                adjustedUV: adjustedUV,
                environmentalFactors: environmentalFactors
            )
            
            // Update local state
            lastSyncTime = Date()
            lastSyncedLocation = location
            lastSyncedUV = currentUV
            
            // Calculate next sync time
            let interval = calculateSyncInterval(currentUV: currentUV, threshold: threshold)
            nextSyncTime = Date().addingTimeInterval(interval)
            
            print("✅ [BackgroundSyncService] Sync successful")
            print("   ⏰ Next sync in: \(Int(interval/60)) minutes")
            print("   📅 Next sync at: \(formatTime(nextSyncTime!))")
            
        } catch {
            print("❌ [BackgroundSyncService] Sync failed: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    /// Force immediate sync (used for significant location changes)
    func forceSync(
        location: CLLocation,
        locationName: String,
        currentUV: Int,
        adjustedUV: Int,
        environmentalFactors: EnvironmentalFactors,
        threshold: Int
    ) async {
        print("⚡️ [BackgroundSyncService] Force sync requested")
        
        // Temporarily clear last sync to force sync
        let tempLastSync = lastSyncTime
        lastSyncTime = nil
        
        await syncUVData(
            location: location,
            locationName: locationName,
            currentUV: currentUV,
            adjustedUV: adjustedUV,
            environmentalFactors: environmentalFactors,
            threshold: threshold
        )
        
        // Restore last sync time if sync failed
        if lastSyncTime == nil {
            lastSyncTime = tempLastSync
        }
    }
    
    // MARK: - Location Change Detection
    
    /// Check if user moved significantly since last sync
    func hasMovedSignificantly(from currentLocation: CLLocation) -> Bool {
        guard let lastLocation = lastSyncedLocation else {
            return true // First location is always significant
        }
        
        let distance = currentLocation.distance(from: lastLocation)
        return distance > significantDistanceThreshold
    }
    
    /// Get distance moved since last sync
    func distanceMovedSinceLastSync(from currentLocation: CLLocation) -> Double? {
        guard let lastLocation = lastSyncedLocation else {
            return nil
        }
        
        return currentLocation.distance(from: lastLocation)
    }
    
    // MARK: - Status & Debug
    
    /// Get human-readable sync status
    func getSyncStatus() -> String {
        guard let lastSync = lastSyncTime else {
            return "Not yet synced"
        }
        
        let timeSinceSync = Date().timeIntervalSince(lastSync)
        let minutesAgo = Int(timeSinceSync / 60)
        
        if minutesAgo < 1 {
            return "Just now"
        } else if minutesAgo == 1 {
            return "1 minute ago"
        } else if minutesAgo < 60 {
            return "\(minutesAgo) minutes ago"
        } else {
            let hoursAgo = minutesAgo / 60
            return "\(hoursAgo) hour\(hoursAgo == 1 ? "" : "s") ago"
        }
    }
    
    /// Get time until next sync
    func timeUntilNextSync() -> String {
        guard let nextSync = nextSyncTime else {
            return "Unknown"
        }
        
        let timeUntil = nextSync.timeIntervalSinceNow
        if timeUntil <= 0 {
            return "Ready"
        }
        
        let minutes = Int(timeUntil / 60)
        if minutes < 1 {
            return "< 1 minute"
        } else if minutes == 1 {
            return "1 minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    /// Debug information
    func printDebugInfo() {
        print("🔄 [BackgroundSyncService] Debug Info:")
        print("   Last Sync: \(lastSyncTime.map { formatTime($0) } ?? "Never")")
        print("   Next Sync: \(nextSyncTime.map { formatTime($0) } ?? "Not scheduled")")
        print("   Last Location: \(lastSyncedLocation?.coordinate ?? CLLocationCoordinate2D())")
        print("   Last UV: \(lastSyncedUV ?? -1)")
        print("   Recommended Interval: \(Int(recommendedSyncInterval/60)) minutes")
        print("   Is Syncing: \(isSyncing)")
        print("   ──────────────────────────────────────")
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Reset sync state (useful for testing or logout)
    func reset() {
        lastSyncTime = nil
        nextSyncTime = nil
        lastSyncedLocation = nil
        lastSyncedUV = nil
        recommendedSyncInterval = 3600
        isSyncing = false
        firstSyncLogged = false  // Allow first sync message again after reset
        print("🔄 [BackgroundSyncService] State reset")
    }
}


