import SwiftUI
import Charts

struct PreWorkoutChart: View {
    let points: [PreWorkoutPoint]
    let targets: PreWorkoutTargets?

    private let trendName = "Trend (protein vs timing)"

    var body: some View {
        if points.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                RectangleMark(
                    xStart: .value("lo", 60),
                    xEnd: .value("hi", 120),
                    yStart: nil,
                    yEnd: nil
                )
                .foregroundStyle(Color(hex: 0x10B981, opacity: 0.08))

                if let t = targets {
                    RuleMark(y: .value("Protein target", t.proteinTargetG))
                        .foregroundStyle(Color(hex: 0x3B82F6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .annotation(position: .topLeading) {
                            Text("Protein: \(Int(t.proteinTargetG))g")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: 0x3B82F6))
                        }

                    RuleMark(y: .value("Carbs target", t.carbsTargetG))
                        .foregroundStyle(Color(hex: 0x10B981))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .annotation(position: .bottomTrailing) {
                            Text("Carbs: \(Int(t.carbsTargetG))g")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: 0x10B981))
                        }
                }

                if let seg = trendSegment {
                    LineMark(
                        x: .value("Minutes Before", seg.x0),
                        y: .value("Protein (g)", seg.y0),
                        series: .value("Series", trendName)
                    )
                    .foregroundStyle(by: .value("Series", trendName))
                    LineMark(
                        x: .value("Minutes Before", seg.x1),
                        y: .value("Protein (g)", seg.y1),
                        series: .value("Series", trendName)
                    )
                    .foregroundStyle(by: .value("Series", trendName))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(points) { point in
                    PointMark(
                        x: .value("Minutes Before", point.minutesBefore),
                        y: .value("Protein (g)", point.proteinG)
                    )
                    .foregroundStyle(color(for: point.timingQuality))
                    .symbolSize(markerSize(carbsG: point.carbsG))
                }
            }
            .chartForegroundStyleScale([
                trendName: Color.white.opacity(0.55),
            ])
            .chartXScale(domain: .automatic(includesZero: true, reversed: true))
            .chartXAxisLabel("Minutes Before Workout")
            .chartYAxisLabel("Protein (g)")
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.6))
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
            .chartLegend(position: .bottom, spacing: 12)
            .frame(height: 300)

            legend
        }
    }

    private var trendSegment: (x0: Double, y0: Double, x1: Double, y1: Double)? {
        let xs = points.map { Double($0.minutesBefore) }
        let ys = points.map(\.proteinG)
        guard let fit = ChartLinearRegression.slopeIntercept(xs: xs, ys: ys) else { return nil }
        let xLo = xs.min() ?? 0
        let xHi = xs.max() ?? 0
        guard xHi > xLo else { return nil }
        let y0 = fit.slope * xLo + fit.intercept
        let y1 = fit.slope * xHi + fit.intercept
        return (xLo, y0, xHi, y1)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: color(for: .good), label: "60–120 min")
            legendItem(color: color(for: .ok), label: "<60 min")
            legendItem(color: color(for: .bad), label: ">120 min")
        }
        .font(.caption2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.white.opacity(0.6))
        }
    }

    private func color(for quality: WorkoutTimingQuality) -> Color {
        switch quality {
        case .good: return .kpiGood
        case .ok: return .kpiOk
        case .bad: return .kpiBad
        }
    }

    private func markerSize(carbsG: Double) -> CGFloat {
        let raw = max(carbsG, 5) / 3 + 8
        return CGFloat(raw * raw * 0.3)
    }

    private var emptyState: some View {
        Text("No pre-workout nutrition data found")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}
