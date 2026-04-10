import SwiftUI
import Charts

struct CalorieBalanceChart: View {
    let data: CalorieBalanceData

    private let appleRawColor = Color(hex: 0x60A5FA, opacity: 0.3)
    private let apple7dColor = Color(hex: 0x60A5FA)
    private let empiricalColor = Color(hex: 0xA78BFA)
    private let maintenanceColor = Color(hex: 0xFF9500)

    private var nameAppleRaw: String { "Balance vs Apple TDEE (raw)" }
    private var nameAppleAvg: String { "Balance vs Apple TDEE (\(data.effectiveDays)d avg)" }
    private var nameEmpirical: String { "Balance vs Empirical TDEE (14d)" }

    var body: some View {
        if data.points.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        Chart {
            RectangleMark(
                yStart: .value("lo", -500),
                yEnd: .value("hi", -300)
            )
            .foregroundStyle(Color(hex: 0x10B981, opacity: 0.08))

            RectangleMark(
                yStart: .value("lo", -2000),
                yEnd: .value("hi", -1000)
            )
            .foregroundStyle(Color.red.opacity(0.08))

            RuleMark(y: .value("Maintenance", 0))
                .foregroundStyle(maintenanceColor)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

            ForEach(Array(appleRawPoints.enumerated()), id: \.offset) { _, pt in
                LineMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Balance", pt.value),
                    series: .value("Series", nameAppleRaw)
                )
                .foregroundStyle(by: .value("Series", nameAppleRaw))
                .lineStyle(StrokeStyle(lineWidth: 1))
            }

            ForEach(Array(apple7dPoints.enumerated()), id: \.offset) { _, pt in
                LineMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Balance", pt.value),
                    series: .value("Series", nameAppleAvg)
                )
                .foregroundStyle(by: .value("Series", nameAppleAvg))
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)
            }

            ForEach(Array(empiricalPoints.enumerated()), id: \.offset) { _, pt in
                LineMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Balance", pt.value),
                    series: .value("Series", nameEmpirical)
                )
                .foregroundStyle(by: .value("Series", nameEmpirical))
                .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 4]))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale([
            nameAppleRaw: appleRawColor,
            nameAppleAvg: apple7dColor,
            nameEmpirical: empiricalColor,
        ])
        .chartYScale(domain: -2000 ... 2000)
        .chartYAxisLabel("kcal balance / day")
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
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .chartLegend(position: .bottom, spacing: 12)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotAnchor = proxy.plotFrame {
                    let rect = geometry[plotAnchor]
                    // Fixed domain -2000...2000 → y = 0 maps to vertical center of plot.
                    Text("Maintenance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(maintenanceColor)
                        .frame(width: 88, alignment: .trailing)
                        .position(x: rect.maxX - 44, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 300)
        .padding(.bottom, 16)
    }

    private var appleRawPoints: [(date: Date, value: Double)] {
        data.points.compactMap { p in
            guard let v = p.balanceApple else { return nil }
            return (p.date, v)
        }
    }

    private var apple7dPoints: [(date: Date, value: Double)] {
        data.points.compactMap { p in
            guard let v = p.balanceApple7d else { return nil }
            return (p.date, v)
        }
    }

    private var empiricalPoints: [(date: Date, value: Double)] {
        data.points.compactMap { p in
            guard let v = p.balanceEmpirical7d else { return nil }
            return (p.date, v)
        }
    }

    private var emptyState: some View {
        Text("No calorie balance data available")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var dateAxisStride: Int {
        NutritionChartAxisMetrics.dateStrideDays(pointCount: data.points.count)
    }
}
