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
                            Text("Back")
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
                    } else if !searchViewModel.selectedLocationHourlyUVData.isEmpty {
                        // Use the same chart as the UV Index tab with selected location's data
                        VStack(spacing: 16) {
                            UVChartView(data: searchViewModel.selectedLocationHourlyUVData)
                                .padding(.horizontal)
                        }
                        
                        // 7-Day Forecast (vertically stacked like Forecast tab)
                        VStack(spacing: 24) {
                            ForEach(Array(searchViewModel.selectedLocationDailyUVData.enumerated()), id: \.offset) { index, dayData in
                                DayForecastCard(
                                    dayOffset: index,
                                    uvData: dayData,
                                    userThreshold: UserDefaults.standard.integer(forKey: "uvUserThreshold") == 0 ? 6 : UserDefaults.standard.integer(forKey: "uvUserThreshold"),
                                    dayInfo: getDayNameAndDate(forDayOffset: index)
                                )
                            }
                        }
                        .padding(.horizontal)
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
    
    private func getDayNameAndDate(forDayOffset offset: Int) -> (dayName: String, date: String) {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else {
            return ("", "")
        }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayName = calendar.isDateInToday(day) ? "Today" : dayFormatter.string(from: day)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let date = dateFormatter.string(from: day)
        
        return (dayName, date)
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