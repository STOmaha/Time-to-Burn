import Foundation
import ActivityKit

struct UVExposureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var totalExposureTime: TimeInterval
        var isTimerRunning: Bool
        var lastSunscreenApplication: Date?
        var uvChangeNotification: String?
    }
    
    var uvIndex: Int
    var maxExposureTime: Int
    var sunscreenReapplyTime: Date
} 
