import SwiftUI

struct ForecastView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    private func getUVData(forDayOffset offset: Int) -> [UVData] {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else { return [] }
        return weatherViewModel.hourlyUVData.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Today's UV Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's UV Forecast")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    UVChartView(data: getUVData(forDayOffset: 0))
                        .environmentObject(weatherViewModel)
                        .frame(minHeight: 260)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Tomorrow's UV Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tomorrow's UV Forecast")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    UVChartView(data: getUVData(forDayOffset: 1))
                        .environmentObject(weatherViewModel)
                        .frame(minHeight: 260)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("UV Forecast")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Fetch forecast data when view appears
            Task {
                await weatherViewModel.refreshData()
            }
        }
    }
} 