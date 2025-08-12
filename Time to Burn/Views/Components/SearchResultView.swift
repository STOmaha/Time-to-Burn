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
                    if searchViewModel.isLoading {
                        LoadingCard()
                    } else {
                        // UV Summary (first, like the UV Index main tab)
                        SelectedLocationUVSummaryCard(locationName: location.displayName,
                                                      uvIndex: searchViewModel.getCurrentUVIndex(),
                                                      timeToBurn: searchViewModel.getTimeToBurnString())
                            .padding(.horizontal)
                        
                        // 24-hour chart using the same component as UV tab
                        if !searchViewModel.selectedLocationHourlyUVData.isEmpty {
                            VStack(spacing: 16) {
                                UVChartView(data: searchViewModel.selectedLocationHourlyUVData)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // 7-Day Forecast (vertically stacked like Forecast tab)
                        if !searchViewModel.selectedLocationDailyUVData.isEmpty {
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
            }
            .padding(.bottom, 20)
        }
        .background(Color.clear)
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

// MARK: - Selected Location UV Summary (matches main UV tab styling)
struct SelectedLocationUVSummaryCard: View {
    let locationName: String
    let uvIndex: Int
    let timeToBurn: String
    
    private var uvColor: Color { UVColorUtils.getUVColor(uvIndex) }
    private var level: String { UVColorUtils.getUVCategory(for: uvIndex) }
    private var advice: String { UVColorUtils.getUVAdvice(uvIndex: uvIndex) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UV Index Forecast")
                        .font(.headline)
                        .foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(locationName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text("\(uvIndex)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(uvColor.opacity(0.85))
                    Text(level)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(uvColor.opacity(0.85))
                }
                .offset(x: 20)
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .foregroundColor(.primary)
                        Text("Time to Burn:")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("~\(timeToBurn)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            Text(advice)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.top, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(uvColor.opacity(0.18))
                .shadow(color: uvColor.opacity(0.18), radius: 16, x: 0, y: 8)
        )
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