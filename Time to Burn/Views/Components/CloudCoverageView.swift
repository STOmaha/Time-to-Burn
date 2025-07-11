import SwiftUI

struct CloudCoverageView: View {
    let cloudCover: Double
    let cloudCondition: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Cloud coverage icon and percentage
            HStack(spacing: 8) {
                Image(systemName: CloudCoverageUtils.getCloudCategory(from: cloudCover).icon)
                    .font(.title2)
                    .foregroundColor(CloudCoverageUtils.getCloudCategory(from: cloudCover).color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudCondition)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(CloudCoverageUtils.formatCloudCover(cloudCover))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(CloudCoverageUtils.getCloudCoverEmoji(cloudCover))
                    .font(.title)
            }
            
            // Cloud coverage progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cloud Coverage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(CloudCoverageUtils.formatCloudCover(cloudCover))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: cloudCover, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: getCloudCoverColor()))
                    .scaleEffect(y: 0.8)
            }
            
            // UV impact information
            VStack(alignment: .leading, spacing: 4) {
                Text("UV Impact")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(CloudCoverageUtils.getUVProtectionImpact(cloudCover: cloudCover))
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getUVImpactColor().opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func getCloudCoverColor() -> Color {
        let category = CloudCoverageUtils.getCloudCategory(from: cloudCover)
        return category.color
    }
    
    private func getUVImpactColor() -> Color {
        let reductionFactor = CloudCoverageUtils.getUVReductionFactor(cloudCover: cloudCover)
        let reductionPercent = (1.0 - reductionFactor) * 100
        
        if reductionPercent == 0 {
            return .green
        } else if reductionPercent < 20 {
            return .yellow
        } else if reductionPercent < 50 {
            return .orange
        } else {
            return .blue
        }
    }
}

struct CloudCoverageCardView: View {
    let cloudCover: Double
    let cloudCondition: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Cloud Coverage")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // Main content
            HStack(spacing: 16) {
                // Cloud icon and condition
                VStack(spacing: 8) {
                    Text(CloudCoverageUtils.getCloudCoverEmoji(cloudCover))
                        .font(.system(size: 40))
                    
                    Text(cloudCondition)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                
                Divider()
                
                // Coverage details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coverage: \(CloudCoverageUtils.formatCloudCover(cloudCover))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("UV Impact:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(CloudCoverageUtils.getUVProtectionImpact(cloudCover: cloudCover))
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(getUVImpactColor().opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cloud Coverage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(CloudCoverageUtils.formatCloudCover(cloudCover))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: cloudCover, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: getCloudCoverColor()))
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    private func getCloudCoverColor() -> Color {
        let category = CloudCoverageUtils.getCloudCategory(from: cloudCover)
        return category.color
    }
    
    private func getUVImpactColor() -> Color {
        let reductionFactor = CloudCoverageUtils.getUVReductionFactor(cloudCover: cloudCover)
        let reductionPercent = (1.0 - reductionFactor) * 100
        
        if reductionPercent == 0 {
            return .green
        } else if reductionPercent < 20 {
            return .yellow
        } else if reductionPercent < 50 {
            return .orange
        } else {
            return .blue
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudCoverageView(cloudCover: 25, cloudCondition: "Partly Cloudy")
        CloudCoverageCardView(cloudCover: 75, cloudCondition: "Mostly Cloudy")
    }
    .padding()
    .background(Color.gray.opacity(0.1))
} 