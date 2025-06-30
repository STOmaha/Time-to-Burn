import SwiftUI
import Charts

struct UVExposureChartView: View {
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Chart title
            HStack {
                Text("UV Exposure Over Time")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // UV Index Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("UV Index")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Chart {
                    ForEach(weatherViewModel.hourlyUVData.prefix(24), id: \.id) { uvData in
                        LineMark(
                            x: .value("Time", uvData.date),
                            y: .value("UV Index", uvData.uvIndex)
                        )
                        .foregroundStyle(UVColorUtils.getUVColor(uvData.uvIndex))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(
                            x: .value("Time", uvData.date),
                            y: .value("UV Index", uvData.uvIndex)
                        )
                        .foregroundStyle(UVColorUtils.getUVColor(uvData.uvIndex).opacity(0.2))
                    }
                    
                    // Current time indicator
                    RuleMark(x: .value("Now", Date()))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let timeInterval = value.as(TimeInterval.self) {
                                Text(formatTimeInterval(timeInterval))
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            
            // Exposure Progress Chart
            if timerViewModel.totalExposureTime > 0 || timerViewModel.isTimerRunning {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exposure Progress")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Chart {
                        // Total exposure time
                        BarMark(
                            x: .value("Category", "Total Exposure"),
                            y: .value("Time", timerViewModel.totalExposureTime + timerViewModel.elapsedTime)
                        )
                        .foregroundStyle(timerViewModel.getExposureStatus().color)
                        
                        // Max safe time
                        RuleMark(y: .value("Max Safe", TimeInterval(timerViewModel.timeToBurn)))
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .trailing) {
                                Text("Max Safe")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let timeInterval = value.as(TimeInterval.self) {
                                    Text(formatTimeInterval(timeInterval))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
            
            // Exposure Statistics
            ExposureStatisticsView()
                .environmentObject(timerViewModel)
        }
        .padding()
    }
}

struct ExposureStatisticsView: View {
    @EnvironmentObject private var timerViewModel: TimerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Exposure Statistics")
                .font(.headline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Current Session",
                    value: timerViewModel.formatTime(timerViewModel.elapsedTime),
                    icon: "timer",
                    color: .orange
                )
                
                StatCard(
                    title: "Total Today",
                    value: timerViewModel.formatTime(timerViewModel.totalExposureTime),
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "Max Safe Time",
                    value: "\(timerViewModel.timeToBurn) min",
                    icon: "shield.checkered",
                    color: .green
                )
                
                StatCard(
                    title: "Progress",
                    value: "\(Int(timerViewModel.getExposureProgress() * 100))%",
                    icon: "chart.bar.fill",
                    color: timerViewModel.getExposureStatus().color
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helper Functions
private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
    let hours = Int(timeInterval) / 3600
    let minutes = Int(timeInterval) / 60 % 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}

#Preview {
    UVExposureChartView()
        .environmentObject(WeatherViewModel(locationManager: LocationManager()))
        .environmentObject(TimerViewModel())
} 