import SwiftUI
import Charts

// Dual-axis: left = VO2 absolute (ml/min) + VO2/kg baseline scaled
//            right = body weight (kg)

struct VO2WeightChart: View {
    let data: VO2WeightData

    private let vo2AbsColor = Color(hex: 0xA78BFA)
    private let vo2ScaledColor = Color(hex: 0x38BDF8)
    private let weightColor = Color(hex: 0xFBBF24)

    private var dateDomain: ClosedRange<Date> {
        let dates = data.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else { return Date()...Date() }
        return lo...hi
    }

    private var vo2Domain: ClosedRange<Double> {
        var vals = data.points.compactMap(\.vo2Absolute14d)
        let avgWeight = data.points.compactMap(\.weightFfill).mean()
        vals += data.points.compactMap(\.vo2Baseline).map { $0 * avgWeight }
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 0...5000 }
        let span = hi - lo
        let pad = max(span * 0.08, 50)
        return (max(0, lo - pad))...(hi + pad)
    }

    private var weightDomain: ClosedRange<Double> {
        var vals = data.points.compactMap(\.weightKg)
        vals += data.points.compactMap(\.weight7d)
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 50...100 }
        let span = hi - lo
        let pad = max(span * 0.1, 2)
        return (lo - pad)...(hi + pad)
    }

    private var axisStride: Int {
        NutritionChartAxisMetrics.dateStrideDays(from: dateDomain.lowerBound, through: dateDomain.upperBound)
    }

    private var avgWeight: Double {
        data.points.compactMap(\.weightFfill).mean()
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
                Text("VO₂ Capacity (ml/min)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("Weight (kg)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.horizontal, 2)

            ZStack {
                weightLayer
                vo2Layer
            }
            .frame(height: 280)

            legend
        }
    }

    private var vo2Layer: some View {
        Chart {
            // Absolute VO2 14d avg
            ForEach(data.points) { point in
                if let abs14d = point.vo2Absolute14d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Abs VO₂ 14d", abs14d),
                        series: .value("S", "abs14d")
                    )
                    .foregroundStyle(vo2AbsColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.linear)
                }
            }

            // VO2/kg baseline scaled by avg weight
            ForEach(data.points) { point in
                if let bl = point.vo2Baseline {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("VO₂/kg scaled", bl * avgWeight),
                        series: .value("S", "scaled")
                    )
                    .foregroundStyle(vo2ScaledColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: vo2Domain)
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
            // Real leading labels (absolute VO₂ ml/min)
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .trailing)
                    }
                }
            }
            // Invisible trailing labels — keeps plot width identical to weightLayer
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                            .opacity(0)
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    private var weightLayer: some View {
        Chart {
            // Daily weight dots
            ForEach(data.points) { point in
                if let w = point.weightKg {
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Weight", w)
                    )
                    .foregroundStyle(weightColor.opacity(0.3))
                    .symbolSize(14)
                }
            }
            // Weight 7d avg
            ForEach(data.points) { point in
                if let w7 = point.weight7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Weight 7d", w7)
                    )
                    .foregroundStyle(weightColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: weightDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            // Invisible leading labels — keeps plot width identical to vo2AbsLayer
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .opacity(0)
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .trailing)
                    }
                }
            }
            // Real trailing labels (weight kg)
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                            .foregroundStyle(weightColor.opacity(0.8))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .allowsHitTesting(false)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(vo2AbsColor).frame(width: 20, height: 3)
                Text("Absolute VO₂ 14d Avg (ml/min)").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(vo2ScaledColor).frame(width: 5, height: 2)
                    }
                }
                .frame(width: 20)
                Text("VO₂/kg Baseline (scaled)").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(weightColor).frame(width: 20, height: 3)
                Text("Weight 7d Avg (kg)").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        Text("Not enough data for this chart")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}

private extension Array where Element == Double {
    func mean() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
