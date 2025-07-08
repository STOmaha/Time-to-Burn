import Foundation
import SwiftUI

// Widget specific SharedDataManager that extends the shared functionality
class WidgetSharedDataManager: ObservableObject {
    static let shared = WidgetSharedDataManager()
    
    private let sharedManager = SharedDataManager.shared
    
    private init() {
        print("🌞 [Widget SharedDataManager] 🚀 Initializing...")
    }
    
    func saveSharedData(_ data: SharedUVData) {
        sharedManager.saveSharedData(data)
    }
    
    func loadSharedData() -> SharedUVData? {
        print("🌞 [Widget] Attempting to read shared data from app group UserDefaults...")
        if let data = sharedManager.loadSharedData() {
            print("🌞 [Widget] ✅ Successfully loaded shared data")
            return data
        } else {
            print("🌞 [Widget] ❌ No shared data found, using defaults")
            return nil
        }
    }
    
    func clearSharedData() {
        sharedManager.clearSharedData()
    }
} 