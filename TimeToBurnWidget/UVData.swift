import Foundation

struct UVData: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let uvIndex: Int
    
    init(uvIndex: Int, date: Date) {
        self.date = date
        self.uvIndex = uvIndex
    }
} 