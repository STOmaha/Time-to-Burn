import Foundation

struct UVData: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let uvIndex: Int
    
    enum CodingKeys: String, CodingKey {
        case id, date, uvIndex
    }
    
    init(uvIndex: Int, date: Date) {
        self.date = date
        self.uvIndex = uvIndex
    }
} 