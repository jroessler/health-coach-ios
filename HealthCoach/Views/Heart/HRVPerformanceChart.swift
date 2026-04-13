import SwiftUI
import Charts

struct HRVPerformanceChart: View {
    let data: HRVPerformanceData

    private let lowColor = Color(hex: 0xF97316)
    private let modColor = Color(hex: 0xFBBF24)
    private let highColor = Color(hex: 0x10B981)

    private var xDomain: ClosedRange<Double> {
        let vals = data.points.map(\.hrv)
        guard let lo = vals.min(), let hi = vals.max(), lo < hi else { return 0...100 }
        let span = hi - lo
        return (lo - span * 0.05)...(hi + span * 0.05)
    }

    private var yDomain: ClosedRange<Double> {
        let vals = data.points.map(\.volume)
        guard let lo = vals.min(), let hi = vals.max(), lo < hi else { return 0...10000 }
        let span = hi - lo
        return (max(0, lo - span * 0.05))...(hi + span * 0.1)
    }

    private var regressionPoints: [(x: Double, y: Double)] {
        let xMin = xDomain.lowerBound
        let xMax = xDomain.upperBound
        return [
            (xMin, data.regressionSlope * xMin + data.regressionIntercept),
            (xMax, data.regressionSlope * xMax + data.regressionIntercept)
        ]
    }

    var body: some View {
        if data.points.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                zoneKPICards
                chartContent
            }
        }
    }

    // MARK: - Zone KPI mini-cards

    private var zoneKPICards: some View {
        HStack(spacing: 10) {
            zoneCard(
                title: "Low HRV",
                threshold: "< \(Int(data.p33))ms",
                avgVolume: data.zoneAverages.low,
                baselineVolume: data.zoneAverages.moderate,
                color: lowColor
            )
            zoneCard(
                title: "Moderate HRV",
                threshold: "\(Int(data.p33))–\(Int(data.p66))ms",
                avgVolume: data.zoneAverages.moderate,
                baselineVolume: nil,
                color: modColor
            )
            zoneCard(
                title: "High HRV",
                threshold: "≥ \(Int(data.p66))ms",
                avgVolume: data.zoneAverages.high,
                baselineVolume: data.zoneAverages.moderate,
                color: highColor
            )
        }
    }

    private func zoneCard(
        title: String,
        threshold: String,
        avgVolume: Double,
        baselineVolume: Double?,
        color: Color
    ) -> some View {
        let cardBg = Color(hex: 0x0A1A24)
        let deltaStr: String = {
            guard let base = baselineVolume, base > 0 else { return "baseline" }
            let pct = (avgVolume - base) / base * 100
            return String(format: "%+.0f%% vs baseline", pct)
        }()

        return VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
            Text(threshold)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(volumeLabel(avgVolume))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(deltaStr)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Scatter chart

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Session Volume (kg)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("Morning HRV (ms)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.horizontal, 2)

            Chart {
                // Zone threshold lines
                RuleMark(x: .value("p33", data.p33))
                    .foregroundStyle(modColor.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(Int(data.p33))ms")
                            .font(.system(size: 9))
                            .foregroundStyle(modColor)
                    }

                RuleMark(x: .value("p66", data.p66))
                    .foregroundStyle(highColor.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(Int(data.p66))ms")
                            .font(.system(size: 9))
                            .foregroundStyle(highColor)
                    }

                // Regression line
                ForEach(regressionPoints, id: \.x) { pt in
                    LineMark(
                        x: .value("HRV", pt.x),
                        y: .value("Volume", pt.y)
                    )
                    .foregroundStyle(Color.white.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .interpolationMethod(.linear)
                }

                // Scatter dots colored by zone
                ForEach(data.points) { point in
                    PointMark(
                        x: .value("HRV", point.hrv),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(zoneColor(point.zone))
                    .symbolSize(50)
                    .opacity(zoneOpacity(point.zone))
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
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
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    if let v = value.as(Double.self) {
                        AxisValueLabel {
                            Text(volumeLabel(v))
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 260)

            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(color: lowColor, label: "Low HRV")
            legendDot(color: modColor, label: "Moderate")
            legendDot(color: highColor, label: "High HRV")
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.3)).frame(width: 4, height: 2)
                    }
                }
                Text("Trend").font(.caption2).foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .padding(.bottom, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.85))
        }
    }

    // MARK: - Helpers

    private func zoneColor(_ zone: HRVZone) -> Color {
        switch zone {
        case .low: return lowColor
        case .moderate: return modColor
        case .high: return highColor
        }
    }

    private func zoneOpacity(_ zone: HRVZone) -> Double {
        switch zone {
        case .low: return 0.5
        case .moderate: return 0.7
        case .high: return 1.0
        }
    }

    private func volumeLabel(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v)
    }

    private var emptyState: some View {
        Text("Not enough overlapping HRV + workout data")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
