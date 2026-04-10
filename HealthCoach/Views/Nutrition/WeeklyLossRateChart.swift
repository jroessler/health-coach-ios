import SwiftUI
import Charts

struct WeeklyLossRateChart: View {
    let data: WeeklyLossRateData
    let preferences: UserPreferences

    private let weightColor = Color(hex: 0x1E3A8A)
    private let fatColor = Color(hex: 0x991B1B)
    private let weightTargetColor = Color(hex: 0x425487)
    private let fatTargetColor = Color(hex: 0x994444)

    private var weightSeriesName: String { "Δ Weight (kg/wk)" }
    private var fatSeriesName: String { "Δ Body Fat (%/wk)" }
    private var weightTargetLegend: String {
        String(format: "Target weight (%.1f kg/wk)", preferences.weeklyWeightLossTargetKg)
    }
    private var fatTargetLegend: String {
        String(format: "Target body fat (%.2f %%/wk)", preferences.weeklyBodyfatLossTargetPct)
    }

    private var yDomain: ClosedRange<Double> {
        var vals: [Double] = []
        for p in data.points {
            if let w = p.deltaWeightKg { vals.append(w) }
            if let b = p.deltaBodyFatPct { vals.append(b) }
        }
        vals.append(preferences.weeklyWeightLossTargetKg)
        vals.append(preferences.weeklyBodyfatLossTargetPct)
        guard let mn = vals.min(), let mx = vals.max(), !vals.isEmpty else {
            return -1...1
        }
        if mn == mx {
            let pad = 0.2
            return (mn - pad)...(mx + pad)
        }
        let span = mx - mn
        let pad = max(span * 0.18, 0.12)
        return (mn - pad)...(mx + pad)
    }

    var body: some View {
        if data.points.count < 2 {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                RuleMark(y: .value("Weight Target", preferences.weeklyWeightLossTargetKg))
                    .foregroundStyle(weightTargetColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                RuleMark(y: .value("BF Target", preferences.weeklyBodyfatLossTargetPct))
                    .foregroundStyle(fatTargetColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))

                ForEach(data.points) { point in
                    if let delta = point.deltaWeightKg {
                        LineMark(
                            x: .value("Week", point.weekLabel),
                            y: .value("Δ Weight", delta),
                            series: .value("Series", "Weight")
                        )
                        .foregroundStyle(weightColor)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(50)

                        PointMark(
                            x: .value("Week", point.weekLabel),
                            y: .value("Δ Weight", delta)
                        )
                        .foregroundStyle(weightColor)
                        .symbolSize(50)
                    }

                    if let delta = point.deltaBodyFatPct {
                        LineMark(
                            x: .value("Week", point.weekLabel),
                            y: .value("Δ Body Fat", delta),
                            series: .value("Series", "Body Fat")
                        )
                        .foregroundStyle(fatColor)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(50)

                        PointMark(
                            x: .value("Week", point.weekLabel),
                            y: .value("Δ Body Fat", delta)
                        )
                        .foregroundStyle(fatColor)
                        .symbolSize(50)
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxisLabel("Δ per Week")
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        Text(value.as(String.self) ?? String(describing: value))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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
            .chartLegend(.hidden)
            .frame(height: 280)

            legendWithTargets
        }
        .padding(.bottom, 16)
    }

    private var legendWithTargets: some View {
        VStack(alignment: .leading, spacing: 10) {
            legendLineRow(color: weightColor, dashed: false, title: weightSeriesName)
            legendLineRow(color: fatColor, dashed: false, title: fatSeriesName)
            legendLineRow(color: weightTargetColor, dashed: true, title: weightTargetLegend)
            legendLineRow(color: fatTargetColor, dashed: true, title: fatTargetLegend)
        }
        .font(.caption2)
        .foregroundStyle(Color.white.opacity(0.88))
    }

    private func legendLineRow(color: Color, dashed: Bool, title: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Group {
                if dashed {
                    Color.clear
                        .frame(width: 22, height: 10)
                        .overlay {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 5))
                                path.addLine(to: CGPoint(x: 22, y: 5))
                            }
                            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 22, height: 3)
                }
            }
            .frame(width: 24, alignment: .leading)

            Text(title)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        Text("Need at least 2 weeks for weekly loss rates")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
