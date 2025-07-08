import Foundation
import SwiftUI

// Main app specific SharedDataManager that extends the shared functionality
class MainAppSharedDataManager: ObservableObject {
    static let shared = MainAppSharedDataManager()
    
    private let sharedManager = SharedDataManager.shared
    
    private init() {
        print("🌞 [MainApp SharedDataManager] 🚀 Initializing...")
    }
    
    func saveSharedData(_ data: SharedUVData) {
        sharedManager.saveSharedData(data)
    }
    
    func loadSharedData() -> SharedUVData? {
        return sharedManager.loadSharedData()
    }
    
    func clearSharedData() {
        sharedManager.clearSharedData()
    }
} 