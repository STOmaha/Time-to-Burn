import SwiftUI

// MARK: - UV Risk Display Components
// Modular components that can be easily commented out during design experimentation

// MARK: - Risk Level Component
struct RiskLevelView: View {
    let riskLevel: UVRiskLevel
    
    var body: some View {
        HStack(spacing: 8) {
            Text(riskLevel.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Risk:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(riskLevel.level.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(riskLevel.color)
                }
                
                Text(riskLevel.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Sun Protection Times Component
struct SunProtectionTimesView: View {
    let protectionGuidance: SunProtectionGuidance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sunscreen Times
            if let sunscreenRange = protectionGuidance.sunscreenRequired {
                ProtectionTimeRow(
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    title: "Wear Sunscreen",
                    timeRange: sunscreenRange,
                    isActive: sunscreenRange.isActive
                )
            }
            
            // Shade Times
            if let shadeRange = protectionGuidance.seekShadeRequired {
                ProtectionTimeRow(
                    icon: "tree.fill",
                    iconColor: .green,
                    title: "Seek Shade",
                    timeRange: shadeRange,
                    isActive: shadeRange.isActive
                )
            }
            
            // Avoid Sun Times
            if let avoidRange = protectionGuidance.avoidSunRequired {
                ProtectionTimeRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    title: "Avoid Sun",
                    timeRange: avoidRange,
                    isActive: avoidRange.isActive
                )
            }
        }
    }
}

// MARK: - Protection Time Row
struct ProtectionTimeRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let timeRange: SunProtectionGuidance.TimeRange
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? iconColor : .primary)
                
                Text(timeRange.formattedRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Text("NOW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(iconColor)
                    )
            }
        }
        .padding(.vertical, 4)
        .background(
            isActive ? iconColor.opacity(0.1) : Color.clear
        )
        .cornerRadius(8)
    }
}

// MARK: - Misery Index Component
struct MiseryIndexView: View {
    let miseryIndex: MiseryIndex
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text(miseryIndex.level.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Misery Index:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(miseryIndex.level.rawValue)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(miseryIndex.level.color)
                    }
                    
                    Text(String(format: "%.0f/100", miseryIndex.value))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Misery level indicator
                Circle()
                    .fill(miseryIndex.level.color)
                    .frame(width: 12, height: 12)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(miseryIndex.level.color)
                        .frame(width: geometry.size.width * (miseryIndex.value / 100), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            
            // Warning if exists
            if let warning = miseryIndex.warning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(warning)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Misery Factors Detail Component (Optional - can be commented out)
struct MiseryFactorsDetailView: View {
    let factors: [MiseryIndex.MiseryFactor]
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDetails.toggle()
                }
            }) {
                HStack {
                    Text("Misery Factors")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(factors.indices, id: \.self) { index in
                        let factor = factors[index]
                        HStack(spacing: 8) {
                            Circle()
                                .fill(factor.impact.color)
                                .frame(width: 8, height: 8)
                            
                            Text(factor.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(factor.impact.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(factor.impact.color)
                        }
                    }
                }
                .padding(.leading, 4)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Overall Recommendation Component
struct OverallRecommendationView: View {
    let assessment: UVRiskDisplayModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Critical warning (if exists)
            if let warning = assessment.criticalWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text(warning)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Primary guidance
            Text(assessment.primaryGuidance)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(nil)
        }
    }
}

// MARK: - Compact Risk Summary (Alternative layout)
struct CompactRiskSummaryView: View {
    let assessment: UVRiskDisplayModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Risk level
            VStack(alignment: .center, spacing: 2) {
                Text(assessment.riskLevel.emoji)
                    .font(.title3)
                
                Text(assessment.riskLevel.level.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(assessment.riskLevel.color)
            }
            
            Divider()
                .frame(height: 30)
            
            // Misery index
            VStack(alignment: .center, spacing: 2) {
                Text(assessment.miseryIndex.level.emoji)
                    .font(.title3)
                
                Text("Misery: \(Int(assessment.miseryIndex.value))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(assessment.miseryIndex.level.color)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview Helpers
#if DEBUG
extension UVRiskDisplayModel {
    static var preview: UVRiskDisplayModel {
        UVRiskDisplayModel(
            timestamp: Date(),
            uvIndex: 8,
            riskLevel: UVRiskLevel.forUVIndex(8),
            protectionGuidance: SunProtectionGuidance(
                sunscreenRequired: SunProtectionGuidance.TimeRange(
                    start: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!,
                    end: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
                ),
                seekShadeRequired: SunProtectionGuidance.TimeRange(
                    start: Date(),
                    end: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
                ),
                avoidSunRequired: nil,
                recommendations: ["Apply SPF 30+", "Wear protective clothing"]
            ),
            miseryIndex: MiseryIndex(
                value: 65,
                level: .oppressive,
                factors: [
                    MiseryIndex.MiseryFactor(type: .uv, value: 8, impact: .high, description: "UV Index: 8"),
                    MiseryIndex.MiseryFactor(type: .temperature, value: 32, impact: .high, description: "Temperature: 32°C")
                ],
                warning: "Heat-related illness risk is high"
            ),
            overallRecommendation: "Limit outdoor time, seek shade frequently",
            criticalWarning: nil
        )
    }
}

struct UVRiskComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                RiskLevelView(riskLevel: UVRiskLevel.forUVIndex(8))
                
                MiseryIndexView(miseryIndex: UVRiskDisplayModel.preview.miseryIndex)
                
                SunProtectionTimesView(protectionGuidance: UVRiskDisplayModel.preview.protectionGuidance)
                
                OverallRecommendationView(assessment: UVRiskDisplayModel.preview)
                
                CompactRiskSummaryView(assessment: UVRiskDisplayModel.preview)
            }
            .padding()
        }
    }
}
#endif
