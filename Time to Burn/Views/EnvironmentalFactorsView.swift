import SwiftUI

struct EnvironmentalFactorsView: View {
    @StateObject private var environmentalDataService = EnvironmentalDataService.shared
    @StateObject private var smartNotificationViewModel = SmartNotificationViewModel.shared
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var showingRiskAssessment = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Current Environmental Factors
                    if let factors = environmentalDataService.currentEnvironmentalFactors {
                        environmentalFactorsSection(factors: factors)
                        
                        // Risk Assessment Section
                        if let assessment = smartNotificationViewModel.currentRiskAssessment {
                            riskAssessmentSection(assessment: assessment)
                        }
                    } else {
                        // Loading or No Data
                        noDataSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Environmental Factors")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
            .onAppear {
                Task {
                    await refreshData()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Environmental UV Analysis")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Understanding how your environment affects UV exposure")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Environmental Factors Section
    
    private func environmentalFactorsSection(factors: EnvironmentalFactors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Environmental Factors")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Altitude
                EnvironmentalFactorCard(
                    title: "Altitude",
                    value: AltitudeUtils.formatAltitude(factors.altitude),
                    emoji: AltitudeUtils.getAltitudeEmoji(altitude: factors.altitude),
                    description: AltitudeUtils.getAltitudeDescription(altitude: factors.altitude),
                    color: .blue
                )
                
                // Snow Conditions
                EnvironmentalFactorCard(
                    title: "Snow",
                    value: "\(Int(factors.snowConditions.snowCoverage))%",
                    emoji: SnowReflectionUtils.getSnowEmoji(snowConditions: factors.snowConditions),
                    description: SnowReflectionUtils.getSnowDescription(snowConditions: factors.snowConditions),
                    color: .cyan
                )
                
                // Water Proximity
                EnvironmentalFactorCard(
                    title: "Water",
                    value: WaterReflectionUtils.formatDistance(factors.waterProximity.distanceToWater),
                    emoji: WaterReflectionUtils.getWaterEmoji(waterProximity: factors.waterProximity),
                    description: WaterReflectionUtils.getWaterDescription(waterProximity: factors.waterProximity),
                    color: .blue
                )
                
                // Terrain Type
                EnvironmentalFactorCard(
                    title: "Terrain",
                    value: factors.terrainType.rawValue,
                    emoji: TerrainAnalysisUtils.getTerrainEmoji(terrainType: factors.terrainType),
                    description: factors.terrainType.description,
                    color: .brown
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Risk Assessment Section
    
    private func riskAssessmentSection(assessment: UVRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UV Risk Assessment")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Risk Level Card
            VStack(spacing: 12) {
                HStack {
                    Text(assessment.riskLevel.emoji)
                        .font(.title)
                    
                    VStack(alignment: .leading) {
                        Text(assessment.riskLevel.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(assessment.riskLevel.color)
                        
                        Text(assessment.riskLevel.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Risk Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f", assessment.riskScore))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(assessment.riskLevel.color)
                    }
                }
                
                // UV Index Comparison
                HStack {
                    VStack(alignment: .leading) {
                        Text("Base UV")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(assessment.baseUVIndex)")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Adjusted UV")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(assessment.adjustedUVIndex)")
                            .font(.headline)
                            .foregroundColor(assessment.riskLevel.color)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(assessment.riskLevel.color.opacity(0.1))
            .cornerRadius(12)
            
            // Risk Factors
            if !assessment.riskFactors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Risk Factors")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(assessment.riskFactors.prefix(3)) { factor in
                        RiskFactorRow(factor: factor)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - No Data Section
    
    private var noDataSection: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading environmental data...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: "leaf")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Environmental Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Environmental factors will be analyzed when location data is available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await refreshData()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Data")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if smartNotificationViewModel.currentRiskAssessment != nil {
                Button(action: {
                    showingRiskAssessment = true
                }) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("View Detailed Assessment")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() async {
        isLoading = true
        
        guard let location = locationManager.location else {
            isLoading = false
            return
        }
        
        // Fetch environmental data
        await environmentalDataService.fetchEnvironmentalData(for: location)
        
        // Perform risk assessment if we have UV data
        if let currentUV = getCurrentUVIndex() {
            await smartNotificationViewModel.performRiskAssessment(baseUVIndex: currentUV)
        }
        
        isLoading = false
    }
    
    private func getCurrentUVIndex() -> Int? {
        // This would integrate with your existing weather service
        // For now, return a placeholder
        return 5
    }
}

// MARK: - Supporting Views

struct EnvironmentalFactorCard: View {
    let title: String
    let value: String
    let emoji: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.title2)
                
                Spacer()
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RiskFactorRow: View {
    let factor: RiskFactor
    
    var body: some View {
        HStack {
            Image(systemName: factor.type.icon)
                .foregroundColor(factor.severity.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(factor.description)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(factor.mitigation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(factor.severity.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(factor.severity.color.opacity(0.2))
                .foregroundColor(factor.severity.color)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct EnvironmentalFactorsView_Previews: PreviewProvider {
    static var previews: some View {
        EnvironmentalFactorsView()
    }
} 