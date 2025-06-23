import Foundation

enum SkinType: String, CaseIterable, Identifiable {
    case type1 = "Type I"
    case type2 = "Type II"
    case type3 = "Type III"
    case type4 = "Type IV"
    case type5 = "Type V"
    case type6 = "Type VI"

    var id: String { self.rawValue }

    var description: String {
        switch self {
        case .type1:
            return "Type I: Very fair skin, always burns, never tans."
        case .type2:
            return "Type II: Fair skin, usually burns, tans with difficulty."
        case .type3:
            return "Type III: Medium skin, sometimes burns, tans gradually."
        case .type4:
            return "Type IV: Olive skin, rarely burns, tans with ease."
        case .type5:
            return "Type V: Brown skin, very rarely burns, tans very easily."
        case .type6:
            return "Type VI: Black skin, never burns, tans very easily."
        }
    }

    /// Base minutes to burn at a UV Index of 1.
    private var baseMinutes: Double {
        switch self {
        case .type1: return 67
        case .type2: return 100
        case .type3: return 200
        case .type4: return 300
        case .type5: return 400
        case .type6: return 500
        }
    }
    
    /// Calculates the estimated minutes to burn for a given UV index.
    func minutesToBurn(uvIndex: Int) -> Double {
        guard uvIndex > 0 else { return .infinity }
        return baseMinutes / Double(uvIndex)
    }
} 