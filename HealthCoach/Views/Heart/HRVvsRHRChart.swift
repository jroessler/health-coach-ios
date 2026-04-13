import SwiftUI
import Charts

// Dual-axis HRV + RHR chart using ZStack of two Chart layers.
// Left axis = HRV (ms), Right axis = RHR (bpm).
//
// Both layers declare BOTH y-axes (leading + trailing) — the non-primary
// side uses opacity(0) labels so plot areas are identical in width,
// exactly matching the WeightTrendsChart alignment pattern.

struct HRVvsRHRChart: View {
    let hrv: HRVChartData
    let rhr: RHRChartData

    private let hrvColor = Color(hex: 0x60A5FA)
    private let rhrColor = Color(hex: 0xEF4444)

    private var dateDomain: ClosedRange<Date> {
        let dates = hrv.points.map(\.date) + rhr.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else { return Date()...Date() }
        return lo...hi
    }

    private var hrvDomain: ClosedRange<Double> {
        var vals = hrv.points.map(\.hrv)
        vals += hrv.points.compactMap(\.hrv7d)
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 0...100 }
        let span = hi - lo
        let pad = max(span * 0.1, 3)
        return (lo - pad)...(hi + pad)
    }

    private var rhrDomain: ClosedRange<Double> {
        var vals = rhr.points.map(\.rhr)
        vals += rhr.points.compactMap(\.rhr7d)
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 40...90 }
        let span = hi - lo
        let pad = max(span * 0.1, 2)
        return (lo - pad)...(hi + pad)
    }

    private var axisStride: Int {
        NutritionChartAxisMetrics.dateStrideDays(from: dateDomain.lowerBound, through: dateDomain.upperBound)
    }

    var body: some View {
        if hrv.points.isEmpty && rhr.points.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("HRV (ms)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(hrvColor.opacity(0.8))
                Spacer()
                Text("RHR (bpm)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(rhrColor.opacity(0.8))
            }
            .padding(.horizontal, 2)

            ZStack {
                // RHR layer (back, right y-axis) — must be rendered first
                rhrLayer
                // HRV layer (front, left y-axis)
                hrvLayer
            }
            .frame(height: 280)

            legend
        }
    }

    // HRV: real leading axis, invisible trailing axis (keeps plot width identical to rhrLayer)
    private var hrvLayer: some View {
        Chart {
            ForEach(hrv.points) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("HRV", point.hrv)
                )
                .foregroundStyle(hrvColor.opacity(0.35))
                .symbolSize(18)
            }
            ForEach(hrv.points) { point in
                if let avg = point.hrv7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV 7d", avg)
                    )
                    .foregroundStyle(hrvColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: hrvDomain)
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
            // Real leading labels (HRV values)
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .foregroundStyle(hrvColor.opacity(0.8))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .trailing)
                    }
                }
            }
            // Invisible trailing labels — match rhrLayer width so plot areas align
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .opacity(0)
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    // RHR: real trailing axis, invisible leading axis (keeps plot width identical to hrvLayer)
    private var rhrLayer: some View {
        Chart {
            ForEach(rhr.points) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("RHR", point.rhr)
                )
                .foregroundStyle(rhrColor.opacity(0.35))
                .symbolSize(18)
            }
            ForEach(rhr.points) { point in
                if let avg = point.rhr7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("RHR 7d", avg)
                    )
                    .foregroundStyle(rhrColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.linear)
                }
            }
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: rhrDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            // Invisible leading labels — match hrvLayer width so plot areas align
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
            // Real trailing labels (RHR values)
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                            .foregroundStyle(rhrColor.opacity(0.8))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .allowsHitTesting(false)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(hrvColor).frame(width: 20, height: 3)
                Text("HRV \(hrv.averagePeriod)d Avg").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(rhrColor).frame(width: 20, height: 3)
                Text("RHR \(rhr.averagePeriod)d Avg").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        Text("No HRV or RHR data in selected range")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
