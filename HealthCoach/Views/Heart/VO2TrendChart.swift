import SwiftUI
import Charts

struct VO2TrendChart: View {
    let data: VO2ChartData
    let ageRefs: VO2AgeRefs

    private let baselineColor = Color(hex: 0xA78BFA)
    private let avgColor = Color(hex: 0xA78BFA).opacity(0.7)

    private var dateDomain: ClosedRange<Date> {
        let dates = data.points.map(\.date)
        guard let lo = dates.min(), let hi = dates.max() else { return Date()...Date() }
        return lo...hi
    }

    private var yDomain: ClosedRange<Double> {
        var vals = data.points.map(\.vo2Max)
        vals += data.points.compactMap(\.vo214d)
        vals += data.points.compactMap(\.baseline)
        vals.append(ageRefs.below - 5)
        vals.append(ageRefs.elite + 5)
        guard let lo = vals.min(), let hi = vals.max() else { return 20...65 }
        let span = hi - lo
        let pad = max(span * 0.05, 2)
        return (max(0, lo - pad))...(hi + pad)
    }

    private var axisStride: Int {
        NutritionChartAxisMetrics.dateStrideDays(from: dateDomain.lowerBound, through: dateDomain.upperBound)
    }

    var body: some View {
        if data.points.count < 2 {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("VO₂ Max (ml/kg/min)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 2)

            Chart {
                // Horizontal colored zone bands
                RectangleMark(
                    xStart: .value("x", dateDomain.lowerBound),
                    xEnd: .value("x", dateDomain.upperBound),
                    yStart: .value("y", yDomain.lowerBound),
                    yEnd: .value("y", ageRefs.below)
                )
                .foregroundStyle(Color(hex: 0xEF4444).opacity(0.07))

                RectangleMark(
                    xStart: .value("x", dateDomain.lowerBound),
                    xEnd: .value("x", dateDomain.upperBound),
                    yStart: .value("y", ageRefs.below),
                    yEnd: .value("y", ageRefs.average)
                )
                .foregroundStyle(Color(hex: 0xF97316).opacity(0.07))

                RectangleMark(
                    xStart: .value("x", dateDomain.lowerBound),
                    xEnd: .value("x", dateDomain.upperBound),
                    yStart: .value("y", ageRefs.average),
                    yEnd: .value("y", ageRefs.elite)
                )
                .foregroundStyle(Color(hex: 0x10B981).opacity(0.07))

                RectangleMark(
                    xStart: .value("x", dateDomain.lowerBound),
                    xEnd: .value("x", dateDomain.upperBound),
                    yStart: .value("y", ageRefs.elite),
                    yEnd: .value("y", yDomain.upperBound)
                )
                .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.07))

                // Reference lines
                RuleMark(y: .value("Below avg", ageRefs.below))
                    .foregroundStyle(Color(hex: 0xEF4444).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .leading) {
                        Text("\(Int(ageRefs.below))")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: 0xEF4444))
                    }

                RuleMark(y: .value("Avg ceiling", ageRefs.average))
                    .foregroundStyle(Color(hex: 0xF97316).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .leading) {
                        Text("\(Int(ageRefs.average))")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: 0xF97316))
                    }

                RuleMark(y: .value("Elite", ageRefs.elite))
                    .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .leading) {
                        Text("\(Int(ageRefs.elite))")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: 0xFBBF24))
                    }

                // Daily dots
                ForEach(data.points) { point in
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("VO₂", point.vo2Max)
                    )
                    .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.45))
                    .symbolSize(22)
                }

                // 14d rolling avg (dashed)
                ForEach(data.points) { point in
                    if let v14 = point.vo214d {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("14d Avg", v14),
                            series: .value("S", "14d")
                        )
                        .foregroundStyle(avgColor)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .interpolationMethod(.linear)
                    }
                }

                // 30d baseline
                ForEach(data.points) { point in
                    if let bl = point.baseline {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Baseline", bl),
                            series: .value("S", "Baseline")
                        )
                        .foregroundStyle(baselineColor)
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
            zoneLegend
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(baselineColor).frame(width: 20, height: 3)
                Text("\(data.baselineDays)d Baseline").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(avgColor).frame(width: 5, height: 2)
                    }
                }
                .frame(width: 20)
                Text("\(data.averagePeriod)d Avg").font(.caption2).foregroundStyle(Color.white.opacity(0.85))
            }
        }
    }

    private var zoneLegend: some View {
        HStack(spacing: 10) {
            zoneTag(label: "Below avg", color: Color(hex: 0xEF4444))
            zoneTag(label: "Average", color: Color(hex: 0xF97316))
            zoneTag(label: "Above avg", color: Color(hex: 0x10B981))
            zoneTag(label: "Elite", color: Color(hex: 0xFBBF24))
        }
        .padding(.bottom, 4)
    }

    private func zoneTag(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.5)).frame(width: 10, height: 10)
            Text(label).font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private var emptyState: some View {
        Text("No VO₂ Max data in selected range")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
