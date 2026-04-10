import SwiftUI
import Charts

struct WeightTrendsChart: View {
    let data: WeightTrendsData

    private let weightColor = Color(hex: 0x1E3A8A)
    private let ffmColor = Color(hex: 0x065F46)
    private let fatColor = Color(hex: 0x991B1B)

    private var labelWeight: String { "Weight (\(data.effectiveDays)d avg)" }
    private var labelFFM: String { "FFM (\(data.effectiveDays)d avg)" }
    private var labelBodyFat: String { "Body Fat (\(data.effectiveDays)d avg)" }

    private var dateDomain: ClosedRange<Date> {
        let dates = data.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else {
            return Date()...Date()
        }
        return lo...hi
    }

    private var kgDomain: ClosedRange<Double> {
        var v: [Double] = []
        for p in data.points {
            if let w = p.weightRolling7d { v.append(w) }
            if let f = p.ffmRolling7d { v.append(f) }
        }
        guard let lo = v.min(), let hi = v.max(), !v.isEmpty else { return 60...100 }
        if lo == hi {
            return (lo - 2)...(hi + 2)
        }
        let span = hi - lo
        let pad = max(span * 0.08, 0.6)
        return (lo - pad)...(hi + pad)
    }

    private var pctDomain: ClosedRange<Double> {
        let v = data.points.compactMap { $0.fatPctRolling7d }
        guard let lo = v.min(), let hi = v.max(), !v.isEmpty else { return 0...40 }
        if lo == hi {
            return (lo - 1)...(hi + 1)
        }
        let span = hi - lo
        let pad = max(span * 0.12, 0.2)
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
            HStack(alignment: .firstTextBaseline) {
                Text("Weight & FFM (kg)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Body Fat (%)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 2)

            ZStack {
                bodyFatLayer
                weightAndFFMLayer
            }
            .frame(height: 300)
            .clipped()

            customLegend
        }
    }

    private var bodyFatLayer: some View {
        Chart {
            ForEach(data.points) { point in
                if let bf = point.fatPctRolling7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("%", bf),
                        series: .value("Series", labelBodyFat)
                    )
                    .foregroundStyle(by: .value("Series", labelBodyFat))
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartForegroundStyleScale([labelBodyFat: fatColor])
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: pctDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                            .monospacedDigit()
                            .opacity(0)
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .trailing)
                    }
                }
            }
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: axisStride)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.clear)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        NutritionChartDateAxisLabel.make(date)
                            .font(.caption2)
                            .foregroundStyle(Color.clear)
                            .frame(height: NutritionChartAxisMetrics.xAxisLabelHeight)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .allowsHitTesting(false)
    }

    private var weightAndFFMLayer: some View {
        Chart {
            ForEach(data.points) { point in
                if let w = point.weightRolling7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("kg", w),
                        series: .value("Series", labelWeight)
                    )
                    .foregroundStyle(by: .value("Series", labelWeight))
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .interpolationMethod(.linear)
                }

                if let ffm = point.ffmRolling7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("kg", ffm),
                        series: .value("Series", labelFFM)
                    )
                    .foregroundStyle(by: .value("Series", labelFFM))
                    .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartForegroundStyleScale([
            labelWeight: weightColor,
            labelFFM: ffmColor,
        ])
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: kgDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .trailing)
                    }
                }
            }
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .monospacedDigit()
                            .opacity(0)
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
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
        .chartLegend(.hidden)
    }

    private var customLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            legendRow(color: weightColor, title: labelWeight)
            legendRow(color: ffmColor, title: labelFFM)
            legendRow(color: fatColor, title: labelBodyFat)
        }
        .font(.caption2)
        .foregroundStyle(Color.white.opacity(0.85))
        .padding(.bottom, 8)
    }

    private func legendRow(color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 20, height: 3)
            Text(title)
        }
    }

    private var emptyState: some View {
        Text("No scale data in date range")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
