import SwiftUI
import Charts

struct DailyCaloriesMacrosChart: View {
    let data: DailyCaloriesMacrosData

    private let proteinColor = Color(hex: 0x1F77B4)
    private let carbsColor = Color(hex: 0x2CA02C)
    private let fatColor = Color(hex: 0xFF7F0E)
    private let rollingColor = Color.yellow

    private var rollingLegendKey: String { "\(data.effectiveDays)-day avg kcal" }

    private var yAxisKcalTicks: [Double] {
        let maxRolling = data.points.compactMap(\.rollingAvgKcal).max() ?? 0
        let maxBar = data.points.map(\.calories).max() ?? 0
        let maxY = max(maxRolling, maxBar, 500)
        let top = max(500, ceil(maxY / 500) * 500)
        return Array(stride(from: 0, through: top, by: 500))
    }

    var body: some View {
        if data.points.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        Chart {
            ForEach(data.points) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("kcal", point.proteinKcal)
                )
                .foregroundStyle(by: .value("Macro", "Protein"))

                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("kcal", point.carbsKcal)
                )
                .foregroundStyle(by: .value("Macro", "Carbs"))

                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("kcal", point.fatKcal)
                )
                .foregroundStyle(by: .value("Macro", "Fat"))

                if let rolling = point.rollingAvgKcal {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("kcal", rolling)
                    )
                    .foregroundStyle(by: .value("Macro", rollingLegendKey))
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartForegroundStyleScale([
            "Protein": proteinColor,
            "Carbs": carbsColor,
            "Fat": fatColor,
            rollingLegendKey: rollingColor,
        ])
        .chartYAxisLabel("Calories (kcal)")
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: dateAxisStride)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        NutritionChartDateAxisLabel.make(date)
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: yAxisKcalTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .chartLegend(position: .bottom, spacing: 12)
        .frame(height: 300)
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        Text("No calorie data available")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var dateAxisStride: Int {
        NutritionChartAxisMetrics.dateStrideDays(pointCount: data.points.count)
    }
}
