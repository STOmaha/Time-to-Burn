import SwiftUI

struct SearchResultView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    let onExit: () -> Void
    @State private var userThreshold: Int = UserDefaults.standard.integer(forKey: "uvUserThreshold") == 0 ? 6 : UserDefaults.standard.integer(forKey: "uvUserThreshold")
    
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
                                UVChartView(data: searchViewModel.selectedLocationHourlyUVData, timeZone: searchViewModel.selectedLocationTimeZone)
                                    .padding(.horizontal)
                                // Timezone context
                                if let tz = searchViewModel.selectedLocationTimeZone {
                                    TimeZoneContextView(selectedTimeZone: tz)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // 7-Day Forecast (vertically stacked like Forecast tab)
                        if !searchViewModel.selectedLocationDailyUVData.isEmpty {
                            VStack(spacing: 24) {
                                ForEach(Array(searchViewModel.selectedLocationDailyUVData.enumerated()), id: \.offset) { index, dayData in
                                    DayForecastCard(
                                        dayOffset: index,
                                        uvData: dayData,
                                        userThreshold: userThreshold,
                                        dayInfo: getDayNameAndDate(forDayOffset: index),
                                        timeZone: searchViewModel.selectedLocationTimeZone
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else if let celestialBody = searchViewModel.selectedCelestialBody {
                    if searchViewModel.isLoading {
                        LoadingCard()
                    } else {
                        // Celestial Body UV Summary
                        CelestialBodyUVSummaryCard(celestialBody: celestialBody)
                            .padding(.horizontal)
                        
                        // 24-hour chart for celestial bodies (flat line since no weather patterns)
                        if !searchViewModel.selectedLocationHourlyUVData.isEmpty {
                            UVChartView(data: searchViewModel.selectedLocationHourlyUVData, timeZone: nil)
                                .padding(.horizontal)
                        }
                        
                        // 7-Day Forecast for celestial bodies
                        if !searchViewModel.selectedLocationDailyUVData.isEmpty {
                            VStack(spacing: 24) {
                                ForEach(Array(searchViewModel.selectedLocationDailyUVData.enumerated()), id: \.offset) { index, dayData in
                                    DayForecastCard(
                                        dayOffset: index,
                                        uvData: dayData,
                                        userThreshold: userThreshold,
                                        dayInfo: getDayNameAndDate(forDayOffset: index),
                                        timeZone: nil
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .padding()
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
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let newThreshold = UserDefaults.standard.integer(forKey: "uvUserThreshold")
            if newThreshold != 0 && newThreshold != userThreshold {
                userThreshold = newThreshold
            }
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

// MARK: - Time Zone Context
struct TimeZoneContextView: View {
    let selectedTimeZone: TimeZone
    @State private var selectedTime: Date? = nil
    
    var body: some View {
        let userTZ = TimeZone.current
        let now = Date()
        let displayTime = selectedTime ?? now
        
        // Formatters for different time zones
        let userFormatter = DateFormatter()
        userFormatter.timeZone = userTZ
        userFormatter.dateFormat = "h:mm a"
        
        let selectedFormatter = DateFormatter()
        selectedFormatter.timeZone = selectedTimeZone
        selectedFormatter.dateFormat = "h:mm a"
        
        // Current times
        let userCurrentTime = userFormatter.string(from: now)
        let selectedCurrentTime = selectedFormatter.string(from: now)
        
        // Selected/scrubbed times (when user interacts with chart)
        let userSelectedTime = userFormatter.string(from: displayTime)
        let selectedLocationTime = selectedFormatter.string(from: displayTime)
        
        // Calculate hour difference
        let userGMTOffset = userTZ.secondsFromGMT(for: now)
        let selectedGMTOffset = selectedTimeZone.secondsFromGMT(for: now)
        let hourDiff = (selectedGMTOffset - userGMTOffset) / 3600
        
        let diffText: String
        if hourDiff == 0 {
            diffText = "Same time zone"
        } else if hourDiff > 0 {
            diffText = "+\(hourDiff)"
        } else {
            diffText = "\(hourDiff)"
        }
        
        return VStack(spacing: 8) {
            // Current time display
            HStack(spacing: 12) {
                Image(systemName: "clock.fill").foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Current:")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("\(selectedCurrentTime)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        if hourDiff != 0 {
                            Text("(\(diffText)h)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                    Text("Your time: \(userCurrentTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Show selected time when user scrubs the chart
            if let _ = selectedTime, selectedTime != now {
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Selected:")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("\(selectedLocationTime)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        Text("Your equivalent: \(userSelectedTime)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onReceive(NotificationCenter.default.publisher(for: .chartTimeSelected)) { notification in
            if let time = notification.object as? Date {
                selectedTime = time
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chartTimeDeselected)) { _ in
            selectedTime = nil
        }
    }
}

// MARK: - Celestial Body UV Summary Card
struct CelestialBodyUVSummaryCard: View {
    let celestialBody: CelestialBody
    
    private var uvColor: Color { UVColorUtils.getUVColor(celestialBody.uvIndex) }
    private var level: String { UVColorUtils.getUVCategory(for: celestialBody.uvIndex) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(celestialBody.emoji)
                            .font(.system(size: 32))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UV Index on \(celestialBody.name)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(celestialBody.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(celestialBody.uvIndex)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(uvColor.opacity(0.85))
                    Text(level)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(uvColor.opacity(0.85))
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    if celestialBody.uvIndex > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass")
                                .foregroundColor(.primary)
                            Text("Time to Burn:")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text("~\(celestialBody.timeToBurn)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(.green)
                            Text("Safe Zone!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        Text("No UV Risk")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                Spacer()
            }
            
            // Fun fact section
            VStack(alignment: .leading, spacing: 8) {
                Text("Space Fact")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(celestialBody.funFact)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(uvColor.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(uvColor.opacity(0.18))
                .shadow(color: uvColor.opacity(0.18), radius: 16, x: 0, y: 8)
        )
    }
}