//
//  AppIntent.swift
//  TimeToBurnWidget
//
//  Created by Steven Taylor on 6/29/25.
//

import WidgetKit
import AppIntents
import ActivityKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

// MARK: - Live Activity App Intents
struct ApplySunscreenIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Sunscreen"
    static var description: IntentDescription = "Apply sunscreen and start 2-hour timer"
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the app's URL scheme
        return .result()
    }
}

struct OpenTimerTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Timer Tab"
    static var description: IntentDescription = "Open the Timer tab in the app"
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the app's URL scheme
        return .result()
    }
}

// MARK: - Notification Names Extension
// Note: These notifications are handled by the main app, not the widget extension
