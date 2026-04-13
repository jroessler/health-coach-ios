import SwiftUI
import Charts

struct HRVTrendChart: View {
    let data: HRVChartData

    private let baselineColor = Color(hex: 0xFBBF24)
    private let avgColor = Color(hex: 0x60A5FA)
    private let bandColor = Color(hex: 0x10B981).opacity(0.12)

    private var dateDomain: ClosedRange<Date> {
        let dates = data.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else { return Date()...Date() }
        return lo...hi
    }

    private var yDomain: ClosedRange<Double> {
        var vals: [Double] = data.points.map(\.hrv)
        vals += data.points.compactMap(\.upper)
        vals += data.points.compactMap(\.lower2)
        vals += data.points.compactMap(\.hrv7d)
        vals += data.points.compactMap(\.baseline)
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 0...100 }
        let span = hi - lo
        let pad = max(span * 0.08, 3)
        return (lo - pad)...(hi + pad)
    }

    private var axisStride: Int {
        NutritionChartAxisMetrics.dateStrideDays(from: dateDomain.lowerBound, through: dateDomain.upperBound)
    }

    var body: some View {
        if data.points.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            axisLabels
            Chart {
                // ±1 SD band (filled area)
                ForEach(data.points) { point in
                    if let upper = point.upper, let lower = point.lower {
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            yStart: .value("Lower", lower),
                            yEnd: .value("Upper", upper)
                        )
                        .foregroundStyle(bandColor)
                        .interpolationMethod(.linear)
                    }
                }

                // Baseline (amber dashed)
                ForEach(data.points) { point in
                    if let baseline = point.baseline {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Baseline", baseline),
                            series: .value("S", "Baseline")
                        )
                        .foregroundStyle(baselineColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .interpolationMethod(.linear)
                    }
                }

                // Daily dots colored by SD zone
                ForEach(data.points) { point in
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.hrv)
                    )
                    .foregroundStyle(dotColor(point.sdZone))
                    .symbolSize(30)
                }

                // 7-day rolling avg (blue line)
                ForEach(data.points) { point in
                    if let avg = point.hrv7d {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("7d Avg", avg),
                            series: .value("S", "7d Avg")
                        )
                        .foregroundStyle(avgColor)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.linear)
                    }
                }
            }
            .chartXScale(domain: dateDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: axisStride)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            NutritionChartDateAxisLabel.make(date)
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.6))
                                .frame(height: NutritionChartAxisMetrics.xAxisLabelHeight)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let v = value.as(Double.self) {
                        AxisValueLabel {
                            Text(String(format: "%.0f", v))
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 280)

            legend
        }
    }

    private var axisLabels: some View {
        HStack {
            Text("HRV (ms)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.55))
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: baselineColor, dash: true, title: "\(data.baselineDays)d Baseline")
            legendRow(color: avgColor, dash: false, title: "\(data.averagePeriod)d Avg")
            legendBandRow(color: Color(hex: 0x10B981), title: "Baseline ± 1 SD")
        }
        .font(.caption2)
        .foregroundStyle(Color.white.opacity(0.85))
        .padding(.bottom, 4)
    }

    private func legendRow(color: Color, dash: Bool, title: String) -> some View {
        HStack(spacing: 8) {
            if dash {
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 8, height: 2)
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 5, height: 2)
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 5, height: 2)
                }
                .frame(width: 20)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 20, height: 3)
            }
            Text(title)
        }
    }

    private func legendBandRow(color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.3)).frame(width: 20, height: 10)
            Text(title)
        }
    }

    private func dotColor(_ zone: SDZone) -> Color {
        switch zone {
        case .normal: return Color(hex: 0x10B981)
        case .stress: return Color(hex: 0xFBBF24)
        case .recovery: return Color(hex: 0xF97316)
        }
    }

    private var emptyState: some View {
        Text("No HRV data in selected range")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
