import SwiftUI
import Charts

struct HRVHistogramChart: View {
    let data: HRVChartData

    private let barColor = Color(hex: 0x60A5FA).opacity(0.7)
    private let goodZoneColor = Color(hex: 0x10B981).opacity(0.10)
    private let stressZoneColor = Color(hex: 0xFBBF24).opacity(0.10)
    private let recoveryZoneColor = Color(hex: 0xF97316).opacity(0.10)

    // Derived from the last available baseline/SD in the dataset
    private var baseline: Double? { data.points.last?.baseline }
    private var sd: Double { data.points.last?.sd ?? 0 }
    private var lower1: Double? { baseline.map { $0 - sd } }
    private var lower2: Double? { baseline.map { $0 - 2 * sd } }

    private struct Bucket: Identifiable {
        let id = UUID()
        let midpoint: Double
        let count: Int
    }

    private var buckets: [Bucket] {
        let vals = data.points.map(\.hrv)
        guard let minV = vals.min(), let maxV = vals.max(), minV < maxV else { return [] }
        let bins = 30
        let binWidth = (maxV - minV) / Double(bins)
        var counts = [Int](repeating: 0, count: bins)
        for v in vals {
            let idx = min(Int((v - minV) / binWidth), bins - 1)
            counts[idx] += 1
        }
        return (0..<bins).map { i in
            Bucket(midpoint: minV + (Double(i) + 0.5) * binWidth, count: counts[i])
        }
    }

    private var xDomain: ClosedRange<Double> {
        let vals = data.points.map(\.hrv)
        guard let lo = vals.min(), let hi = vals.max(), lo < hi else { return 0...100 }
        let pad = (hi - lo) * 0.05
        return (lo - pad)...(hi + pad)
    }

    private var yMax: Double {
        Double(buckets.map(\.count).max() ?? 1) * 1.15
    }

    var body: some View {
        if data.points.count < 3 || buckets.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Count")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("HRV (ms)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.horizontal, 2)

            Chart {
                // Zone background rectangles
                if let lo2 = lower2, let lo1 = lower1 {
                    let xMax = xDomain.upperBound
                    // Good zone (>=lower1)
                    RectangleMark(
                        xStart: .value("x", lo1),
                        xEnd: .value("x", xMax),
                        yStart: .value("y", 0),
                        yEnd: .value("y", yMax)
                    )
                    .foregroundStyle(goodZoneColor)

                    // Stress zone (lower2...lower1)
                    RectangleMark(
                        xStart: .value("x", lo2),
                        xEnd: .value("x", lo1),
                        yStart: .value("y", 0),
                        yEnd: .value("y", yMax)
                    )
                    .foregroundStyle(stressZoneColor)

                    // Recovery zone (<lower2)
                    RectangleMark(
                        xStart: .value("x", xDomain.lowerBound),
                        xEnd: .value("x", lo2),
                        yStart: .value("y", 0),
                        yEnd: .value("y", yMax)
                    )
                    .foregroundStyle(recoveryZoneColor)
                }

                // Histogram bars
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("HRV", bucket.midpoint),
                        y: .value("Count", bucket.count),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(barColor)
                }

                // Reference lines
                if let b = baseline {
                    RuleMark(x: .value("Baseline", b))
                        .foregroundStyle(Color(hex: 0x10B981))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                if let lo1 = lower1 {
                    RuleMark(x: .value("-1 SD", lo1))
                        .foregroundStyle(Color(hex: 0xFBBF24))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                if let lo2 = lower2 {
                    RuleMark(x: .value("-2 SD", lo2))
                        .foregroundStyle(Color(hex: 0xF97316))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: 0...yMax)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
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
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let v = value.as(Int.self) {
                        AxisValueLabel {
                            Text("\(v)")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 240)

            zoneAnnotations
        }
    }

    // Estimate a good bar width from x domain
    private var barWidth: CGFloat {
        guard !buckets.isEmpty else { return 6 }
        let range = xDomain.upperBound - xDomain.lowerBound
        let approxPixelsPerUnit: CGFloat = 2.5
        return max(3, CGFloat(range / Double(30)) * approxPixelsPerUnit)
    }

    private var zoneAnnotations: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                zoneTag(label: "Normal", color: Color(hex: 0x10B981))
                zoneTag(label: "Stress", color: Color(hex: 0xFBBF24))
                zoneTag(label: "Recovery", color: Color(hex: 0xF97316))
            }
            HStack(spacing: 12) {
                if let b = baseline {
                    thresholdTag(label: "Baseline: \(Int(b))ms", color: Color(hex: 0x10B981), dashed: false)
                }
                if let lo1 = lower1 {
                    thresholdTag(label: "-1 SD: \(Int(lo1))ms", color: Color(hex: 0xFBBF24), dashed: true)
                }
                if let lo2 = lower2 {
                    thresholdTag(label: "-2 SD: \(Int(lo2))ms", color: Color(hex: 0xF97316), dashed: true)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func zoneTag(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.5)).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private func thresholdTag(label: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            if dashed {
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 6, height: 2)
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 4, height: 2)
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 4, height: 2)
                }
                .frame(width: 18)
            } else {
                RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 18, height: 2)
            }
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private var emptyState: some View {
        Text("Not enough data for distribution")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 160)
    }
}
