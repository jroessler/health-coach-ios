import SwiftUI
import Charts

struct RHRTrendChart: View {
    let data: RHRChartData

    private let baselineColor = Color(hex: 0xFBBF24)
    private let avgColor = Color(hex: 0xEF4444)
    private let bandColor = Color(hex: 0x10B981).opacity(0.12)

    private var dateDomain: ClosedRange<Date> {
        let dates = data.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else { return Date()...Date() }
        return lo...hi
    }

    private var yDomain: ClosedRange<Double> {
        var vals: [Double] = data.points.map(\.rhr)
        vals += data.points.compactMap(\.upper2)
        vals += data.points.compactMap(\.lower)
        vals += data.points.compactMap(\.rhr7d)
        vals += data.points.compactMap(\.baseline)
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 40...90 }
        let span = hi - lo
        let pad = max(span * 0.08, 2)
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
            HStack {
                Text("RHR (bpm)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 2)

            Chart {
                // ±1 SD band
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

                // Daily dots colored by SD zone (inverted: higher = worse)
                ForEach(data.points) { point in
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("RHR", point.rhr)
                    )
                    .foregroundStyle(dotColor(point.sdZone))
                    .symbolSize(30)
                }

                // 7-day rolling avg
                ForEach(data.points) { point in
                    if let avg = point.rhr7d {
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

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(baselineColor).frame(width: 5, height: 2)
                    }
                }
                .frame(width: 20)
                Text("\(data.baselineDays)d Baseline").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(avgColor).frame(width: 20, height: 3)
                Text("\(data.averagePeriod)d Avg").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x10B981).opacity(0.3)).frame(width: 20, height: 10)
                Text("Baseline ± 1 SD").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.bottom, 4)
    }

    private func dotColor(_ zone: SDZone) -> Color {
        switch zone {
        case .normal: return Color(hex: 0x10B981)
        case .stress: return Color(hex: 0xFBBF24)
        case .recovery: return Color(hex: 0xF97316)
        }
    }

    private var emptyState: some View {
        Text("No RHR data in selected range")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
