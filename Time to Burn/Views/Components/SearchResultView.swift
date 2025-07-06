import SwiftUI

struct SearchResultView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    let onExit: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with exit button
                HStack {
                    Button(action: onExit) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back to Map")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if let location = searchViewModel.selectedLocation {
                    // Location Info Card
                    LocationInfoCard(location: location)
                    
                    if searchViewModel.isLoading {
                        // Loading State
                        LoadingCard()
                    } else if let uvData = searchViewModel.selectedLocationUVData {
                        // Current UV Info Card
                        CurrentUVCard(
                            uvData: uvData,
                            timeToBurn: searchViewModel.getTimeToBurnString(),
                            uvColor: searchViewModel.getUVColor()
                        )
                        
                        // UV Graph Card
                        UVGraphCard(uvData: searchViewModel.selectedLocationHourlyUVData)
                        
                        // UV Forecast Card
                        UVForecastCard(uvData: searchViewModel.selectedLocationHourlyUVData)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .alert("Error", isPresented: $searchViewModel.showError) {
            Button("OK") { }
        } message: {
            Text(searchViewModel.errorMessage ?? "An unknown error occurred")
        }
    }
}

// MARK: - Location Info Card

struct LocationInfoCard: View {
    let location: LocationSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(location.fullDisplayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("Lat: \(location.coordinate.latitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Lon: \(location.coordinate.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Current UV Card

struct CurrentUVCard: View {
    let uvData: UVData
    let timeToBurn: String
    let uvColor: Color
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(uvColor)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current UV Index")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("Updated \(uvData.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(uvData.uvIndex)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(uvColor)
                    
                    Text("UV Index")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time to Burn")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(timeToBurn)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(uvColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Risk Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(getRiskLevelText(uvData.uvIndex))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(uvColor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func getRiskLevelText(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }
}

// MARK: - UV Graph Card

struct UVGraphCard: View {
    let uvData: [UVData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("24-Hour UV Forecast")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            if uvData.isEmpty {
                Text("No UV data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                UVChartView(data: uvData)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - UV Forecast Card

struct UVForecastCard: View {
    let uvData: [UVData]
    
    private var maxUV: Int {
        uvData.map { $0.uvIndex }.max() ?? 0
    }
    
    private var peakTime: String {
        guard let peakData = uvData.max(by: { $0.uvIndex < $1.uvIndex }) else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: peakData.date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Today's UV Summary")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak UV")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(maxUV)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(UVColorUtils.getUVColor(maxUV))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(peakTime)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Loading Card

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading UV data...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
} 