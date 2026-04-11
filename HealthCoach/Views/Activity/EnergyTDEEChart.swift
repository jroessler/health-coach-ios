import SwiftUI
import Charts

struct EnergyTDEEChart: View {
    let data: EnergyTDEEData

    private let activeColor  = Color(red: 1.0, green: 0.584, blue: 0.0).opacity(0.75)  // #FF9500
    private let basalColor   = Color(hex: 0x3B82F6).opacity(0.6)
    private let tdeeColor    = Color.yellow
    private let targetColor  = Color(hex: 0x10B981)

    private var tdeeLabel: String { "\(data.effectiveDays)d avg TDEE" }

    private var yAxisTicks: [Double] {
        let maxY = data.points.map { p in
            let bar = p.activeKcal + p.basalKcal
            let line = p.tdee ?? 0
            return max(bar, line)
        }.max() ?? 3000
        let top = max(2000, ceil(maxY / 500) * 500)
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
            // Active energy bars (stacked on top of basal)
            ForEach(data.points) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("kcal", point.activeKcal),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Series", "Active Energy"))

                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("kcal", point.basalKcal),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Series", "Basal (BMR)"))

                if let tdee = point.tdee {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("kcal", tdee)
                    )
                    .foregroundStyle(by: .value("Series", tdeeLabel))
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Active target rule line
            RuleMark(y: .value("Target", ActivityConstants.activeKcalTarget))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(targetColor)
                .annotation(position: .top, alignment: .leading) {
                    Text("Active target: \(Int(ActivityConstants.activeKcalTarget)) kcal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(targetColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(hex: 0x0A1A24).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
        }
        .chartForegroundStyleScale([
            "Active Energy": activeColor,
            "Basal (BMR)":  basalColor,
            tdeeLabel:      tdeeColor,
        ])
        .chartYAxisLabel("kcal")
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: dateAxisStride)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: yAxisTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .chartLegend(position: .bottom, spacing: 12)
        .frame(height: 320)
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        Text("No energy data available")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var dateAxisStride: Int {
        let n = max(1, data.points.count)
        return max(2, min(14, n / 5))
    }
}
