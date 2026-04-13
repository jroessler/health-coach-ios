import SwiftUI
import Charts

// Dual-axis: left = HRV (ms), right = Training volume (kg)
// Volume bars represent 1–2 day lagged training volume.

struct HRVTrainingVolumeChart: View {
    let data: HRVVolumeData

    private let hrvColor = Color(hex: 0x22D3EE)
    private let volumeBarColor = Color(hex: 0x22D3EE).opacity(0.12)
    private let volumeBarBorder = Color(hex: 0x22D3EE).opacity(0.3)

    private var dateDomain: ClosedRange<Date> {
        let dates = data.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else { return Date()...Date() }
        return lo...hi
    }

    private var hrvDomain: ClosedRange<Double> {
        var vals = data.points.compactMap(\.hrv)
        vals += data.points.compactMap(\.hrv7d)
        guard let lo = vals.min(), let hi = vals.max(), !vals.isEmpty else { return 0...100 }
        let span = hi - lo
        let pad = max(span * 0.1, 3)
        return (lo - pad)...(hi + pad)
    }

    private var volDomain: ClosedRange<Double> {
        let vals = data.points.compactMap(\.laggedVolume)
        guard let hi = vals.max(), hi > 0 else { return 0...10000 }
        return 0...(hi * 1.2)
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
                Text("HRV (ms)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(hrvColor.opacity(0.8))
                Spacer()
                Text("Volume (kg)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 2)

            ZStack {
                volumeLayer
                hrvLayer
            }
            .frame(height: 260)

            legend
        }
    }

    // Volume bars on right axis (rendered behind)
    private var volumeLayer: some View {
        Chart {
            ForEach(data.points) { point in
                if let vol = point.laggedVolume, vol > 0 {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Volume", vol)
                    )
                    .foregroundStyle(volumeBarColor)
                }
            }
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: volDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            // Invisible leading labels — keeps plot width identical to hrvLayer
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
            // Real trailing labels (volume)
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(volumeLabel(v))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.3))
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .allowsHitTesting(false)
    }

    // HRV dots + line on left axis
    private var hrvLayer: some View {
        Chart {
            // Raw dots
            ForEach(data.points) { point in
                if let hrv = point.hrv {
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", hrv)
                    )
                    .foregroundStyle(hrvColor.opacity(0.35))
                    .symbolSize(16)
                }
            }

            // 7d rolling avg line
            ForEach(data.points) { point in
                if let avg = point.hrv7d {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV 7d", avg)
                    )
                    .foregroundStyle(hrvColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
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
            // Real leading labels (HRV ms)
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
            // Invisible trailing labels — keeps plot width identical to volumeLayer
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(volumeLabel(v))
                            .font(.caption2)
                            .opacity(0)
                            .frame(width: NutritionChartAxisMetrics.yAxisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    private func volumeLabel(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(hrvColor).frame(width: 20, height: 3)
                Text("HRV \(data.averagePeriod)d Avg").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(volumeBarColor).frame(width: 16, height: 12)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(volumeBarBorder, lineWidth: 1))
                Text("Volume (1–2d prior)").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        Text("No HRV or training data in selected range")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
